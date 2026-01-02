---
name: project-init
description: 새 프로젝트 초기화. 기술 스택 감지 후 CLAUDE.md 생성, 인증/메뉴 관리 기본 생성, 사용 가능한 agents/skills 목록 자동 기술.
tools: Read, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide
---

# 프로젝트 초기화 에이전트

새 프로젝트에 **CLAUDE.md**를 자동 생성하고, **인증**, **메뉴 관리** 시스템을 기본 세팅합니다.

> **기본 생성 항목**:
> 1. CLAUDE.md (프로젝트 가이드)
> 2. 인증 시스템 (회원가입, 로그인, 휴대폰/이메일 인증)
> 3. 메뉴 관리 시스템

> **지원 인증 방식**:
> - 휴대폰 번호 인증 (OTP)
> - 이메일/비밀번호 인증
> - 소셜 로그인 (카카오, 네이버, 구글)

---

## 사용법

```bash
# 새 프로젝트 설정 (전체)
Use project-init

# 또는
"새 프로젝트를 설정하자"
"프로젝트 초기화해줘"

# 특정 기능만
Use project-init --auth-only       # 인증만
Use project-init --menu-only       # 메뉴만
Use project-init --docs-only       # CLAUDE.md만

# 인증 방식 선택
Use project-init --auth=phone      # 휴대폰 인증 (OTP)
Use project-init --auth=email      # 이메일/비밀번호 인증
Use project-init --auth=social     # 소셜 로그인만
Use project-init --auth=all        # 전체 (기본값)
```

---

## 실행 단계

### Phase 1: 기술 스택 감지

```bash
# Backend 확인
ls package.json          # Node.js
ls requirements.txt      # Python
ls pom.xml              # Java

# Frontend 확인
ls frontend/package.json
grep -E "react|vue|angular" frontend/package.json 2>/dev/null
grep -E "@mui/material|bootstrap|tailwind" frontend/package.json 2>/dev/null

# Database 확인
grep -E "mysql|postgres|mongodb" package.json requirements.txt 2>/dev/null
```

### Phase 2: CLAUDE.md 생성

프로젝트 루트에 `CLAUDE.md` 파일 생성

### Phase 3: 공유 스키마 초기화

```bash
# shared-schema 에이전트 호출
Use shared-schema --init
```

### Phase 4: 인증 시스템 생성

```bash
# Backend (인증 방식에 따라 선택)
Use auth-backend --init                    # 전체 인증 시스템
Use auth-backend --init --type=phone       # 휴대폰 인증 기반
Use auth-backend --init --type=email       # 이메일/비밀번호 기반
Use auth-backend --init --type=jwt         # JWT 토큰 기반
Use auth-backend --feature=social-kakao    # 카카오 소셜 로그인 추가
Use auth-backend --feature=social-naver    # 네이버 소셜 로그인 추가
Use auth-backend --feature=social-google   # 구글 소셜 로그인 추가

# Frontend
Use auth-frontend --init
Use auth-frontend --page=phone-login       # 휴대폰 로그인 페이지
Use auth-frontend --page=social-login      # 소셜 로그인 페이지
```

**생성되는 API 엔드포인트 (인증):**

| Method | Endpoint | 설명 |
|--------|----------|------|
| POST | `/api/auth/send-code` | 휴대폰/이메일 인증번호 발송 |
| POST | `/api/auth/verify-code` | 인증번호 확인 |
| POST | `/api/auth/register` | 회원가입 |
| POST | `/api/auth/login` | 로그인 (이메일/비밀번호) |
| POST | `/api/auth/phone-login` | 휴대폰 인증 로그인 |
| POST | `/api/auth/logout` | 로그아웃 |
| POST | `/api/auth/refresh` | 토큰 갱신 |
| GET | `/api/auth/me` | 현재 사용자 정보 |
| PUT | `/api/auth/profile` | 프로필 수정 |
| PUT | `/api/auth/password` | 비밀번호 변경 |
| DELETE | `/api/auth/withdraw` | 회원 탈퇴 |
| POST | `/api/auth/kakao` | 카카오 로그인 |
| POST | `/api/auth/naver` | 네이버 로그인 |
| POST | `/api/auth/google` | 구글 로그인 |

### Phase 5: 메뉴 관리 시스템 생성

```bash
# Backend
Use menu-backend --init

# Frontend
Use menu-frontend --init

# 메뉴 타입별 생성
Use menu-manager --type=site             # 사이트 전체 메뉴 (GNB)
Use menu-manager --type=user             # 사용자 전용 메뉴 (마이페이지)
Use menu-manager --type=admin            # 관리자 메뉴
Use menu-manager --utility=header        # 헤더 유틸리티 (로그인/로그아웃)
Use menu-manager --utility=footer        # 푸터 유틸리티 (이용약관 등)
```

**생성되는 API 엔드포인트 (메뉴 관리):**

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/admin/menus` | 메뉴 목록 조회 |
| GET | `/api/admin/menus/:id` | 메뉴 상세 조회 |
| POST | `/api/admin/menus` | 메뉴 생성 |
| PUT | `/api/admin/menus/:id` | 메뉴 수정 |
| DELETE | `/api/admin/menus/:id` | 메뉴 삭제 (Soft Delete) |
| PUT | `/api/admin/menus/reorder` | 메뉴 순서 변경 |
| PUT | `/api/admin/menus/:id/move` | 메뉴 이동 (부모 변경) |
| GET | `/api/menus` | 사용자용 메뉴 조회 |
| GET | `/api/menus/:type` | 타입별 메뉴 조회 |

### Phase 6: 테넌트 관리 (멀티사이트 필요 시)

> **멀티 테넌시**가 필요한 경우에만 실행합니다.

```bash
# 테넌트 관리 시스템 초기화
Use tenant-manager --init

# 테넌트 추가
Use tenant-manager to create tenant "사이트A" with code: site_a
```

**생성되는 API 엔드포인트 (테넌트 관리):**

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/tenants` | 테넌트 목록 조회 (super_admin만) |
| GET | `/api/tenants/:id` | 테넌트 상세 조회 |
| POST | `/api/tenants` | 테넌트 생성 (super_admin만) |
| PUT | `/api/tenants/:id` | 테넌트 수정 |
| DELETE | `/api/tenants/:id` | 테넌트 삭제 (Soft Delete) |
| GET | `/api/tenants/current/info` | 현재 테넌트 정보 |

**테넌트 설정 항목:**

| 설정 | 설명 |
|------|------|
| `domain` | 커스텀 도메인 (예: www.site-a.com) |
| `subdomain` | 서브도메인 (예: site-a.example.com) |
| `theme` | 테마 설정 (default, dark, light) |
| `logo` | 로고 이미지 경로 |
| `primaryColor` | 기본 색상 |
| `language` | 기본 언어 (ko, en, ja, zh) |

### Phase 7: 카테고리 관리

> 게시판에서 **카테고리 분류**가 필요한 경우 실행합니다.

```bash
# 카테고리 관리 시스템 초기화
Use category-manager --init

# 게시판에 카테고리 추가
Use category-manager to add category "공지" to board "notice"
```

**생성되는 API 엔드포인트 (카테고리 관리):**

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/categories/board/:boardId` | 카테고리 목록 (트리) |
| GET | `/api/categories/board/:boardId/flat` | 카테고리 목록 (flat) |
| GET | `/api/categories/:id` | 카테고리 상세 |
| POST | `/api/categories` | 카테고리 생성 (admin/manager) |
| PUT | `/api/categories/:id` | 카테고리 수정 |
| DELETE | `/api/categories/:id` | 카테고리 삭제 |
| PUT | `/api/categories/reorder` | 순서 변경 (드래그앤드롭) |

**카테고리 기능:**

| 기능 | 설명 |
|------|------|
| 계층형 카테고리 | 무제한 depth, path 기반 빠른 조회 |
| 순서 관리 | 드래그앤드롭으로 순서/계층 변경 |
| 권한 설정 | 카테고리별 읽기/쓰기 권한 |
| 색상/아이콘 | 시각적 구분을 위한 설정 |

### Phase 8: 게시판 생성

> 기본 게시판 템플릿을 생성합니다.

```bash
# 게시판 시스템 초기화
Use board-generator --init

# 공지사항 게시판 생성
Use board-generator --template notice

# FAQ 게시판 생성
Use board-generator --template faq

# 자유게시판 생성
Use board-generator --template free

# Q&A 게시판 생성
Use board-generator --template qna

# 갤러리 게시판 생성
Use board-generator --template gallery

# 리뷰 게시판 생성
Use board-generator --template review

# 커스텀 게시판 생성
Use board-generator to create "상품문의" --type=qna
```

**생성되는 API 엔드포인트 (게시판):**

| Method | Endpoint | 설명 |
|--------|----------|------|
| GET | `/api/boards` | 게시판 목록 조회 |
| GET | `/api/boards/:boardCode` | 게시판 상세 |
| GET | `/api/boards/:boardCode/posts` | 게시글 목록 |
| GET | `/api/posts/:id` | 게시글 상세 |
| POST | `/api/posts` | 게시글 작성 |
| PUT | `/api/posts/:id` | 게시글 수정 |
| DELETE | `/api/posts/:id` | 게시글 삭제 |
| POST | `/api/posts/:id/comments` | 댓글 작성 |
| PUT | `/api/comments/:id` | 댓글 수정 |
| DELETE | `/api/comments/:id` | 댓글 삭제 |
| POST | `/api/posts/:id/like` | 좋아요/추천 |
| POST | `/api/attachments/upload` | 파일 업로드 |

**게시판 템플릿:**

| 템플릿 | 설명 | 주요 기능 |
|--------|------|----------|
| `notice` | 공지사항 | 상단 고정, 관리자만 작성 |
| `faq` | FAQ | 질문/답변 형식, 카테고리 분류 |
| `free` | 자유게시판 | 기본 게시판, 댓글/좋아요 |
| `qna` | Q&A | 질문/답변, 비밀글 지원 |
| `gallery` | 갤러리 | 이미지 썸네일, 그리드 뷰 |
| `review` | 리뷰 | 별점, 이미지 첨부 |

---

## 생성되는 파일 목록

### 문서

| 파일 | 설명 |
|------|------|
| `CLAUDE.md` | 프로젝트 가이드, 사용 가능한 에이전트/스킬 문서화 |

### 인증 (Backend)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/authHandler.js` | 인증 API 핸들러 |
| `middleware/node/middleware/auth.js` | JWT 미들웨어 |
| `middleware/node/db/schema/auth_schema.sql` | 사용자 테이블 |

### 인증 (Frontend)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/auth.ts` | 인증 타입 정의 |
| `frontend/src/lib/authApi.ts` | 인증 API 클라이언트 |
| `frontend/src/contexts/AuthContext.tsx` | 인증 Context |
| `frontend/src/components/auth/LoginPage.tsx` | 로그인 페이지 |
| `frontend/src/components/auth/RegisterPage.tsx` | 회원가입 페이지 |

### 메뉴 관리 (Backend)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/menuAdminHandler.js` | 관리자 메뉴 API |
| `middleware/node/api/menuHandler.js` | 사용자 메뉴 API |
| `middleware/node/db/schema/menu_schema.sql` | 메뉴 테이블 |

### 메뉴 관리 (Frontend)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/menu.ts` | 메뉴 타입 정의 |
| `frontend/src/lib/menuApi.ts` | 메뉴 API 클라이언트 |
| `frontend/src/components/admin/menu/MenuManager.tsx` | 메뉴 관리 메인 |
| `frontend/src/components/admin/menu/MenuTree.tsx` | 메뉴 트리 |
| `frontend/src/components/admin/menu/MenuForm.tsx` | 메뉴 폼 |

### 테넌트 관리 (Backend)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/tenants.js` | 테넌트 API |
| `middleware/node/middleware/tenantMiddleware.js` | 테넌트 식별 미들웨어 |
| `middleware/node/db/schema/tenant_schema.sql` | 테넌트 테이블 |

### 테넌트 관리 (Frontend)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/tenant.ts` | 테넌트 타입 정의 |
| `frontend/src/lib/tenantApi.ts` | 테넌트 API 클라이언트 |
| `frontend/src/components/admin/TenantManagement.tsx` | 테넌트 관리 UI |

### 카테고리 관리 (Backend)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/categories.js` | 카테고리 API |
| `middleware/node/db/schema/category_schema.sql` | 카테고리 테이블 |

### 카테고리 관리 (Frontend)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/category.ts` | 카테고리 타입 정의 |
| `frontend/src/lib/categoryApi.ts` | 카테고리 API 클라이언트 |
| `frontend/src/components/admin/CategoryManagement.tsx` | 카테고리 관리 UI |

### 게시판 (Backend)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/boards.js` | 게시판 API |
| `middleware/node/api/posts.js` | 게시글 API |
| `middleware/node/api/comments.js` | 댓글 API |
| `middleware/node/api/attachments.js` | 파일 첨부 API |
| `middleware/node/db/schema/board_schema.sql` | 게시판/게시글/댓글 테이블 |

### 게시판 (Frontend)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/board.ts` | 게시판 타입 정의 |
| `frontend/src/types/post.ts` | 게시글 타입 정의 |
| `frontend/src/lib/boardApi.ts` | 게시판 API 클라이언트 |
| `frontend/src/components/board/BoardList.tsx` | 게시글 목록 |
| `frontend/src/components/board/PostDetail.tsx` | 게시글 상세 |
| `frontend/src/components/board/PostForm.tsx` | 게시글 작성/수정 |
| `frontend/src/components/board/CommentList.tsx` | 댓글 목록 |
| `frontend/src/components/admin/BoardManagement.tsx` | 게시판 관리 UI |

---

## CLAUDE.md 템플릿

```markdown
# [프로젝트명] - Claude Code 가이드

## 프로젝트 정보

- **기술 스택**: {감지된 스택}
- **생성일**: {오늘 날짜}

---

## 개발 원칙

### Security First (보안 우선)
- 모든 사용자 입력 검증 (SQL Injection, XSS 방지)
- Parameterized Query 필수
- 비밀번호는 bcrypt로 해싱 (SALT_ROUNDS >= 12)
- JWT는 python-jose[cryptography] 또는 jose 사용
- API 키는 환경변수로 관리 (.env.local)
- httpOnly 쿠키로 토큰 저장 (XSS 방지)
- 인증번호는 개발모드에서 000000 고정 허용

### Error Handling First (오류 처리 우선)
- 모든 외부 호출에 try-catch
- 적절한 에러 응답 (error_code, message)
- 로깅 (민감 정보 제외)
- 프로덕션에서 스택 트레이스 노출 금지

### API 응답 표준 형식
```typescript
// 성공 응답
{
  "success": true,
  "data": { ... }
}

// 실패 응답
{
  "success": false,
  "error_code": "INVALID_INPUT",
  "message": "이메일 형식이 올바르지 않습니다."
}
```

| Error Code | HTTP Status | 설명 |
|------------|-------------|------|
| `DATABASE_UNAVAILABLE` | 503 | DB 연결 실패 |
| `ACCESS_DENIED` | 403 | 권한 없음 |
| `INVALID_INPUT` | 400 | 입력값 검증 실패 |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `INVALID_CREDENTIALS` | 401 | 인증 실패 |
| `INTERNAL_ERROR` | 500 | 서버 내부 오류 |

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

### 인증

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `auth-backend` | 인증 Backend API | `Use auth-backend --init` |
| `auth-frontend` | 인증 Frontend UI | `Use auth-frontend --init` |

### 메뉴 관리

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `menu-manager` | 통합 메뉴 관리 (프로토콜 문서) | `Use menu-manager --init` |
| `menu-backend` | 메뉴 Backend API | `Use menu-backend --init` |
| `menu-frontend` | 메뉴 Frontend UI | `Use menu-frontend --init` |

**메뉴 타입**: site, user, admin, header_utility, footer_utility

### 게시판

| 에이전트 | 설명 | 사용법 |
|----------|------|--------|
| `board-generator` | 멀티게시판 오케스트레이터 | `Use board-generator --init` |
| `board-schema` | DB 스키마 정의 (공유) | 참조용 |
| `board-templates` | 템플릿 정의 (공유) | 참조용 |
| `board-frontend-pages` | 페이지 템플릿 (공유) | 참조용 |
| `board-attachments` | 파일 첨부 기능 (공유) | 참조용 |

**템플릿**: notice, free, qna, gallery, faq, review

---

## 초기화 순서

\`\`\`bash
# 1. 공유 스키마 (필수 - 가장 먼저)
Use shared-schema --init

# 2. 인증 시스템 (인증 방식 선택)
# 옵션 A: 휴대폰 인증 기반 (권장)
Use auth-backend --init --type=phone
Use auth-frontend --init

# 옵션 B: 이메일/비밀번호 인증
Use auth-backend --init --type=email
Use auth-frontend --init

# 옵션 C: 소셜 로그인 추가
Use auth-backend --feature=social-kakao
Use auth-backend --feature=social-naver

# 3. 테넌트 관리 (멀티사이트 필요 시)
Use tenant-manager --init

# 4. 카테고리 관리
Use category-manager --init

# 5. 메뉴 관리
Use menu-backend --init
Use menu-frontend --init
Use menu-manager --type=user       # 마이페이지 메뉴
Use menu-manager --utility=header  # 헤더 유틸리티

# 6. 게시판 시스템
Use board-generator --init
Use board-generator --template notice
Use board-generator --template free
\`\`\`

**휴대폰 인증 흐름:**
\`\`\`
1. POST /api/auth/send-code       → 인증번호 발송
2. POST /api/auth/verify-code     → 인증번호 확인 (verification_token 발급)
3. POST /api/auth/register        → 회원가입 (verification_token 필요)
4. POST /api/auth/login           → 로그인 (휴대폰 + 인증번호)
\`\`\`

> **개발 모드**: 인증번호 `000000` 입력 시 항상 인증 통과

---

## 코딩 규칙

### 네이밍 컨벤션

| 구분 | 규칙 | 예시 |
|------|------|------|
| 컴포넌트/클래스 | PascalCase | `MenuManager`, `AuthHandler` |
| 변수/함수 | camelCase | `getAllMenus`, `isLoading` |
| 상수 | UPPER_SNAKE_CASE | `API_BASE_URL`, `MAX_RETRIES` |
| Boolean | is/has/should 접두사 | `isActive`, `hasPermission` |

### 필수 감사 컬럼

\`\`\`sql
created_at, created_by, updated_at, updated_by, is_active, is_deleted
\`\`\`

### Import 순서

1. 외부 라이브러리 (react, express 등)
2. 내부 패키지 (@project/shared 등)
3. 상대 경로 (../components 등)
4. 타입 import (type { ... })

---

## 자주 쓰는 명령

\`\`\`bash
# 인증 시스템
Use auth-backend --init --type=phone       # 휴대폰 인증 Backend
Use auth-backend --feature=social-kakao    # 카카오 소셜 로그인 추가
Use auth-frontend --page=phone-login       # 휴대폰 로그인 페이지

# 메뉴 관리
Use menu-manager --type=user               # 마이페이지 메뉴 생성
Use menu-manager --type=admin              # 관리자 메뉴 생성
Use menu-manager to add menu "[메뉴명]" --type=site

# 게시판 생성
Use board-generator to create [게시판명]
Use board-generator --template notice      # 공지사항 템플릿

# Git
/gitpush
/gitpull

# 개발 환경
/dev-setup                                 # Docker, 의존성 설치
/lint --fix                                # 린트 오류 수정
/test                                      # 테스트 실행
/db-migrate --generate "설명"              # 마이그레이션 생성
\`\`\`
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
  ✓ 인증 시스템 (Backend + Frontend)
  ✓ 메뉴 관리 시스템 (Backend + Frontend)

사용 가능한 기능:
  - Agents: auth-*, menu-*, board-*, tenant-*, category-*
  - Skills: coding-guide, gitpush, gitpull, refactor, modular-check

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

다음 단계:
  1. CLAUDE.md 내용 확인 및 필요시 수정
  2. 데이터베이스 스키마 실행:
     - middleware/node/db/schema/auth_schema.sql
     - middleware/node/db/schema/menu_schema.sql
  3. 환경 변수 설정 (.env.local):
     - JWT_SECRET
     - JWT_REFRESH_SECRET
     - MYSQL_HOST, MYSQL_USER, MYSQL_PASSWORD, MYSQL_DATABASE
  4. 서버 시작 및 테스트

---

## 환경 변수 설정

### Backend (.env)

\`\`\`bash
# Database
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/mydb

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
SECRET_KEY=your-secret-key-change-in-production-min-32-chars
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d

# SMS (프로덕션 전용)
SMS_API_KEY=
SMS_SENDER_NUMBER=

# 소셜 로그인
KAKAO_CLIENT_ID=
KAKAO_CLIENT_SECRET=
NAVER_CLIENT_ID=
NAVER_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# 개발 모드
DEV_MODE=true
DEV_VERIFICATION_CODE=000000
\`\`\`

### Frontend (.env.local)

\`\`\`bash
# API URL
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1

# 소셜 로그인
NEXT_PUBLIC_KAKAO_CLIENT_ID=
NEXT_PUBLIC_NAVER_CLIENT_ID=
NEXT_PUBLIC_GOOGLE_CLIENT_ID=

# 지도
NEXT_PUBLIC_KAKAO_MAP_KEY=
\`\`\`
```

---

## 스택별 추가 설정

### Express + React + MySQL

```
middleware/node/
├── api/
│   ├── authHandler.js      # 인증 API
│   └── menuAdminHandler.js # 메뉴 API
├── middleware/
│   └── auth.js             # JWT 미들웨어
├── db/
│   └── schema/
│       ├── auth_schema.sql
│       └── menu_schema.sql
└── server.js               # 라우터 등록

frontend/
├── src/
│   ├── types/
│   │   ├── auth.ts
│   │   └── menu.ts
│   ├── lib/
│   │   ├── authApi.ts
│   │   └── menuApi.ts
│   ├── contexts/
│   │   └── AuthContext.tsx
│   └── components/
│       ├── auth/
│       │   ├── LoginPage.tsx
│       │   └── RegisterPage.tsx
│       └── admin/
│           └── menu/
│               ├── MenuManager.tsx
│               ├── MenuTree.tsx
│               └── MenuForm.tsx
```

### FastAPI + React + PostgreSQL (권장 스택)

```
backend/
├── alembic/                     # DB 마이그레이션
│   ├── versions/
│   └── env.py
├── app/
│   ├── api/
│   │   ├── deps.py              # 의존성 (인증, DB 세션)
│   │   └── v1/
│   │       └── endpoints/
│   │           ├── auth.py      # 인증 API
│   │           ├── users.py     # 사용자 API
│   │           └── menus.py     # 메뉴 API
│   ├── core/
│   │   ├── config.py            # 환경 설정
│   │   └── security.py          # JWT, 비밀번호 해싱
│   ├── db/
│   │   ├── base.py              # Base 클래스, TimestampMixin
│   │   └── session.py           # DB 세션
│   ├── models/
│   │   ├── user.py              # User 모델
│   │   ├── menu.py              # Menu 모델
│   │   └── verification.py      # 인증번호 모델
│   ├── schemas/
│   │   ├── auth.py              # 인증 스키마
│   │   ├── user.py              # 사용자 스키마
│   │   └── menu.py              # 메뉴 스키마
│   ├── services/
│   │   ├── auth.py              # 인증 서비스
│   │   └── sms.py               # SMS 발송 서비스
│   └── main.py                  # FastAPI 앱
├── requirements.txt
└── .env

frontend/
├── src/
│   ├── app/                     # Next.js App Router
│   │   ├── (auth)/              # 인증 그룹
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── mypage/              # 마이페이지
│   │   └── admin/               # 관리자
│   │       └── menus/           # 메뉴 관리
│   ├── components/
│   │   ├── auth/                # 인증 컴포넌트
│   │   └── admin/
│   │       └── menu/            # 메뉴 관리 컴포넌트
│   ├── hooks/
│   │   ├── useAuth.ts           # 인증 훅
│   │   └── useMenu.ts           # 메뉴 훅
│   ├── lib/
│   │   └── api.ts               # API 클라이언트
│   ├── stores/
│   │   └── authStore.ts         # 인증 상태 (Zustand)
│   └── types/
│       ├── auth.ts              # 인증 타입
│       ├── user.ts              # 사용자 타입
│       └── menu.ts              # 메뉴 타입
└── package.json
```

**FastAPI 인증 예시 (휴대폰 인증):**

```python
# app/api/v1/endpoints/auth.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db
from app.core.security import create_access_token, verify_password
from app.schemas.auth import SendCodeRequest, VerifyCodeRequest, LoginRequest

router = APIRouter()

@router.post("/send-code")
async def send_verification_code(
    request: SendCodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """휴대폰 인증번호 발송"""
    # 개발 모드: 000000 고정
    # 프로덕션: SMS 발송
    ...

@router.post("/verify-code")
async def verify_code(
    request: VerifyCodeRequest,
    db: AsyncSession = Depends(get_db)
):
    """인증번호 확인 → verification_token 발급"""
    ...

@router.post("/register")
async def register(
    request: RegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    """회원가입 (verification_token 필요)"""
    ...

@router.post("/login")
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """로그인 (휴대폰 + 인증번호)"""
    ...
```

**FastAPI 필수 의존성:**

```txt
# requirements.txt
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy[asyncio]>=2.0.0
asyncpg>=0.29.0
alembic>=1.13.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
pydantic>=2.5.0
pydantic-settings>=2.1.0
python-multipart>=0.0.6
httpx>=0.26.0
redis>=5.0.0
```

**감사 컬럼 Mixin (필수):**

```python
# app/db/base.py
from sqlalchemy import Column, DateTime, String, Boolean
from sqlalchemy.sql import func

class TimestampMixin:
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    updated_by = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)
```

---

## 에이전트 실행 순서

```mermaid
graph TD
    A[project-init] --> B[기술 스택 감지]
    B --> C[CLAUDE.md 생성]
    C --> D[shared-schema]
    D --> E[auth-backend]
    D --> F[auth-frontend]
    E --> G[menu-backend]
    F --> H[menu-frontend]
    G --> I[완료]
    H --> I
```

---

## 참고

이 에이전트는 다음 에이전트들을 호출합니다:

**최우선 (순서대로):**
- `~/.claude/agents/shared-schema.md` (공유 테이블)
- `~/.claude/agents/tenant-manager.md` (테넌트/멀티사이트)
- `~/.claude/agents/category-manager.md` (카테고리 관리)

**인증:**
- `~/.claude/agents/auth-backend.md`
- `~/.claude/agents/auth-frontend.md`

**메뉴 관리:**
- `~/.claude/agents/menu-manager.md` (프로토콜 문서)
- `~/.claude/agents/menu-backend.md`
- `~/.claude/agents/menu-frontend.md`

**게시판:**
- `~/.claude/agents/board-generator.md` (오케스트레이터)
- `~/.claude/agents/board-schema.md` (DB 스키마)
- `~/.claude/agents/board-templates.md` (템플릿)
- `~/.claude/agents/board-frontend-pages.md` (페이지 템플릿)
- `~/.claude/agents/board-attachments.md` (파일 첨부)

**스킬:**
- `~/.claude/skills/coding-guide/`
- `~/.claude/skills/gitpush/`
- `~/.claude/skills/gitpull/`
- `~/.claude/skills/refactor/`
- `~/.claude/skills/modular-check/`
