#!/bin/bash
# ============================================================
# UserPromptSubmit: 사용자 요청에 E2E 체크리스트 자동 주입
# ~/.claude/hooks/prompt-e2e-remind.sh
#
# 기능 구현/수정 요청 감지 시 additionalContext로 체크리스트 주입.
# 단순 질문/검색에는 주입하지 않음.
# ============================================================

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty')

# 짧은 질문, 상태 확인, 대화는 스킵
[ ${#PROMPT} -lt 15 ] && exit 0
echo "$PROMPT" | grep -qiE '^(ls|cd|git |cat |what|how|why|where|status|확인|뭐|어디|언제)' && exit 0

# 구현/수정/추가/만들기 키워드 감지
if echo "$PROMPT" | grep -qiE '구현|만들|추가|수정|변경|개발|implement|add|create|fix|build|feature|기능|버튼|API|페이지|컴포넌트|탭'; then
  cat << 'REMIND'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "E2E 완성도 리마인드: 이 작업 완료 시 반드시 확인 — (1) 백엔드 API 있으면 프론트 호출 코드도 있는가? (2) 프론트 UI 있으면 데이터를 실제로 표시하는가? (3) 탭 전환 있으면 데이터도 함께 전달하는가? (4) Playwright 테스트로 실제 동작 검증했는가?"
  }
}
REMIND
  exit 0
fi

exit 0
