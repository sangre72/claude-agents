# Claude Code Hooks

Claude Code의 자동 검증 hook 모음. `~/.claude/settings.json`에 등록하여 전 프로젝트에 적용.

## 설치

```bash
# 1. hook 파일 복사
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# 2. settings.json에 등록 (기존 설정에 merge)
```

## Hook 목록

### post-edit-guard.sh (PostToolUse)
`.ts/.tsx` 파일 Edit/Write 후 자동 실행. 위험 패턴 감지 시 차단(exit 2).

| 감지 항목 | 예시 |
|----------|------|
| 외부 데이터 `?.` 누락 | `result.tags.length` → `result.tags?.length` |
| `dangerouslySetInnerHTML` | XSS 위험 |
| `eval()` / `new Function()` | 코드 인젝션 |

### stop-completeness-check.sh (Stop)
Claude 응답 완료 시 자동 실행. git diff 분석하여 E2E 연결 누락 감지.

| 감지 항목 | 상황 |
|----------|------|
| API 엔드포인트 고아 | 백엔드 라우터 추가했는데 프론트에서 호출 안 함 |
| API 함수 고아 | `src/utils/*Api.ts` 함수를 컴포넌트에서 안 씀 |
| 프론트/백엔드 불균형 | 백엔드만 수정하고 프론트 변경 없음 |
| Playwright 누락 | 프론트 수정했는데 `.spec.ts` 없음 |

감지 시 기획 관점 검증을 강제하고 자동 재작업 지시.

## settings.json 설정 예시

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/post-edit-guard.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/stop-completeness-check.sh",
            "timeout": 15
          }
        ]
      }
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "echo '★ 컨텍스트 압축됨. 핵심: (1) E2E 체인 완성 필수 (2) 외부 데이터 ?. 필수 (3) Playwright 필수 (4) getState/setState 전부 반영'"
          }
        ]
      }
    ]
  }
}
```
