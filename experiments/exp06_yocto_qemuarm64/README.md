# exp06 — yocto_qemuarm64

## 질문

Yocto로 aarch64 타깃 이미지를 빌드하고, **내가 만든 바이너리를 그 이미지에 넣어** 부팅시킬 수 있는가.

Bazel이 "애플리케이션을 어떻게 빌드하는가"라면 Yocto는 "그 애플리케이션이 올라갈
**리눅스 자체**를 어떻게 빌드하는가"다. 임베디드 제품에서 둘 다 필요한 이유가 이것이고,
둘의 경계를 어디에 두느냐가 실제 조직의 설계 결정이다.

> ⏱️ **경고: 첫 빌드는 몇 시간, 디스크 50GB+ 를 쓴다.** 다른 실험과 병행해서
> 백그라운드로 돌릴 것. 노트북 배터리로 하지 말 것.

## 방법

```bash
sudo apt install -y gawk wget git diffstat unzip texinfo gcc build-essential \
  chrpath socat cpio python3 python3-pip python3-pexpect xz-utils debianutils \
  iputils-ping python3-git python3-jinja2 libegl1-mesa libsdl1.2-dev \
  python3-subunit zstd liblz4-tool file locales

git clone -b scarthgap git://git.yoctoproject.org/poky
cd poky && source oe-init-build-env

# conf/local.conf 에서 MACHINE ?= "qemuarm64"
bitbake core-image-minimal
runqemu qemuarm64 nographic
```

내 바이너리 넣기 — 레시피를 하나 쓴다:

```
recipes-example/hello/hello_0.1.bb
  -> Bazel 산출물을 가져오거나, 소스를 직접 빌드하도록 작성
  -> IMAGE_INSTALL:append = " hello" 로 이미지에 포함
```

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

미실행.
