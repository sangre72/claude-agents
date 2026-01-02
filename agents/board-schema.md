---
name: board-schema
description: 게시판 DB 스키마 정의. boards, posts, comments, attachments, likes 테이블. board-generator가 참조하는 공유 모듈.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 DB 스키마

게시판 시스템의 **데이터베이스 스키마**를 정의하는 공유 모듈입니다.

> **사용처**: board-generator, board-backend-model이 이 스키마를 참조합니다.

---

## 테이블 관계도

```
┌──────────────────────────────────────────────────────────────┐
│                      tenants (shared-schema)                  │
│                         │                                     │
│                         ▼                                     │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                     boards                               │ │
│  │   (게시판 설정: code, name, permissions, features)        │ │
│  └────────────────────────┬────────────────────────────────┘ │
│                           │                                   │
│            ┌──────────────┼──────────────┐                   │
│            ▼              ▼              ▼                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │board_posts  │  │board_       │  │categories   │          │
│  │ (게시글)    │  │ categories  │  │(category-   │          │
│  │             │  │ (단순)      │  │ manager)    │          │
│  └──────┬──────┘  └─────────────┘  └─────────────┘          │
│         │                                                    │
│    ┌────┼────────────┬────────────┐                         │
│    ▼    ▼            ▼            ▼                         │
│ ┌─────────┐   ┌───────────┐  ┌──────────┐                   │
│ │comments │   │attachments│  │  likes   │                   │
│ │ (댓글)  │   │ (첨부파일)│  │ (좋아요) │                   │
│ └─────────┘   └───────────┘  └──────────┘                   │
└──────────────────────────────────────────────────────────────┘
```

---

## 의존성

```
shared-schema (tenants)
      │
      ▼
board-schema (이 파일)
      │
      ├── board-generator (참조)
      └── board-backend-model (참조)
```

---

## boards (게시판 설정)

```sql
CREATE TABLE IF NOT EXISTS boards (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 테넌트 (멀티사이트)
  tenant_id BIGINT NOT NULL,                  -- shared-schema.tenants 참조

  -- 기본 정보
  board_code VARCHAR(50) NOT NULL,            -- 게시판 코드 (URL에 사용)
  board_name VARCHAR(100) NOT NULL,           -- 게시판 이름
  description TEXT,                           -- 게시판 설명
  board_type ENUM('notice', 'free', 'qna', 'gallery', 'faq', 'review') DEFAULT 'free',

  -- 권한 설정
  read_permission ENUM('public', 'member', 'admin') DEFAULT 'public',
  write_permission ENUM('public', 'member', 'admin') DEFAULT 'member',
  comment_permission ENUM('disabled', 'public', 'member', 'admin') DEFAULT 'member',

  -- 보기 설정
  list_view_type ENUM('list', 'gallery', 'webzine', 'blog') DEFAULT 'list',
  posts_per_page INT DEFAULT 20,
  gallery_cols INT DEFAULT 4,                  -- 갤러리 열 수

  -- 기능 설정
  use_category BOOLEAN DEFAULT FALSE,          -- 카테고리 사용
  use_notice BOOLEAN DEFAULT TRUE,             -- 공지 기능
  use_secret BOOLEAN DEFAULT FALSE,            -- 비밀글 기능
  use_attachment BOOLEAN DEFAULT TRUE,         -- 파일첨부
  use_like BOOLEAN DEFAULT TRUE,               -- 좋아요
  use_comment BOOLEAN DEFAULT TRUE,            -- 댓글
  use_thumbnail BOOLEAN DEFAULT FALSE,         -- 썸네일 사용
  use_top_fixed BOOLEAN DEFAULT TRUE,          -- 상위 고정 기능
  use_display_period BOOLEAN DEFAULT FALSE,    -- 노출 기간 설정

  -- 파일 설정
  max_file_size INT DEFAULT 10485760,          -- 10MB
  max_file_count INT DEFAULT 5,
  allowed_file_types VARCHAR(500) DEFAULT 'jpg,jpeg,png,gif,pdf,zip,doc,docx,xls,xlsx,ppt,pptx',
  thumbnail_width INT DEFAULT 200,
  thumbnail_height INT DEFAULT 200,

  -- 정렬 설정
  display_order INT DEFAULT 0,

  -- 필수 감사 컬럼 (coding-guide 준수)
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  -- 제약 조건
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
  UNIQUE KEY uk_tenant_board (tenant_id, board_code),
  INDEX idx_tenant (tenant_id),
  INDEX idx_board_code (board_code),
  INDEX idx_display_order (display_order)
);
```

---

## board_categories (단순 카테고리)

> **참고**: 고급 계층형 카테고리는 `category-manager`의 `categories` 테이블 사용

```sql
CREATE TABLE IF NOT EXISTS board_categories (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  board_id BIGINT NOT NULL,

  category_name VARCHAR(100) NOT NULL,
  category_code VARCHAR(50),
  display_order INT DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE,
  INDEX idx_board (board_id)
);
```

---

## board_posts (게시글)

```sql
CREATE TABLE IF NOT EXISTS board_posts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  board_id BIGINT NOT NULL,
  category_id BIGINT,

  -- 기본 정보
  title VARCHAR(500) NOT NULL,
  content LONGTEXT NOT NULL,
  author VARCHAR(100) NOT NULL,               -- 작성자 이름 (표시용)
  author_id VARCHAR(50),                      -- 작성자 ID (users FK)

  -- 공지/비밀글 설정
  is_notice BOOLEAN DEFAULT FALSE,            -- 공지사항 여부
  is_secret BOOLEAN DEFAULT FALSE,            -- 비밀글 여부
  secret_password VARCHAR(255),               -- 비밀글 비밀번호 (bcrypt)

  -- 읽기 권한 설정 (그누보드 스타일)
  read_target ENUM('all', 'author', 'group') DEFAULT 'all',
  target_group_ids VARCHAR(500),              -- 대상 그룹 ID (콤마 구분)

  -- 노출 기간 설정
  display_start_date DATETIME NULL,           -- 노출 시작일시
  display_end_date DATETIME NULL,             -- 노출 종료일시

  -- 상위 고정 설정
  is_top_fixed BOOLEAN DEFAULT FALSE,         -- 상위 고정 여부
  top_fixed_order INT DEFAULT 0,              -- 상위 고정 순서
  top_fixed_end_date DATETIME NULL,           -- 상위 고정 종료일시

  -- 그누보드 호환 옵션
  wr_option VARCHAR(100) DEFAULT '',          -- html1, html2, secret, mail 등
  wr_link1 VARCHAR(1000) DEFAULT '',          -- 링크1
  wr_link2 VARCHAR(1000) DEFAULT '',          -- 링크2
  wr_ip VARCHAR(50) DEFAULT '',               -- 작성자 IP

  -- 썸네일
  thumbnail_path VARCHAR(500),

  -- 카운트
  view_count INT DEFAULT 0,
  like_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,
  file_count INT DEFAULT 0,

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  -- 제약 조건
  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES board_categories(id) ON DELETE SET NULL,

  INDEX idx_board_list (board_id, is_deleted, is_notice, created_at DESC),
  INDEX idx_board_top (board_id, is_top_fixed, top_fixed_order),
  INDEX idx_display_period (display_start_date, display_end_date),
  INDEX idx_author (author_id)
);
```

---

## board_comments (댓글)

```sql
CREATE TABLE IF NOT EXISTS board_comments (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,
  parent_id BIGINT,                           -- 대댓글용

  content TEXT NOT NULL,
  author VARCHAR(100) NOT NULL,
  author_id VARCHAR(50),
  is_secret BOOLEAN DEFAULT FALSE,            -- 비밀 댓글

  like_count INT DEFAULT 0,

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  -- 제약 조건
  FOREIGN KEY (post_id) REFERENCES board_posts(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES board_comments(id) ON DELETE SET NULL,

  INDEX idx_post (post_id),
  INDEX idx_parent (parent_id)
);
```

---

## board_attachments (첨부파일)

```sql
CREATE TABLE IF NOT EXISTS board_attachments (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,

  -- 파일 정보
  original_name VARCHAR(255) NOT NULL,        -- 원본 파일명
  stored_name VARCHAR(255) NOT NULL,          -- 저장된 파일명 (UUID)
  file_path VARCHAR(500) NOT NULL,            -- 파일 경로
  file_size BIGINT NOT NULL,                  -- 파일 크기 (bytes)
  mime_type VARCHAR(100) NOT NULL,            -- MIME 타입
  file_ext VARCHAR(20) NOT NULL,              -- 확장자

  -- 이미지 정보
  is_image BOOLEAN DEFAULT FALSE,
  image_width INT,
  image_height INT,
  thumbnail_path VARCHAR(500),

  download_count INT DEFAULT 0,

  -- 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_deleted BOOLEAN DEFAULT FALSE,

  -- 제약 조건
  FOREIGN KEY (post_id) REFERENCES board_posts(id) ON DELETE CASCADE,

  INDEX idx_post (post_id)
);
```

---

## board_likes (좋아요)

```sql
CREATE TABLE IF NOT EXISTS board_likes (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,
  user_id VARCHAR(50) NOT NULL,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  -- 제약 조건 (중복 방지)
  UNIQUE KEY uk_post_user (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES board_posts(id) ON DELETE CASCADE,

  INDEX idx_post (post_id),
  INDEX idx_user (user_id)
);
```

---

## 전체 스키마 파일

**파일**: `db/schema/board_schema.sql`

```sql
-- ============================================
-- Board System Schema
-- 게시판 시스템 테이블 정의
-- ============================================

-- 1. boards (게시판 설정)
CREATE TABLE IF NOT EXISTS boards ( ... );

-- 2. board_categories (단순 카테고리)
CREATE TABLE IF NOT EXISTS board_categories ( ... );

-- 3. board_posts (게시글)
CREATE TABLE IF NOT EXISTS board_posts ( ... );

-- 4. board_comments (댓글)
CREATE TABLE IF NOT EXISTS board_comments ( ... );

-- 5. board_attachments (첨부파일)
CREATE TABLE IF NOT EXISTS board_attachments ( ... );

-- 6. board_likes (좋아요)
CREATE TABLE IF NOT EXISTS board_likes ( ... );
```

---

## 테이블 존재 확인 쿼리

```sql
-- MySQL/MariaDB
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('boards', 'board_categories', 'board_posts', 'board_comments', 'board_attachments', 'board_likes');

-- 결과가 6개 미만이면 초기화 필요
```

---

## PostgreSQL 버전

> PostgreSQL 사용 시 아래 문법 조정 필요:

```sql
-- ENUM 대신 CHECK 제약 사용
board_type VARCHAR(20) DEFAULT 'free' CHECK (board_type IN ('notice', 'free', 'qna', 'gallery', 'faq', 'review')),

-- AUTO_INCREMENT 대신 SERIAL
id SERIAL PRIMARY KEY,

-- DATETIME 대신 TIMESTAMP
created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

-- BOOLEAN은 동일
is_active BOOLEAN DEFAULT TRUE,
```

---

## 참고

- 이 스키마는 `board-generator`가 초기화 시 생성
- `shared-schema`의 `tenants` 테이블이 먼저 존재해야 함
- 고급 카테고리는 `category-manager`의 `categories` 테이블 사용
