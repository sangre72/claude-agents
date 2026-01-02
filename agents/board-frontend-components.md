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

## Next.js App Router 페이지 템플릿

### 게시판 목록 페이지 (`app/boards/[boardCode]/page.tsx`)

```tsx
'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  Box,
  Container,
  Paper,
  Typography,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Chip,
  CircularProgress,
  Alert,
  Pagination,
  TextField,
  InputAdornment,
} from '@mui/material';
import {
  Search,
  Visibility,
  Announcement,
  ExpandMore,
  QuestionAnswer,
} from '@mui/icons-material';

import Header from '@/components/common/Header';
import Footer from '@/components/common/Footer';
import Breadcrumb from '@/components/common/Breadcrumb';
import { useBoard, usePosts } from '@/hooks';

export default function BoardPage() {
  const params = useParams();
  const router = useRouter();
  const boardCode = params.boardCode as string;

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');

  const { data: board, isLoading: boardLoading, error: boardError } = useBoard(boardCode);
  const { data: postsData, isLoading: postsLoading } = usePosts(boardCode, {
    page,
    limit: 20,
    search,
  });

  const posts = postsData?.items || [];
  const totalPages = postsData?.totalPages || 1;

  // 브레드크럼 아이템 (홈은 Breadcrumb 컴포넌트에서 자동 추가됨)
  const breadcrumbItems = [{ label: board?.name || '게시판' }];

  if (boardLoading) {
    return (
      <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
        <Header />
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 10 }}>
            <CircularProgress />
          </Box>
        </Container>
        <Footer />
      </Box>
    );
  }

  if (boardError || !board) {
    return (
      <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
        <Header />
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Breadcrumb items={[{ label: '게시판' }]} />
          <Alert severity="error" sx={{ mt: 2 }}>게시판을 찾을 수 없습니다.</Alert>
        </Container>
        <Footer />
      </Box>
    );
  }

  // FAQ 게시판인 경우 카드 스타일로 표시
  if (boardCode === 'faq') {
    return (
      <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
        <Header />
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Breadcrumb items={breadcrumbItems} />
          <Box sx={{ mb: 4, mt: 2 }}>
            <Typography variant="h4" fontWeight={700} gutterBottom>
              {board.name}
            </Typography>
            {board.description && (
              <Typography variant="body1" color="text.secondary">
                {board.description}
              </Typography>
            )}
          </Box>
          {/* 검색 */}
          <Box sx={{ mb: 3 }}>
            <TextField
              fullWidth
              placeholder="궁금한 내용을 검색해보세요"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <Search />
                  </InputAdornment>
                ),
              }}
              sx={{ maxWidth: 400 }}
            />
          </Box>
          {postsLoading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
              <CircularProgress />
            </Box>
          ) : posts.length === 0 ? (
            <Paper sx={{ p: 6, textAlign: 'center' }}>
              <QuestionAnswer sx={{ fontSize: 48, color: 'text.disabled', mb: 2 }} />
              <Typography variant="h6" color="text.secondary">
                등록된 FAQ가 없습니다.
              </Typography>
            </Paper>
          ) : (
            <Box>
              {posts.map((post) => (
                <Paper
                  key={post.id}
                  sx={{
                    mb: 1,
                    p: 2,
                    cursor: 'pointer',
                    '&:hover': { bgcolor: 'action.hover' },
                    display: 'flex',
                    alignItems: 'center',
                    gap: 1.5,
                  }}
                  onClick={() => router.push(`/boards/${boardCode}/${post.id}`)}
                >
                  <QuestionAnswer sx={{ color: 'primary.main', fontSize: 20 }} />
                  <Box sx={{ flex: 1 }}>
                    <Typography fontWeight={500}>{post.title}</Typography>
                    {post.categoryName && (
                      <Typography variant="caption" color="text.secondary">
                        {post.categoryName}
                      </Typography>
                    )}
                  </Box>
                  <ExpandMore sx={{ color: 'text.disabled' }} />
                </Paper>
              ))}
              {totalPages > 1 && (
                <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
                  <Pagination
                    count={totalPages}
                    page={page}
                    onChange={(_, value) => setPage(value)}
                    color="primary"
                  />
                </Box>
              )}
            </Box>
          )}
        </Container>
        <Footer />
      </Box>
    );
  }

  // 일반 게시판 (공지사항 등) - 테이블 형태
  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
      <Header />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Breadcrumb items={breadcrumbItems} />
        <Box sx={{ mb: 4, mt: 2 }}>
          <Typography variant="h4" fontWeight={700} gutterBottom>
            {board.name}
          </Typography>
          {board.description && (
            <Typography variant="body1" color="text.secondary">
              {board.description}
            </Typography>
          )}
        </Box>
        {/* 검색 */}
        <Box sx={{ mb: 3 }}>
          <TextField
            placeholder="검색어를 입력하세요"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            size="small"
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Search />
                </InputAdornment>
              ),
            }}
            sx={{ minWidth: 300 }}
          />
        </Box>
        {/* 게시글 목록 */}
        <TableContainer component={Paper} sx={{ borderRadius: 2 }}>
          <Table>
            <TableHead sx={{ bgcolor: '#F8FAFC' }}>
              <TableRow>
                <TableCell width="60" align="center">번호</TableCell>
                <TableCell>제목</TableCell>
                <TableCell width="120" align="center">작성자</TableCell>
                <TableCell width="120" align="center">작성일</TableCell>
                <TableCell width="80" align="center">조회수</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {postsLoading ? (
                <TableRow>
                  <TableCell colSpan={5} align="center" sx={{ py: 6 }}>
                    <CircularProgress size={32} />
                  </TableCell>
                </TableRow>
              ) : posts.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} align="center" sx={{ py: 6 }}>
                    <Typography color="text.secondary">등록된 게시글이 없습니다.</Typography>
                  </TableCell>
                </TableRow>
              ) : (
                posts.map((post, index) => (
                  <TableRow
                    key={post.id}
                    hover
                    sx={{
                      cursor: 'pointer',
                      bgcolor: post.isNotice ? 'rgba(33, 150, 243, 0.04)' : 'inherit',
                    }}
                    onClick={() => router.push(`/boards/${boardCode}/${post.id}`)}
                  >
                    <TableCell align="center">
                      {post.isNotice ? (
                        <Chip icon={<Announcement sx={{ fontSize: 14 }} />} label="공지" size="small" color="primary" variant="outlined" />
                      ) : (
                        (page - 1) * 20 + index + 1
                      )}
                    </TableCell>
                    <TableCell>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography sx={{ fontWeight: post.isNotice ? 600 : 400, color: post.isNotice ? 'primary.main' : 'inherit' }}>
                          {post.title}
                        </Typography>
                        {post.commentCount > 0 && (
                          <Typography variant="caption" color="primary.main">[{post.commentCount}]</Typography>
                        )}
                      </Box>
                    </TableCell>
                    <TableCell align="center">
                      <Typography variant="body2">{post.authorName || '관리자'}</Typography>
                    </TableCell>
                    <TableCell align="center">
                      <Typography variant="body2" color="text.secondary">
                        {new Date(post.createdAt).toLocaleDateString('ko-KR')}
                      </Typography>
                    </TableCell>
                    <TableCell align="center">
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 0.5 }}>
                        <Visibility sx={{ fontSize: 14, color: 'text.disabled' }} />
                        <Typography variant="body2" color="text.secondary">{post.viewCount}</Typography>
                      </Box>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>
        {totalPages > 1 && (
          <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
            <Pagination count={totalPages} page={page} onChange={(_, value) => setPage(value)} color="primary" />
          </Box>
        )}
      </Container>
      <Footer />
    </Box>
  );
}
```

### 게시글 상세 페이지 (`app/boards/[boardCode]/[postId]/page.tsx`)

```tsx
'use client';

import { useParams, useRouter } from 'next/navigation';
import {
  Box, Container, Paper, Typography, Button, CircularProgress, Alert,
  Divider, Chip, IconButton,
} from '@mui/material';
import {
  ArrowBack, Visibility, CalendarToday, Person, Announcement, AttachFile, Download,
} from '@mui/icons-material';

import Header from '@/components/common/Header';
import Footer from '@/components/common/Footer';
import Breadcrumb from '@/components/common/Breadcrumb';
import { useBoard, usePost } from '@/hooks';

export default function PostDetailPage() {
  const params = useParams();
  const router = useRouter();
  const boardCode = params.boardCode as string;
  const postId = params.postId as string;

  const { data: board, isLoading: boardLoading } = useBoard(boardCode);
  const { data: post, isLoading: postLoading, error: postError } = usePost(boardCode, postId);

  // 브레드크럼 아이템 (홈은 Breadcrumb 컴포넌트에서 자동 추가됨)
  const breadcrumbItems = [
    { label: board?.name || '게시판', href: `/boards/${boardCode}` },
    { label: post?.title || '게시글' },
  ];

  if (boardLoading || postLoading) {
    return (
      <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
        <Header />
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 10 }}>
            <CircularProgress />
          </Box>
        </Container>
        <Footer />
      </Box>
    );
  }

  if (postError || !post) {
    return (
      <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
        <Header />
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Breadcrumb items={[{ label: board?.name || '게시판', href: `/boards/${boardCode}` }, { label: '게시글' }]} />
          <Alert severity="error" sx={{ mt: 2 }}>게시글을 찾을 수 없습니다.</Alert>
          <Button startIcon={<ArrowBack />} onClick={() => router.push(`/boards/${boardCode}`)} sx={{ mt: 2 }}>
            목록으로
          </Button>
        </Container>
        <Footer />
      </Box>
    );
  }

  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
      <Header />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Breadcrumb items={breadcrumbItems} />
        <Box sx={{ mb: 3, mt: 2 }}>
          <Button startIcon={<ArrowBack />} onClick={() => router.push(`/boards/${boardCode}`)} sx={{ mb: 2 }}>
            {board?.name || '목록'}으로
          </Button>
        </Box>
        <Paper sx={{ borderRadius: 2, overflow: 'hidden' }}>
          {/* 제목 영역 */}
          <Box sx={{ p: 3, bgcolor: '#F8FAFC', borderBottom: '1px solid #E5E7EB' }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, mb: 1 }}>
              {post.isNotice && (
                <Chip icon={<Announcement sx={{ fontSize: 14 }} />} label="공지" size="small" color="primary" />
              )}
              <Typography variant="h5" fontWeight={600}>{post.title}</Typography>
            </Box>
            <Box sx={{ display: 'flex', gap: 3, flexWrap: 'wrap', color: 'text.secondary' }}>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                <Person sx={{ fontSize: 16 }} />
                <Typography variant="body2">{post.authorName || '관리자'}</Typography>
              </Box>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                <CalendarToday sx={{ fontSize: 16 }} />
                <Typography variant="body2">{new Date(post.createdAt).toLocaleString('ko-KR')}</Typography>
              </Box>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
                <Visibility sx={{ fontSize: 16 }} />
                <Typography variant="body2">조회 {post.viewCount}</Typography>
              </Box>
            </Box>
          </Box>
          {/* 본문 */}
          <Box sx={{ p: 4, minHeight: 300 }}>
            <Typography
              component="div"
              sx={{ lineHeight: 1.8, '& p': { mb: 2 }, '& img': { maxWidth: '100%', height: 'auto' } }}
              dangerouslySetInnerHTML={{ __html: post.content }}
            />
          </Box>
          {/* 첨부파일 */}
          {post.attachments && post.attachments.length > 0 && (
            <>
              <Divider />
              <Box sx={{ p: 3, bgcolor: '#FAFAFA' }}>
                <Typography variant="subtitle2" sx={{ mb: 1.5, display: 'flex', alignItems: 'center', gap: 0.5 }}>
                  <AttachFile sx={{ fontSize: 18 }} />
                  첨부파일 ({post.attachments.length})
                </Typography>
                <Box sx={{ display: 'flex', flexDirection: 'column', gap: 1 }}>
                  {post.attachments.map((file) => (
                    <Box
                      key={file.id}
                      sx={{
                        display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                        p: 1.5, bgcolor: 'white', borderRadius: 1, border: '1px solid #E5E7EB',
                      }}
                    >
                      <Typography variant="body2">{file.originalName}</Typography>
                      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
                        <Typography variant="caption" color="text.secondary">
                          {(file.fileSize / 1024).toFixed(1)} KB
                        </Typography>
                        <IconButton size="small" color="primary"><Download fontSize="small" /></IconButton>
                      </Box>
                    </Box>
                  ))}
                </Box>
              </Box>
            </>
          )}
        </Paper>
        <Box sx={{ mt: 3, display: 'flex', justifyContent: 'center' }}>
          <Button variant="outlined" startIcon={<ArrowBack />} onClick={() => router.push(`/boards/${boardCode}`)}>
            목록으로
          </Button>
        </Box>
      </Container>
      <Footer />
    </Box>
  );
}
```

---

## 레이아웃 필수 요소 (CRITICAL)

> **모든 페이지에 반드시 포함되어야 하는 요소**

1. **Header**: 페이지 상단에 `<Header />` 컴포넌트
2. **Footer**: 페이지 하단에 `<Footer />` 컴포넌트
3. **Breadcrumb**: 네비게이션 경로 표시
   - `items` 배열에 홈을 **포함하지 않음** (Breadcrumb 컴포넌트가 자동 추가)
   - 예: `[{ label: '게시판명' }]` 또는 `[{ label: '게시판명', href: '/boards/code' }, { label: '게시글 제목' }]`
4. **Container**: MUI Container로 컨텐츠 영역 감싸기
5. **배경색**: `bgcolor: 'background.default'`
6. **최소 높이**: `minHeight: '100vh'`

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
9. 페이지 컴포넌트 생성됨 (Header, Footer, Breadcrumb 포함)
10. 라우터에 경로 등록됨
11. 기존 코드 패턴과 일관성 유지됨
