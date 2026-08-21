# ch2 — 크로스컴파일과 타깃 실행

> 대응 실험: [exp03](../../experiments/exp03_cross_aarch64/),
> [exp04](../../experiments/exp04_qemu_device/), [exp06](../../experiments/exp06_yocto_qemuarm64/)

## 이 챕터의 목표

"호스트에서 빌드해서 타깃에서 돌린다"의 전 구간을 한 번씩 손으로 통과한다.
그리고 **어디까지가 진짜 타깃 검증이고 어디부터가 흉내인지** 선을 그을 수 있게 된다.

## 개념 사전 (채워나갈 것)

| 용어 | 한 줄 정의 | 확인한 곳 |
|---|---|---|
| host / exec / target platform (3종 구분) | host=Bazel이 도는 곳, exec=컴파일러가 도는 곳, target=산출물이 돌 곳. `toolchain` 규칙의 exec/target_compatible_with 가 이것 | exp03 |
| sysroot | 타깃용 헤더·라이브러리 트리. **배포판 크로스 패키지를 그대로 sysroot로 쓰면 깨진다** — 링커 스크립트가 `/` 기준 절대 경로를 담고 있어서 | exp03 B |
| triple (`aarch64-linux-gnu`) | arch-os-abi. 크로스 툴 이름의 접두사이자 sysroot 경로의 키 | exp03 |
| ABI, soft/hard float | | |
| QEMU user mode vs system mode | | |
| binfmt_misc | 커널이 외부 아키텍처 바이너리를 보면 자동으로 에뮬레이터로 넘기는 등록 기구 | exp04 예정 |
| Yocto SDK / `populate_sdk` | 재배치 가능한 sysroot + 툴체인을 뽑아준다. 배포판 크로스 패키지와 달리 링커 스크립트가 sysroot 기준 상대 경로 | exp06 ✅ |
| BSP, machine, layer | | |
| device tree | | |

## Bazel의 플랫폼 모델

Bazel은 플랫폼을 **세 개** 구분한다. 처음엔 과해 보이지만 크로스 빌드에서 필요해진다.

- **host**: Bazel 자신이 도는 곳
- **exec**: 빌드 액션(컴파일러)이 도는 곳
- **target**: 산출물이 실행될 곳

원격 실행에서 exec ≠ host가 되고, 크로스 빌드에서 target ≠ exec가 된다.
CMake의 툴체인 파일이 이 셋을 뭉뚱그리는 것과 대비된다.

## "타깃에서 돌았다"의 층위

| 층 | 무엇을 검증하나 | 무엇을 못 잡나 |
|---|---|---|
| 호스트 x86_64 | 로직 | 아키텍처 의존 전부 |
| QEMU user | 명령어 셋, 정렬, 타입 크기, 엔디언 | 커널, 드라이버, 타이밍 |
| QEMU system | 부팅, 커널·유저스페이스 통합 | 실제 주변장치, 실시간성 |
| 실기기 | 전부 | (재현성이 낮다) |

**아래로 갈수록 신뢰도가 높고 비용도 높다.** 이 표가 ch3 테스트 계층의 근거다.

## 열린 질문

- [ ] 호스트에서는 통과하고 aarch64에서만 깨지는 버그를 **일부러 만들 수 있는가?**
      (정렬, `char`의 부호, `long` 크기, 엄격한 정렬 접근)
      → 이걸 만들 수 있어야 계층별 테스트가 의미 있다는 걸 증명할 수 있다.
- [ ] Yocto SDK의 sysroot를 Bazel 툴체인으로 쓸 수 있는가? 그게 실무의 정답인가?
- [ ] `binfmt_misc` 등록으로 aarch64 바이너리를 투명하게 실행하면
      테스트 러너 설계가 얼마나 단순해지는가?


## exp03에서 실제로 걸린 것

1. **`cxx_builtin_include_directories`를 안 주면 빌드가 거부된다.** Bazel이 시스템
   헤더를 "선언되지 않은 include"로 판정한다. 크로스 툴체인 설정의 첫 관문.
   경로는 `aarch64-linux-gnu-g++ -E -v -xc++ /dev/null`로 뽑는다.
2. **`--platforms`는 출력 디렉터리 이름을 바꾸지 않는다.** 이름은 레거시 `--cpu`에서
   오므로 호스트와 타깃이 같은 `bazel-out/k8-fastbuild/`를 놓고 싸운다.
   `--experimental_platform_in_output_dir`로 해결.
3. **`bazel-out`은 심볼릭 링크다.** `rm -rf`로는 안 지워진다. `bazel clean`을 쓸 것.
4. **hermetic 은 한 번에 달성되지 않는다 — 실제로 여섯 층이었다.** 컴파일러를 고정하면 그 컴파일러가 쓰는
   공유 라이브러리가, 그걸 컨테이너로 덮으면 타깃 libc·CRT가, 그다음엔 sysroot의
   절대 경로가 드러난다. 층마다 하나씩 걷어내야 하고, 어디까지 걷어낼지가 곧
   비용 대비 판단이다. (exp03 B → exp07 → exp06)

## 참고

- [Bazel — Platforms](https://bazel.build/extending/platforms)
- [Bazel — Toolchains](https://bazel.build/extending/toolchains)
- [QEMU User space emulator](https://www.qemu.org/docs/master/user/main.html)
