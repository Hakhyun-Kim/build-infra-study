#!/usr/bin/env bash
# exp02 합격 기준 자동 검증 (disk cache 부분).
# remote cache(docker)는 별도 - 여기서는 검증하지 않는다.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

D=experiments/exp02_remote_cache
T=//experiments/exp02_remote_cache/workload:all_workload
CACHE="$(mktemp -d)"
fail=0

cleanup() { rm -rf "$CACHE"; }
trap cleanup EXIT

# 검증은 빨라야 하니 작은 워크로드로. README 의 수치는 40개 기준이다.
python3 "$D/gen_workload.py" --count 12 >/dev/null || { echo "  FAIL: workload generation"; exit 1; }

elapsed() {
  local s e
  s=$(date +%s.%N); "$@" >/tmp/exp02_out 2>&1; e=$(date +%s.%N)
  echo "$e - $s" | bc
}
hits() { grep -oE '[0-9]+ disk cache hit' /tmp/exp02_out | grep -oE '^[0-9]+' | tail -1; }

echo "[1/4] 캐시 히트가 캐시 없음보다 3배 이상 빠른가"
bazel clean >/dev/null 2>&1; COLD=$(elapsed bazel build "$T")
bazel clean >/dev/null 2>&1; elapsed bazel build --disk_cache="$CACHE" "$T" >/dev/null
bazel clean >/dev/null 2>&1; WARM=$(elapsed bazel build --disk_cache="$CACHE" "$T")
RATIO=$(echo "scale=2; $COLD / $WARM" | bc)
if [ "$(echo "$RATIO >= 3" | bc)" = "1" ]; then
  echo "  PASS (cold ${COLD}s / warm ${WARM}s = ${RATIO}x)"
else
  echo "  FAIL: only ${RATIO}x (cold ${COLD}s / warm ${WARM}s)"
  fail=1
fi

echo "[2/4] --copt 변경이 캐시를 무효화하는가 (플래그가 액션 키에 있는가)"
bazel clean >/dev/null 2>&1
elapsed bazel build --disk_cache="$CACHE" --copt=-O2 "$T" >/dev/null
H=$(hits)
if [ "${H:-0}" = "0" ]; then
  echo "  PASS (cache hits = 0, 전부 재컴파일)"
else
  echo "  FAIL: expected 0 cache hits, got ${H}"
  fail=1
fi

echo "[3/4] touch(mtime만 변경)는 캐시를 무효화하지 않는가"
touch "$D/workload/lib_003.cc"
bazel clean >/dev/null 2>&1
elapsed bazel build --disk_cache="$CACHE" "$T" >/dev/null
H=$(hits)
if [ "${H:-0}" -gt 0 ]; then
  echo "  PASS (cache hits = ${H}, 내용 해시가 키다)"
else
  echo "  FAIL: expected cache hits, got ${H:-0}"
  fail=1
fi

echo "[4/4] strict_action_env 가 PATH 누수를 막는가"
bazel clean >/dev/null 2>&1
mkdir -p /tmp/exp02-extra-bin
PATH="/tmp/exp02-extra-bin:$PATH" elapsed bazel build --disk_cache="$CACHE" "$T" >/dev/null
H=$(hits)
if [ "${H:-0}" -gt 0 ]; then
  echo "  PASS (PATH 바뀌어도 cache hits = ${H})"
else
  echo "  FAIL: PATH 변경만으로 캐시가 깨졌다 (hits=${H:-0})"
  fail=1
fi

exit $fail
