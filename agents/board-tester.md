---
name: board-tester
description: 게시판 테스트 에이전트. Backend API 테스트(pytest) + Frontend 컴포넌트 테스트(Jest/Vitest) + 보안 테스트를 수행. coding-guide 준수 검증 포함.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide, refactor
---

# 게시판 테스트 Sub Agent

게시판 시스템의 Backend API, Frontend 컴포넌트, 보안을 종합적으로 테스트하는 전문 에이전트입니다.

## 사용법

```bash
# 전체 테스트
Use board-tester to run all tests

# 특정 테스트만
Use board-tester --backend           # Backend API 테스트만
Use board-tester --frontend          # Frontend 컴포넌트 테스트만
Use board-tester --security          # 보안 테스트만
Use board-tester --board notice      # 특정 게시판만 테스트

# 테스트 생성
Use board-tester --generate          # 테스트 파일 생성
Use board-tester --generate --board qna  # 특정 게시판 테스트 생성
```

---

## 테스트 범위

### 1. Backend API 테스트 (pytest)

| 영역 | 테스트 항목 |
|------|------------|
| 게시판 CRUD | 생성, 조회, 수정, 삭제, 권한 검증 |
| 게시글 CRUD | 생성, 조회, 수정, 삭제, 페이지네이션 |
| 댓글 CRUD | 생성, 조회, 수정, 삭제, 대댓글 |
| 파일 첨부 | 업로드, 다운로드, 삭제, 검증 |
| 권한 검증 | public/member/admin 권한별 접근 |
| 에러 처리 | 에러 코드, 메시지, 상태 코드 |

### 2. Frontend 컴포넌트 테스트 (Jest/Vitest)

| 영역 | 테스트 항목 |
|------|------------|
| PostList | 렌더링, 페이지네이션, 필터링, 정렬 |
| PostDetail | 렌더링, 권한별 버튼, 비밀글 |
| PostForm | 유효성 검증, 제출, 파일 첨부 |
| CommentList | 렌더링, 대댓글, 삭제 |
| FileUploader | 파일 선택, 업로드, 에러 |

### 3. 보안 테스트

| 취약점 | 테스트 항목 |
|--------|------------|
| SQL Injection | 쿼리 파라미터, 검색어 |
| XSS | 제목, 내용, 댓글 |
| CSRF | 토큰 검증 |
| 권한 우회 | 비밀글 접근, 타인 글 수정 |
| Path Traversal | 파일 경로 조작 |
| 파일 업로드 | 악성 파일, MIME 위조 |

---

## 테스트 워크플로우

### Phase 1: 사전 검사

```bash
# 1. 프로젝트 구조 확인
ls backend/tests/
ls frontend/src/**/*.test.ts

# 2. 테스트 환경 확인
cd backend && source .venv/bin/activate && pytest --version
cd frontend && npm test -- --version

# 3. 게시판 모델/API 존재 확인
ls backend/app/models/board.py
ls backend/app/api/v1/endpoints/boards.py
```

### Phase 2: Backend 테스트 생성/실행

#### 2.1 테스트 파일 구조

```
backend/tests/
├── conftest.py           # 공통 fixtures
├── test_boards.py        # 게시판 API 테스트
├── test_posts.py         # 게시글 API 테스트
├── test_comments.py      # 댓글 API 테스트
├── test_attachments.py   # 첨부파일 API 테스트
└── test_security.py      # 보안 테스트
```

#### 2.2 conftest.py (공통 Fixtures)

```python
"""게시판 테스트 Fixtures."""
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from typing import AsyncGenerator

from app.main import app
from app.db.base import Base
from app.models import User, Board, Post, Comment
from app.core.security import create_access_token

# 테스트용 DB
TEST_DATABASE_URL = "postgresql+asyncpg://postgres:password@localhost:5432/skyedu_test"


@pytest_asyncio.fixture
async def db_session() -> AsyncGenerator[AsyncSession, None]:
    """테스트용 DB 세션."""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async_session = async_sessionmaker(engine, expire_on_commit=False)
    async with async_session() as session:
        yield session

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def client(db_session: AsyncSession) -> AsyncGenerator[AsyncClient, None]:
    """테스트용 HTTP 클라이언트."""
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest_asyncio.fixture
async def test_user(db_session: AsyncSession) -> User:
    """테스트용 일반 사용자."""
    user = User(
        name="테스트유저",
        phone="01012345678",
        role="customer",
        is_verified=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def test_admin(db_session: AsyncSession) -> User:
    """테스트용 관리자."""
    admin = User(
        name="관리자",
        phone="01099999999",
        role="admin",
        is_verified=True,
    )
    db_session.add(admin)
    await db_session.commit()
    await db_session.refresh(admin)
    return admin


@pytest_asyncio.fixture
async def user_token(test_user: User) -> str:
    """일반 사용자 토큰."""
    return create_access_token({"sub": str(test_user.id)})


@pytest_asyncio.fixture
async def admin_token(test_admin: User) -> str:
    """관리자 토큰."""
    return create_access_token({"sub": str(test_admin.id)})


@pytest_asyncio.fixture
async def test_board(db_session: AsyncSession, test_admin: User) -> Board:
    """테스트용 게시판."""
    board = Board(
        code="test",
        name="테스트게시판",
        description="테스트용 게시판입니다.",
        read_permission="public",
        write_permission="member",
        comment_permission="member",
        use_category=False,
        use_notice=True,
        use_secret=True,
        use_attachment=True,
        use_like=True,
        created_by=test_admin.id,
    )
    db_session.add(board)
    await db_session.commit()
    await db_session.refresh(board)
    return board


@pytest_asyncio.fixture
async def test_post(db_session: AsyncSession, test_board: Board, test_user: User) -> Post:
    """테스트용 게시글."""
    post = Post(
        board_id=test_board.id,
        author_id=test_user.id,
        title="테스트 게시글",
        content="테스트 내용입니다.",
        is_notice=False,
        is_secret=False,
        created_by=test_user.id,
    )
    db_session.add(post)
    await db_session.commit()
    await db_session.refresh(post)
    return post
```

#### 2.3 게시판 API 테스트 (test_boards.py)

```python
"""게시판 API 테스트."""
import pytest
from httpx import AsyncClient

from app.models import Board, User


class TestBoardList:
    """게시판 목록 테스트."""

    async def test_list_boards_success(self, client: AsyncClient, test_board: Board):
        """게시판 목록 조회 성공."""
        response = await client.get("/api/v1/boards")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert len(data["data"]) >= 1

    async def test_list_boards_empty(self, client: AsyncClient):
        """게시판이 없는 경우."""
        response = await client.get("/api/v1/boards")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"] == []


class TestBoardCreate:
    """게시판 생성 테스트."""

    async def test_create_board_admin_success(
        self, client: AsyncClient, admin_token: str
    ):
        """관리자 게시판 생성 성공."""
        response = await client.post(
            "/api/v1/boards",
            json={
                "code": "new_board",
                "name": "새 게시판",
                "read_permission": "public",
                "write_permission": "member",
            },
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["code"] == "new_board"

    async def test_create_board_user_forbidden(
        self, client: AsyncClient, user_token: str
    ):
        """일반 사용자 게시판 생성 실패."""
        response = await client.post(
            "/api/v1/boards",
            json={"code": "user_board", "name": "유저 게시판"},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "ACCESS_DENIED"

    async def test_create_board_duplicate_code(
        self, client: AsyncClient, admin_token: str, test_board: Board
    ):
        """중복 코드 게시판 생성 실패."""
        response = await client.post(
            "/api/v1/boards",
            json={"code": test_board.code, "name": "중복 게시판"},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "BOARD_CODE_DUPLICATE"

    async def test_create_board_no_auth(self, client: AsyncClient):
        """인증 없이 게시판 생성 실패."""
        response = await client.post(
            "/api/v1/boards",
            json={"code": "noauth", "name": "무인증 게시판"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "AUTH_REQUIRED"


class TestBoardDetail:
    """게시판 상세 테스트."""

    async def test_get_board_success(self, client: AsyncClient, test_board: Board):
        """게시판 상세 조회 성공."""
        response = await client.get(f"/api/v1/boards/{test_board.code}")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["code"] == test_board.code

    async def test_get_board_not_found(self, client: AsyncClient):
        """존재하지 않는 게시판."""
        response = await client.get("/api/v1/boards/nonexistent")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "BOARD_NOT_FOUND"
```

#### 2.4 게시글 API 테스트 (test_posts.py)

```python
"""게시글 API 테스트."""
import pytest
from httpx import AsyncClient

from app.models import Board, Post, User


class TestPostList:
    """게시글 목록 테스트."""

    async def test_list_posts_success(
        self, client: AsyncClient, test_board: Board, test_post: Post
    ):
        """게시글 목록 조회 성공."""
        response = await client.get(f"/api/v1/boards/{test_board.code}/posts")
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert len(data["data"]["items"]) >= 1

    async def test_list_posts_pagination(
        self, client: AsyncClient, test_board: Board
    ):
        """게시글 페이지네이션."""
        response = await client.get(
            f"/api/v1/boards/{test_board.code}/posts",
            params={"page": 1, "size": 10},
        )
        assert response.status_code == 200
        data = response.json()
        assert "total" in data["data"]
        assert "page" in data["data"]
        assert "size" in data["data"]


class TestPostCreate:
    """게시글 생성 테스트."""

    async def test_create_post_success(
        self, client: AsyncClient, test_board: Board, user_token: str
    ):
        """게시글 생성 성공."""
        response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "새 게시글", "content": "내용입니다."},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["title"] == "새 게시글"

    async def test_create_post_no_auth(
        self, client: AsyncClient, test_board: Board
    ):
        """인증 없이 게시글 생성 실패 (write_permission: member)."""
        response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "무인증", "content": "내용"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "AUTH_REQUIRED"

    async def test_create_post_empty_title(
        self, client: AsyncClient, test_board: Board, user_token: str
    ):
        """빈 제목 게시글 생성 실패."""
        response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "", "content": "내용"},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is False

    async def test_create_post_xss_sanitized(
        self, client: AsyncClient, test_board: Board, user_token: str
    ):
        """XSS 스크립트 이스케이프 확인."""
        xss_content = '<script>alert("xss")</script>'
        response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "XSS 테스트", "content": xss_content},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        # 스크립트 태그가 이스케이프되었는지 확인
        assert "<script>" not in data["data"]["content"]
        assert "&lt;script&gt;" in data["data"]["content"]


class TestPostDetail:
    """게시글 상세 테스트."""

    async def test_get_post_success(
        self, client: AsyncClient, test_board: Board, test_post: Post
    ):
        """게시글 상세 조회 성공."""
        response = await client.get(
            f"/api/v1/boards/{test_board.code}/posts/{test_post.id}"
        )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["data"]["id"] == str(test_post.id)

    async def test_get_post_view_count_increment(
        self, client: AsyncClient, test_board: Board, test_post: Post
    ):
        """조회수 증가 확인."""
        initial_count = test_post.view_count
        await client.get(f"/api/v1/boards/{test_board.code}/posts/{test_post.id}")
        response = await client.get(
            f"/api/v1/boards/{test_board.code}/posts/{test_post.id}"
        )
        data = response.json()
        assert data["data"]["viewCount"] > initial_count


class TestSecretPost:
    """비밀글 테스트."""

    async def test_secret_post_author_access(
        self, client: AsyncClient, test_board: Board, user_token: str, test_user: User
    ):
        """작성자는 비밀글 접근 가능."""
        # 비밀글 생성
        create_response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "비밀글", "content": "비밀 내용", "is_secret": True},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        post_id = create_response.json()["data"]["id"]

        # 작성자가 조회
        response = await client.get(
            f"/api/v1/boards/{test_board.code}/posts/{post_id}",
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.json()["success"] is True

    async def test_secret_post_other_user_denied(
        self, client: AsyncClient, test_board: Board, user_token: str, admin_token: str
    ):
        """타인은 비밀글 접근 불가 (관리자 제외)."""
        # 비밀글 생성 (일반 사용자)
        create_response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "비밀글", "content": "비밀 내용", "is_secret": True},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        post_id = create_response.json()["data"]["id"]

        # 다른 사용자가 조회 (실패)
        # 이 테스트는 별도의 사용자 토큰이 필요

    async def test_secret_post_admin_access(
        self, client: AsyncClient, test_board: Board, user_token: str, admin_token: str
    ):
        """관리자는 비밀글 접근 가능."""
        # 비밀글 생성
        create_response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "비밀글", "content": "비밀 내용", "is_secret": True},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        post_id = create_response.json()["data"]["id"]

        # 관리자가 조회
        response = await client.get(
            f"/api/v1/boards/{test_board.code}/posts/{post_id}",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert response.json()["success"] is True
```

#### 2.5 보안 테스트 (test_security.py)

```python
"""보안 테스트."""
import pytest
from httpx import AsyncClient

from app.models import Board, Post


class TestSQLInjection:
    """SQL Injection 테스트."""

    @pytest.mark.parametrize("payload", [
        "'; DROP TABLE posts; --",
        "1 OR 1=1",
        "1; SELECT * FROM users",
        "' UNION SELECT * FROM users --",
    ])
    async def test_sql_injection_search(
        self, client: AsyncClient, test_board: Board, payload: str
    ):
        """검색어 SQL Injection 방어."""
        response = await client.get(
            f"/api/v1/boards/{test_board.code}/posts",
            params={"search": payload},
        )
        # SQL Injection이 성공하면 에러가 발생하거나 예상치 못한 데이터 반환
        # 정상 처리되어야 함
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True


class TestXSS:
    """XSS 테스트."""

    @pytest.mark.parametrize("payload", [
        '<script>alert("xss")</script>',
        '<img src="x" onerror="alert(1)">',
        '<svg onload="alert(1)">',
        'javascript:alert(1)',
        '<a href="javascript:alert(1)">click</a>',
    ])
    async def test_xss_post_title(
        self, client: AsyncClient, test_board: Board, user_token: str, payload: str
    ):
        """게시글 제목 XSS 방어."""
        response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": payload, "content": "내용"},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        if data["success"]:
            # 스크립트 태그가 이스케이프되어야 함
            assert "<script>" not in data["data"]["title"]
            assert "javascript:" not in data["data"]["title"]

    @pytest.mark.parametrize("payload", [
        '<script>document.cookie</script>',
        '<iframe src="http://evil.com"></iframe>',
    ])
    async def test_xss_post_content(
        self, client: AsyncClient, test_board: Board, user_token: str, payload: str
    ):
        """게시글 내용 XSS 방어."""
        response = await client.post(
            f"/api/v1/boards/{test_board.code}/posts",
            json={"title": "테스트", "content": payload},
            headers={"Authorization": f"Bearer {user_token}"},
        )
        assert response.status_code == 200
        data = response.json()
        if data["success"]:
            assert "<script>" not in data["data"]["content"]
            assert "<iframe>" not in data["data"]["content"]


class TestPathTraversal:
    """Path Traversal 테스트."""

    @pytest.mark.parametrize("filename", [
        "../../../etc/passwd",
        "..\\..\\..\\windows\\system32\\config\\sam",
        "....//....//....//etc/passwd",
        "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc/passwd",
    ])
    async def test_path_traversal_file_upload(
        self, client: AsyncClient, user_token: str, filename: str
    ):
        """파일 업로드 Path Traversal 방어."""
        # 파일 업로드 시 경로 조작 시도
        files = {"file": (filename, b"test content", "text/plain")}
        response = await client.post(
            "/api/v1/attachments/upload",
            files=files,
            headers={"Authorization": f"Bearer {user_token}"},
        )
        data = response.json()
        # Path Traversal 시도 시 실패해야 함
        if data["success"]:
            # 저장된 파일명에 ..이 없어야 함
            assert ".." not in data["data"]["storedName"]


class TestAuthBypass:
    """인증 우회 테스트."""

    async def test_modify_other_user_post(
        self, client: AsyncClient, test_board: Board, test_post: Post, admin_token: str
    ):
        """타인 게시글 수정 시도."""
        # 다른 사용자 토큰으로 수정 시도
        # 이 경우 test_post는 test_user가 작성한 것
        # admin_token으로 수정 가능해야 함 (관리자)
        response = await client.patch(
            f"/api/v1/boards/{test_board.code}/posts/{test_post.id}",
            json={"title": "수정된 제목"},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        # 관리자는 수정 가능
        assert response.json()["success"] is True

    async def test_delete_other_user_post_non_admin(
        self, client: AsyncClient, test_board: Board, test_post: Post
    ):
        """일반 사용자가 타인 게시글 삭제 시도."""
        # 별도 사용자 토큰으로 삭제 시도 - 실패해야 함
        pass


class TestFileUpload:
    """파일 업로드 보안 테스트."""

    async def test_upload_executable_file(
        self, client: AsyncClient, user_token: str
    ):
        """실행 파일 업로드 차단."""
        files = {"file": ("malware.exe", b"MZ...", "application/x-executable")}
        response = await client.post(
            "/api/v1/attachments/upload",
            files=files,
            headers={"Authorization": f"Bearer {user_token}"},
        )
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "FILE_TYPE_NOT_ALLOWED"

    async def test_upload_php_file(
        self, client: AsyncClient, user_token: str
    ):
        """PHP 파일 업로드 차단."""
        files = {"file": ("shell.php", b"<?php system($_GET['cmd']); ?>", "text/plain")}
        response = await client.post(
            "/api/v1/attachments/upload",
            files=files,
            headers={"Authorization": f"Bearer {user_token}"},
        )
        data = response.json()
        assert data["success"] is False

    async def test_upload_mime_type_spoofing(
        self, client: AsyncClient, user_token: str
    ):
        """MIME 타입 위조 탐지."""
        # .jpg 확장자지만 실제 내용은 PHP
        files = {"file": ("image.jpg", b"<?php system($_GET['cmd']); ?>", "image/jpeg")}
        response = await client.post(
            "/api/v1/attachments/upload",
            files=files,
            headers={"Authorization": f"Bearer {user_token}"},
        )
        data = response.json()
        # 매직 바이트 검사로 차단되어야 함
        assert data["success"] is False

    async def test_upload_file_size_limit(
        self, client: AsyncClient, user_token: str
    ):
        """파일 크기 제한."""
        # 11MB 파일 (제한: 10MB)
        large_content = b"x" * (11 * 1024 * 1024)
        files = {"file": ("large.txt", large_content, "text/plain")}
        response = await client.post(
            "/api/v1/attachments/upload",
            files=files,
            headers={"Authorization": f"Bearer {user_token}"},
        )
        data = response.json()
        assert data["success"] is False
        assert data["error_code"] == "FILE_SIZE_EXCEEDED"
```

### Phase 3: Frontend 테스트 생성/실행

#### 3.1 테스트 파일 구조

```
frontend/src/
├── components/board/
│   ├── __tests__/
│   │   ├── PostList.test.tsx
│   │   ├── PostDetail.test.tsx
│   │   ├── PostForm.test.tsx
│   │   ├── CommentList.test.tsx
│   │   └── FileUploader.test.tsx
│   └── ...
└── hooks/
    └── __tests__/
        └── useBoard.test.ts
```

#### 3.2 PostList 테스트

```typescript
// frontend/src/components/board/__tests__/PostList.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { PostList } from '../PostList';
import { usePosts } from '@/hooks/useBoard';

jest.mock('@/hooks/useBoard');

const mockPosts = [
  {
    id: '1',
    title: '테스트 게시글 1',
    authorName: '작성자1',
    viewCount: 10,
    createdAt: '2025-01-01T00:00:00Z',
  },
  {
    id: '2',
    title: '테스트 게시글 2',
    authorName: '작성자2',
    viewCount: 20,
    createdAt: '2025-01-02T00:00:00Z',
  },
];

describe('PostList', () => {
  beforeEach(() => {
    (usePosts as jest.Mock).mockReturnValue({
      data: { items: mockPosts, total: 2, page: 1, size: 10 },
      isLoading: false,
      error: null,
    });
  });

  it('게시글 목록을 렌더링한다', async () => {
    render(<PostList boardCode="test" />);

    await waitFor(() => {
      expect(screen.getByText('테스트 게시글 1')).toBeInTheDocument();
      expect(screen.getByText('테스트 게시글 2')).toBeInTheDocument();
    });
  });

  it('로딩 중일 때 스피너를 표시한다', () => {
    (usePosts as jest.Mock).mockReturnValue({
      data: null,
      isLoading: true,
      error: null,
    });

    render(<PostList boardCode="test" />);
    expect(screen.getByRole('progressbar')).toBeInTheDocument();
  });

  it('에러 발생 시 에러 메시지를 표시한다', () => {
    (usePosts as jest.Mock).mockReturnValue({
      data: null,
      isLoading: false,
      error: new Error('Failed to fetch'),
    });

    render(<PostList boardCode="test" />);
    expect(screen.getByText(/오류가 발생했습니다/)).toBeInTheDocument();
  });

  it('게시글이 없을 때 빈 상태를 표시한다', () => {
    (usePosts as jest.Mock).mockReturnValue({
      data: { items: [], total: 0, page: 1, size: 10 },
      isLoading: false,
      error: null,
    });

    render(<PostList boardCode="test" />);
    expect(screen.getByText(/게시글이 없습니다/)).toBeInTheDocument();
  });

  it('페이지네이션이 동작한다', async () => {
    const user = userEvent.setup();
    render(<PostList boardCode="test" />);

    const nextButton = screen.getByRole('button', { name: /다음/ });
    await user.click(nextButton);

    expect(usePosts).toHaveBeenCalledWith('test', expect.objectContaining({ page: 2 }));
  });
});
```

#### 3.3 PostForm 테스트

```typescript
// frontend/src/components/board/__tests__/PostForm.test.tsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { PostForm } from '../PostForm';
import { useCreatePost } from '@/hooks/useBoard';

jest.mock('@/hooks/useBoard');

describe('PostForm', () => {
  const mockCreatePost = jest.fn();

  beforeEach(() => {
    (useCreatePost as jest.Mock).mockReturnValue({
      mutate: mockCreatePost,
      isPending: false,
    });
  });

  it('폼을 렌더링한다', () => {
    render(<PostForm boardCode="test" />);

    expect(screen.getByLabelText(/제목/)).toBeInTheDocument();
    expect(screen.getByLabelText(/내용/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /작성/ })).toBeInTheDocument();
  });

  it('필수 필드가 비어있으면 제출되지 않는다', async () => {
    const user = userEvent.setup();
    render(<PostForm boardCode="test" />);

    await user.click(screen.getByRole('button', { name: /작성/ }));

    expect(mockCreatePost).not.toHaveBeenCalled();
    expect(screen.getByText(/제목을 입력해주세요/)).toBeInTheDocument();
  });

  it('유효한 데이터로 제출한다', async () => {
    const user = userEvent.setup();
    render(<PostForm boardCode="test" />);

    await user.type(screen.getByLabelText(/제목/), '테스트 제목');
    await user.type(screen.getByLabelText(/내용/), '테스트 내용');
    await user.click(screen.getByRole('button', { name: /작성/ }));

    await waitFor(() => {
      expect(mockCreatePost).toHaveBeenCalledWith({
        title: '테스트 제목',
        content: '테스트 내용',
      });
    });
  });

  it('XSS 스크립트가 입력되면 경고를 표시한다', async () => {
    const user = userEvent.setup();
    render(<PostForm boardCode="test" />);

    await user.type(screen.getByLabelText(/제목/), '<script>alert(1)</script>');

    // 경고 또는 자동 이스케이프 확인
  });

  it('제출 중일 때 버튼이 비활성화된다', () => {
    (useCreatePost as jest.Mock).mockReturnValue({
      mutate: mockCreatePost,
      isPending: true,
    });

    render(<PostForm boardCode="test" />);

    expect(screen.getByRole('button', { name: /작성/ })).toBeDisabled();
  });
});
```

### Phase 4: 테스트 실행

```bash
# Backend 테스트
cd backend
source .venv/bin/activate
pytest tests/ -v --cov=app --cov-report=html

# 특정 테스트만
pytest tests/test_posts.py -v
pytest tests/test_security.py -v

# Frontend 테스트
cd frontend
npm test -- --coverage

# 특정 테스트만
npm test -- PostList.test.tsx
npm test -- --testPathPattern="board"
```

---

## 테스트 결과 형식

```
📋 게시판 테스트 결과

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backend API 테스트: ✅ 45/45 통과
  - 게시판 CRUD: 8/8
  - 게시글 CRUD: 15/15
  - 댓글 CRUD: 10/10
  - 첨부파일: 7/7
  - 권한 검증: 5/5

Frontend 컴포넌트 테스트: ✅ 28/28 통과
  - PostList: 6/6
  - PostDetail: 5/5
  - PostForm: 8/8
  - CommentList: 5/5
  - FileUploader: 4/4

보안 테스트: ✅ 20/20 통과
  - SQL Injection: 4/4
  - XSS: 6/6
  - Path Traversal: 4/4
  - 인증 우회: 2/2
  - 파일 업로드: 4/4

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

커버리지:
  - Backend: 87%
  - Frontend: 82%

총 테스트: 93개 | 통과: 93개 | 실패: 0개
실행 시간: 12.5초
```

---

## 실패 시 처리

```
❌ 테스트 실패 발견

실패한 테스트:
  1. test_xss_post_content (test_security.py:45)
     - 예상: <script> 태그 이스케이프
     - 실제: 원본 그대로 저장됨
     - 원인: PostCreate 스키마에 sanitize_input 누락

  2. test_secret_post_other_user_denied (test_posts.py:120)
     - 예상: ACCESS_DENIED 에러
     - 실제: 성공 (비밀글 접근됨)
     - 원인: 비밀글 접근 제어 로직 누락

권장 조치:
  1. backend/app/schemas/board.py에 field_validator 추가
  2. backend/app/api/v1/endpoints/boards.py에 비밀글 검증 추가

board-fixer를 사용하여 수정하시겠습니까? (y/n)
```

---

## 준수 규칙

### coding-guide

1. **필수 컬럼 테스트**: created_at, updated_at 등 필수 컬럼 존재 확인
2. **에러 응답 테스트**: success 필드, error_code 형식 검증
3. **보안 라이브러리**: python-jose, passlib 사용 확인

### 보안 테스트 필수 항목

1. **SQL Injection**: 모든 입력 파라미터 테스트
2. **XSS**: 제목, 내용, 댓글 모든 텍스트 필드 테스트
3. **권한 우회**: 비밀글, 타인 글 수정/삭제 테스트
4. **파일 업로드**: 악성 파일, MIME 위조, 크기 초과 테스트
5. **Path Traversal**: 파일 경로 조작 테스트
