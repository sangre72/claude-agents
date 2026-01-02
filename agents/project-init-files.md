---
name: project-init-files
description: 생성되는 파일 목록. project-init에서 참조.
tools: Read
model: haiku
---

# 생성되는 파일 목록

project-init 에이전트가 생성하는 파일 목록입니다.

---

## 문서

| 파일 | 설명 |
|------|------|
| `CLAUDE.md` | 프로젝트 가이드, 에이전트/스킬 문서화 |

---

## 인증 시스템

### Express Backend

| 파일 | 설명 |
|------|------|
| `middleware/node/api/authHandler.js` | 인증 API 핸들러 |
| `middleware/node/middleware/auth.js` | JWT 미들웨어 |
| `middleware/node/db/schema/auth_schema.sql` | 사용자 테이블 |

### Next.js (App Router + API Routes)

| 파일 | 설명 |
|------|------|
| `src/app/api/auth/[...nextauth]/route.ts` | NextAuth 핸들러 |
| `src/app/api/auth/send-code/route.ts` | 인증번호 발송 API |
| `src/app/api/auth/verify-code/route.ts` | 인증번호 확인 API |
| `src/app/(auth)/login/page.tsx` | 로그인 페이지 |
| `src/app/(auth)/register/page.tsx` | 회원가입 페이지 |
| `src/lib/auth.ts` | 인증 유틸리티 |

### FastAPI Backend

| 파일 | 설명 |
|------|------|
| `backend/app/api/v1/endpoints/auth.py` | 인증 API |
| `backend/app/core/security.py` | JWT, 비밀번호 해싱 |
| `backend/app/models/user.py` | User 모델 |

### Frontend (별도 프로젝트)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/auth.ts` | 인증 타입 정의 |
| `frontend/src/lib/authApi.ts` | 인증 API 클라이언트 |
| `frontend/src/contexts/AuthContext.tsx` | 인증 Context |
| `frontend/src/components/auth/LoginPage.tsx` | 로그인 페이지 |
| `frontend/src/components/auth/RegisterPage.tsx` | 회원가입 페이지 |

---

## 메뉴 관리 시스템

### Backend

| 파일 | 설명 |
|------|------|
| `middleware/node/api/menuAdminHandler.js` | 관리자 메뉴 API |
| `middleware/node/api/menuHandler.js` | 사용자 메뉴 API |
| `middleware/node/db/schema/menu_schema.sql` | 메뉴 테이블 |

### Frontend

| 파일 | 설명 |
|------|------|
| `frontend/src/types/menu.ts` | 메뉴 타입 정의 |
| `frontend/src/lib/menuApi.ts` | 메뉴 API 클라이언트 |
| `frontend/src/components/admin/menu/MenuManager.tsx` | 메뉴 관리 메인 |
| `frontend/src/components/admin/menu/MenuTree.tsx` | 메뉴 트리 |
| `frontend/src/components/admin/menu/MenuForm.tsx` | 메뉴 폼 |

---

## 테넌트 관리 (선택)

### Backend

| 파일 | 설명 |
|------|------|
| `middleware/node/api/tenants.js` | 테넌트 API |
| `middleware/node/middleware/tenantMiddleware.js` | 테넌트 식별 미들웨어 |
| `middleware/node/db/schema/tenant_schema.sql` | 테넌트 테이블 |

### Frontend

| 파일 | 설명 |
|------|------|
| `frontend/src/types/tenant.ts` | 테넌트 타입 정의 |
| `frontend/src/lib/tenantApi.ts` | 테넌트 API 클라이언트 |
| `frontend/src/components/admin/TenantManagement.tsx` | 테넌트 관리 UI |

---

## 카테고리 관리 (선택)

### Backend

| 파일 | 설명 |
|------|------|
| `middleware/node/api/categories.js` | 카테고리 API |
| `middleware/node/db/schema/category_schema.sql` | 카테고리 테이블 |

### Frontend

| 파일 | 설명 |
|------|------|
| `frontend/src/types/category.ts` | 카테고리 타입 정의 |
| `frontend/src/lib/categoryApi.ts` | 카테고리 API 클라이언트 |
| `frontend/src/components/admin/CategoryManagement.tsx` | 카테고리 관리 UI |

---

## 게시판 시스템 (선택)

### Backend

| 파일 | 설명 |
|------|------|
| `middleware/node/api/boards.js` | 게시판 API |
| `middleware/node/api/posts.js` | 게시글 API |
| `middleware/node/api/comments.js` | 댓글 API |
| `middleware/node/api/attachments.js` | 파일 첨부 API |
| `middleware/node/db/schema/board_schema.sql` | 게시판/게시글/댓글 테이블 |

### Frontend

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
