#!/bin/bash
# ============================================================
# SessionStart: 프로젝트 초기 상태 확인
# ~/.claude/hooks/session-init.sh
#
# 세션 시작 시 실행. .claude/rules/ 없으면 생성 안내.
# ============================================================

CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# git 프로젝트가 아니면 스킵
[ ! -d "$CWD/.git" ] && exit 0

WARNINGS=()

# .claude/rules/ 디렉토리 존재 확인
if [ ! -d "$CWD/.claude/rules" ]; then
  WARNINGS+=(".claude/rules/ 디렉토리가 없습니다. 프로젝트 기술 스택에 맞는 규칙 파일을 생성하세요.")
  WARNINGS+=("예: .claude/rules/frontend.md (paths: src/**/*.tsx), .claude/rules/backend.md (paths: python-server/**/*.py)")
fi

# .claude/rules/ 있지만 파일이 없으면
if [ -d "$CWD/.claude/rules" ] && [ -z "$(ls -A "$CWD/.claude/rules/" 2>/dev/null)" ]; then
  WARNINGS+=(".claude/rules/ 디렉토리가 비어있습니다. 경로별 규칙 파일을 추가하세요.")
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "━━━ 프로젝트 초기화 필요 ━━━"
  for w in "${WARNINGS[@]}"; do
    echo "⚠️  $w"
  done
fi

exit 0
