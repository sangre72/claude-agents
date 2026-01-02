---
name: board-frontend-types
description: 게시판 Frontend 타입 생성. TypeScript 타입 + API 클라이언트 + 훅. board-shared 완료 후 병렬 실행 가능.
tools: Read, Edit, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 Frontend 타입 에이전트

TypeScript 타입, API 클라이언트, 커스텀 훅을 생성합니다.
**board-shared 완료 후** 다른 에이전트와 **병렬 실행** 가능합니다.

## 의존성

- board-shared (필수, 먼저 완료되어야 함)

## 생성 파일

### 1. 게시판 타입 (frontend/src/types/board.ts)

```typescript
/**
 * 게시판 관련 타입 정의
 */
import type { Permission } from '@/lib/board/constants';

// ===== Board =====
export interface Board {
  id: string;
  code: string;
  name: string;
  description?: string;
  readPermission: Permission;
  writePermission: Permission;
  commentPermission: Permission;
  useCategory: boolean;
  useNotice: boolean;
  useSecret: boolean;
  useAttachment: boolean;
  useLike: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface BoardCreate {
  code: string;
  name: string;
  description?: string;
  readPermission?: Permission;
  writePermission?: Permission;
  commentPermission?: Permission;
  useCategory?: boolean;
  useNotice?: boolean;
  useSecret?: boolean;
  useAttachment?: boolean;
  useLike?: boolean;
}

// ===== Category =====
export interface BoardCategory {
  id: string;
  boardId: string;
  name: string;
  sortOrder: number;
}

// ===== Post =====
export interface Post {
  id: string;
  boardId: string;
  categoryId?: string;
  authorId: string;
  authorName: string;
  title: string;
  content: string;
  isNotice: boolean;
  isSecret: boolean;
  viewCount: number;
  likeCount: number;
  commentCount: number;
  isAnswered: boolean;
  createdAt: string;
  updatedAt: string;
  attachments: Attachment[];
}

export interface PostListItem {
  id: string;
  title: string;
  authorName: string;
  isNotice: boolean;
  isSecret: boolean;
  viewCount: number;
  commentCount: number;
  createdAt: string;
}

export interface PostCreate {
  title: string;
  content: string;
  categoryId?: string;
  isNotice?: boolean;
  isSecret?: boolean;
  secretPassword?: string;
}

export interface PostUpdate {
  title?: string;
  content?: string;
  categoryId?: string;
  isNotice?: boolean;
  isSecret?: boolean;
}

// ===== Comment =====
export interface Comment {
  id: string;
  postId: string;
  parentId?: string;
  authorId: string;
  authorName: string;
  content: string;
  isSecret: boolean;
  likeCount: number;
  createdAt: string;
  replies: Comment[];
}

export interface CommentCreate {
  content: string;
  parentId?: string;
  isSecret?: boolean;
}

// ===== Attachment =====
export interface Attachment {
  id: string;
  postId: string;
  originalName: string;
  fileSize: number;
  mimeType: string;
  downloadCount: number;
}

// ===== Pagination =====
export interface PaginatedPosts {
  items: PostListItem[];
  total: number;
  page: number;
  size: number;
  pages: number;
}

// ===== API Response =====
export interface BoardApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  errorCode?: string;
}
```

### 2. types/index.ts 업데이트

```typescript
// frontend/src/types/index.ts에 추가
export type {
  Board,
  BoardCreate,
  BoardCategory,
  Post,
  PostListItem,
  PostCreate,
  PostUpdate,
  Comment,
  CommentCreate,
  Attachment,
  PaginatedPosts,
  BoardApiResponse,
} from './board';
```

### 3. API 클라이언트 (frontend/src/lib/board/api.ts)

```typescript
/**
 * 게시판 API 클라이언트
 */
import { api } from '@/lib/api';
import type {
  Board,
  BoardCreate,
  Post,
  PostCreate,
  PostUpdate,
  Comment,
  CommentCreate,
  PaginatedPosts,
  BoardApiResponse,
} from '@/types/board';

export interface PostListParams {
  page?: number;
  size?: number;
  categoryId?: string;
  search?: string;
}

export const boardApi = {
  // ===== Board =====
  getBoards: async (): Promise<Board[]> => {
    const response = await api.get<BoardApiResponse<Board[]>>('/boards');
    if (!response.data.success) {
      throw new Error(response.data.message || '게시판 목록을 불러올 수 없습니다.');
    }
    return response.data.data || [];
  },

  getBoard: async (code: string): Promise<Board> => {
    const response = await api.get<BoardApiResponse<Board>>(`/boards/${code}`);
    if (!response.data.success) {
      throw new Error(response.data.message || '게시판을 찾을 수 없습니다.');
    }
    return response.data.data!;
  },

  createBoard: async (data: BoardCreate): Promise<Board> => {
    const response = await api.post<BoardApiResponse<Board>>('/boards', data);
    if (!response.data.success) {
      throw new Error(response.data.message || '게시판 생성에 실패했습니다.');
    }
    return response.data.data!;
  },

  // ===== Post =====
  getPosts: async (boardCode: string, params?: PostListParams): Promise<PaginatedPosts> => {
    const response = await api.get<BoardApiResponse<PaginatedPosts>>(
      `/boards/${boardCode}/posts`,
      { params }
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '게시글 목록을 불러올 수 없습니다.');
    }
    return response.data.data!;
  },

  getPost: async (boardCode: string, postId: string, password?: string): Promise<Post> => {
    const response = await api.get<BoardApiResponse<Post>>(
      `/boards/${boardCode}/posts/${postId}`,
      { params: password ? { password } : undefined }
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '게시글을 찾을 수 없습니다.');
    }
    return response.data.data!;
  },

  createPost: async (boardCode: string, data: PostCreate): Promise<{ id: string }> => {
    const response = await api.post<BoardApiResponse<{ id: string }>>(
      `/boards/${boardCode}/posts`,
      data
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '게시글 작성에 실패했습니다.');
    }
    return response.data.data!;
  },

  updatePost: async (boardCode: string, postId: string, data: PostUpdate): Promise<{ id: string }> => {
    const response = await api.patch<BoardApiResponse<{ id: string }>>(
      `/boards/${boardCode}/posts/${postId}`,
      data
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '게시글 수정에 실패했습니다.');
    }
    return response.data.data!;
  },

  deletePost: async (boardCode: string, postId: string): Promise<void> => {
    const response = await api.delete<BoardApiResponse<void>>(
      `/boards/${boardCode}/posts/${postId}`
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '게시글 삭제에 실패했습니다.');
    }
  },

  // ===== Comment =====
  getComments: async (boardCode: string, postId: string): Promise<Comment[]> => {
    const response = await api.get<BoardApiResponse<Comment[]>>(
      `/boards/${boardCode}/posts/${postId}/comments`
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '댓글을 불러올 수 없습니다.');
    }
    return response.data.data || [];
  },

  createComment: async (
    boardCode: string,
    postId: string,
    data: CommentCreate
  ): Promise<{ id: string }> => {
    const response = await api.post<BoardApiResponse<{ id: string }>>(
      `/boards/${boardCode}/posts/${postId}/comments`,
      data
    );
    if (!response.data.success) {
      throw new Error(response.data.message || '댓글 작성에 실패했습니다.');
    }
    return response.data.data!;
  },

  deleteComment: async (commentId: string): Promise<void> => {
    const response = await api.delete<BoardApiResponse<void>>(`/boards/comments/${commentId}`);
    if (!response.data.success) {
      throw new Error(response.data.message || '댓글 삭제에 실패했습니다.');
    }
  },
};
```

### 4. 커스텀 훅 (frontend/src/hooks/useBoard.ts)

```typescript
/**
 * 게시판 커스텀 훅
 */
'use client';

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { boardApi, type PostListParams } from '@/lib/board/api';
import type { PostCreate, PostUpdate, CommentCreate } from '@/types/board';

// Query Keys
export const boardKeys = {
  all: ['boards'] as const,
  lists: () => [...boardKeys.all, 'list'] as const,
  detail: (code: string) => [...boardKeys.all, 'detail', code] as const,
  posts: (boardCode: string) => [...boardKeys.all, boardCode, 'posts'] as const,
  postList: (boardCode: string, params?: PostListParams) =>
    [...boardKeys.posts(boardCode), params] as const,
  postDetail: (boardCode: string, postId: string) =>
    [...boardKeys.posts(boardCode), postId] as const,
  comments: (boardCode: string, postId: string) =>
    [...boardKeys.postDetail(boardCode, postId), 'comments'] as const,
};

// ===== Board Hooks =====
export function useBoards() {
  return useQuery({
    queryKey: boardKeys.lists(),
    queryFn: boardApi.getBoards,
  });
}

export function useBoard(code: string) {
  return useQuery({
    queryKey: boardKeys.detail(code),
    queryFn: () => boardApi.getBoard(code),
    enabled: !!code,
  });
}

// ===== Post Hooks =====
export function usePosts(boardCode: string, params?: PostListParams) {
  return useQuery({
    queryKey: boardKeys.postList(boardCode, params),
    queryFn: () => boardApi.getPosts(boardCode, params),
    enabled: !!boardCode,
  });
}

export function usePost(boardCode: string, postId: string, password?: string) {
  return useQuery({
    queryKey: boardKeys.postDetail(boardCode, postId),
    queryFn: () => boardApi.getPost(boardCode, postId, password),
    enabled: !!boardCode && !!postId,
  });
}

export function useCreatePost(boardCode: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: PostCreate) => boardApi.createPost(boardCode, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: boardKeys.posts(boardCode) });
    },
  });
}

export function useUpdatePost(boardCode: string, postId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: PostUpdate) => boardApi.updatePost(boardCode, postId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: boardKeys.postDetail(boardCode, postId) });
      queryClient.invalidateQueries({ queryKey: boardKeys.posts(boardCode) });
    },
  });
}

export function useDeletePost(boardCode: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (postId: string) => boardApi.deletePost(boardCode, postId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: boardKeys.posts(boardCode) });
    },
  });
}

// ===== Comment Hooks =====
export function useComments(boardCode: string, postId: string) {
  return useQuery({
    queryKey: boardKeys.comments(boardCode, postId),
    queryFn: () => boardApi.getComments(boardCode, postId),
    enabled: !!boardCode && !!postId,
  });
}

export function useCreateComment(boardCode: string, postId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CommentCreate) => boardApi.createComment(boardCode, postId, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: boardKeys.comments(boardCode, postId) });
      queryClient.invalidateQueries({ queryKey: boardKeys.postDetail(boardCode, postId) });
    },
  });
}

export function useDeleteComment(boardCode: string, postId: string) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (commentId: string) => boardApi.deleteComment(commentId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: boardKeys.comments(boardCode, postId) });
      queryClient.invalidateQueries({ queryKey: boardKeys.postDetail(boardCode, postId) });
    },
  });
}
```

### 5. hooks/index.ts 업데이트

```typescript
// frontend/src/hooks/index.ts에 추가
export {
  useBoards,
  useBoard,
  usePosts,
  usePost,
  useCreatePost,
  useUpdatePost,
  useDeletePost,
  useComments,
  useCreateComment,
  useDeleteComment,
  boardKeys,
} from './useBoard';
```

### 6. lib/board/index.ts (re-export)

```typescript
/**
 * 게시판 라이브러리 Public API
 */
export * from './constants';
export * from './templates';
export * from './api';
```

## 완료 조건

1. frontend/src/types/board.ts 생성됨
2. frontend/src/lib/board/api.ts 생성됨
3. frontend/src/hooks/useBoard.ts 생성됨
4. index.ts 파일들 업데이트됨
5. 린트 통과 (npm run lint)
6. 타입 체크 통과 (npx tsc --noEmit)
