---
name: board-frontend-pages
description: 게시판 Frontend 페이지 템플릿. Next.js App Router 기반 목록/상세/작성/수정 페이지. board-generator와 병렬 실행 가능.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 Frontend 페이지 템플릿

Next.js App Router 기반 **게시판 페이지 템플릿**을 제공하는 에이전트입니다.

> **병렬 실행**: board-backend-api, board-frontend-types와 병렬로 실행 가능

---

## 레이아웃 필수 요소 (CRITICAL)

모든 게시판 페이지는 다음 레이아웃 요소를 **반드시** 포함해야 합니다:

```
┌─────────────────────────────────────────┐
│               Header                    │  ← 필수
├─────────────────────────────────────────┤
│  Container (maxWidth="lg")              │
│  ┌─────────────────────────────────────┐│
│  │ Breadcrumb                          ││ ← 필수
│  │ (홈은 자동 추가됨 - items에 포함 X)   ││
│  ├─────────────────────────────────────┤│
│  │                                     ││
│  │         Page Content                ││
│  │                                     ││
│  └─────────────────────────────────────┘│
├─────────────────────────────────────────┤
│               Footer                    │  ← 필수
└─────────────────────────────────────────┘
```

**필수 규칙:**

| 요소 | 규칙 |
|------|------|
| Header | 모든 페이지 상단에 필수 |
| Footer | 모든 페이지 하단에 필수 |
| Breadcrumb | items에 '홈' 포함하지 않음 (자동 추가됨) |
| Container | `maxWidth="lg"`, `py={4}` |
| Box wrapper | `bgcolor: 'background.default'`, `minHeight: '100vh'` |

---

## 페이지 파일 구조

```
frontend/src/app/boards/
├── page.tsx                      # 게시판 목록 (선택)
├── [boardCode]/
│   ├── page.tsx                  # 게시글 목록
│   ├── write/
│   │   └── page.tsx              # 게시글 작성
│   └── [postId]/
│       ├── page.tsx              # 게시글 상세
│       └── edit/
│           └── page.tsx          # 게시글 수정
```

---

## 게시글 목록 페이지

**파일**: `frontend/src/app/boards/[boardCode]/page.tsx`

```tsx
'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  Box, Container, Paper, Typography, Table, TableBody,
  TableCell, TableContainer, TableHead, TableRow,
  CircularProgress, Alert, Pagination, TextField,
  InputAdornment, Chip, Button,
} from '@mui/material';
import { Search, Visibility, Announcement, Edit } from '@mui/icons-material';

import Header from '@/components/common/Header';
import Footer from '@/components/common/Footer';
import Breadcrumb from '@/components/common/Breadcrumb';
import { useBoard, usePosts, useAuth } from '@/hooks';

export default function BoardPage() {
  const params = useParams();
  const router = useRouter();
  const boardCode = params.boardCode as string;

  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');

  const { user } = useAuth();
  const { data: board, isLoading: boardLoading, error: boardError } = useBoard(boardCode);
  const { data: postsData, isLoading: postsLoading } = usePosts(boardCode, {
    page,
    limit: 20,
    search,
  });

  const posts = postsData?.items || [];
  const totalPages = postsData?.totalPages || 1;

  // 작성 권한 확인
  const canWrite = board && (
    board.writePermission === 'public' ||
    (board.writePermission === 'member' && user) ||
    (board.writePermission === 'admin' && user?.role === 'admin')
  );

  // 브레드크럼 아이템 (홈은 Breadcrumb 컴포넌트에서 자동 추가됨)
  const breadcrumbItems = [{ label: board?.name || '게시판' }];

  // 로딩 상태
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

  // 에러 상태
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

  // 정상 렌더링
  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
      <Header />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Breadcrumb items={breadcrumbItems} />

        {/* 게시판 헤더 */}
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

        {/* 검색 + 글쓰기 버튼 */}
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
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

          {canWrite && (
            <Button
              variant="contained"
              startIcon={<Edit />}
              onClick={() => router.push(`/boards/${boardCode}/write`)}
            >
              글쓰기
            </Button>
          )}
        </Box>

        {/* 게시글 목록 테이블 */}
        <TableContainer component={Paper}>
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
                    <Typography color="text.secondary">
                      등록된 게시글이 없습니다.
                    </Typography>
                  </TableCell>
                </TableRow>
              ) : (
                posts.map((post, index) => (
                  <TableRow
                    key={post.id}
                    hover
                    sx={{ cursor: 'pointer' }}
                    onClick={() => router.push(`/boards/${boardCode}/${post.id}`)}
                  >
                    <TableCell align="center">
                      {post.isNotice ? (
                        <Chip
                          icon={<Announcement sx={{ fontSize: 14 }} />}
                          label="공지"
                          size="small"
                          color="primary"
                          variant="outlined"
                        />
                      ) : (
                        (page - 1) * 20 + index + 1
                      )}
                    </TableCell>
                    <TableCell>
                      <Typography fontWeight={post.isNotice ? 600 : 400}>
                        {post.title}
                      </Typography>
                    </TableCell>
                    <TableCell align="center">{post.authorName}</TableCell>
                    <TableCell align="center">
                      {new Date(post.createdAt).toLocaleDateString('ko-KR')}
                    </TableCell>
                    <TableCell align="center">
                      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 0.5 }}>
                        <Visibility sx={{ fontSize: 14, color: 'text.disabled' }} />
                        {post.viewCount}
                      </Box>
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </TableContainer>

        {/* 페이지네이션 */}
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
      </Container>
      <Footer />
    </Box>
  );
}
```

---

## 게시글 상세 페이지

**파일**: `frontend/src/app/boards/[boardCode]/[postId]/page.tsx`

```tsx
'use client';

import { useParams, useRouter } from 'next/navigation';
import {
  Box, Container, Paper, Typography, Divider, Button,
  CircularProgress, Alert, Chip, Stack,
} from '@mui/material';
import {
  ArrowBack, Visibility, CalendarToday,
  Edit, Delete,
} from '@mui/icons-material';

import Header from '@/components/common/Header';
import Footer from '@/components/common/Footer';
import Breadcrumb from '@/components/common/Breadcrumb';
import { useBoard, usePost, useAuth, useDeletePost } from '@/hooks';

export default function PostDetailPage() {
  const params = useParams();
  const router = useRouter();
  const boardCode = params.boardCode as string;
  const postId = params.postId as string;

  const { user } = useAuth();
  const { data: board, isLoading: boardLoading } = useBoard(boardCode);
  const { data: post, isLoading: postLoading, error: postError } = usePost(boardCode, postId);
  const deleteMutation = useDeletePost(boardCode);

  const isLoading = boardLoading || postLoading;

  // 수정/삭제 권한 확인
  const isAuthor = user && post && user.id === post.authorId;
  const isAdmin = user?.role === 'admin';
  const canEdit = isAuthor || isAdmin;
  const canDelete = isAuthor || isAdmin;

  // 브레드크럼 아이템 (홈은 Breadcrumb 컴포넌트에서 자동 추가됨)
  const breadcrumbItems = [
    { label: board?.name || '게시판', href: `/boards/${boardCode}` },
    { label: post?.title || '게시글' },
  ];

  const handleDelete = async () => {
    if (!confirm('정말 삭제하시겠습니까?')) return;

    try {
      await deleteMutation.mutateAsync(parseInt(postId));
      router.push(`/boards/${boardCode}`);
    } catch (error) {
      alert('삭제에 실패했습니다.');
    }
  };

  // 로딩 상태
  if (isLoading) {
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

  // 에러 상태
  if (postError || !post) {
    return (
      <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
        <Header />
        <Container maxWidth="lg" sx={{ py: 4 }}>
          <Breadcrumb items={[
            { label: board?.name || '게시판', href: `/boards/${boardCode}` },
            { label: '게시글' },
          ]} />
          <Alert severity="error" sx={{ mt: 2 }}>게시글을 찾을 수 없습니다.</Alert>
        </Container>
        <Footer />
      </Box>
    );
  }

  // 정상 렌더링
  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
      <Header />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Breadcrumb items={breadcrumbItems} />

        <Paper sx={{ p: 4, mt: 2 }}>
          {/* 제목 영역 */}
          <Box sx={{ mb: 3 }}>
            {post.isNotice && (
              <Chip label="공지" color="primary" size="small" sx={{ mb: 1 }} />
            )}
            <Typography variant="h5" fontWeight={700}>
              {post.title}
            </Typography>
          </Box>

          {/* 메타 정보 */}
          <Stack direction="row" spacing={2} sx={{ mb: 3, color: 'text.secondary' }}>
            <Typography variant="body2">{post.authorName}</Typography>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
              <CalendarToday sx={{ fontSize: 14 }} />
              <Typography variant="body2">
                {new Date(post.createdAt).toLocaleDateString('ko-KR')}
              </Typography>
            </Box>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 0.5 }}>
              <Visibility sx={{ fontSize: 14 }} />
              <Typography variant="body2">{post.viewCount}</Typography>
            </Box>
          </Stack>

          <Divider sx={{ mb: 3 }} />

          {/* 본문 */}
          <Box
            sx={{ minHeight: 200, mb: 4 }}
            dangerouslySetInnerHTML={{ __html: post.content }}
          />

          <Divider sx={{ mb: 3 }} />

          {/* 하단 버튼 */}
          <Box sx={{ display: 'flex', justifyContent: 'space-between' }}>
            <Button
              startIcon={<ArrowBack />}
              onClick={() => router.push(`/boards/${boardCode}`)}
            >
              목록으로
            </Button>

            {(canEdit || canDelete) && (
              <Box sx={{ display: 'flex', gap: 1 }}>
                {canEdit && (
                  <Button
                    startIcon={<Edit />}
                    onClick={() => router.push(`/boards/${boardCode}/${postId}/edit`)}
                  >
                    수정
                  </Button>
                )}
                {canDelete && (
                  <Button
                    color="error"
                    startIcon={<Delete />}
                    onClick={handleDelete}
                  >
                    삭제
                  </Button>
                )}
              </Box>
            )}
          </Box>
        </Paper>
      </Container>
      <Footer />
    </Box>
  );
}
```

---

## 게시글 작성 페이지

**파일**: `frontend/src/app/boards/[boardCode]/write/page.tsx`

```tsx
'use client';

import { useState } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  Box, Container, Paper, Typography, TextField, Button,
  CircularProgress, Alert, FormControl, InputLabel, Select, MenuItem,
} from '@mui/material';
import { Save, Cancel } from '@mui/icons-material';

import Header from '@/components/common/Header';
import Footer from '@/components/common/Footer';
import Breadcrumb from '@/components/common/Breadcrumb';
import { useBoard, useCategories, useCreatePost } from '@/hooks';

export default function WritePostPage() {
  const params = useParams();
  const router = useRouter();
  const boardCode = params.boardCode as string;

  const { data: board, isLoading: boardLoading } = useBoard(boardCode);
  const { data: categories = [] } = useCategories(boardCode);
  const createMutation = useCreatePost(boardCode);

  const [formData, setFormData] = useState({
    title: '',
    content: '',
    categoryId: '',
  });
  const [errors, setErrors] = useState<Record<string, string>>({});

  // 브레드크럼
  const breadcrumbItems = [
    { label: board?.name || '게시판', href: `/boards/${boardCode}` },
    { label: '글쓰기' },
  ];

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!formData.title.trim()) newErrors.title = '제목을 입력하세요.';
    if (!formData.content.trim()) newErrors.content = '내용을 입력하세요.';
    if (board?.useCategory && !formData.categoryId) {
      newErrors.categoryId = '카테고리를 선택하세요.';
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validate()) return;

    try {
      const result = await createMutation.mutateAsync({
        title: formData.title,
        content: formData.content,
        categoryId: formData.categoryId ? parseInt(formData.categoryId) : undefined,
      });
      router.push(`/boards/${boardCode}/${result.id}`);
    } catch (error) {
      alert('등록에 실패했습니다.');
    }
  };

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

  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
      <Header />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Breadcrumb items={breadcrumbItems} />

        <Paper sx={{ p: 4, mt: 2 }}>
          <Typography variant="h5" fontWeight={700} gutterBottom>
            글쓰기
          </Typography>

          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, mt: 3 }}>
            {/* 카테고리 선택 */}
            {board?.useCategory && categories.length > 0 && (
              <FormControl error={!!errors.categoryId}>
                <InputLabel>카테고리</InputLabel>
                <Select
                  value={formData.categoryId}
                  onChange={(e) => setFormData({ ...formData, categoryId: e.target.value })}
                  label="카테고리"
                >
                  {categories.map((cat) => (
                    <MenuItem key={cat.id} value={cat.id}>
                      {cat.name}
                    </MenuItem>
                  ))}
                </Select>
                {errors.categoryId && (
                  <Typography variant="caption" color="error">{errors.categoryId}</Typography>
                )}
              </FormControl>
            )}

            {/* 제목 */}
            <TextField
              label="제목"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              error={!!errors.title}
              helperText={errors.title}
              fullWidth
            />

            {/* 내용 */}
            <TextField
              label="내용"
              value={formData.content}
              onChange={(e) => setFormData({ ...formData, content: e.target.value })}
              error={!!errors.content}
              helperText={errors.content}
              multiline
              rows={15}
              fullWidth
            />

            {/* 버튼 */}
            <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1 }}>
              <Button
                variant="outlined"
                startIcon={<Cancel />}
                onClick={() => router.back()}
              >
                취소
              </Button>
              <Button
                variant="contained"
                startIcon={<Save />}
                onClick={handleSubmit}
                disabled={createMutation.isPending}
              >
                등록
              </Button>
            </Box>
          </Box>
        </Paper>
      </Container>
      <Footer />
    </Box>
  );
}
```

---

## 게시글 수정 페이지

**파일**: `frontend/src/app/boards/[boardCode]/[postId]/edit/page.tsx`

```tsx
'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import {
  Box, Container, Paper, Typography, TextField, Button,
  CircularProgress, Alert, FormControl, InputLabel, Select, MenuItem,
} from '@mui/material';
import { Save, Cancel } from '@mui/icons-material';

import Header from '@/components/common/Header';
import Footer from '@/components/common/Footer';
import Breadcrumb from '@/components/common/Breadcrumb';
import { useBoard, usePost, useCategories, useUpdatePost } from '@/hooks';

export default function EditPostPage() {
  const params = useParams();
  const router = useRouter();
  const boardCode = params.boardCode as string;
  const postId = params.postId as string;

  const { data: board } = useBoard(boardCode);
  const { data: post, isLoading: postLoading } = usePost(boardCode, postId);
  const { data: categories = [] } = useCategories(boardCode);
  const updateMutation = useUpdatePost(boardCode);

  const [formData, setFormData] = useState({
    title: '',
    content: '',
    categoryId: '',
  });
  const [errors, setErrors] = useState<Record<string, string>>({});

  // 기존 데이터 로드
  useEffect(() => {
    if (post) {
      setFormData({
        title: post.title,
        content: post.content,
        categoryId: post.categoryId?.toString() || '',
      });
    }
  }, [post]);

  const breadcrumbItems = [
    { label: board?.name || '게시판', href: `/boards/${boardCode}` },
    { label: post?.title || '게시글', href: `/boards/${boardCode}/${postId}` },
    { label: '수정' },
  ];

  const validate = () => {
    const newErrors: Record<string, string> = {};
    if (!formData.title.trim()) newErrors.title = '제목을 입력하세요.';
    if (!formData.content.trim()) newErrors.content = '내용을 입력하세요.';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validate()) return;

    try {
      await updateMutation.mutateAsync({
        id: parseInt(postId),
        data: {
          title: formData.title,
          content: formData.content,
          categoryId: formData.categoryId ? parseInt(formData.categoryId) : undefined,
        },
      });
      router.push(`/boards/${boardCode}/${postId}`);
    } catch (error) {
      alert('수정에 실패했습니다.');
    }
  };

  if (postLoading) {
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

  return (
    <Box sx={{ bgcolor: 'background.default', minHeight: '100vh' }}>
      <Header />
      <Container maxWidth="lg" sx={{ py: 4 }}>
        <Breadcrumb items={breadcrumbItems} />

        <Paper sx={{ p: 4, mt: 2 }}>
          <Typography variant="h5" fontWeight={700} gutterBottom>
            글 수정
          </Typography>

          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, mt: 3 }}>
            {/* 카테고리 선택 */}
            {board?.useCategory && categories.length > 0 && (
              <FormControl>
                <InputLabel>카테고리</InputLabel>
                <Select
                  value={formData.categoryId}
                  onChange={(e) => setFormData({ ...formData, categoryId: e.target.value })}
                  label="카테고리"
                >
                  {categories.map((cat) => (
                    <MenuItem key={cat.id} value={cat.id}>
                      {cat.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
            )}

            {/* 제목 */}
            <TextField
              label="제목"
              value={formData.title}
              onChange={(e) => setFormData({ ...formData, title: e.target.value })}
              error={!!errors.title}
              helperText={errors.title}
              fullWidth
            />

            {/* 내용 */}
            <TextField
              label="내용"
              value={formData.content}
              onChange={(e) => setFormData({ ...formData, content: e.target.value })}
              error={!!errors.content}
              helperText={errors.content}
              multiline
              rows={15}
              fullWidth
            />

            {/* 버튼 */}
            <Box sx={{ display: 'flex', justifyContent: 'flex-end', gap: 1 }}>
              <Button
                variant="outlined"
                startIcon={<Cancel />}
                onClick={() => router.back()}
              >
                취소
              </Button>
              <Button
                variant="contained"
                startIcon={<Save />}
                onClick={handleSubmit}
                disabled={updateMutation.isPending}
              >
                저장
              </Button>
            </Box>
          </Box>
        </Paper>
      </Container>
      <Footer />
    </Box>
  );
}
```

---

## Breadcrumb 사용 규칙 (CRITICAL)

**올바른 사용:**
```tsx
// 목록 페이지
const breadcrumbItems = [{ label: board?.name || '게시판' }];
// 결과: 홈 > 공지사항

// 상세 페이지
const breadcrumbItems = [
  { label: board?.name || '게시판', href: `/boards/${boardCode}` },
  { label: post?.title || '게시글' },
];
// 결과: 홈 > 공지사항 > 게시글 제목

// 수정 페이지
const breadcrumbItems = [
  { label: board?.name || '게시판', href: `/boards/${boardCode}` },
  { label: post?.title || '게시글', href: `/boards/${boardCode}/${postId}` },
  { label: '수정' },
];
// 결과: 홈 > 공지사항 > 게시글 제목 > 수정
```

**잘못된 사용 (중복 발생):**
```tsx
// ❌ 홈을 직접 추가하면 중복됨
const breadcrumbItems = [
  { label: '홈', href: '/' },  // ← 이것은 포함하지 마세요!
  { label: board?.name || '게시판' },
];
// 결과: 홈 > 홈 > 공지사항 (중복!)
```

---

## 참고

- `board-frontend-types`의 타입 정의 사용
- `board-frontend-components`의 공통 컴포넌트 사용
- Header, Footer, Breadcrumb은 프로젝트 공통 컴포넌트
