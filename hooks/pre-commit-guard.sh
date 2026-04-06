#!/bin/bash
# ============================================================
# PreToolUse: git commit 전 테스트 통과 여부 확인
# ~/.claude/hooks/pre-commit-guard.sh
#
# git commit 시도 시 자동 실행.
# 프론트 변경 있는데 Playwright 미실행 → 차단 (exit 2)
# 백엔드 변경 있는데 API 테스트 미실행 → 차단 (exit 2)
# ============================================================

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# git commit 명령만 검사
echo "$COMMAND" | grep -q "^git commit" || exit 0

# 변경 파일 분석
STAGED=$(cd "$CWD" && git diff --cached --name-only 2>/dev/null)
[ -z "$STAGED" ] && exit 0

HAS_FRONTEND=$(echo "$STAGED" | grep -c 'src/.*\.\(ts\|tsx\)$')
HAS_BACKEND=$(echo "$STAGED" | grep -c 'python-server/.*\.py$')
HAS_TEST=$(echo "$STAGED" | grep -c '\.spec\.ts$')

BLOCKS=()

# 프론트 변경 + Playwright 테스트 파일 없음
if [ "$HAS_FRONTEND" -gt 0 ] && [ "$HAS_TEST" -eq 0 ]; then
  BLOCKS+=("프론트엔드 코드 변경 있지만 Playwright 테스트(.spec.ts)가 staged에 없습니다.")
fi

# 백엔드 라우터 변경 + 프론트 변경 없음
if [ "$HAS_BACKEND" -gt 0 ] && [ "$HAS_FRONTEND" -eq 0 ]; then
  if echo "$STAGED" | grep -q 'routers/'; then
    BLOCKS+=("백엔드 라우터 변경 있지만 프론트엔드 코드가 staged에 없습니다. API만 커밋하려는 건 아닌지 확인하세요.")
  fi
fi

if [ ${#BLOCKS[@]} -gt 0 ]; then
  {
    echo "━━━ 커밋 차단: 불완전한 구현 감지 ━━━"
    echo ""
    for b in "${BLOCKS[@]}"; do
      echo "⛔ $b"
    done
    echo ""
    echo "조치: 누락된 부분을 구현한 후 다시 커밋하세요."
    echo "의도적 제외라면 사용자에게 확인 후 진행하세요."
  } >&2
  exit 2
fi

exit 0
