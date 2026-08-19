#!/usr/bin/env bash
# exp05 합격 기준 자동 검증.
# git 상태에 의존하지 않도록 query/cquery 를 직접 호출한다.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
fail=0

tests_for() {  # $1=engine(query|cquery) $2=label
  bazel "$1" "kind('.*_test rule', rdeps(//..., $2))" 2>/dev/null \
    | grep -oE '^//[^ ]+' | sort -u | tr '\n' ' '
}

echo "[1/4] greeter.cc 변경 -> 의존하는 두 테스트가 모두 선별되는가"
got=$(tests_for cquery //experiments/exp01_bazel_hello:greeter.cc)
if echo "$got" | grep -q "exp01_bazel_hello:greeter_test" && \
   echo "$got" | grep -q "exp05_test_impact:formatter_test"; then
  echo "  PASS ($got)"
else
  echo "  FAIL: got '$got'"; fail=1
fi

echo "[2/4] formatter.cc 변경 -> 무관한 테스트는 빠지는가"
got=$(tests_for cquery //experiments/exp05_test_impact:formatter.cc)
if echo "$got" | grep -q "formatter_test" && ! echo "$got" | grep -q "greeter_test"; then
  echo "  PASS ($got)"
else
  echo "  FAIL: got '$got'"; fail=1
fi

echo "[3/4] select() 비선택 분기 -> query 는 과다 선택하고 cquery 는 안 하는가"
q=$(tests_for query //experiments/exp05_test_impact:arch_note_aarch64.cc)
c=$(tests_for cquery //experiments/exp05_test_impact:arch_note_aarch64.cc)
if [ -n "${q// /}" ] && [ -z "${c// /}" ]; then
  echo "  PASS (query='$q' / cquery=<empty>)"
else
  echo "  FAIL: query='$q' cquery='$c' - 과다 선택이 재현되지 않았다"; fail=1
fi

echo "[4/4] BUILD 파일 변경 -> 선별이 아무것도 못 잡는가 (전체 폴백이 필요한 이유)"
got=$(tests_for query //experiments/exp01_bazel_hello:BUILD.bazel)
if [ -z "${got// /}" ]; then
  echo "  PASS (Empty results - impacted_tests.sh 가 //... 로 폴백해야 한다)"
else
  echo "  FAIL: 예상과 달리 결과가 있다: '$got'"; fail=1
fi

exit $fail
