# exp06 — yocto_qemuarm64

## 질문

Yocto로 aarch64 타깃 이미지를 빌드하고, **내가 만든 바이너리를 그 이미지에 넣어** 부팅시킬 수 있는가.

Bazel이 "애플리케이션을 어떻게 빌드하는가"라면 Yocto는 "그 애플리케이션이 올라갈
**리눅스 자체**를 어떻게 빌드하는가"다. 임베디드 제품에서 둘 다 필요한 이유가 이것이고,
둘의 경계를 어디에 두느냐가 실제 조직의 설계 결정이다.

> ⏱️ **경고: 첫 빌드는 몇 시간, 디스크 50GB+ 를 쓴다.** 다른 실험과 병행해서
> 백그라운드로 돌릴 것. 노트북 배터리로 하지 말 것.

## 방법

> ⏱️ **첫 빌드는 몇 시간, 디스크 수십 GB를 쓴다.** 백그라운드로 돌리고 다른 일을 할 것.
> 노트북 배터리로 하지 말 것.

### 컨테이너 안에서 돌린다

Yocto는 **검증된 호스트 배포판 목록**(`SANITY_TESTED_DISTROS`)을 갖고 있고,
최신 우분투는 대개 거기에 없다. exp03 B에서 배운 것과 같은 이야기 —
도구를 고정해도 도구가 도는 바닥을 고정하지 않으면 호스트를 탄다.
`docker/Dockerfile.yocto`가 22.04 기반으로 Yocto 호스트 패키지와 UTF-8 로케일을 넣는다.

```bash
docker build -t build-infra:yocto -f docker/Dockerfile.yocto docker/
```

### 소스와 빌드 디렉터리는 저장소 밖에

산출물이 수십 GB라 저장소 안에 두지 않는다.

```bash
mkdir -p ~/yocto && cd ~/yocto
git clone -b scarthgap --depth 1 https://git.yoctoproject.org/poky
```

`scarthgap`(5.0 LTS)을 쓴다. LTS라 재현성이 좋고 22.04 호스트에서 검증돼 있다.

### 설정

`oe-init-build-env`로 빌드 디렉터리를 만든 뒤 `conf/local.conf`에 붙인다:

```
MACHINE ?= "qemuarm64"

# 빌드 디렉터리 밖에 둔다. 이 둘을 팀이 공유하느냐가
# Yocto 빌드 시간을 시간 단위에서 분 단위로 바꾼다.
DL_DIR ?= "/yocto/downloads"
SSTATE_DIR ?= "/yocto/sstate-cache"

# 15GB RAM / 8코어. 기본값(=nproc)은 메모리 스파이크가 커서 낮췄다.
BB_NUMBER_THREADS ?= "6"
PARALLEL_MAKE ?= "-j 6"
```

`MACHINE ??= "qemux86-64"`가 이미 있지만 `?=`가 `??=`보다 우선하므로 qemuarm64가 이긴다.

### 실행

```bash
docker run --rm --user "$(id -u):$(id -g)" -e HOME=/yocto -e USER=builder   -v "$HOME/yocto":/yocto build-infra:yocto   bash -lc "cd /yocto/poky && source oe-init-build-env /yocto/build && bitbake core-image-minimal"
```

### 그다음: SDK 뽑기 (exp03 B 의 해답)

```bash
bitbake -c populate_sdk core-image-minimal
```

크로스 툴체인 + **경로가 자기 완결적인 sysroot**를 한 덩어리로 뽑아준다.
배포판 크로스 패키지를 sysroot로 쓰려다 링커 스크립트의 절대 경로에 막혔던
[exp03 B](../exp03_cross_aarch64/README.md)의 해결 경로가 이것이다.

## 합격 기준

1. `runqemu qemuarm64`로 이미지가 부팅되고 셸이 뜬다.
2. 그 셸에서 `hello`를 실행하면 `arch=aarch64`가 나온다.
3. `bitbake -c populate_sdk core-image-minimal`로 SDK를 뽑고,
   그 sysroot로 exp03의 크로스 빌드가 된다 (Yocto ↔ Bazel 연결).
4. sstate-cache를 지우지 않은 상태의 **재빌드 시간**을 첫 빌드와 비교 기록한다.

## 관찰 (직접 채울 것)

| 항목 | 값 |
|---|---|
| Poky 브랜치 / 릴리스 | |
| 첫 `bitbake` 소요 시간 | |
| 디스크 사용량 (`build/` 전체) | |
| sstate 있는 상태의 재빌드 시간 | |
| `downloads/` 크기 | |
| 막혔던 지점 | |

## 알아둘 것

- **sstate-cache와 downloads가 Yocto 운영의 전부다.** 팀 전체가 이 둘을 공유하느냐가
  빌드 시간을 시간 단위에서 분 단위로 바꾼다. CI에서 이걸 어디에 두느냐가 실무 설계 문제.
- 레이어 우선순위와 `.bbappend`는 "남의 레시피를 고치지 않고 바꾸는" 메커니즘이다.
  게임 엔진에서 미들웨어를 패치 없이 확장하던 것과 발상이 같다.
- Yocto 빌드는 hermetic하지 않다 — 호스트 도구를 상당히 탄다. Bazel과의 철학 차이를
  여기서 체감하게 된다. 기록해둘 것.

## 결과

**진행 중 (2026-08-19 시작)** — `core-image-minimal` 첫 빌드 실행 중.

곁가지로, bitbake가 WSLv2를 감지하고 경고를 냈다:
`You are running bitbake under WSLv2 ... you should optimize your VHDX file
eventually to avoid running out of storage space`.
빌드 산출물이 VHDX를 부풀리고, 파일을 지워도 VHDX는 자동으로 줄지 않는다.
