---
name: board-backend-model
description: 게시판 Backend 모델 생성. SQLAlchemy 모델 + Pydantic 스키마. board-shared 완료 후 병렬 실행 가능.
tools: Read, Edit, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 Backend 모델 에이전트

SQLAlchemy 모델과 Pydantic 스키마를 생성합니다.
**board-shared 완료 후** 다른 에이전트와 **병렬 실행** 가능합니다.

## 의존성

- board-shared (필수, 먼저 완료되어야 함)

---

## Enum 정의 규칙 (CRITICAL)

> **핵심**: DB에 저장되는 값은 **소문자**, Python Enum 이름은 **대문자**

### 올바른 Enum 정의

```python
from enum import Enum

# ✅ 올바른 예 - str 상속으로 값이 DB에 저장됨
class BoardPermissionEnum(str, Enum):
    """게시판 권한 레벨."""
    PUBLIC = "public"      # DB에 "public" 저장
    MEMBER = "member"      # DB에 "member" 저장
    MANAGER = "manager"    # DB에 "manager" 저장
    ADMIN = "admin"        # DB에 "admin" 저장


class PostStatusEnum(str, Enum):
    """게시글 상태."""
    DRAFT = "draft"
    PUBLISHED = "published"
    HIDDEN = "hidden"
    DELETED = "deleted"
```

### SQLAlchemy 컬럼에서 사용

```python
# ❌ 잘못된 예 - SQLEnum이 이름(대문자)을 저장함
from sqlalchemy import Enum as SQLEnum

read_permission: Mapped[BoardPermissionEnum] = mapped_column(
    SQLEnum(BoardPermissionEnum),  # DB에 "PUBLIC" 저장됨!
    default=BoardPermissionEnum.PUBLIC
)


# ✅ 올바른 예 1 - String 타입 사용 (권장)
read_permission: Mapped[str] = mapped_column(
    String(20),
    default="public"  # 소문자 문자열
)


# ✅ 올바른 예 2 - SQLEnum + values_callable 사용
read_permission: Mapped[BoardPermissionEnum] = mapped_column(
    SQLEnum(
        BoardPermissionEnum,
        values_callable=lambda x: [e.value for e in x]  # 값(소문자) 사용
    ),
    default=BoardPermissionEnum.PUBLIC
)


# ✅ 올바른 예 3 - native_enum=False + 값 지정
read_permission: Mapped[str] = mapped_column(
    SQLEnum(
        "public", "member", "manager", "admin",
        name="board_permission_enum",
        native_enum=False  # VARCHAR로 저장
    ),
    default="public"
)
```

### Enum 값 비교

```python
# ✅ 올바른 비교
if board.read_permission == "public":
    pass

if board.read_permission == BoardPermissionEnum.PUBLIC.value:
    pass

# str 상속 시 직접 비교 가능
if board.read_permission == BoardPermissionEnum.PUBLIC:
    pass  # str 상속했으므로 "public" == BoardPermissionEnum.PUBLIC 는 True
```

### Pydantic 스키마에서 사용

```python
from pydantic import BaseModel
from enum import Enum

class BoardPermissionEnum(str, Enum):
    PUBLIC = "public"
    MEMBER = "member"

class BoardCreate(BaseModel):
    read_permission: BoardPermissionEnum = BoardPermissionEnum.PUBLIC

    # 또는 문자열로 받아서 변환
    # read_permission: str = "public"
```

### 마이그레이션과 일치 확인

```python
# alembic/versions/xxx_create_boards.py

# ❌ 잘못된 예 - 대문자
sa.Enum('PUBLIC', 'MEMBER', 'MANAGER', 'ADMIN', name='permission_enum')

# ✅ 올바른 예 - 소문자
sa.Enum('public', 'member', 'manager', 'admin', name='permission_enum')

# ✅ 권장 - VARCHAR 사용 (Enum 타입 피하기)
sa.Column('read_permission', sa.String(20), default='public')
```

---

## 인덱스/제약조건 명명 규칙 (CRITICAL)

> **인덱스 이름 충돌 방지**: 반드시 테이블명을 접두사로 포함!

| 유형 | 패턴 | 예시 |
|------|------|------|
| 인덱스 | `ix_{table}_{column}` | `ix_posts_board_id` |
| 복합 인덱스 | `ix_{table}_{col1}_{col2}` | `ix_posts_board_created_at` |
| Unique | `uq_{table}_{column}` | `uq_boards_tenant_code` |
| Foreign Key | `fk_{table}_{column}_{ref}` | `fk_posts_board_id_boards` |

**❌ 잘못된 예 - 충돌 가능:**
```python
Index("ix_board_id", "board_id")      # 다른 테이블과 충돌!
Index("ix_tenant_id", "tenant_id")    # 모든 테이블에서 충돌!
```

**✅ 올바른 예 - 테이블명 포함:**
```python
Index("ix_posts_board_id", "board_id")
Index("ix_posts_tenant_id", "tenant_id")
Index("ix_comments_post_id", "post_id")
```

---

## 생성 파일

### 1. SQLAlchemy 모델 (backend/app/models/board.py)

**주의: __init__.py에서는 실제 정의된 클래스만 import**

```python
# app/models/__init__.py - 정확한 export 목록
from app.models.board import (
    Board,
    BoardCategory,
    Post,
    Comment,
    Attachment,
    PostLike,
    # Enum은 정의한 경우만 export
)
```

```python
"""게시판 관련 모델."""
import uuid
from datetime import datetime
from enum import Enum
from typing import Optional, List, TYPE_CHECKING

from sqlalchemy import Boolean, ForeignKey, Integer, String, Text, Index, Enum as SQLEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func

from app.db.base import Base

if TYPE_CHECKING:
    from app.models.user import User


# Enum 정의 (필요시)
class BoardPermissionEnum(str, Enum):
    """게시판 권한 레벨"""
    PUBLIC = "public"      # 모두 접근 가능
    MEMBER = "member"      # 회원만
    MANAGER = "manager"    # 관리자만
    ADMIN = "admin"        # 최고관리자만


class PostStatusEnum(str, Enum):
    """게시글 상태"""
    DRAFT = "draft"
    PUBLISHED = "published"
    HIDDEN = "hidden"
    DELETED = "deleted"


class TimestampMixin:
    """필수 컬럼 Mixin (coding-guide 준수)."""

    created_at: Mapped[datetime] = mapped_column(default=func.now(), nullable=False)
    created_by: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(default=func.now(), onupdate=func.now(), nullable=False)
    updated_by: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False)


class Board(Base, TimestampMixin):
    """게시판 모델."""
    __tablename__ = "boards"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    code: Mapped[str] = mapped_column(String(50), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # 권한 설정
    read_permission: Mapped[str] = mapped_column(String(20), default="public")
    write_permission: Mapped[str] = mapped_column(String(20), default="member")
    comment_permission: Mapped[str] = mapped_column(String(20), default="member")

    # 기능 설정
    use_category: Mapped[bool] = mapped_column(Boolean, default=False)
    use_notice: Mapped[bool] = mapped_column(Boolean, default=True)
    use_secret: Mapped[bool] = mapped_column(Boolean, default=False)
    use_attachment: Mapped[bool] = mapped_column(Boolean, default=True)
    use_like: Mapped[bool] = mapped_column(Boolean, default=False)

    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    # Relationships
    categories: Mapped[List["BoardCategory"]] = relationship(back_populates="board", cascade="all, delete-orphan")
    posts: Mapped[List["Post"]] = relationship(back_populates="board", cascade="all, delete-orphan")


class BoardCategory(Base, TimestampMixin):
    """게시판 분류 모델."""
    __tablename__ = "board_categories"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    board_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("boards.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0)

    board: Mapped["Board"] = relationship(back_populates="categories")

    __table_args__ = (
        Index("ix_board_categories_board_id", "board_id"),
    )


class Post(Base, TimestampMixin):
    """게시글 모델."""
    __tablename__ = "posts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    board_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("boards.id", ondelete="CASCADE"), nullable=False)
    category_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("board_categories.id", ondelete="SET NULL"), nullable=True)
    author_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)

    is_notice: Mapped[bool] = mapped_column(Boolean, default=False)
    is_secret: Mapped[bool] = mapped_column(Boolean, default=False)
    secret_password: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    view_count: Mapped[int] = mapped_column(Integer, default=0)
    like_count: Mapped[int] = mapped_column(Integer, default=0)
    comment_count: Mapped[int] = mapped_column(Integer, default=0)

    is_answered: Mapped[bool] = mapped_column(Boolean, default=False)

    # Relationships
    board: Mapped["Board"] = relationship(back_populates="posts")
    category: Mapped[Optional["BoardCategory"]] = relationship()
    author: Mapped["User"] = relationship()
    comments: Mapped[List["Comment"]] = relationship(back_populates="post", cascade="all, delete-orphan")
    attachments: Mapped[List["Attachment"]] = relationship(back_populates="post", cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_posts_board_id", "board_id"),
        Index("ix_posts_author_id", "author_id"),
        Index("ix_posts_created_at", "created_at"),
    )


class Comment(Base, TimestampMixin):
    """댓글 모델."""
    __tablename__ = "comments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)
    parent_id: Mapped[Optional[uuid.UUID]] = mapped_column(UUID(as_uuid=True), ForeignKey("comments.id", ondelete="CASCADE"), nullable=True)
    author_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    content: Mapped[str] = mapped_column(Text, nullable=False)
    is_secret: Mapped[bool] = mapped_column(Boolean, default=False)
    like_count: Mapped[int] = mapped_column(Integer, default=0)

    # Relationships
    post: Mapped["Post"] = relationship(back_populates="comments")
    author: Mapped["User"] = relationship()
    replies: Mapped[List["Comment"]] = relationship(cascade="all, delete-orphan")

    __table_args__ = (
        Index("ix_comments_post_id", "post_id"),
        Index("ix_comments_author_id", "author_id"),
    )


class Attachment(Base, TimestampMixin):
    """첨부파일 모델."""
    __tablename__ = "attachments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)

    original_name: Mapped[str] = mapped_column(String(255), nullable=False)
    stored_name: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_size: Mapped[int] = mapped_column(Integer, nullable=False)
    mime_type: Mapped[str] = mapped_column(String(100), nullable=False)
    download_count: Mapped[int] = mapped_column(Integer, default=0)

    post: Mapped["Post"] = relationship(back_populates="attachments")

    __table_args__ = (
        Index("ix_attachments_post_id", "post_id"),
    )
```

### 2. Pydantic 스키마 (backend/app/schemas/board.py)

```python
"""게시판 스키마."""
import html
from datetime import datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, ConfigDict


# ===== Board =====
class BoardBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    read_permission: str = Field(default="public")
    write_permission: str = Field(default="member")
    comment_permission: str = Field(default="member")
    use_category: bool = False
    use_notice: bool = True
    use_secret: bool = False
    use_attachment: bool = True
    use_like: bool = False


class BoardCreate(BoardBase):
    code: str = Field(..., min_length=1, max_length=50, pattern=r"^[a-z][a-z0-9_]*$")


class BoardUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    read_permission: Optional[str] = None
    write_permission: Optional[str] = None
    comment_permission: Optional[str] = None
    use_category: Optional[bool] = None
    use_notice: Optional[bool] = None
    use_secret: Optional[bool] = None
    use_attachment: Optional[bool] = None
    use_like: Optional[bool] = None


class BoardResponse(BoardBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    code: str
    created_at: datetime
    updated_at: datetime


# ===== Category =====
class CategoryCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=50)
    sort_order: int = 0


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    board_id: UUID
    name: str
    sort_order: int


# ===== Post =====
class PostBase(BaseModel):
    title: str = Field(..., min_length=1, max_length=200)
    content: str = Field(..., min_length=1, max_length=50000)

    @field_validator('title', 'content', mode='before')
    @classmethod
    def sanitize_input(cls, v: str) -> str:
        """XSS 방지."""
        if not isinstance(v, str):
            return v
        return html.escape(v.strip())


class PostCreate(PostBase):
    category_id: Optional[UUID] = None
    is_notice: bool = False
    is_secret: bool = False
    secret_password: Optional[str] = Field(None, max_length=100)


class PostUpdate(BaseModel):
    title: Optional[str] = Field(None, min_length=1, max_length=200)
    content: Optional[str] = Field(None, min_length=1, max_length=50000)
    category_id: Optional[UUID] = None
    is_notice: Optional[bool] = None
    is_secret: Optional[bool] = None

    @field_validator('title', 'content', mode='before')
    @classmethod
    def sanitize_input(cls, v: str | None) -> str | None:
        if v is None or not isinstance(v, str):
            return v
        return html.escape(v.strip())


class PostResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    board_id: UUID
    category_id: Optional[UUID]
    author_id: UUID
    author_name: str
    title: str
    content: str
    is_notice: bool
    is_secret: bool
    view_count: int
    like_count: int
    comment_count: int
    is_answered: bool
    created_at: datetime
    updated_at: datetime
    attachments: List["AttachmentResponse"] = []


class PostListResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    title: str
    author_name: str
    is_notice: bool
    is_secret: bool
    view_count: int
    comment_count: int
    created_at: datetime


# ===== Comment =====
class CommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=5000)
    parent_id: Optional[UUID] = None
    is_secret: bool = False

    @field_validator('content', mode='before')
    @classmethod
    def sanitize_content(cls, v: str) -> str:
        if not isinstance(v, str):
            return v
        return html.escape(v.strip())


class CommentUpdate(BaseModel):
    content: str = Field(..., min_length=1, max_length=5000)

    @field_validator('content', mode='before')
    @classmethod
    def sanitize_content(cls, v: str) -> str:
        if not isinstance(v, str):
            return v
        return html.escape(v.strip())


class CommentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    post_id: UUID
    parent_id: Optional[UUID]
    author_id: UUID
    author_name: str
    content: str
    is_secret: bool
    like_count: int
    created_at: datetime
    replies: List["CommentResponse"] = []


# ===== Attachment =====
class AttachmentResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    post_id: UUID
    original_name: str
    file_size: int
    mime_type: str
    download_count: int


# ===== Pagination =====
class PaginatedPostResponse(BaseModel):
    items: List[PostListResponse]
    total: int
    page: int
    size: int
    pages: int


# Forward references
PostResponse.model_rebuild()
CommentResponse.model_rebuild()
```

### 3. models/__init__.py 업데이트

```python
# backend/app/models/__init__.py에 추가
from app.models.board import Board, BoardCategory, Post, Comment, Attachment
```

### 4. schemas/__init__.py 업데이트

```python
# backend/app/schemas/__init__.py에 추가
from app.schemas.board import (
    BoardCreate, BoardUpdate, BoardResponse,
    CategoryCreate, CategoryResponse,
    PostCreate, PostUpdate, PostResponse, PostListResponse, PaginatedPostResponse,
    CommentCreate, CommentUpdate, CommentResponse,
    AttachmentResponse,
)
```

## 완료 조건

1. backend/app/models/board.py 생성됨
2. backend/app/schemas/board.py 생성됨
3. models/__init__.py 업데이트됨
4. schemas/__init__.py 업데이트됨
5. 린트 통과 (ruff check)
