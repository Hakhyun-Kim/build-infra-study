# exp01 — bazel_hello

## 질문

최소한의 C++ 타깃(라이브러리 · 실행파일 · 테스트)을 Bazel로 빌드·테스트할 수 있는가.
그리고 **Bazel이 실제로 무슨 액션을 실행했는지**를 눈으로 볼 수 있는가.

CMake와의 차이를 처음 체감하는 지점이 여기다. CMake는 빌드 스크립트를 생성해서
make/ninja에 넘기지만, Bazel은 **액션 그래프**를 만들고 그것을 직접 실행한다.
그래서 "무엇이 왜 다시 빌드되는가"를 그래프에 물어볼 수 있다.

## 방법

```bash
cd ~/build-infra-research

# 1. 빌드
bazel build //experiments/exp01_bazel_hello:hello

# 2. 실행
bazel run //experiments/exp01_bazel_hello:hello -- bazel

# 3. 테스트
bazel test //experiments/exp01_bazel_hello:greeter_test

# 4. 의존성 그래프
bazel query 'deps(//experiments/exp01_bazel_hello:hello)'

# 5. 실제 실행되는 액션 (컴파일러 명령줄까지 보인다)
bazel aquery //experiments/exp01_bazel_hello:hello

# 6. 증분 빌드 확인 - 아무것도 안 바꾸고 다시 빌드하면 액션이 0개여야 한다
bazel build //experiments/exp01_bazel_hello:hello
```

## 합격 기준

1. `bazel test`가 exit 0으로 통과한다.
2. `bazel run`의 출력에 `arch=x86_64`가 포함된다 (호스트 빌드이므로).
3. **아무 소스도 바꾸지 않고** 다시 빌드하면 재컴파일이 일어나지 않는다.
4. `greeter.cc`만 고치면 `main.cc`는 **재컴파일되지 않는다** (그래프가 정확하다는 증거).

`bash check.sh`가 1~3번을 자동 검증한다. 4번은 아래 "관찰" 절대로 손으로 확인한다.

## 관찰 (2026-08-18 실측)

환경: WSL2 Ubuntu 26.04 LTS (커널 6.18.33.2), x86_64, 8코어 / Bazel 7.4.1 (bazelisk)

| 항목 | 값 |
|---|---|
| Bazel 버전 | 7.4.1 (`.bazelversion` 대로 bazelisk가 자동 다운로드) |
| 최초 클린 빌드 | **21.8s** (86 packages loaded, 402 targets configured, 10 actions) |
| 증분 빌드(무변경) | **0.75s → 0.31s** (서버 워밍업 후), 1 total action = 내부 액션만 |
| `aquery` 액션 개수 | **8** |
| 테스트 | `greeter_test PASSED in 0.1s` |

재컴파일 입도 (핵심 관찰):

| 무엇을 바꿨나 | 재컴파일된 소스 | 해석 |
|---|---|---|
| `touch greeter.cc` (내용 동일) | **없음** (1 total action) | 재빌드 판단이 **mtime이 아니라 내용 해시**다 |
| `greeter.cc` 내용 변경 | `greeter.cc` 만 | `main.cc`는 건드리지 않음 — 그래프가 정확하다 |
| `main.cc` 내용 변경 | `main.cc` 만 | 대칭 확인 |
| `greeter.h` 내용 변경 | `greeter.cc` + `main.cc` | 헤더는 포함한 모든 곳으로 전파 |

> ⚠️ **측정하다 만난 함정**: 파일을 되돌린 뒤 빌드하지 않고 다음 실험으로 넘어가면,
> 그 되돌림 자체가 다음 빌드에 섞여 들어와 "greeter.cc를 고쳤는데 main.cc도 재컴파일된다"는
> 잘못된 결과가 나온다. 증분 빌드를 측정할 때는 **매 측정 전에 steady state를 확보**해야 한다.
> CI에서 캐시 실험을 할 때 똑같이 당할 수 있는 실수라 기록해둔다.

### `query`가 Windows 타깃을 보여주는 것

`bazel query 'deps(//...:hello)'` 결과에 `@bazel_tools//src/conditions:host_windows`,
`def_parser.exe` 같은 **윈도우 전용 타깃**이 들어 있었다. 리눅스에서 빌드했는데도.

이유: `query`는 **configuration을 모르는** 정적 그래프 질의라 `select()`의 모든 분기를
다 보여준다. 실제로 선택된 것만 보려면 `cquery`를 써야 한다.
→ exp05(변경 영향 분석)에서 `query`로 테스트를 고르면 **실제로는 안 도는 타깃까지
골라낼 수 있다**는 뜻이다. 그때 다시 확인할 것.

## 알아둘 것

- **`bazel-*` 심볼릭 링크**: 워크스페이스 루트에 `bazel-bin`, `bazel-out` 등이 생긴다.
  실제 산출물은 워크스페이스 밖(`~/.cache/bazel/...`)에 있고 이건 링크다.
  `.gitignore`에 넣어둔 이유.
- **`bazel clean` vs `bazel clean --expunge`**: 전자는 출력만, 후자는 외부 의존성
  다운로드까지 지운다. 캐시 실험(exp02)에서 어느 쪽을 쓰느냐가 결과를 바꾼다.
- **테스트 size**: `small/medium/large/enormous`는 타임아웃과 병렬 스케줄링에 쓰인다.
  regression farm에서 이 선언이 곧 자원 배분 정책이 된다.
- 첫 실행은 bazelisk가 Bazel 7.4.1을 내려받느라 몇 분 걸릴 수 있다.

## 결과

**통과 (2026-08-18)** — 합격 기준 1~4 모두 충족.
`bash check.sh`가 1~3을 자동 검증하고, 4번은 위 재컴파일 입도 표로 확인했다.
