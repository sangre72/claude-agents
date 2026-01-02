---
name: board-frontend-components
description: 게시판 Frontend 컴포넌트 생성. 프로젝트의 기술 스택(React/Vue/Angular)과 UI 라이브러리(MUI/Bootstrap/Tailwind)에 맞게 생성. board-shared 완료 후 병렬 실행 가능.
tools: Read, Edit, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 Frontend 컴포넌트 에이전트

프로젝트의 **기존 Frontend 스택을 분석**하여 컴포넌트를 생성합니다.
**board-shared 완료 후** 다른 에이전트와 **병렬 실행** 가능합니다.

---

## Phase 0: 기술 스택 분석 (CRITICAL)

```bash
# Frontend 프레임워크 감지
cat frontend/package.json | grep -E "react|vue|angular|svelte"

# UI 라이브러리 감지
cat frontend/package.json | grep -E "@mui|bootstrap|tailwind|antd|chakra"

# 기존 컴포넌트 패턴 분석
ls frontend/src/components/
head -50 frontend/src/components/**/*.{tsx,jsx,vue}
```

### 지원 스택

| Framework | UI Library | 파일 확장자 |
|-----------|-----------|------------|
| React | MUI | `.tsx` |
| React | Bootstrap | `.tsx` |
| React | Tailwind | `.tsx` |
| Vue | Vuetify | `.vue` |
| Vue | Bootstrap Vue | `.vue` |
| Angular | Material | `.ts` |

---

## 컴포넌트 설계 (공통)

> 기술 스택에 관계없이 동일한 컴포넌트 구조

### 필수 컴포넌트

| 컴포넌트 | 설명 |
|----------|------|
| `PostList` | 게시글 목록 (페이지네이션, 검색, 공지 표시) |
| `PostDetail` | 게시글 상세 (비밀글 처리, 첨부파일) |
| `PostForm` | 게시글 작성/수정 폼 |
| `CommentList` | 댓글 목록 (대댓글 지원) |
| `CommentForm` | 댓글 작성 폼 |
| `AttachmentList` | 첨부파일 목록 |

### 컴포넌트 Props 설계

```typescript
// PostList
interface PostListProps {
  boardCode: string;
  boardName?: string;
}

// PostDetail
interface PostDetailProps {
  boardCode: string;
  postId: string | number;
}

// PostForm
interface PostFormProps {
  boardCode: string;
  postId?: string | number;  // 수정 시
}

// CommentList
interface CommentListProps {
  boardCode: string;
  postId: string | number;
}
```

---

## 구현 원칙

### 1. 기존 패턴 따르기

- 기존 컴포넌트의 **네이밍 컨벤션** 유지
- 기존 컴포넌트의 **스타일링 방식** 유지
- 기존 컴포넌트의 **상태 관리 방식** 유지

### 2. 멀티게시판 지원

- 모든 컴포넌트는 `boardCode`를 Props로 받음
- 게시판 설정(categories, useSecret 등)에 따라 UI 동적 변경
- 권한에 따른 버튼/기능 표시/숨김

### 3. UX 필수 요소

- **목록으로 버튼**: 상세 페이지에서 목록으로 돌아가기
- **취소 버튼**: 폼에서 이전 페이지로
- **로딩 상태**: 데이터 로딩 중 표시
- **에러 상태**: 에러 발생 시 사용자에게 알림

---

## 스택별 생성 파일

### React + MUI

**경로**: `frontend/src/components/board/`

```
PostList.tsx
PostDetail.tsx
PostForm.tsx
CommentList.tsx
CommentForm.tsx
AttachmentList.tsx
index.ts
```

### React + Bootstrap

**경로**: `frontend/src/components/board/`

```
PostList.tsx
PostDetail.tsx
PostForm.tsx
CommentList.tsx
CommentForm.tsx
AttachmentList.tsx
index.ts
```

### Vue

**경로**: `frontend/src/components/board/`

```
PostList.vue
PostDetail.vue
PostForm.vue
CommentList.vue
CommentForm.vue
AttachmentList.vue
index.ts
```

---

## 핵심 기능 구현

### 1. 게시글 목록 (PostList)

```
기능:
- 게시판 코드로 게시글 목록 조회
- 페이지네이션
- 검색 (제목/내용)
- 카테고리 필터 (게시판 설정에 따라)
- 공지글 상단 고정
- 비밀글 아이콘 표시
- 댓글 수 표시

UI:
- 테이블 또는 카드 형태
- 반응형 지원
- 로딩 스피너
- 빈 상태 메시지
```

### 2. 게시글 상세 (PostDetail)

```
기능:
- 게시글 상세 조회
- 비밀글 비밀번호 입력 처리
- 조회수 자동 증가
- 수정/삭제 버튼 (권한에 따라)
- 첨부파일 다운로드
- 댓글 목록 표시

UI:
- 제목, 작성자, 작성일, 조회수
- 공지/비밀글 배지
- 본문 영역
- 첨부파일 목록
- 이전/다음 글 (선택)
```

### 3. 게시글 폼 (PostForm)

```
기능:
- 작성/수정 모드 분기
- 제목, 내용 입력
- 카테고리 선택 (게시판 설정에 따라)
- 공지글 체크 (관리자만)
- 비밀글 체크 및 비밀번호
- 파일 첨부
- 유효성 검사

UI:
- 폼 레이아웃
- 에러 메시지
- 제출/취소 버튼
```

### 4. 댓글 목록 (CommentList)

```
기능:
- 댓글 목록 조회
- 대댓글 표시 (들여쓰기)
- 댓글 작성 (로그인 필요)
- 댓글 삭제 (작성자/관리자)
- 답글 달기

UI:
- 댓글 카드
- 작성자, 작성일
- 답글 버튼
- 삭제 버튼
```

---

## 페이지 생성 (라우팅)

### React (react-router 또는 Next.js)

```
/boards/:boardCode              → 게시글 목록
/boards/:boardCode/:postId      → 게시글 상세
/boards/:boardCode/write        → 게시글 작성
/boards/:boardCode/:postId/edit → 게시글 수정
```

### Vue (vue-router)

```
/boards/:boardCode              → 게시글 목록
/boards/:boardCode/:postId      → 게시글 상세
/boards/:boardCode/write        → 게시글 작성
/boards/:boardCode/:postId/edit → 게시글 수정
```

---

## API 호출 (Hooks/Composables)

### React

**파일 경로**: `frontend/src/hooks/useBoard.ts`

```typescript
// 게시판 정보 조회
export function useBoard(boardCode: string);

// 게시글 목록 조회
export function usePosts(boardCode: string, options?: PostListOptions);

// 게시글 상세 조회
export function usePost(boardCode: string, postId: string, password?: string);

// 게시글 생성
export function useCreatePost(boardCode: string);

// 게시글 수정
export function useUpdatePost(boardCode: string, postId: string);

// 게시글 삭제
export function useDeletePost(boardCode: string);

// 댓글 목록 조회
export function useComments(boardCode: string, postId: string);

// 댓글 생성
export function useCreateComment(boardCode: string, postId: string);

// 댓글 삭제
export function useDeleteComment(boardCode: string, postId: string);
```

### Vue

**파일 경로**: `frontend/src/composables/useBoard.ts`

```typescript
// Composable 형태로 동일한 기능 제공
export function useBoard(boardCode: Ref<string>);
export function usePosts(boardCode: Ref<string>, options?: PostListOptions);
// ...
```

---

## 생성 워크플로우

### Step 1: 기술 스택 분석

```bash
# package.json 분석
cat frontend/package.json

# 기존 컴포넌트 패턴 분석
ls frontend/src/components/
```

### Step 2: 기존 패턴 파악

```bash
# 기존 컴포넌트 구조 확인
head -100 frontend/src/components/**/*.tsx
```

### Step 3: 컴포넌트 생성

1. `PostList` 컴포넌트 생성
2. `PostDetail` 컴포넌트 생성
3. `PostForm` 컴포넌트 생성
4. `CommentList` 컴포넌트 생성
5. `index` 파일 (re-export)

### Step 4: Hooks/Composables 생성

1. API 호출 훅 생성
2. 기존 상태 관리 방식에 맞게 구현

### Step 5: 페이지/라우터 설정

1. 페이지 컴포넌트 생성
2. 라우터에 경로 추가

---

## 완료 조건

1. 기술 스택 분석 완료
2. 기존 컴포넌트 패턴 분석 완료
3. PostList 컴포넌트 생성됨
4. PostDetail 컴포넌트 생성됨
5. PostForm 컴포넌트 생성됨
6. CommentList 컴포넌트 생성됨
7. index 파일 생성됨
8. Hooks/Composables 생성됨
9. 페이지 컴포넌트 생성됨
10. 라우터에 경로 등록됨
11. 기존 코드 패턴과 일관성 유지됨
