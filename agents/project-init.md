---
name: project-init
description: 새 프로젝트 초기화. 기술 스택 감지 후 CLAUDE.md 생성, 인증/메뉴 관리 기본 생성, 사용 가능한 agents/skills 목록 자동 기술.
tools: Read, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide
---

# 프로젝트 초기화 에이전트

새 프로젝트에 **CLAUDE.md**를 자동 생성하고, **인증**, **메뉴 관리** 시스템을 기본 세팅합니다.

> **기본 생성 항목**: CLAUDE.md, 인증 시스템, 메뉴 관리 시스템
>
> **지원 인증**: 휴대폰 OTP, 이메일/비밀번호, 소셜 로그인 (카카오/네이버/구글)

---

## 사용법

```bash
Use project-init                   # 전체 설정
Use project-init --auth-only       # 인증만
Use project-init --menu-only       # 메뉴만
Use project-init --docs-only       # CLAUDE.md만
Use project-init --auth=phone      # 휴대폰 인증
Use project-init --auth=email      # 이메일 인증
Use project-init --auth=social     # 소셜 로그인만
```

---

## 실행 단계

> **병렬 실행 원칙**: 의존성이 없는 에이전트들은 동시에 실행
> - Phase 4: `auth-backend` + `auth-frontend` 병렬
> - Phase 5: `menu-backend` + `menu-frontend` 병렬

### Phase 1: 기술 스택 감지 + 최신 버전 조회

```bash
# 스택 감지
ls package.json requirements.txt pom.xml 2>/dev/null

# 최신 버전 조회 (npm 프로젝트)
npm info next version
npm info react version
npm info @tanstack/react-query version
```

> **중요**: 항상 최신 버전 사용. 상세 버전 정책은 `project-init-stacks.md` 참조

### Phase 2: CLAUDE.md 생성

프로젝트 루트에 `CLAUDE.md` 생성 (템플릿: `project-init-claude-template.md` 참조)

### Phase 3: 공유 스키마

```bash
Use shared-schema --init
```

### Phase 4: 인증 시스템 (병렬 실행 가능)

```bash
Use auth-backend --init --type=phone   # Backend
Use auth-frontend --init               # Frontend (동시 실행)
```

### Phase 5: 메뉴 관리 (병렬 실행 가능)

```bash
Use menu-backend --init                # Backend
Use menu-frontend --init               # Frontend (동시 실행)
```

### Phase 6: 테넌트 관리 (선택)

```bash
Use tenant-manager --init              # 멀티사이트 필요 시
```

### Phase 7: 카테고리 관리 (선택)

```bash
Use category-manager --init
```

### Phase 8: 게시판 생성 (선택)

```bash
Use board-generator --init
Use board-generator --template notice  # 공지사항
Use board-generator --template free    # 자유게시판
Use board-generator --template qna     # Q&A
Use board-generator --template faq     # FAQ
Use board-generator --template gallery # 갤러리
Use board-generator --template review  # 리뷰
```

---

## 완료 메시지

```
✅ 프로젝트 초기화 완료!

감지된 기술 스택:
  - Backend: {Express/FastAPI/etc.}
  - Frontend: {React/Vue/etc.}
  - Database: {MySQL/PostgreSQL/etc.}

생성된 파일:
  ✓ CLAUDE.md
  ✓ 인증 시스템 (Backend + Frontend)
  ✓ 메뉴 관리 시스템 (Backend + Frontend)

다음 단계:
  1. CLAUDE.md 확인
  2. DB 스키마 실행
  3. 환경 변수 설정 (.env)
  4. 서버 시작
```

---

## 참고 문서

상세 내용은 분리된 파일 참조:

| 파일 | 내용 |
|------|------|
| `project-init-claude-template.md` | CLAUDE.md 템플릿, 환경변수 설정 |
| `project-init-stacks.md` | 스택별 프로젝트 구조 (Express, FastAPI) |
| `project-init-files.md` | 생성되는 파일 목록 |

---

## 호출하는 에이전트

**최우선 (순서대로):**
- `shared-schema` → `tenant-manager` → `category-manager`

**인증 (병렬 가능):**
- `auth-backend` + `auth-frontend`

**메뉴 (병렬 가능):**
- `menu-backend` + `menu-frontend`

**게시판:**
- `board-generator`
