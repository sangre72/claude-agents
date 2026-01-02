---
name: board-shared
description: 게시판 공유 모듈 생성. Backend/Frontend 간 공유되는 타입, 상수, 인터페이스 정의. 프로젝트 기술 스택에 맞게 생성. 다른 에이전트보다 먼저 실행되어야 함.
tools: Read, Edit, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 공유 모듈 에이전트

Backend와 Frontend 간 공유되는 타입, 상수, 인터페이스를 정의합니다.
다른 병렬 에이전트들이 참조하므로 **가장 먼저 실행**되어야 합니다.

> **중요**: 프로젝트의 기술 스택을 분석하여 적절한 형식으로 생성합니다.

---

## Phase 0: 기술 스택 분석

```bash
# Backend 언어 확인
ls package.json          # JavaScript/TypeScript
ls requirements.txt      # Python
ls pom.xml              # Java

# Frontend 언어 확인
ls frontend/package.json
grep "typescript" frontend/package.json
```

---

## 공유 상수 (멀티게시판 공통)

### 권한 타입

```
Permission:
  - public: 전체 공개
  - member: 회원만
  - admin: 관리자만
  - disabled: 비활성화
```

### 에러 코드

```
BoardErrorCode:
  - BOARD_NOT_FOUND: 게시판을 찾을 수 없음
  - BOARD_CODE_DUPLICATE: 게시판 코드 중복
  - POST_NOT_FOUND: 게시글을 찾을 수 없음
  - COMMENT_NOT_FOUND: 댓글을 찾을 수 없음
  - ACCESS_DENIED: 접근 권한 없음
  - AUTH_REQUIRED: 로그인 필요
  - SECRET_POST_ACCESS_DENIED: 비밀글 접근 불가
  - FILE_UPLOAD_FAILED: 파일 업로드 실패
  - FILE_SIZE_EXCEEDED: 파일 크기 초과
  - FILE_TYPE_NOT_ALLOWED: 허용되지 않은 파일 형식
  - COMMENT_DISABLED: 댓글 비활성화됨
```

### 파일 업로드 설정

```
ALLOWED_EXTENSIONS: ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx', '.xls', '.xlsx']
MAX_FILE_SIZE: 10 * 1024 * 1024  // 10MB
```

### 페이지네이션

```
DEFAULT_PAGE_SIZE: 20
MAX_PAGE_SIZE: 100
```

---

## 스택별 생성 파일

### JavaScript/Node.js Backend

**파일 경로**: `{backend_path}/constants/boardConstants.js`

```javascript
/**
 * 게시판 공유 상수
 */

// 권한 타입
const Permission = {
  PUBLIC: 'public',
  MEMBER: 'member',
  ADMIN: 'admin',
  DISABLED: 'disabled',
};

// 에러 코드
const BoardErrorCode = {
  BOARD_NOT_FOUND: 'BOARD_NOT_FOUND',
  BOARD_CODE_DUPLICATE: 'BOARD_CODE_DUPLICATE',
  POST_NOT_FOUND: 'POST_NOT_FOUND',
  COMMENT_NOT_FOUND: 'COMMENT_NOT_FOUND',
  ACCESS_DENIED: 'ACCESS_DENIED',
  AUTH_REQUIRED: 'AUTH_REQUIRED',
  SECRET_POST_ACCESS_DENIED: 'SECRET_POST_ACCESS_DENIED',
  FILE_UPLOAD_FAILED: 'FILE_UPLOAD_FAILED',
  FILE_SIZE_EXCEEDED: 'FILE_SIZE_EXCEEDED',
  FILE_TYPE_NOT_ALLOWED: 'FILE_TYPE_NOT_ALLOWED',
  COMMENT_DISABLED: 'COMMENT_DISABLED',
};

// 파일 업로드 설정
const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx', '.xls', '.xlsx'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

// 페이지네이션
const DEFAULT_PAGE_SIZE = 20;
const MAX_PAGE_SIZE = 100;

// 권한 라벨 (한글)
const PERMISSION_LABELS = {
  public: '전체 공개',
  member: '회원만',
  admin: '관리자만',
  disabled: '비활성화',
};

module.exports = {
  Permission,
  BoardErrorCode,
  ALLOWED_EXTENSIONS,
  MAX_FILE_SIZE,
  DEFAULT_PAGE_SIZE,
  MAX_PAGE_SIZE,
  PERMISSION_LABELS,
};
```

### Python Backend

**파일 경로**: `{backend_path}/core/board_constants.py`

```python
"""게시판 공유 상수."""
from enum import Enum


class Permission(str, Enum):
    """권한 타입."""
    PUBLIC = "public"
    MEMBER = "member"
    ADMIN = "admin"
    DISABLED = "disabled"


class BoardErrorCode(str, Enum):
    """게시판 에러 코드."""
    BOARD_NOT_FOUND = "BOARD_NOT_FOUND"
    BOARD_CODE_DUPLICATE = "BOARD_CODE_DUPLICATE"
    POST_NOT_FOUND = "POST_NOT_FOUND"
    COMMENT_NOT_FOUND = "COMMENT_NOT_FOUND"
    ACCESS_DENIED = "ACCESS_DENIED"
    AUTH_REQUIRED = "AUTH_REQUIRED"
    SECRET_POST_ACCESS_DENIED = "SECRET_POST_ACCESS_DENIED"
    FILE_UPLOAD_FAILED = "FILE_UPLOAD_FAILED"
    FILE_SIZE_EXCEEDED = "FILE_SIZE_EXCEEDED"
    FILE_TYPE_NOT_ALLOWED = "FILE_TYPE_NOT_ALLOWED"
    COMMENT_DISABLED = "COMMENT_DISABLED"


# 파일 업로드 설정
ALLOWED_EXTENSIONS = {'.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx', '.xls', '.xlsx'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

# 페이지네이션
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE = 100

# 권한 라벨
PERMISSION_LABELS = {
    "public": "전체 공개",
    "member": "회원만",
    "admin": "관리자만",
    "disabled": "비활성화",
}
```

### TypeScript Frontend

**파일 경로**: `{frontend_path}/lib/board/constants.ts`

```typescript
/**
 * 게시판 공유 상수
 */

export type Permission = 'public' | 'member' | 'admin' | 'disabled';

export const BoardErrorCode = {
  BOARD_NOT_FOUND: 'BOARD_NOT_FOUND',
  BOARD_CODE_DUPLICATE: 'BOARD_CODE_DUPLICATE',
  POST_NOT_FOUND: 'POST_NOT_FOUND',
  COMMENT_NOT_FOUND: 'COMMENT_NOT_FOUND',
  ACCESS_DENIED: 'ACCESS_DENIED',
  AUTH_REQUIRED: 'AUTH_REQUIRED',
  SECRET_POST_ACCESS_DENIED: 'SECRET_POST_ACCESS_DENIED',
  FILE_UPLOAD_FAILED: 'FILE_UPLOAD_FAILED',
  FILE_SIZE_EXCEEDED: 'FILE_SIZE_EXCEEDED',
  FILE_TYPE_NOT_ALLOWED: 'FILE_TYPE_NOT_ALLOWED',
  COMMENT_DISABLED: 'COMMENT_DISABLED',
} as const;

export type BoardErrorCodeType = typeof BoardErrorCode[keyof typeof BoardErrorCode];

// 파일 업로드 설정
export const ALLOWED_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.gif', '.pdf', '.doc', '.docx', '.xls', '.xlsx'];
export const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB

// 페이지네이션
export const DEFAULT_PAGE_SIZE = 20;
export const MAX_PAGE_SIZE = 100;

// 권한 라벨
export const PERMISSION_LABELS: Record<Permission, string> = {
  public: '전체 공개',
  member: '회원만',
  admin: '관리자만',
  disabled: '비활성화',
};
```

---

## 게시판 템플릿 정의

**파일 경로**: `{frontend_path}/lib/board/templates.ts` 또는 `.js`

```typescript
/**
 * 게시판 템플릿 정의 (멀티게시판용)
 */
import type { Permission } from './constants';

export interface BoardTemplate {
  name: string;
  code: string;
  description: string;
  readPermission: Permission;
  writePermission: Permission;
  commentPermission: Permission;
  useCategory: boolean;
  useNotice: boolean;
  useSecret: boolean;
  useAttachment: boolean;
  useLike: boolean;
  useComment: boolean;
  categories?: string[];
}

export const BOARD_TEMPLATES: Record<string, BoardTemplate> = {
  notice: {
    name: '공지사항',
    code: 'notice',
    description: '중요한 공지사항을 알려드립니다.',
    readPermission: 'public',
    writePermission: 'admin',
    commentPermission: 'disabled',
    useCategory: false,
    useNotice: true,
    useSecret: false,
    useAttachment: true,
    useLike: false,
    useComment: false,
  },
  free: {
    name: '자유게시판',
    code: 'free',
    description: '자유롭게 의견을 나눠보세요.',
    readPermission: 'public',
    writePermission: 'member',
    commentPermission: 'member',
    useCategory: false,
    useNotice: true,
    useSecret: true,
    useAttachment: true,
    useLike: true,
    useComment: true,
  },
  qna: {
    name: '질문과 답변',
    code: 'qna',
    description: '궁금한 점을 질문해주세요.',
    readPermission: 'public',
    writePermission: 'member',
    commentPermission: 'member',
    useCategory: true,
    useNotice: true,
    useSecret: true,
    useAttachment: true,
    useLike: false,
    useComment: true,
    categories: ['서비스문의', '결제문의', '기타'],
  },
  faq: {
    name: '자주 묻는 질문',
    code: 'faq',
    description: '자주 묻는 질문과 답변입니다.',
    readPermission: 'public',
    writePermission: 'admin',
    commentPermission: 'disabled',
    useCategory: true,
    useNotice: false,
    useSecret: false,
    useAttachment: false,
    useLike: false,
    useComment: false,
    categories: ['서비스안내', '결제/환불', '이용방법'],
  },
};
```

---

## 타입 정의 (TypeScript Frontend)

**파일 경로**: `{frontend_path}/types/board.ts`

```typescript
/**
 * 게시판 타입 정의 (멀티게시판용)
 */
import type { Permission } from '@/lib/board/constants';

// 게시판 설정 (boards 테이블)
export interface Board {
  id: number;
  code: string;
  name: string;
  description: string | null;
  readPermission: Permission;
  writePermission: Permission;
  commentPermission: Permission;
  useCategory: boolean;
  categories: string[];
  useNotice: boolean;
  useSecret: boolean;
  useAttachment: boolean;
  useLike: boolean;
  useComment: boolean;
  createdAt: string;
  updatedAt: string;
}

// 게시글 목록 아이템
export interface PostListItem {
  id: number;
  boardCode: string;
  title: string;
  authorName: string;
  category: string | null;
  isNotice: boolean;
  isSecret: boolean;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  createdAt: string;
}

// 게시글 상세
export interface Post extends PostListItem {
  content: string;
  authorId: string;
  attachments: Attachment[];
  updatedAt: string;
}

// 게시글 생성
export interface PostCreate {
  title: string;
  content: string;
  category?: string;
  isNotice?: boolean;
  isSecret?: boolean;
  secretPassword?: string;
}

// 게시글 수정
export interface PostUpdate {
  title?: string;
  content?: string;
  category?: string;
  isNotice?: boolean;
  isSecret?: boolean;
}

// 댓글
export interface Comment {
  id: string;
  postId: number;
  parentId: string | null;
  content: string;
  authorId: string;
  authorName: string;
  likeCount: number;
  createdAt: string;
  replies?: Comment[];
}

// 댓글 생성
export interface CommentCreate {
  content: string;
  parentId?: string;
}

// 첨부파일
export interface Attachment {
  id: number;
  postId: number;
  originalName: string;
  storedName: string;
  fileSize: number;
  mimeType: string;
  downloadCount: number;
}

// 페이지네이션 응답
export interface PaginatedResponse<T> {
  items: T[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

// API 응답
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error_code?: string;
  message?: string;
}
```

---

## 생성 워크플로우

### Step 1: 기술 스택 분석

```bash
# Backend 언어/프레임워크 확인
# Frontend 언어/프레임워크 확인
```

### Step 2: 경로 결정

| 스택 | Backend 경로 | Frontend 경로 |
|------|-------------|--------------|
| Express (JS) | `api/constants/` | `src/lib/board/` |
| Express (TS) | `src/constants/` | `src/lib/board/` |
| FastAPI | `app/core/` | `src/lib/board/` |
| Flask | `app/constants/` | `src/lib/board/` |

### Step 3: 파일 생성

1. Backend 상수 파일 생성
2. Frontend 상수 파일 생성
3. Frontend 타입 파일 생성
4. Frontend 템플릿 파일 생성
5. index 파일 (re-export) 생성

---

## 완료 조건

1. 기술 스택 분석 완료
2. Backend 상수 파일 생성됨
3. Frontend 상수 파일 생성됨
4. Frontend 타입 파일 생성됨
5. Frontend 템플릿 파일 생성됨
6. index.ts/js re-export 파일 생성됨
