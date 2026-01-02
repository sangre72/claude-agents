# 프로젝트 CLAUDE.md 템플릿

> 새 프로젝트 생성 시 이 파일을 프로젝트 루트에 `CLAUDE.md`로 복사하고, 프로젝트에 맞게 수정하세요.

---

## 프로젝트 정보

- **프로젝트명**: [프로젝트명]
- **설명**: [프로젝트 설명]
- **기술 스택**: [Backend] + [Frontend] + [Database]

---

## 사용 가능한 Skills

### Git 관련

| 스킬 | 설명 | 사용법 |
|------|------|--------|
| `gitpush` | 자동 커밋 + dev merge + push | `/gitpush` |
| `gitpull` | dev merge + pull | `/gitpull` |

### 코드 품질

| 스킬 | 설명 | 사용법 |
|------|------|--------|
| `coding-guide` | 코드 품질, 보안, 네이밍 규칙 | 자동 적용 |
| `refactor` | 모듈화 및 타입 리팩토링 | `/refactor` 또는 `/refactor --fix` |
| `modular-check` | 모듈화 상태 분석 | `/modular-check` |

### Refactor 주요 기능

```bash
/refactor              # 전체 검사
/refactor products     # 특정 모듈만 검사
/refactor --types      # 타입 중복만 검사
/refactor --fix        # 자동 수정 포함
```

**검사 항목:**
- 타입 중복 정의 (CRITICAL)
- 유틸리티 함수 중복 (WARNING)
- 모듈 독립성
- 앱 간 직접 import 검출
- 컴포넌트 크기 제한 (200줄)

### Modular-check 주요 기능

```bash
/modular-check         # 전체 분석
```

**분석 항목:**
- 타입 중복 검사 (30%)
- 순환 의존성 검사 (20%)
- 레이어 분리 검사 (20%)
- 앱별 타입 분리 (15%)
- Public API 정의 (15%)

---

## 사용 가능한 Agents

### 공통 (먼저 실행)

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `shared-schema` | 공유 테이블 (user_groups, roles 등) | `Use shared-schema --init` |

### 게시판 시스템

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `board-generator` | 멀티게시판 Full Stack 생성 | `Use board-generator --init` |
| | 템플릿으로 게시판 추가 | `Use board-generator --template notice` |
| | 커스텀 게시판 생성 | `Use board-generator to create 후기게시판` |

**템플릿 종류**: `notice`, `free`, `qna`, `gallery`, `faq`, `review`

### 메뉴 관리 시스템

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `menu-manager` | 통합 메뉴 관리 시스템 | `Use menu-manager --init` |
| | 타입별 메뉴 생성 | `Use menu-manager --type=admin` |
| | 유틸리티 메뉴 생성 | `Use menu-manager --utility=header` |

**메뉴 타입**: `site`, `user`, `admin`, `header_utility`, `footer_utility`, `quick_menu`

---

## 초기화 순서 (신규 프로젝트)

```bash
# 1. 공유 스키마 초기화 (필수 - 가장 먼저)
Use shared-schema --init

# 2. 필요한 기능 초기화
Use board-generator --init      # 게시판 시스템
Use menu-manager --init         # 메뉴 관리 시스템

# 3. 게시판 추가 (필요시)
Use board-generator --template notice
Use board-generator --template free
Use board-generator --template qna

# 4. 메뉴 설정
Use menu-manager --type=site    # 사이트 메뉴
Use menu-manager --type=admin   # 관리자 메뉴
Use menu-manager --utility=header
Use menu-manager --utility=footer
```

---

## 프로젝트별 설정

### 기술 스택 (자동 감지됨)

```
Backend:  [ ] Express  [ ] FastAPI  [ ] Flask  [ ] Django  [ ] Spring
Frontend: [ ] React    [ ] Vue      [ ] Angular [ ] Next.js
UI:       [ ] MUI      [ ] Bootstrap [ ] Tailwind
Database: [ ] MySQL    [ ] PostgreSQL [ ] SQLite [ ] MongoDB
```

### 디렉토리 구조

```
프로젝트/
├── CLAUDE.md              # 이 파일
├── backend/ 또는 middleware/
│   └── ...
├── frontend/
│   └── ...
└── db/
    └── schema/
```

---

## 코딩 규칙 요약

### 필수 감사 컬럼 (모든 테이블)

```sql
created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
created_by VARCHAR(100),
updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
updated_by VARCHAR(100),
is_active BOOLEAN DEFAULT TRUE,
is_deleted BOOLEAN DEFAULT FALSE
```

### 보안 규칙

- ✅ Parameterized Query 사용 (SQL Injection 방지)
- ✅ 입력 검증 (express-validator 등)
- ✅ JWT 인증 미들웨어
- ❌ 문자열 연결로 SQL 생성 금지

### Admin UI 패턴 (한국형)

- 레이아웃: 좌측 트리(280px) + 우측 상세 패널
- 편집: 모달 대신 인라인 편집
- 삭제: 인라인 확인 다이얼로그
- 드래그앤드롭: 트리 내 순서 변경

---

## 자주 사용하는 명령어

```bash
# 게시판 추가
Use board-generator to create [게시판명] with code: [코드]

# 메뉴 추가
Use menu-manager to add menu "[메뉴명]" --type=site
Use menu-manager to add submenu "[하위메뉴]" under "[상위메뉴]"

# 코드 푸시
/gitpush

# 코드 풀
/gitpull
```

---

## 참고 문서

- [shared-schema.md](~/.claude/agents/shared-schema.md) - 공유 스키마
- [board-generator.md](~/.claude/agents/board-generator.md) - 게시판 생성
- [menu-manager.md](~/.claude/agents/menu-manager.md) - 메뉴 관리
- [coding-guide](~/.claude/skills/coding-guide/) - 코딩 가이드
