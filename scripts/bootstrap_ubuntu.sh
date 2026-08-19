#!/usr/bin/env bash
# Ubuntu 22.04+ 개발 환경 준비.
# exp06(Yocto)에 필요한 패키지는 무겁고 느려서 여기 넣지 않았다 - exp06 README 참조.
set -euo pipefail

echo "== apt packages =="
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  git curl wget unzip \
  python3 python3-pip \
  file \
  gcc-aarch64-linux-gnu g++-aarch64-linux-gnu \
  qemu-user \
  qemu-system-arm

echo "== qemu binfmt =="
# 패키지 이름이 릴리스마다 다르다.
#   Ubuntu 24.04 이하 : qemu-user-static
#   Ubuntu 26.04      : qemu-user-binfmt (qemu-user-static 은 가상 패키지가 되어 설치 불가)
# binfmt 등록은 exp04 의 '투명 실행' 경로에만 필요하고,
# qemu-aarch64 를 직접 호출하는 경로는 qemu-user 만으로 된다.
sudo apt-get install -y qemu-user-static \
  || sudo apt-get install -y qemu-user-binfmt \
  || echo "WARN: no binfmt package - exp04 must invoke qemu-aarch64 explicitly"

echo "== bazelisk =="
# bazelisk 는 .bazelversion 을 읽어 해당 Bazel 을 자동으로 내려받아 실행한다.
# Bazel 을 직접 설치하지 않는 이유: 버전 고정이 곧 재현성이다.
if ! command -v bazelisk >/dev/null 2>&1; then
  BAZELISK_URL="https://github.com/bazelbuild/bazelisk/releases/latest/download/bazelisk-linux-amd64"
  sudo curl -fsSL -o /usr/local/bin/bazelisk "$BAZELISK_URL"
  sudo chmod +x /usr/local/bin/bazelisk
  # 'bazel' 이름으로도 부를 수 있게
  sudo ln -sf /usr/local/bin/bazelisk /usr/local/bin/bazel
fi

echo "== versions =="
bazel --version || true
aarch64-linux-gnu-gcc --version | head -1 || true
qemu-aarch64 --version | head -1 || true

cat <<'EOF'

Done.

Next:
  bazel test //experiments/exp01_bazel_hello:greeter_test
  python3 scripts/verify.py

Note: docker is optional and only needed for exp02 (remote cache) and exp07 (CI runner).
Install it separately if you get that far.
EOF
