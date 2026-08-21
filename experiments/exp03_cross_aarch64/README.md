# exp03 — cross_aarch64

## 질문

exp01의 **같은 소스**를, BUILD 파일을 고치지 않고 플래그만 바꿔서 aarch64로 빌드할 수 있는가.

크로스컴파일을 CMake 툴체인 파일로 해본 사람에게 Bazel의 방식은 낯설다.
Bazel은 "플랫폼(platform)"과 "툴체인(toolchain)"이라는 개념으로 이걸 푼다 —
타깃 플랫폼을 선언하면 Bazel이 그 플랫폼에 맞는 툴체인을 **자동으로 고른다**.
이 구조가 왜 필요한지는 타깃이 두 종류 이상 되는 순간 알게 된다.

## 방법

두 경로가 있다. **A는 완료, B는 미완**이다.

### A. 시스템 크로스 툴체인 (빠르지만 hermetic 하지 않다) — 완료

```bash
sudo apt install -y gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

그리고 툴체인을 직접 정의한다. 이게 exp03의 실제 학습 내용이다:

- `platforms/BUILD.bazel` — `linux_aarch64` 플랫폼 (cpu·os constraint)
- `toolchains/aarch64/cc_toolchain_config.bzl` — 도구 경로, 컴파일/링크 플래그,
  **`cxx_builtin_include_directories`**
- `toolchains/aarch64/BUILD.bazel` — `cc_toolchain` + `toolchain` 등록
- `MODULE.bazel` — `register_toolchains(...)`

```bash
bazel build --platforms=//platforms:linux_aarch64 //experiments/exp01_bazel_hello:hello
file bazel-out/linux_aarch64-fastbuild/bin/experiments/exp01_bazel_hello/hello
```

### B. `toolchains_llvm` + sysroot (hermetic) — 미완

Bazel이 LLVM 툴체인과 sysroot를 직접 내려받게 해서 호스트에 무엇이 깔렸든 같은
결과가 나오게 하는 경로. ⚠️ 버전 번호는 **Bazel Central Registry에서 직접 확인할 것.**

## 합격 기준

1. `file` 출력에 `ARM aarch64`가 나온다.
2. **BUILD 파일과 소스를 전혀 수정하지 않았다** (`--platforms`만 바꿨다).
3. 호스트 빌드와 aarch64 빌드가 **같은 캐시를 오염시키지 않는다**
   (두 산출물이 서로 다른 `bazel-out/<config>` 아래에 공존한다).
4. B 경로에서, 호스트에 `gcc-aarch64-linux-gnu`가 **없어도** 빌드가 성공한다.

## 관찰 (2026-08-18 실측)

환경: WSL2 Ubuntu 26.04 / Bazel 7.4.1 / `aarch64-linux-gnu-gcc 15.2.0`

```
ELF 64-bit LSB pie executable, ARM aarch64, dynamically linked,
interpreter /lib/ld-linux-aarch64.so.1
```

`cquery`로 `//toolchains/aarch64:aarch64_cc_toolchain`이 선택된 것을,
`aquery`로 `/usr/bin/aarch64-linux-gnu-gcc`가 실제 실행된 것을 확인했다.
**실험 소스와 BUILD 파일은 한 줄도 고치지 않았다** — `--platforms`만 바꿨다.

QEMU에서도 돌았다 (exp04 미리보기):

```
$ qemu-aarch64 -L /usr/aarch64-linux-gnu <binary> cross
hello, cross
arch=aarch64
```

### 🔴 걸린 문제: 두 configuration 이 같은 디렉터리에서 충돌한다

기본 설정에서는 **호스트 빌드와 aarch64 빌드가 둘 다 `bazel-out/k8-fastbuild/`로 들어간다.**

| | 출력 디렉터리 | 산출물 |
|---|---|---|
| 호스트 빌드 후 | `bazel-out/k8-fastbuild/` | x86-64 |
| aarch64 빌드 후 | `bazel-out/k8-fastbuild/` | **ARM aarch64 (덮어씀)** |

출력 디렉터리 이름이 **레거시 `--cpu` 값(기본 `k8`)에서 오기 때문**이다.
`--platforms`는 이 값을 갱신하지 않는다. 액션 캐시는 키가 달라 양쪽 다 살아 있지만
(전환 시 전량 재컴파일은 없었다), **출력 트리는 매번 다시 깔린다.**

해결책 두 가지를 다 확인했다:

| 방법 | 결과 |
|---|---|
| `--experimental_platform_in_output_dir` | `k8-fastbuild` + **`linux_aarch64-fastbuild`** 공존 |
| `--platform_suffix=_aarch64` | `k8-fastbuild` + `k8-fastbuild-_aarch64` (예전 방식) |

앞의 것을 `.bazelrc`에 넣었다. 적용 후 호스트 ↔ aarch64 **전환 비용은 0.2초**,
재실행되는 액션 없음.

> 💡 곁가지: `bazel-out`은 **심볼릭 링크**다. `rm -rf bazel-out` 해도 실제 출력은
> 안 지워진다. 지우려면 `bazel clean`을 써야 한다. 실험 중 이걸로 한 번 헷갈렸다.

## 알아둘 것

- ⚠️ `toolchains_llvm`의 버전 번호는 **직접 확인해서 채울 것**. 이 문서에 적힌 버전을
  그대로 믿지 말 것 (Bazel Central Registry에서 현재 버전 확인).
- `bazel-out/k8-fastbuild/` vs `bazel-out/aarch64-fastbuild/` — 디렉터리 이름이
  configuration을 담는다. 이게 3번 합격 기준의 근거다.
- Yocto가 만들어주는 SDK(`populate_sdk`)도 sysroot 공급원이 될 수 있다 → exp06과 연결.

## 결과

**통과 (A 2026-08-18 / B 2026-08-21)** — 기준 1~3은 A 경로, 기준 4는 B 경로로 충족.
`bash check.sh`는 A 경로를 자동 검증한다(B는 Yocto SDK 설치가 전제라 자동화에서 제외).
