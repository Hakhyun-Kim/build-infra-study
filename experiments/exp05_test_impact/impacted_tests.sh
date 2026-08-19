#!/usr/bin/env bash
# 변경된 파일 -> 돌려야 할 테스트 타깃.
#
# 사용법:  impacted_tests.sh [<base-ref>]      (기본값 HEAD~1)
#
# 설계상 중요한 점 두 가지 (exp05 에서 실측으로 확인한 것):
#
#  1) 그래프 자체를 바꾸는 파일(BUILD, .bzl, .bazelrc, MODULE.bazel, 툴체인,
#     플랫폼)은 파일 단위 rdeps 로는 영향이 잡히지 않는다. 실제로 BUILD 파일을
#     넣고 물어보면 "Empty results" 가 나온다 - 아무 테스트도 안 돌린다는 뜻이고
#     이건 위험하다. 이런 파일이 하나라도 섞이면 선별을 포기하고 전체를 돌린다.
#
#  2) query 가 아니라 cquery 를 쓴다. query 는 configuration 을 모르므로
#     select() 의 모든 분기를 의존으로 보고, 실제로는 컴파일되지도 않는 소스
#     때문에 테스트를 과다 선택한다.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
BASE="${1:-HEAD~1}"

CHANGED="$(git diff --name-only "$BASE" 2>/dev/null)"
if [ -z "$CHANGED" ]; then
  echo "# 변경 없음" >&2
  exit 0
fi

# 그래프를 바꾸는 파일 -> 보수적으로 전체
GRAPH_RE='(^|/)BUILD(\.bazel)?$|\.bzl$|^MODULE\.bazel(\.lock)?$|^\.bazelrc$|^\.bazelversion$|^toolchains/|^platforms/'
if echo "$CHANGED" | grep -qE "$GRAPH_RE"; then
  echo "# 그래프 정의 파일이 변경됨 -> 전체 실행" >&2
  echo "//..."
  exit 0
fi

# 소스 경로 -> Bazel 라벨. bazel query 가 패키지 경계를 알고 있으므로
# 문자열로 조립하지 않고 물어본다 (서브디렉터리 패키지에서 틀리지 않는다).
labels=""
while IFS= read -r f; do
  [ -f "$f" ] || continue
  lbl="$(bazel query "$f" 2>/dev/null | head -1)"
  [ -n "$lbl" ] && labels="$labels $lbl"
done <<< "$CHANGED"

if [ -z "${labels// /}" ]; then
  echo "# Bazel 그래프에 속한 파일 없음" >&2
  exit 0
fi

bazel cquery "kind('.*_test rule', rdeps(//..., set($labels)))" 2>/dev/null \
  | grep -oE '^//[^ ]+' | sort -u
