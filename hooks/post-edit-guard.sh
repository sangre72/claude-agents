#!/bin/bash
# ============================================================
# Claude Code Global Post-Edit Guard
# ~/.claude/hooks/post-edit-guard.sh
#
# Edit/Write 후 자동 실행. 위험 패턴 감지 시 Claude에게 피드백.
# exit 0 = 통과, exit 2 = 차단 (stderr가 Claude에게 전달됨)
# ============================================================

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# .ts/.tsx 파일만 검사
[[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

WARNINGS=()

# ─── 1. 방어적 접근 누락 (Defensive Data Access) ───
# 외부/API/props 데이터의 .length, .map(), .forEach(), .filter() 앞에 ?. 없으면 위험
# 패턴: result.tags.length, data.items.map( 등 (a.b.method 형태에서 b 앞에 ?. 없음)
while IFS= read -r line; do
  [ -z "$line" ] && continue
  LINENUM=$(echo "$line" | cut -d: -f1)
  CONTENT=$(echo "$line" | cut -d: -f2-)
  WARNINGS+=("  L${LINENUM}: 외부 데이터 방어 누락 가능 — ${CONTENT}")
done < <(grep -n -E '\b(result|data|response|props|state|item|res)\.[a-zA-Z_]+\.(length|map|forEach|filter|reduce|find|some|every|includes|join|slice|splice)\b' "$FILE_PATH" | grep -v '\?\.' | grep -v '^\s*//' | head -5)

# ─── 2. dangerouslySetInnerHTML 사용 ───
if grep -qn 'dangerouslySetInnerHTML' "$FILE_PATH"; then
  LINE=$(grep -n 'dangerouslySetInnerHTML' "$FILE_PATH" | head -1 | cut -d: -f1)
  WARNINGS+=("  L${LINE}: dangerouslySetInnerHTML 사용 — XSS 위험. 정말 필요한지 확인하세요.")
fi

# ─── 3. eval / new Function 사용 ───
if grep -qn -E '\beval\s*\(|new\s+Function\s*\(' "$FILE_PATH"; then
  LINE=$(grep -n -E '\beval\s*\(|new\s+Function\s*\(' "$FILE_PATH" | head -1 | cut -d: -f1)
  WARNINGS+=("  L${LINE}: eval()/new Function() 사용 — 코드 인젝션 위험.")
fi

# ─── 결과 출력 ───
if [ ${#WARNINGS[@]} -gt 0 ]; then
  {
    echo "⚠️  Post-Edit Guard: ${FILE_PATH##*/} 에서 위험 패턴 감지"
    echo ""
    printf '%s\n' "${WARNINGS[@]}"
    echo ""
    echo "→ 외부 데이터 접근 시 ?. (optional chaining) 또는 fallback 필수"
    echo "→ 예: result.tags?.length, (data.items || []).map()"
  } >&2
  exit 2
fi

exit 0
