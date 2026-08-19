#!/usr/bin/env bash
# exp03 합격 기준 자동 검증 (A 경로: 시스템 크로스 툴체인).
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

T=//experiments/exp01_bazel_hello:hello
P=//platforms:linux_aarch64
fail=0

echo "[1/3] --platforms 만으로 aarch64 산출물이 나오는가"
bazel build --platforms=$P "$T" >/dev/null 2>&1
BIN=$(ls bazel-out/*aarch64*/bin/experiments/exp01_bazel_hello/hello 2>/dev/null | head -1)
if [ -n "$BIN" ] && file -b "$BIN" | grep -q "ARM aarch64"; then
  echo "  PASS ($(file -b "$BIN" | cut -d, -f2 | tr -d ' '))"
else
  echo "  FAIL: aarch64 바이너리를 찾지 못했다"
  fail=1
fi

echo "[2/3] 호스트 빌드와 configuration 이 공존하는가"
bazel build "$T" >/dev/null 2>&1
HOST=$(ls bazel-out/k8-fastbuild/bin/experiments/exp01_bazel_hello/hello 2>/dev/null | head -1)
if [ -n "$HOST" ] && file -b "$HOST" | grep -q "x86-64" && [ -n "$BIN" ] && file -b "$BIN" | grep -q "ARM aarch64"; then
  echo "  PASS (두 출력 트리가 서로를 덮어쓰지 않는다)"
else
  echo "  FAIL: 출력 디렉터리가 충돌한다 - .bazelrc 의"
  echo "        --experimental_platform_in_output_dir 확인"
  fail=1
fi

echo "[3/3] 선택된 툴체인이 실제 크로스 컴파일러인가"
if bazel aquery --platforms=$P "mnemonic(\"CppCompile\", $T)" 2>/dev/null \
     | grep -q "aarch64-linux-gnu-gcc"; then
  echo "  PASS (aarch64-linux-gnu-gcc)"
else
  echo "  FAIL: 호스트 컴파일러가 쓰였을 수 있다"
  fail=1
fi

exit $fail
