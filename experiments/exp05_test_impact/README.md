# exp05 — test_impact

## 질문

"이 커밋이 영향을 주는 테스트만" 골라낼 수 있는가.

regression farm의 비용은 대부분 **돌 필요 없었던 테스트**에서 나온다.
전부 돌리면 안전하지만 느리고, 골라 돌리면 빠르지만 놓칠 수 있다.
Bazel은 의존성 그래프를 알고 있으니 이 질문에 답할 수 있어야 한다.

## 방법

의존 엣지가 있어야 분석할 것이 생긴다. 이 실험용으로 두 번째 패키지를 만들었다:

```
//experiments/exp01_bazel_hello:greeter      (라이브러리)
        ^                          ^
        |                          |
  greeter_test              //experiments/exp05_test_impact:formatter
                                   ^
                                   |
                            formatter_test
```

그리고 `select()` 분기를 하나 넣었다 — `arch_note`는 aarch64에서 다른 소스를 쓴다.
`query`와 `cquery`의 차이를 실증하기 위한 장치다.

```bash
# 파일 경로 -> 라벨 (문자열 조립하지 말 것, Bazel 이 패키지 경계를 안다)
bazel query experiments/exp01_bazel_hello/greeter.cc
#=> //experiments/exp01_bazel_hello:greeter.cc

# 영향받는 테스트
bazel cquery "kind('.*_test rule', rdeps(//..., //experiments/exp01_bazel_hello:greeter.cc))"

# 실제 사용
bash experiments/exp05_test_impact/impacted_tests.sh HEAD~1
```

## 합격 기준

1. `greeter.cc`를 고쳤을 때 → `greeter_test`가 선별 목록에 **포함된다**.
2. 두 번째 패키지의 파일만 고쳤을 때 → `greeter_test`가 목록에서 **빠진다**.
3. BUILD 파일이나 `.bazelrc`를 고쳤을 때 어떻게 되는지 기록한다
   (여기가 함정이다 — 빌드 설정 변경은 모든 것에 영향을 줄 수 있다).
4. 선별 실행이 전체 실행보다 빠르다.

## 관찰 (2026-08-18 실측)

### 선별 결과 표

| 바꾼 파일 | `query` | `cquery` (호스트) |
|---|---|---|
| `exp01:greeter.cc` | greeter_test, formatter_test | greeter_test, formatter_test |
| `exp01:greeter.h` | greeter_test, formatter_test | greeter_test, formatter_test |
| `exp05:formatter.cc` | formatter_test | formatter_test |
| `exp05:arch_note_x86.cc` | formatter_test | formatter_test |
| **`exp05:arch_note_aarch64.cc`** | **formatter_test** | **(없음)** |
| `exp01:main.cc` | (없음) | (없음) |
| **`exp01:BUILD.bazel`** | **Empty results** | **Empty results** |

전체 실행 6.17s vs 테스트 하나만 0.72s.

### 🔴 위험한 쪽은 과다 선택이 아니라 과소 선택이다

두 가지가 나왔는데 성격이 완전히 다르다.

**과다 선택 (`arch_note_aarch64.cc`)** — 호스트 빌드에서는 컴파일되지도 않는 소스인데
`query`는 "formatter_test가 영향받는다"고 답한다. `query`가 configuration을 모르고
`select()`의 **모든 분기**를 의존으로 보기 때문이다. `cquery`는 정확히 비어 있다.
결과는 **필요 없는 테스트를 도는 것** — 돈은 새지만 안전하다.

**과소 선택 (`BUILD.bazel`)** — 이쪽이 진짜 문제다. BUILD 파일을 바꿨을 때
`rdeps` 질의는 **아무것도 반환하지 않는다**(`Empty results`). 파일 단위 역의존 질의에서
BUILD 파일은 그래프의 *노드*가 아니라 그래프를 *정의하는* 것이기 때문이다.
그런데 BUILD 한 줄이 패키지 전체의 의존성·플래그를 바꿀 수 있다.

**즉 "변경된 파일 → 영향받는 테스트"를 순진하게 구현하면, 빌드 설정을 바꾼 커밋에서
테스트를 하나도 안 돌리고 초록불을 준다.** 같은 문제가 `.bzl`, `.bazelrc`,
`MODULE.bazel`, 툴체인·플랫폼 정의에도 똑같이 적용된다.

### 그래서 스크립트는 이렇게 생겼다

[`impacted_tests.sh`](impacted_tests.sh)의 설계 규칙 두 개:

1. **그래프 정의 파일이 하나라도 섞이면 선별을 포기하고 `//...`를 반환한다.**
   (BUILD / `.bzl` / `.bazelrc` / `.bazelversion` / `MODULE.bazel` / `toolchains/` / `platforms/`)
2. **`query`가 아니라 `cquery`를 쓴다.** 과다 선택을 줄인다.

실제 동작:

```
소스만 변경        -> //experiments/exp01_bazel_hello:greeter_test
                      //experiments/exp05_test_impact:formatter_test
BUILD 파일 변경    -> # 그래프 정의 파일이 변경됨 -> 전체 실행
                      //...
```

## 알아둘 것

- **이 기법의 진짜 위험은 "안 도는 테스트"가 아니라 "그래프에 없는 의존성"이다.**
  런타임에만 읽는 설정 파일, 하드코딩된 경로, 외부 서비스는 그래프에 안 잡힌다.
  hermetic 빌드를 강제하는 이유가 여기서 다시 나온다.
- 실무 절충안: 선별 실행은 PR마다, 전체 실행은 야간에. 그리고 **선별이 놓친 실패를
  야간 빌드가 잡았는지 추적**해서 선별 규칙의 신뢰도를 측정한다.
- 선별 실행을 릴리스 근거로 삼으려면 선별 규칙 자체의 신뢰도를 따로 증명해야 한다.

## 결과

**통과 (2026-08-18)** — 기준 1~4 충족. `bash check.sh`가 자동 검증한다.

기준 3(BUILD·`.bazelrc` 변경 시 어떻게 되는가)의 답은 **"아무것도 안 잡힌다"** 였고,
그게 이 실험에서 가장 값진 결과다. 안전한 선별은 그래프 정의 파일을 만나면
포기할 줄 알아야 한다.

**남은 질문**: 선별이 놓친 실패를 야간 전체 실행이 잡았는지 추적해서
**선별 규칙의 신뢰도를 수치로** 만드는 것. 그건 파이프라인이 있어야 하니 exp07에서.
