# exp02 — remote_cache

## 질문

빌드 캐시는 **무엇을 키로 삼는가**, 그리고 캐시가 있고 없고가 클린 빌드 시간을 얼마나 가르는가.
더 중요한 질문: **언제 캐시가 잘못 맞는가.**

CI에서 캐시는 비용의 전부다. 그런데 잘못 맞는 캐시는 캐시 없는 것보다 나쁘다 —
빌드는 빨라지고 결과는 틀린다. Bazel이 이걸 어떻게 방지하는지가 hermetic 빌드의 핵심이다.

## 방법

### 먼저: 측정 가능한 워크로드 만들기

**exp01의 소스 3개로는 캐시를 측정할 수 없다.** 실제로 재보니 클린 빌드 1.33초,
캐시 히트 0.62초로 2.2배밖에 차이가 나지 않았는데, 캐시가 안 듣는 게 아니라
**Bazel의 고정 오버헤드(분석 0.15초 + 서버 왕복)가 측정을 지배**하기 때문이다.
컴파일이 차지하는 비중이 없으면 캐시가 아낄 것도 없다.

그래서 컴파일 비용이 지배하는 워크로드를 생성한다:

```bash
python3 experiments/exp02_remote_cache/gen_workload.py --count 40
```

`<regex>`를 포함하고 템플릿을 인스턴스화하는 번역 단위 40개를 만든다
(`<regex>`는 컴파일이 느리기로 유명하고, 여기서는 그게 목적이다).
생성물은 `.gitignore` 대상 — 스크립트로 재생성되고, 기계가 쓴 파일 80여 개가
저장소의 실제 내용을 덮으면 안 된다.

### 측정

```bash
CACHE=$HOME/.cache/bazel-disk
T=//experiments/exp02_remote_cache/workload:all_workload

bazel clean && time bazel build $T                      # 캐시 없음
bazel clean && time bazel build --disk_cache=$CACHE $T  # 캐시 채우기
bazel clean && time bazel build --disk_cache=$CACHE $T  # 캐시 히트
```

`bazel clean`은 출력만 지우고 서버와 외부 의존성은 남긴다. `--expunge`는 툴체인
재탐지까지 일으켜 노이즈가 섞이므로 캐시 실험에는 `clean`이 맞다.

### 원격 캐시

```bash
docker run -d --name bazel-remote --user "$(id -u):$(id -g)"   -p 9092:8080 -v /tmp/bazel-remote-data:/data   buchgr/bazel-remote-cache --max_size 5

bazel clean && time bazel build --remote_cache=http://localhost:9092 $T
```

⚠️ `--user`가 없으면 컨테이너가 바인드 마운트에 못 쓴다(`mkdir /data/cas.v2: permission denied`).
호스트 디렉터리 소유자와 컨테이너 사용자의 UID가 안 맞는 전형적인 문제.

### 캐시 키 깨뜨리기 (이쪽이 진짜 목적)

```bash
bazel build --disk_cache=$CACHE --copt=-O2 $T                          # 플래그가 키에 있는가
touch experiments/exp02_remote_cache/workload/lib_007.cc               # mtime 이 키에 있는가
PATH=/tmp/extra-bin:$PATH bazel build --disk_cache=$CACHE $T           # 환경이 새는가
PATH=/tmp/extra-bin:$PATH bazel build --noincompatible_strict_action_env --disk_cache=$C2 $T
```

## 합격 기준

1. 캐시 히트 시 클린 빌드 시간이 캐시 없을 때의 **1/3 이하**로 줄어든다.
2. `--copt` 변경 시 캐시가 **맞지 않는다** (액션 키에 플래그가 들어간다는 증거).
3. `touch`만 한 경우 재빌드가 **일어나지 않는다** (mtime이 아니라 내용 해시가 키라는 증거).
4. `--incompatible_strict_action_env` 없이 환경변수를 바꿨을 때의 동작을 기록한다.

## 관찰 (2026-08-18 실측)

환경: WSL2 Ubuntu 26.04, x86_64 8코어, Bazel 7.4.1 / 워크로드 40 라이브러리(컴파일 액션 82개)

| 시나리오 | 시간 | 프로세스 |
|---|---|---|
| 캐시 없음 (클린) 1회차 | 15.71s | 82 linux-sandbox |
| 캐시 없음 (클린) 2회차 | 15.45s | 82 linux-sandbox |
| disk cache 채우기 | 15.55s | 82 linux-sandbox |
| **disk cache 히트** | **0.59s / 0.49s** | **82 disk cache hit** |

→ **28.9배**. 캐시 크기 112M (40 라이브러리 기준).

### 무엇이 액션 키에 들어가는가

| 바꾼 것 | 결과 | 결론 |
|---|---|---|
| 아무것도 (같은 플래그) | 0.84s, 82 hit | 기준선 |
| `--copt=-O2` 추가 | **29.63s, 0 hit** | **컴파일러 플래그는 키에 들어간다** |
| `-O2`로 두 번째 | 0.78s, 82 hit | -O2 판이 따로 캐시됨 |
| 플래그 원복 | 0.52s, 82 hit | **두 설정이 캐시에 공존한다** — 서로를 밀어내지 않는다 |
| `touch` (mtime만) | 0.51s, 82 hit | **mtime은 키가 아니다. 내용 해시다** |

> 곁가지 관찰: `-O2` 빌드는 29.6초로 기본(fastbuild) 15.5초의 약 2배다.
> 최적화는 컴파일 자체를 느리게 만든다 — 최적화 빌드를 CI의 어느 계층에 둘지의 근거.

### 원격 캐시 (bazel-remote, localhost)

| 시나리오 | 시간 | 프로세스 |
|---|---|---|
| 캐시 없음 | 14.78s | 82 linux-sandbox |
| remote 채우기 | 15.93s | 82 linux-sandbox |
| **remote 히트** | **0.58s / 0.50s** | **82 remote cache hit** |
| disk 히트 (비교군) | 0.43s | 82 disk cache hit |

- **업로드 비용은 약 +1.15초(8%)** — 캐시를 채우는 빌드는 그만큼 느리다.
- **loopback에서 remote는 disk보다 0.07~0.15초 느린 정도.** 실제 네트워크에서는
  이 격차가 커지고, 그때부터 "어느 계층에 캐시를 둘 것인가"가 설계 문제가 된다.
- **저장 용량: remote 15M vs disk 112M.** bazel-remote가 zstd로 압축한다
  (기동 로그 `Storage mode: zstd`). 7배 이상 차이 — 팜 규모에서는 무시 못 할 숫자다.

### 🟢 팜이 성립하는 근거: 다른 체크아웃에서도 히트한다

같은 저장소를 **완전히 다른 경로**(`/tmp/other-checkout`)로 클론해 빌드했다.

```
82 remote cache hit  (6.04s, 캐시 없이 같은 빌드는 15.83s)
```

액션 키가 워크스페이스 경로에 묶여 있지 않다는 뜻이고, **이게 빌드 팜의 전제**다.
CI 러너가 매번 새 워크스페이스에 체크아웃해도 이전 빌드의 결과를 그대로 받는다.
(6.04초에는 새 워크스페이스의 서버 기동·분석·툴체인 탐지가 포함돼 있다 — 컴파일은 전부 캐시.)

### `--incompatible_strict_action_env` 가 막는 것

`PATH` 앞에 디렉터리 하나를 추가한 뒤 재빌드했다. 소스는 그대로다.

| 설정 | 결과 |
|---|---|
| strict **켬** (`.bazelrc` 기본값) | **0.66s, 82 hit** — PATH가 바뀌어도 캐시가 산다 |
| strict **끔** (`--noincompatible_strict_action_env`) | **16.82s, 0 hit** — 전부 재컴파일 |

**hermetic 빌드가 캐시에 필요한 이유가 이 표에 다 있다.** strict를 끄면 호스트 환경이
액션 키로 새어 들어가고, 개발자 A와 B의 `PATH`가 다르다는 이유만으로 공유 캐시가
전혀 히트하지 않는다. 개발 머신과 CI 러너 사이라면 더 확실히 어긋난다.
"공유 캐시가 안 듣는다"는 신고가 들어오면 가장 먼저 볼 곳.

## 알아둘 것

- `--execution_log_binary_file`, `bazel aquery`로 액션 키에 무엇이 들어가는지 볼 수 있다.
- 실무에서 캐시 오염의 단골 원인: 절대 경로, 타임스탬프 삽입(`__DATE__`),
  호스트 툴체인 버전, 환경변수. 전부 hermetic 원칙을 깨는 것들이다.
- 재현 가능한 빌드가 중요한 이유는 속도가 아니라 **증거 능력**이다.
  같은 입력이 같은 출력을 낸다고 말할 수 없으면 테스트 결과도 근거가 되지 못한다.

## 결과

**통과 (2026-08-18~19)** — disk cache와 remote cache 모두 확인.

| 항목 | 결과 |
|---|---|
| 캐시 히트 속도 향상 | disk **28.9x**, remote **~28x** |
| 액션 키 구성 | 내용 해시 O, 컴파일러 플래그 O, mtime X, (strict 끄면) 환경변수 O |
| 워크스페이스 경로 독립성 | **O** — 다른 체크아웃에서 82개 전부 히트 |
| 저장 용량 | remote 15M vs disk 112M (zstd 압축) |

`bash check.sh`가 disk cache 기준 네 가지를 자동 검증한다(워크로드 12개 기준).
원격 캐시는 docker 컨테이너가 필요해 자동 검증에서는 제외했다.

**남은 질문**: 실제 네트워크(로컬 LAN, 클라우드)에서의 왕복 비용과,
캐시 서버 자체의 운영 문제(용량 정책, 축출, 가용성). loopback 측정으로는 알 수 없다.
