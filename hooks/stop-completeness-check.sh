#!/bin/bash
# ============================================================
# Claude Code Stop Hook — E2E 완성도 검증
# ~/.claude/hooks/stop-completeness-check.sh
#
# Claude가 응답을 마칠 때 실행.
# 이번 세션에서 수정한 파일을 분석하여 누락된 연결을 감지.
# exit 0 + stdout = Claude에게 피드백 (추가 작업 지시)
# ============================================================

CWD="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# git에서 이번 세션 변경 파일 목록 (staged + unstaged + untracked)
CHANGED=$(cd "$CWD" && git diff --name-only HEAD 2>/dev/null; git diff --name-only --cached 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null)

[ -z "$CHANGED" ] && exit 0

WARNINGS=()

# ─── 1. 백엔드 라우터 추가했는데 프론트 API 클라이언트 없음 ───
NEW_ROUTES=$(echo "$CHANGED" | grep -E 'python-server/routers/.*\.py$')
if [ -n "$NEW_ROUTES" ]; then
  for route_file in $NEW_ROUTES; do
    # 라우터 파일에서 엔드포인트 경로 추출 (macOS 호환)
    ENDPOINTS=$(cd "$CWD" && grep -oE '@router\.(get|post|put|delete|patch)\("(/[^"]+)"' "$route_file" 2>/dev/null | sed 's/.*"\/\([^"]*\)".*/\1/' | head -5)
    for ep in $ENDPOINTS; do
      # 프론트엔드에서 이 경로를 호출하는 코드가 있는지
      if ! grep -rq "$ep" "$CWD/src/" 2>/dev/null; then
        WARNINGS+=("API 엔드포인트 /$ep 가 프론트엔드에서 호출되지 않습니다. src/utils/ 에 API 클라이언트 함수가 필요합니다.")
      fi
    done
  done
fi

# ─── 2. 프론트 API 함수 추가했는데 컴포넌트에서 안 씀 ───
NEW_UTILS=$(echo "$CHANGED" | grep -E 'src/utils/.*Api\.ts$|src/utils/.*api\.ts$')
if [ -n "$NEW_UTILS" ]; then
  for util_file in $NEW_UTILS; do
    # export 함수명 추출 (macOS 호환)
    FUNCS=$(cd "$CWD" && grep -oE 'export (const|async function|function) [a-zA-Z]+' "$util_file" 2>/dev/null | sed 's/.*\(const\|function\) //' | head -10)
    for fn in $FUNCS; do
      # 컴포넌트에서 import/사용하는지
      USAGE=$(cd "$CWD" && grep -rl "$fn" src/components/ src/hooks/ src/app/ 2>/dev/null | head -1)
      if [ -z "$USAGE" ]; then
        WARNINGS+=("API 함수 $fn() (${util_file##*/}) 가 어떤 컴포넌트에서도 호출되지 않습니다. 프론트엔드 연결이 누락된 것 같습니다.")
      fi
    done
  done
fi

# ─── 3. 백엔드만 수정하고 프론트 수정 없음 (API 변경 시) ───
HAS_BACKEND=$(echo "$CHANGED" | grep -c 'python-server/')
HAS_FRONTEND=$(echo "$CHANGED" | grep -c 'src/')
if [ "$HAS_BACKEND" -gt 0 ] && [ "$HAS_FRONTEND" -eq 0 ]; then
  # 백엔드에 라우터 변경이 있는지
  if echo "$CHANGED" | grep -q 'routers/'; then
    WARNINGS+=("백엔드 라우터를 수정했지만 프론트엔드 코드는 변경하지 않았습니다. API 연결이 누락된 건 아닌지 확인하세요.")
  fi
fi

# ─── 4. 코드 수정했는데 테스트 없음 (프론트 + 백엔드 모두) ───
HAS_TEST=$(echo "$CHANGED" | grep -c '\.spec\.ts$\|test_.*\.py$\|.*_test\.py$')
if [ "$HAS_FRONTEND" -gt 0 ] && [ "$HAS_TEST" -eq 0 ]; then
  WARNINGS+=("프론트엔드 코드를 수정했지만 테스트가 없습니다. Playwright 테스트를 작성/실행하세요.")
fi
if [ "$HAS_BACKEND" -gt 0 ] && [ "$HAS_TEST" -eq 0 ]; then
  if echo "$CHANGED" | grep -qE 'routers/|services/|schemas/'; then
    WARNINGS+=("백엔드 API/서비스를 수정했지만 테스트가 없습니다. API 스모크 테스트(curl 또는 Playwright request)를 실행하세요.")
  fi
fi

# ─── 5. 새 state 추가했는데 getState/setState 누락 ───
NEW_TSX=$(echo "$CHANGED" | grep -E 'src/.*\.(ts|tsx)$')
if [ -n "$NEW_TSX" ]; then
  for f in $NEW_TSX; do
    [ ! -f "$CWD/$f" ] && continue
    # useState 추가 확인
    NEW_STATES=$(cd "$CWD" && grep -c 'useState' "$f" 2>/dev/null)
    if [ "$NEW_STATES" -gt 0 ]; then
      # ScenarioGenerator의 getState에 포함되는지 (간접 확인)
      if echo "$f" | grep -q 'Scenario'; then
        if ! echo "$CHANGED" | grep -q 'ScenarioGenerator.tsx'; then
          : # ScenarioGenerator 자체가 아니면 무시
        fi
      fi
    fi
  done
fi

# ─── 5. 막다른 에러 UX 감지 (수정된 .tsx 파일에서) ───
NEW_TSX=$(echo "$CHANGED" | grep -E 'src/.*\.tsx$')
if [ -n "$NEW_TSX" ]; then
  for f in $NEW_TSX; do
    [ ! -f "$CWD/$f" ] && continue
    DEADEND=$(grep -n -E "먼저.*해주세요|먼저.*하세요|먼저.*작성|먼저.*선택|먼저.*생성" "$CWD/$f" 2>/dev/null | grep -v '^\s*//' | head -2)
    if [ -n "$DEADEND" ]; then
      WARNINGS+=("${f##*/}에 '먼저 X 하세요' 에러가 있습니다. 사용자에게 에러 대신 자동 안내/실행 UI를 제공하세요.")
    fi
  done
fi

# ─── 결과 출력 ───
if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo "━━━ E2E 완성도 검증: 기획 관점 검토 필수 ━━━"
  echo ""
  echo "아래 누락이 감지되었습니다. 멈추지 말고 즉시 다음을 수행하세요:"
  echo ""
  for w in "${WARNINGS[@]}"; do
    echo "⚠️  $w"
  done
  echo ""
  echo "━━━ 필수 조치 (자동 진행, 사용자 확인 불필요) ━━━"
  echo ""
  echo "1. [기획 검증] 위 누락이 의도된 설계인지 기획 관점에서 판단하세요:"
  echo "   - 사용자가 이 기능을 쓸 때 UI가 필요한가?"
  echo "   - API만 있고 UI가 없으면 사용자가 접근할 방법이 있는가?"
  echo "   - 프론트 코드만 있고 테스트가 없으면 동작을 어떻게 보장하는가?"
  echo ""
  echo "2. [조치 결정] 판단 결과에 따라 즉시 실행:"
  echo "   - 누락이 맞으면 → 프론트 연결/테스트를 지금 구현"
  echo "   - 의도적 제외면 → 이유를 사용자에게 1줄로 보고"
  echo ""
  echo "3. [재검증] 수정 후 빌드 + Playwright 테스트까지 완료해야 종료"
  echo ""
  echo "이 메시지를 무시하고 종료하면 안 됩니다. 위 조치를 수행하세요."

  # 테스트 누락이 있으면 종료 차단 (exit 2 = Claude가 멈출 수 없음)
  for w in "${WARNINGS[@]}"; do
    if echo "$w" | grep -q "테스트가 없습니다"; then
      echo "" >&2
      echo "⛔ 테스트 미실행으로 종료 차단. 테스트를 실행한 후 다시 시도하세요." >&2
      exit 2
    fi
  done
fi

exit 0
