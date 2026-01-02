---
name: project-init
description: 새 프로젝트 초기화. 기술 스택 감지 후 CLAUDE.md 생성, 사용 가능한 agents/skills 목록 자동 기술.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 프로젝트 초기화 에이전트

새 프로젝트에 **CLAUDE.md**를 자동 생성하고, 사용 가능한 agents/skills를 문서화합니다.

---

## 사용법

```bash
# 새 프로젝트 설정
Use project-init

# 또는
"새 프로젝트를 설정하자"
"프로젝트 초기화해줘"
```

---

## 실행 단계

### Step 1: 기술 스택 감지

```bash
# Backend 확인
ls package.json          # Node.js
ls requirements.txt      # Python
ls pom.xml              # Java

# Frontend 확인
ls frontend/package.json
grep -E "react|vue|angular" frontend/package.json 2>/dev/null

# Database 확인
grep -E "mysql|postgres|mongodb" package.json requirements.txt 2>/dev/null
```

### Step 2: CLAUDE.md 생성

프로젝트 루트에 `CLAUDE.md` 파일 생성:

```markdown
# [프로젝트명] - Claude Code 가이드

## 프로젝트 정보

- **기술 스택**: {감지된 스택}
- **생성일**: {오늘 날짜}

---

## 사용 가능한 Skills

### Git 관련
| 스킬 | 설명 | 사용법 |
|------|------|--------|
| `gitpush` | 자동 커밋 + push | `/gitpush` |
| `gitpull` | dev merge + pull | `/gitpull` |

### 코드 품질
| 스킬 | 설명 | 사용법 |
|------|------|--------|
| `coding-guide` | 코드 품질, 보안 규칙 | 자동 적용 |
| `refactor` | 모듈화/타입 리팩토링 | `/refactor` `/refactor --fix` |
| `modular-check` | 모듈화 상태 분석 | `/modular-check` |

---

## 사용 가능한 Agents

### 최우선 (순서대로 실행)

| 순서 | 에이전트 | 설명 | 사용법 |
|------|----------|------|--------|
| 1 | `shared-schema` | 공유 테이블 초기화 | `Use shared-schema --init` |
| 2 | `tenant-manager` | 테넌트(멀티사이트) 관리 | `Use tenant-manager --init` |
| 3 | `category-manager` | 카테고리 관리 | `Use category-manager --init` |
| 4 | `menu-manager` | 통합 메뉴 관리 | `Use menu-manager --init` |

### 게시판

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `board-generator` | 멀티게시판 오케스트레이터 | `Use board-generator --init` |
| `board-schema` | DB 스키마 정의 (공유) | 참조용 |
| `board-templates` | 템플릿 정의 (공유) | 참조용 |
| `board-frontend-pages` | 페이지 템플릿 (공유) | 참조용 |
| `board-attachments` | 파일 첨부 기능 (공유) | 참조용 |

**템플릿**: notice, free, qna, gallery, faq, review

### 메뉴 관리

**타입**: site, user, admin, header_utility, footer_utility

---

## 초기화 순서

\`\`\`bash
# 1. 공유 스키마 (필수 - 가장 먼저)
Use shared-schema --init

# 2. 테넌트 관리 (최우선)
Use tenant-manager --init

# 3. 카테고리 관리 (최우선)
Use category-manager --init

# 4. 메뉴 관리 (최우선)
Use menu-manager --init
Use menu-manager --type=site
Use menu-manager --type=admin

# 5. 게시판 시스템
Use board-generator --init
Use board-generator --template notice
Use board-generator --template free
\`\`\`

---

## 코딩 규칙

### 필수 감사 컬럼

\`\`\`sql
created_at, created_by, updated_at, updated_by, is_active, is_deleted
\`\`\`

### 보안

- ✅ Parameterized Query
- ✅ 입력 검증
- ✅ JWT 인증
- ❌ SQL 문자열 연결 금지

### Admin UI (한국형)

- 좌측 트리 + 우측 상세 패널
- 모달 대신 인라인 편집
- 드래그앤드롭 순서 변경

---

## 자주 쓰는 명령

\`\`\`bash
Use board-generator to create [게시판명]
Use menu-manager to add menu "[메뉴명]" --type=site
/gitpush
/gitpull
\`\`\`
```

### Step 3: 기존 CLAUDE.md 확인

```bash
# 이미 존재하면 백업
if [ -f CLAUDE.md ]; then
  mv CLAUDE.md CLAUDE.md.backup
  echo "기존 CLAUDE.md를 백업했습니다."
fi
```

---

## 완료 메시지

```
✅ 프로젝트 초기화 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

감지된 기술 스택:
  - Backend: {Express/FastAPI/etc.}
  - Frontend: {React/Vue/etc.}
  - Database: {MySQL/PostgreSQL/etc.}

생성된 파일:
  ✓ CLAUDE.md - 프로젝트 가이드

사용 가능한 기능:
  - Agents: shared-schema, tenant-manager, category-manager, menu-manager, board-generator
  - Skills: coding-guide, gitpush, gitpull, refactor, modular-check

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

다음 단계:
  1. CLAUDE.md 내용 확인 및 필요시 수정
  2. Use shared-schema --init (공유 테이블 초기화)
  3. Use tenant-manager --init (테넌트 관리)
  4. 필요한 기능 초기화 (category-manager, menu-manager, board-generator)
```

---

## 스택별 추가 설정

### Express + React + MySQL

```markdown
## 디렉토리 구조

middleware/node/
├── api/           # API 핸들러
├── db/schema/     # SQL 스키마
└── server.js      # 메인 서버

frontend/
├── src/components/
├── src/lib/       # API 클라이언트
└── src/types/     # TypeScript 타입
```

### FastAPI + React + PostgreSQL

```markdown
## 디렉토리 구조

app/
├── api/           # API 라우터
├── models/        # SQLAlchemy 모델
└── main.py        # FastAPI 앱

frontend/
├── src/components/
└── src/lib/
```

---

## 참고

이 에이전트는 다음 파일들을 참조합니다:

**최우선 에이전트:**
- `~/.claude/agents/shared-schema.md`
- `~/.claude/agents/tenant-manager.md`
- `~/.claude/agents/category-manager.md`
- `~/.claude/agents/menu-manager.md`

**게시판 에이전트:**
- `~/.claude/agents/board-generator.md` (오케스트레이터)
- `~/.claude/agents/board-schema.md` (DB 스키마)
- `~/.claude/agents/board-templates.md` (템플릿 정의)
- `~/.claude/agents/board-frontend-pages.md` (페이지 템플릿)
- `~/.claude/agents/board-attachments.md` (파일 첨부)

**스킬:**
- `~/.claude/skills/coding-guide/`
- `~/.claude/skills/gitpush/`
- `~/.claude/skills/gitpull/`
- `~/.claude/skills/refactor/`
- `~/.claude/skills/modular-check/`
