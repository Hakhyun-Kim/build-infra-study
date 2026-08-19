#!/usr/bin/env bash
# exp01 합격 기준 1~3 자동 검증. 성공하면 exit 0.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

TARGET="//experiments/exp01_bazel_hello:hello"
TEST_TARGET="//experiments/exp01_bazel_hello:greeter_test"
fail=0

echo "[1/3] bazel test"
if bazel test "$TEST_TARGET"; then
  echo "  PASS"
else
  echo "  FAIL: test did not pass"
  fail=1
fi

echo "[2/3] host arch is x86_64"
out="$(bazel run --ui_event_filters=-info,-stdout --noshow_progress "$TARGET" -- checker 2>/dev/null)"
if echo "$out" | grep -q "arch=x86_64"; then
  echo "  PASS"
else
  echo "  FAIL: expected arch=x86_64, got:"
  echo "$out" | sed 's/^/    /'
  fail=1
fi

echo "[3/3] incremental rebuild is a no-op"
bazel build "$TARGET" >/dev/null 2>&1
rebuild="$(bazel build "$TARGET" 2>&1)"
# 변경이 없으면 Bazel 은 내부 액션 1개만 실행한다:
#   "INFO: Build completed successfully, 1 total action"
actions="$(echo "$rebuild" | grep -oE '[0-9]+ total action' | grep -oE '^[0-9]+' | tail -1)"
if [ "${actions:-0}" = "1" ]; then
  echo "  PASS (1 internal action, nothing recompiled)"
else
  echo "  FAIL: expected 1 total action, got '${actions:-none}'"
  fail=1
fi

exit $fail
