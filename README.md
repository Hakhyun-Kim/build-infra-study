# Build Infra Study — 임베디드 타깃 빌드·검증 인프라

Bazel · Yocto · 크로스컴파일 · regression farm · CI 파이프라인을
**직접 돌려보고 수치로 확인하는** 공개 학습 저장소.

> 목표: "커밋 하나가 타깃 보드 위에서 검증되기까지"의 전 구간을 한 번씩 손으로 만들어보고,
> 각 구간에서 **무엇이 병목이고 무엇이 신뢰를 잃게 만드는지**를 기록으로 남긴다.

## 왜 이걸 하는가

빌드/CI를 "파이프라인 YAML 짜는 일"로 배우면 규모가 커질 때 무너진다.
실제로 어려운 문제는 따로 있다.

- 빌드가 **재현 가능한가** (같은 입력 → 같은 산출물). 아니라면 테스트 결과는 증거가 아니다.
- 캐시가 **언제 맞고 언제 틀리는가**. 잘못 맞는 캐시는 캐시 없는 것보다 나쁘다.
- 실기기 테스트가 **왜 깨지는가**. 코드 때문인가, 디바이스 상태 때문인가.
- 싼 계층(호스트/QEMU)의 결과가 비싼 계층(실기기)을 **얼마나 예측하는가**.

이 저장소는 이 네 질문을 실험으로 쪼갠 것이다.

## 환경

| 항목 | 값 |
|---|---|
| 대상 OS | Ubuntu (22.04+) — 네이티브 또는 WSL2 |
| 호스트 아키텍처 | x86_64 |
| 타깃 아키텍처 | aarch64 (Linux) |
| 빌드 | Bazel (bazelisk로 버전 고정), Yocto/BitBake |
| 타깃 실행 | QEMU (user 모드 / system 모드) |
| 컨테이너 | Docker |

> ⚠️ **Windows에서는 안 돌아간다.** Bazel의 크로스컴파일 툴체인, Yocto, QEMU 모두
> 리눅스 전제다. Windows 머신이라면 WSL2 우분투 안에서, 저장소도 WSL 파일시스템
> (`~/build-infra-study`)에 두고 작업할 것 — `/mnt/d/` 경로에 두면 파일 I/O가
> 몇 배 느려져 빌드 시간 측정이 무의미해진다.

```bash
bash scripts/bootstrap_ubuntu.sh   # bazelisk, qemu, 빌드 도구 설치
```

## 설계 선택

처음 계획과 다르게 간 부분은 이유를 남겨둔다.

| 항목 | 선택 | 대신 고려한 것 | 이유 |
|---|---|---|---|
| 빌드 시스템 | Bazel 중심 (CMake는 비교군) | CMake만 | 익숙한 쪽은 이미 CMake다. 배워야 하는 건 hermetic 빌드·액션 그래프·remote cache 모델이고 그건 Bazel 쪽에 있다 |
| 저장소 구조 | 단일 Bazel 워크스페이스 + 실험별 패키지 | 실험마다 독립 워크스페이스 | 모노레포여야 exp05(변경 영향 분석)가 성립한다. 실제 조직도 모노레포다 |
| 타깃 실행 | QEMU 먼저, 실기기는 나중 | 처음부터 실보드 | 하드웨어 없이도 "타깃 위에서 돈다"의 90%를 연습할 수 있다. 실기기에서만 드러나는 차이가 무엇인지가 오히려 연구 주제 |
| 결과 기록 | `scripts/verify.py` → `docs/results.json` | 수동 기록 | 실험 합격 기준을 코드로 박아두면 나중에 "그때 진짜 통과했나"를 다시 물을 필요가 없다. `deep-learning-study`의 대시보드와 같은 발상 |
| 언어 | 노트는 한국어, 코드/커밋은 영어 | 전부 영어 | 개념 정리는 모국어가 빠르고, 코드는 그대로 실무에 옮겨야 하니 영어 |

## 실험

각 실험은 **질문 / 방법 / 합격 기준 / 결과**를 갖는다. 합격 기준이 없는 실험은 실험이 아니다.

| # | 실험 | 질문 | 상태 |
|---|---|---|---|
| [01](experiments/exp01_bazel_hello/) | `bazel_hello` | 최소 C++ 타깃을 Bazel로 빌드·테스트하고, 액션 그래프를 눈으로 확인할 수 있는가 | ✅ **통과** (2026-08-18) |
| [02](experiments/exp02_remote_cache/) | `remote_cache` | 캐시가 있을 때와 없을 때 클린 빌드 시간이 얼마나 갈리는가. 캐시 히트는 무엇을 키로 삼는가 | 🟡 **부분 통과** (disk cache 28.9x / remote 보류) |
| [03](experiments/exp03_cross_aarch64/) | `cross_aarch64` | 같은 소스를 `--platforms`만 바꿔 aarch64로 빌드할 수 있는가 | 🟡 **부분 통과** (시스템 툴체인 O, hermetic 미완) |
| [04](experiments/exp04_qemu_device/) | `qemu_device` | 크로스 빌드한 바이너리를 QEMU 타깃에서 실행하고 결과를 수집할 수 있는가 | 미실행 |
| [05](experiments/exp05_test_impact/) | `test_impact` | `bazel query`로 "이 커밋이 영향을 주는 테스트만" 골라낼 수 있는가 | ✅ **통과** (2026-08-18) |
| [06](experiments/exp06_yocto_qemuarm64/) | `yocto_qemuarm64` | Yocto로 타깃 이미지를 빌드하고 그 위에서 내 바이너리를 돌릴 수 있는가 | 🟡 **부분 통과** (부팅 O, sstate 재빌드 8초 / SDK 진행 중) |
| [07](experiments/exp07_ci_pipeline/) | `ci_pipeline` | 위 전부를 GitLab CI 파이프라인 하나로 엮고, 계층별 소요 시간을 측정할 수 있는가 | 미실행 |

결과 갱신:

```bash
python3 scripts/verify.py
```

## 공부 노트

**📚 [notes/](notes/README.md)** — 챕터별 개념 정리와 질문 노트

| 챕터 | 주제 | 상태 |
|---|---|---|
| [ch1 — Bazel의 모델](notes/ch1-bazel-model/README.md) | hermetic 빌드, 액션 그래프, bzlmod, 캐시가 맞는 조건 | 진행 중 |
| [ch2 — 크로스컴파일과 타깃 실행](notes/ch2-cross-and-target/README.md) | 툴체인/플랫폼, sysroot, QEMU user vs system, Yocto SDK | 진행 중 |
| [ch3 — regression farm](notes/ch3-regression-farm/README.md) | 테스트 계층 사다리, 디바이스 상태 관리, flaky, 재현 번들 | 시작 전 |

## 구조

```
experiments/   실험별 코드 + README(질문/방법/합격기준) + check.sh
notes/         챕터별 개념 노트
scripts/       bootstrap_ubuntu.sh, verify.py
docs/          results.json (실험 결과 기록)
```

## 참고

- [Bazel 공식 문서](https://bazel.build/docs)
- [Yocto Project Mega Manual](https://docs.yoctoproject.org/)
- [LAVA — Linaro Automated Validation Architecture](https://docs.lavasoftware.org/lava/) (보드 팜 오케스트레이션의 레퍼런스 모델)
