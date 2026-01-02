---
name: board-generator
description: 멀티게시판 Full Stack 생성기. 대화형/템플릿 모드 지원. 게시판, 게시글, 댓글, 파일첨부 기능을 프로젝트의 기존 기술 스택에 맞게 생성. 게시판 추가 시 사용.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide, refactor
---

# 멀티게시판 생성 오케스트레이터

그누보드 스타일의 **멀티게시판**을 Full Stack으로 생성하는 **오케스트레이터 에이전트**입니다.

> **핵심 원칙**:
> 1. **기술 스택 자동 감지**: 프로젝트의 기존 기술 스택을 분석하여 적용
> 2. **하나의 테이블 세트**로 여러 게시판 관리 (boards, posts, comments, attachments)
> 3. 새 게시판 추가 시 boards 테이블에 레코드만 추가

---

## 사용법

```bash
# 최초 설치 (테이블 생성 및 기본 컴포넌트 추가)
Use board-generator --init

# 대화형 모드 (질문을 통해 설정 수집)
Use board-generator to create a new board

# 템플릿 모드 (미리 정의된 게시판 생성)
Use board-generator --template notice      # 공지사항
Use board-generator --template free        # 자유게시판
Use board-generator --template qna         # Q&A
Use board-generator --template faq         # FAQ

# 직접 지정
Use board-generator to create 후기게시판 with code: review, categories: 병원후기, 매니저후기
```

---

## Phase 0: 사전 검증 및 초기화 (CRITICAL)

> **중요**: 코드 생성 전 반드시 다음을 확인합니다.

### Step 1: 공유 테이블 존재 확인

```sql
-- 공유 테이블 확인 (shared-schema 의존성)
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('user_groups', 'user_group_members', 'roles', 'user_roles');
```

**결과가 4개 미만이면:**
```
⚠️ 공유 테이블이 초기화되지 않았습니다.
🔧 자동으로 shared-schema를 초기화합니다...
```

→ `shared-schema.md`의 스키마를 먼저 실행

### Step 2: 게시판 테이블 존재 확인

```sql
-- 게시판 테이블 확인
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('boards', 'board_categories', 'board_posts', 'board_comments', 'board_attachments', 'board_likes');
```

**결과가 6개 미만이면:**
```
⚠️ 게시판 테이블이 초기화되지 않았습니다.
🔧 자동으로 게시판 스키마를 초기화합니다...
```

→ 게시판 스키마 생성 실행 (이 문서의 스키마 섹션)

### Step 3: 기술 스택 분석

> **중요**: 코드 생성 전 반드시 프로젝트 기술 스택을 분석합니다.

### 분석 순서

```bash
# 1. Backend 기술 스택 확인
ls package.json          # Node.js/Express
ls requirements.txt      # Python (Flask/FastAPI/Django)
ls pom.xml              # Java (Spring)
ls go.mod               # Go
ls Gemfile              # Ruby on Rails

# 2. Frontend 기술 스택 확인
ls frontend/package.json
grep -E "react|vue|angular|next|nuxt" frontend/package.json

# 3. 데이터베이스 확인
grep -E "mysql|postgres|mongodb|sqlite" package.json requirements.txt
ls docker-compose.yml    # DB 컨테이너 확인

# 4. 기존 API 패턴 확인
ls -la **/api/**/*.js **/api/**/*.py **/routes/**/*
head -50 server.js       # Express 패턴
head -50 app/main.py     # FastAPI 패턴
```

### 지원 기술 스택

| Backend | Frontend | Database |
|---------|----------|----------|
| Node.js/Express | React | MySQL |
| Python/FastAPI | React + MUI | PostgreSQL |
| Python/Flask | Vue.js | SQLite |
| Python/Django | Next.js | MongoDB |
| Java/Spring | Angular | - |
| Go/Gin | Nuxt.js | - |

### 스택별 생성 템플릿 선택

```javascript
const detectStack = async () => {
  // Backend 감지
  if (await fileExists('package.json') && await hasModule('express')) {
    backend = 'express';
  } else if (await fileExists('requirements.txt')) {
    if (await hasModule('fastapi')) backend = 'fastapi';
    else if (await hasModule('flask')) backend = 'flask';
    else if (await hasModule('django')) backend = 'django';
  }

  // Frontend 감지
  if (await fileExists('frontend/package.json')) {
    const pkg = await readJson('frontend/package.json');
    if (pkg.dependencies?.react) frontend = 'react';
    if (pkg.dependencies?.vue) frontend = 'vue';
    if (pkg.dependencies?.['@mui/material']) ui = 'mui';
    if (pkg.dependencies?.bootstrap) ui = 'bootstrap';
  }

  // Database 감지
  // ... 환경변수, 설정 파일 분석

  return { backend, frontend, ui, database };
};
```

---

## 아키텍처: 멀티게시판 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                        boards 테이블                             │
│  (게시판 설정: code, name, permissions, features, etc.)          │
├─────────────────────────────────────────────────────────────────┤
│  notice  │  free  │  qna  │  review  │  ...                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        posts 테이블                              │
│  (모든 게시글: board_code로 게시판 구분)                          │
├─────────────────────────────────────────────────────────────────┤
│  id │ board_code │ title │ content │ author │ ...               │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│     comments 테이블      │     │   attachments 테이블     │
│  (post_id로 연결)        │     │  (post_id로 연결)        │
└─────────────────────────┘     └─────────────────────────┘
```

---

## 데이터베이스 스키마 (그누보드 스타일)

> **중요**: 데이터베이스 종류에 맞게 문법 조정 (MySQL, PostgreSQL, SQLite 등)

### boards (게시판 설정)

```sql
CREATE TABLE boards (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  board_code VARCHAR(50) NOT NULL UNIQUE,     -- 게시판 코드 (URL에 사용)
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
  use_category BOOLEAN DEFAULT FALSE,
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
  is_deleted BOOLEAN DEFAULT FALSE
);
```

### board_categories (게시판 카테고리)

```sql
CREATE TABLE board_categories (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  board_id BIGINT NOT NULL,
  category_name VARCHAR(100) NOT NULL,
  display_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE
);
```

### board_posts (게시글) - 그누보드 스타일

```sql
CREATE TABLE board_posts (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  board_id BIGINT NOT NULL,
  category_id BIGINT,

  -- 기본 정보
  title VARCHAR(500) NOT NULL,
  content LONGTEXT NOT NULL,
  author VARCHAR(100) NOT NULL,               -- 작성자 이름 (표시용)
  author_id VARCHAR(50),                      -- 작성자 ID (users 테이블 FK)

  -- 공지/비밀글 설정
  is_notice BOOLEAN DEFAULT FALSE,            -- 공지사항 여부
  is_secret BOOLEAN DEFAULT FALSE,            -- 비밀글 여부
  secret_password VARCHAR(255),               -- 비밀글 비밀번호 (bcrypt)

  -- 읽기 권한 설정 (그누보드 스타일)
  read_target ENUM('all', 'author', 'group') DEFAULT 'all',  -- all: 전체, author: 작성자만, group: 그룹
  target_group_ids VARCHAR(500),              -- 대상 그룹 ID (콤마 구분)

  -- 노출 기간 설정
  display_start_date DATETIME NULL,           -- 노출 시작일시
  display_end_date DATETIME NULL,             -- 노출 종료일시

  -- 상위 고정 설정
  is_top_fixed BOOLEAN DEFAULT FALSE,         -- 상위 고정 여부
  top_fixed_order INT DEFAULT 0,              -- 상위 고정 순서 (낮을수록 위)
  top_fixed_end_date DATETIME NULL,           -- 상위 고정 종료일시

  -- 그누보드 옵션 (wr_option)
  wr_option VARCHAR(100) DEFAULT '',          -- html1, html2, secret, mail 등
  wr_link1 VARCHAR(1000) DEFAULT '',          -- 링크1
  wr_link2 VARCHAR(1000) DEFAULT '',          -- 링크2
  wr_ip VARCHAR(50) DEFAULT '',               -- 작성자 IP

  -- 썸네일
  thumbnail_path VARCHAR(500),                -- 썸네일 이미지 경로

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
  is_active BOOLEAN DEFAULT TRUE,             -- 노출 여부
  is_deleted BOOLEAN DEFAULT FALSE,           -- 삭제 여부 (소프트 삭제)

  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES board_categories(id) ON DELETE SET NULL,

  INDEX idx_board_notice (board_id, is_notice, is_deleted),
  INDEX idx_board_top (board_id, is_top_fixed, top_fixed_order),
  INDEX idx_display_period (display_start_date, display_end_date)
);
```

### board_comments (댓글)

```sql
CREATE TABLE board_comments (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,
  parent_id BIGINT,                           -- 대댓글용

  content TEXT NOT NULL,
  author VARCHAR(100) NOT NULL,
  author_id VARCHAR(50),
  is_secret BOOLEAN DEFAULT FALSE,            -- 비밀 댓글

  like_count INT DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (post_id) REFERENCES board_posts(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES board_comments(id) ON DELETE SET NULL
);
```

### board_attachments (첨부파일)

```sql
CREATE TABLE board_attachments (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,

  original_name VARCHAR(255) NOT NULL,        -- 원본 파일명
  stored_name VARCHAR(255) NOT NULL,          -- 저장된 파일명
  file_path VARCHAR(500) NOT NULL,            -- 파일 경로
  file_size BIGINT NOT NULL,                  -- 파일 크기 (bytes)
  mime_type VARCHAR(100) NOT NULL,            -- MIME 타입
  file_ext VARCHAR(20) NOT NULL,              -- 확장자

  is_image BOOLEAN DEFAULT FALSE,             -- 이미지 여부
  image_width INT,                            -- 이미지 너비
  image_height INT,                           -- 이미지 높이
  thumbnail_path VARCHAR(500),                -- 썸네일 경로

  download_count INT DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (post_id) REFERENCES board_posts(id) ON DELETE CASCADE
);
```

### board_likes (좋아요)

```sql
CREATE TABLE board_likes (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  post_id BIGINT NOT NULL,
  user_id VARCHAR(50) NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uk_post_user (post_id, user_id),
  FOREIGN KEY (post_id) REFERENCES board_posts(id) ON DELETE CASCADE
);
```

### user_groups, user_group_members (공유 테이블)

> **참고**: `user_groups`와 `user_group_members` 테이블은 `shared-schema.md`에서 정의됩니다.
> 게시판 시스템은 해당 테이블을 참조만 합니다.

---

## API 엔드포인트 (공통)

> 기술 스택에 관계없이 동일한 API 설계

### 게시판 설정

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/boards` | 게시판 목록 |
| GET | `/api/boards/:code` | 게시판 상세 |
| POST | `/api/boards` | 게시판 생성 (관리자) |
| PUT | `/api/boards/:code` | 게시판 수정 (관리자) |
| DELETE | `/api/boards/:code` | 게시판 삭제 (관리자) |

### 게시글

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/boards/:code/posts` | 게시글 목록 |
| GET | `/api/boards/:code/posts/:id` | 게시글 상세 |
| POST | `/api/boards/:code/posts` | 게시글 작성 |
| PUT | `/api/boards/:code/posts/:id` | 게시글 수정 |
| DELETE | `/api/boards/:code/posts/:id` | 게시글 삭제 |
| POST | `/api/boards/:code/posts/:id/like` | 좋아요 |

### 댓글

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/posts/:postId/comments` | 댓글 목록 |
| POST | `/api/posts/:postId/comments` | 댓글 작성 |
| PUT | `/api/comments/:id` | 댓글 수정 |
| DELETE | `/api/comments/:id` | 댓글 삭제 |

### 첨부파일

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/posts/:postId/attachments` | 첨부파일 목록 |
| POST | `/api/posts/:postId/attachments` | 파일 업로드 |
| GET | `/api/attachments/:id/download` | 파일 다운로드 |
| DELETE | `/api/attachments/:id` | 파일 삭제 |

---

## 템플릿 정의

### notice (공지사항)
```javascript
{
  board_code: 'notice',
  board_name: '공지사항',
  description: '중요한 공지사항을 알려드립니다.',
  board_type: 'notice',
  list_view_type: 'list',
  read_permission: 'public',
  write_permission: 'admin',
  comment_permission: 'disabled',
  use_category: false,
  use_notice: true,
  use_secret: false,
  use_attachment: true,
  use_like: false,
  use_comment: false,
  use_thumbnail: false,
  use_top_fixed: true,
  use_display_period: true
}
```

### free (자유게시판)
```javascript
{
  board_code: 'free',
  board_name: '자유게시판',
  description: '자유롭게 의견을 나눠보세요.',
  board_type: 'free',
  list_view_type: 'list',
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',
  use_category: false,
  use_notice: true,
  use_secret: true,
  use_attachment: true,
  use_like: true,
  use_comment: true,
  use_thumbnail: false,
  use_top_fixed: true,
  use_display_period: false
}
```

### qna (Q&A)
```javascript
{
  board_code: 'qna',
  board_name: '질문과 답변',
  description: '궁금한 점을 질문해주세요.',
  board_type: 'qna',
  list_view_type: 'list',
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',
  use_category: true,
  categories: ['서비스문의', '결제문의', '기타'],
  use_notice: true,
  use_secret: true,
  use_attachment: true,
  use_like: false,
  use_comment: true,
  use_thumbnail: false,
  use_top_fixed: false,
  use_display_period: false
}
```

### gallery (갤러리)
```javascript
{
  board_code: 'gallery',
  board_name: '갤러리',
  description: '사진을 공유해보세요.',
  board_type: 'gallery',
  list_view_type: 'gallery',           // 갤러리 보기
  gallery_cols: 4,                      // 4열 표시
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',
  use_category: true,
  categories: ['풍경', '인물', '일상', '기타'],
  use_notice: false,
  use_secret: false,
  use_attachment: true,
  use_like: true,
  use_comment: true,
  use_thumbnail: true,                  // 썸네일 사용
  thumbnail_width: 300,
  thumbnail_height: 300,
  use_top_fixed: false,
  use_display_period: false,
  allowed_file_types: 'jpg,jpeg,png,gif,webp'  // 이미지만 허용
}
```

### faq (FAQ)
```javascript
{
  board_code: 'faq',
  board_name: 'FAQ',
  description: '자주 묻는 질문입니다.',
  board_type: 'faq',
  list_view_type: 'list',
  read_permission: 'public',
  write_permission: 'admin',
  comment_permission: 'disabled',
  use_category: true,
  categories: ['회원', '서비스', '결제', '기타'],
  use_notice: false,
  use_secret: false,
  use_attachment: false,
  use_like: false,
  use_comment: false,
  use_thumbnail: false,
  use_top_fixed: false,
  use_display_period: false
}
```

### review (후기게시판)
```javascript
{
  board_code: 'review',
  board_name: '이용후기',
  description: '이용 후기를 남겨주세요.',
  board_type: 'review',
  list_view_type: 'webzine',            // 웹진 스타일 (썸네일 + 내용 미리보기)
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',
  use_category: true,
  categories: ['병원후기', '매니저후기', '서비스후기'],
  use_notice: true,
  use_secret: false,
  use_attachment: true,
  use_like: true,
  use_comment: true,
  use_thumbnail: true,
  thumbnail_width: 200,
  thumbnail_height: 150,
  use_top_fixed: true,
  use_display_period: false
}
```

---

## 게시판 관리 기능 (관리자)

> **관리자 화면**에서 게시판 생성/수정/삭제 가능

### 게시판 관리 API

```javascript
// 게시판 생성
POST /api/admin/boards
{
  board_code: "review",
  board_name: "이용후기",
  description: "서비스 이용 후기를 남겨주세요.",
  board_type: "review",
  list_view_type: "gallery",       // list, gallery, webzine, blog

  // 권한
  read_permission: "public",
  write_permission: "member",
  comment_permission: "member",

  // 기능 ON/OFF
  use_category: true,
  use_notice: true,
  use_secret: false,
  use_attachment: true,
  use_like: true,
  use_comment: true,
  use_thumbnail: true,
  use_top_fixed: true,
  use_display_period: false,

  // 파일 설정
  max_file_size: 10485760,         // 10MB (bytes)
  max_file_count: 5,
  allowed_file_types: "jpg,jpeg,png,gif,pdf,zip",

  // 썸네일 설정
  thumbnail_width: 200,
  thumbnail_height: 200,

  // 표시 설정
  posts_per_page: 20,
  gallery_cols: 4,
  display_order: 1
}

// 게시판 수정
PUT /api/admin/boards/:code

// 게시판 삭제 (소프트 삭제)
DELETE /api/admin/boards/:code

// 카테고리 관리
POST /api/admin/boards/:code/categories
PUT /api/admin/boards/:code/categories/:id
DELETE /api/admin/boards/:code/categories/:id
```

### 프론트엔드 관리자 화면

생성할 컴포넌트:
- `components/admin/BoardManagement.tsx` - 게시판 목록/관리
- `components/admin/BoardForm.tsx` - 게시판 생성/수정 폼
- `components/admin/CategoryManagement.tsx` - 카테고리 관리

**BoardForm 설정 항목:**

| 섹션 | 항목 | 설명 |
|------|------|------|
| 기본정보 | board_code | 게시판 코드 (URL에 사용, 영문/숫자) |
| | board_name | 게시판 이름 |
| | description | 게시판 설명 |
| | board_type | 유형 (notice/free/qna/gallery/faq/review) |
| 권한설정 | read_permission | 읽기 권한 (public/member/admin) |
| | write_permission | 쓰기 권한 |
| | comment_permission | 댓글 권한 (disabled 포함) |
| 보기설정 | list_view_type | 목록 스타일 (list/gallery/webzine/blog) |
| | posts_per_page | 페이지당 게시글 수 |
| | gallery_cols | 갤러리 열 수 (갤러리 타입) |
| 기능설정 | use_category | 카테고리 사용 |
| | use_notice | 공지 기능 |
| | use_secret | 비밀글 기능 |
| | use_attachment | 파일 첨부 |
| | use_like | 좋아요 |
| | use_comment | 댓글 |
| | use_thumbnail | 썸네일 |
| | use_top_fixed | 상위 고정 |
| | use_display_period | 노출 기간 |
| 파일설정 | max_file_size | 최대 파일 크기 (MB) |
| | max_file_count | 최대 파일 수 |
| | allowed_file_types | 허용 확장자 |
| | thumbnail_width | 썸네일 너비 |
| | thumbnail_height | 썸네일 높이 |

---

## 파일 첨부 기능

### 파일 업로드 API

```javascript
// 파일 업로드
POST /api/boards/:code/posts/:postId/attachments
Content-Type: multipart/form-data

// Response
{
  success: true,
  data: {
    id: 1,
    original_name: "photo.jpg",
    stored_name: "20240102_abc123.jpg",
    file_path: "/uploads/boards/review/2024/01/20240102_abc123.jpg",
    file_size: 1024000,
    mime_type: "image/jpeg",
    file_ext: "jpg",
    is_image: true,
    image_width: 1920,
    image_height: 1080,
    thumbnail_path: "/uploads/boards/review/2024/01/thumb_20240102_abc123.jpg"
  }
}

// 파일 다운로드
GET /api/attachments/:id/download

// 파일 삭제
DELETE /api/attachments/:id
```

### 파일 업로드 검증

```javascript
// 파일 검증 로직
function validateFile(file, board) {
  // 1. 확장자 검증
  const ext = file.originalname.split('.').pop().toLowerCase();
  const allowedTypes = board.allowed_file_types.split(',');
  if (!allowedTypes.includes(ext)) {
    throw new Error(`허용되지 않는 파일 형식입니다. (허용: ${allowedTypes.join(', ')})`);
  }

  // 2. 파일 크기 검증
  if (file.size > board.max_file_size) {
    throw new Error(`파일 크기가 ${board.max_file_size / 1024 / 1024}MB를 초과합니다.`);
  }

  // 3. MIME 타입 검증 (보안)
  const allowedMimes = getMimeTypes(allowedTypes);
  if (!allowedMimes.includes(file.mimetype)) {
    throw new Error('유효하지 않은 파일입니다.');
  }

  return true;
}
```

### 썸네일 생성

```javascript
// 이미지 썸네일 생성 (sharp 라이브러리)
const sharp = require('sharp');

async function createThumbnail(imagePath, board) {
  const thumbnailPath = imagePath.replace(/(\.[^.]+)$/, '_thumb$1');

  await sharp(imagePath)
    .resize(board.thumbnail_width, board.thumbnail_height, {
      fit: 'cover',
      position: 'center'
    })
    .toFile(thumbnailPath);

  return thumbnailPath;
}
```

---

## 생성 워크플로우

### Phase 1: 기술 스택 분석

```bash
# 프로젝트 구조 분석
ls -la
cat package.json 2>/dev/null || cat requirements.txt 2>/dev/null
ls frontend/ 2>/dev/null
```

### Phase 2: 초기화 (--init)

테이블 및 기본 컴포넌트 생성

**생성되는 파일 (기술 스택별):**

| 스택 | Backend | Frontend |
|------|---------|----------|
| Express + React | `api/board/*.js` | `components/board/*.tsx` |
| FastAPI + React | `app/api/boards.py` | `components/board/*.tsx` |
| Flask + Vue | `routes/boards.py` | `components/Board*.vue` |
| Django + React | `boards/views.py` | `components/board/*.tsx` |

**Frontend 컴포넌트 목록:**

| 파일 | 설명 |
|------|------|
| `BoardList.tsx` | 게시판 목록 |
| `PostList.tsx` | 게시글 목록 (list 보기) |
| `PostGallery.tsx` | 게시글 목록 (gallery 보기) |
| `PostWebzine.tsx` | 게시글 목록 (webzine 보기) |
| `PostView.tsx` | 게시글 상세 |
| `PostForm.tsx` | 게시글 작성/수정 |
| `CommentList.tsx` | 댓글 목록 |
| `FileUploader.tsx` | 파일 업로드 컴포넌트 |
| `admin/BoardManagement.tsx` | 게시판 관리 |
| `admin/BoardForm.tsx` | 게시판 생성/수정 폼 |

### Phase 3: 게시판 추가

boards 테이블에 레코드 추가 (INSERT 쿼리 또는 API 호출)

---

## 실행 액션 (CRITICAL - 반드시 실행)

> **중요**: 에이전트 실행 시 아래 액션들을 **순서대로 실제 실행**해야 합니다.

### Action 1: 프로젝트 분석

```bash
# 반드시 실행하여 기술 스택 확인
ls -la
cat package.json 2>/dev/null | head -50
ls middleware/node/ 2>/dev/null
ls frontend/src/ 2>/dev/null
grep -l "mysql\|mysql2" middleware/node/*.js middleware/node/**/*.js 2>/dev/null | head -3
```

### Action 2: DB 스키마 생성 (--init 시)

```bash
# MySQL 스키마 파일 생성 후 실행
# 파일 경로: middleware/node/db/schema/multi_board_schema.sql
```

**반드시 Write 도구로 스키마 파일 생성:**
- 위 "데이터베이스 스키마" 섹션의 모든 CREATE TABLE 문 포함
- boards, board_categories, board_posts, board_comments, board_attachments, board_likes 테이블

### Action 3: Backend API 핸들러 생성

**생성할 파일들 (Express + mysql2 기준):**

| 파일 | 역할 |
|------|------|
| `middleware/node/api/boardHandler.js` | 게시판 CRUD, 게시글 CRUD |
| `middleware/node/api/boardCommentHandler.js` | 댓글 CRUD |
| `middleware/node/api/boardAttachmentHandler.js` | 파일 업로드/다운로드/삭제 |
| `middleware/node/api/boardAdminHandler.js` | 게시판 관리 (관리자) |

**각 핸들러에 반드시 포함:**
1. mysql2 연결 설정
2. 입력 검증 함수 (validateInput)
3. 권한 체크 함수 (checkPermission)
4. 에러 핸들링 (try-catch)
5. Parameterized Query (SQL Injection 방지)

### Action 4: Frontend 컴포넌트 생성

**생성할 파일들 (React + MUI + TypeScript 기준):**

| 파일 | 역할 |
|------|------|
| `frontend/src/types/board.ts` | 타입 정의 |
| `frontend/src/lib/boardApi.ts` | API 클라이언트 |
| `frontend/src/components/board/BoardList.tsx` | 게시판 목록 |
| `frontend/src/components/board/PostList.tsx` | 게시글 목록 (list) |
| `frontend/src/components/board/PostGallery.tsx` | 게시글 목록 (gallery) |
| `frontend/src/components/board/PostView.tsx` | 게시글 상세 |
| `frontend/src/components/board/PostForm.tsx` | 게시글 작성/수정 |
| `frontend/src/components/board/CommentList.tsx` | 댓글 목록 |
| `frontend/src/components/board/FileUploader.tsx` | 파일 업로드 |
| `frontend/src/components/admin/BoardManagement.tsx` | 게시판 관리 |
| `frontend/src/components/admin/BoardForm.tsx` | 게시판 생성/수정 폼 |

### Action 5: 라우트 등록

**server.js에 라우트 추가:**
```javascript
// Board API Routes 추가
const boardHandler = require('./api/boardHandler');
const boardCommentHandler = require('./api/boardCommentHandler');
const boardAttachmentHandler = require('./api/boardAttachmentHandler');
const boardAdminHandler = require('./api/boardAdminHandler');

// 게시판 (externalApiRouter보다 먼저 등록)
app.get('/api/boards', boardHandler.getBoards);
app.get('/api/boards/:boardCode', boardHandler.getBoardByCode);
// ... 모든 라우트 등록
```

**App.tsx에 React Router 추가:**
```tsx
<Route path="/boards" element={<BoardList />} />
<Route path="/boards/:boardCode" element={<PostList />} />
// ... 모든 라우트 등록
```

### Action 6: 기본 게시판 데이터 삽입 (--template 시)

```sql
-- 템플릿에 따른 INSERT 문 실행
INSERT INTO boards (...) VALUES (...);
INSERT INTO board_categories (...) VALUES (...);
```

---

## 코드 생성 원칙

### 1. 기존 패턴 따르기

```bash
# 기존 API 핸들러 패턴 분석 (반드시 읽고 패턴 파악)
head -100 middleware/node/api/noticeHandler.js
head -100 middleware/node/api/authHandler.js
```

- 기존 코드의 네이밍 컨벤션 유지
- 기존 코드의 에러 처리 패턴 유지
- 기존 코드의 인증/인가 방식 유지

### 2. 보안 규칙 (CRITICAL)

1. **입력 검증**: 모든 사용자 입력 검증
2. **SQL Injection 방지**: Parameterized Query 사용
3. **XSS 방지**: 콘텐츠 이스케이프
4. **권한 검증**: 게시판 설정에 따른 권한 체크
5. **비밀글 접근 제어**: 작성자/관리자만 열람
6. **파일 업로드 검증**: MIME 타입, 크기, 확장자

### 3. 필수 컬럼 (coding-guide)

모든 테이블에 다음 컬럼 포함:
- `id`, `created_at`, `created_by`
- `updated_at`, `updated_by`
- `is_active`, `is_deleted`

---

## 권한 처리 (공통 로직)

```javascript
// 게시판 설정 기반 권한 체크 (언어 무관 로직)
function checkPermission(board, user, action) {
  const permission = board[`${action}_permission`];

  switch (permission) {
    case 'public':
      return true;
    case 'member':
      return user != null;
    case 'admin':
      return user != null && user.isAdmin === true;
    case 'disabled':
      return false;
    default:
      return false;
  }
}
```

---

## 완료 메시지

```
✅ 멀티게시판 시스템 초기화 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

감지된 기술 스택:
  - Backend: {Express/FastAPI/Flask/etc.}
  - Frontend: {React/Vue/etc.}
  - UI Library: {MUI/Bootstrap/etc.}
  - Database: {MySQL/PostgreSQL/etc.}

생성된 테이블:
  - boards: 게시판 설정
  - posts: 게시글
  - comments: 댓글
  - attachments: 첨부파일

생성된 파일:
  Backend:
    ✓ {path}/boardHandler.{ext}
    ✓ {path}/postHandler.{ext}
    ✓ {path}/commentHandler.{ext}
    ✓ {path}/attachmentHandler.{ext}

  Frontend:
    ✓ {path}/PostList.{ext}
    ✓ {path}/PostDetail.{ext}
    ✓ {path}/PostForm.{ext}
    ✓ {path}/CommentList.{ext}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

다음 단계:
  1. 데이터베이스 마이그레이션 실행
  2. 서버 재시작
  3. 게시판 추가: Use board-generator --template notice
```

```
✅ 게시판 추가 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

추가된 게시판:
  - 이름: {name}
  - 코드: {code}
  - 경로: /boards/{code}

설정:
  - 읽기: {read_permission}
  - 쓰기: {write_permission}
  - 댓글: {comment_permission}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

다음 단계:
  1. 게시판 접속: http://localhost:{port}/boards/{code}
```

---

## 생성된 파일 목록 (2024.01 기준)

> 아래는 이 프로젝트에서 실제 생성/사용되는 파일 목록입니다.

### Backend (Node.js/Express + mysql2)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/boardHandler.js` | 게시판/게시글 CRUD API |
| `middleware/node/api/boardCommentHandler.js` | 댓글 CRUD API |
| `middleware/node/api/boardAttachmentHandler.js` | 파일 업로드/다운로드 API |
| `middleware/node/api/boardAdminHandler.js` | 관리자 게시판 관리 API |
| `middleware/node/db/schema/multi_board_schema.sql` | DB 스키마 |

### Frontend (React + MUI + TypeScript)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/board.ts` | Board, Post, Comment, Attachment 타입 정의 |
| `frontend/src/lib/boardApi.ts` | API 클라이언트 (axios) |
| `frontend/src/components/board/BoardList.tsx` | 게시판 목록 페이지 |
| `frontend/src/components/board/PostList.tsx` | 게시글 목록 (list 뷰) |
| `frontend/src/components/board/PostGallery.tsx` | 게시글 목록 (gallery 뷰) |
| `frontend/src/components/board/PostView.tsx` | 게시글 상세 보기 |
| `frontend/src/components/board/PostForm.tsx` | 게시글 작성/수정 |
| `frontend/src/components/board/CommentList.tsx` | 댓글 목록 |
| `frontend/src/components/board/FileUploader.tsx` | 파일 업로드 컴포넌트 |
| `frontend/src/components/admin/BoardManagement.tsx` | 게시판 관리 페이지 |
| `frontend/src/components/admin/BoardForm.tsx` | 게시판 생성/수정 폼 |

### 라우트 등록 (server.js)

```javascript
// Multi Board System imports
const { getBoards, getBoardByCode, getPosts, getPostById, createPost, updatePost, deletePost } = require('./api/boardHandler');
const { getComments: getBoardComments, createComment: createBoardComment, updateComment: updateBoardComment, deleteComment: deleteBoardComment } = require('./api/boardCommentHandler');
const { loadBoardSettings, uploadMiddleware, uploadFiles, getAttachments, downloadFile, deleteFile } = require('./api/boardAttachmentHandler');
const { requireAdmin, getBoards: getAdminBoards, createBoard, updateBoard, deleteBoard, addCategory, getCategories, deleteCategory } = require('./api/boardAdminHandler');

// Multi Board System API Routes (externalApiRouter보다 먼저 등록)
app.get('/api/boards', getBoards);
app.get('/api/boards/:boardCode', getBoardByCode);
app.get('/api/boards/:boardCode/posts', getPosts);
app.get('/api/boards/:boardCode/posts/:postId', getPostById);
app.post('/api/boards/:boardCode/posts', createPost);
app.put('/api/boards/:boardCode/posts/:postId', updatePost);
app.delete('/api/boards/:boardCode/posts/:postId', deletePost);

// Board Comments API Routes
app.get('/api/boards/:boardCode/posts/:postId/comments', getBoardComments);
app.post('/api/boards/:boardCode/posts/:postId/comments', createBoardComment);
app.put('/api/boards/:boardCode/posts/:postId/comments/:commentId', updateBoardComment);
app.delete('/api/boards/:boardCode/posts/:postId/comments/:commentId', deleteBoardComment);

// Board Attachments API Routes
app.get('/api/boards/:boardCode/posts/:postId/attachments', getAttachments);
app.post('/api/boards/:boardCode/posts/:postId/attachments', loadBoardSettings, uploadMiddleware, uploadFiles);
app.get('/api/attachments/:attachmentId/download', downloadFile);
app.delete('/api/attachments/:attachmentId', deleteFile);

// Board Admin API Routes
app.get('/api/admin/boards', requireAdmin, getAdminBoards);
app.post('/api/admin/boards', requireAdmin, createBoard);
app.put('/api/admin/boards/:boardCode', requireAdmin, updateBoard);
app.delete('/api/admin/boards/:boardCode', requireAdmin, deleteBoard);
app.get('/api/admin/boards/:boardCode/categories', requireAdmin, getCategories);
app.post('/api/admin/boards/:boardCode/categories', requireAdmin, addCategory);
app.delete('/api/admin/boards/:boardCode/categories/:categoryId', requireAdmin, deleteCategory);
```

### 라우트 등록 (App.tsx)

```tsx
// Multi Board System imports
import BoardList from './components/board/BoardList';
import PostList from './components/board/PostList';
import PostGallery from './components/board/PostGallery';
import PostView from './components/board/PostView';
import PostForm from './components/board/PostForm';
import BoardManagement from './components/admin/BoardManagement';
import BoardForm from './components/admin/BoardForm';

// Routes
<Route path="/boards" element={<BoardList />} />
<Route path="/boards/:boardCode" element={<PostList />} />
<Route path="/boards/:boardCode/gallery" element={<PostGallery />} />
<Route path="/boards/:boardCode/posts/:postId" element={<PostView />} />
<Route path="/boards/:boardCode/write" element={<PostForm />} />
<Route path="/boards/:boardCode/posts/:postId/edit" element={<PostForm />} />
{/* Admin Routes */}
<Route path="/admin/boards" element={<BoardManagement />} />
<Route path="/admin/boards/new" element={<BoardForm />} />
<Route path="/admin/boards/:boardCode/edit" element={<BoardForm />} />
```

---

## TypeScript 타입 정의 (board.ts)

```typescript
// Board Types (그누보드 스타일)
export type BoardType = 'notice' | 'free' | 'qna' | 'gallery' | 'faq' | 'review';
export type ListViewType = 'list' | 'gallery' | 'webzine' | 'blog';
export type PermissionType = 'public' | 'member' | 'admin';
export type CommentPermissionType = 'public' | 'member' | 'admin' | 'disabled';
export type ReadTarget = 'all' | 'author' | 'group';

export interface Board {
  id: number;
  board_code: string;
  board_name: string;
  description: string | null;
  board_type: BoardType;
  list_view_type: ListViewType;
  read_permission: PermissionType;
  write_permission: PermissionType;
  comment_permission: CommentPermissionType;
  posts_per_page: number;
  gallery_cols: number;
  use_category: boolean;
  use_notice: boolean;
  use_secret: boolean;
  use_attachment: boolean;
  use_like: boolean;
  use_comment: boolean;
  use_thumbnail: boolean;
  use_top_fixed: boolean;
  use_display_period: boolean;
  max_file_size: number;
  max_file_count: number;
  allowed_file_types: string;
  thumbnail_width: number;
  thumbnail_height: number;
  display_order: number;
  created_at: string;
  updated_at: string;
  categories?: BoardCategory[];
}

export interface Post {
  id: number;
  board_id: number;
  category_id: number | null;
  title: string;
  content: string;
  author: string;
  is_notice: boolean;
  is_secret: boolean;
  read_target: ReadTarget;
  display_start_date: string | null;
  display_end_date: string | null;
  is_top_fixed: boolean;
  top_fixed_order: number;
  thumbnail_path: string | null;
  view_count: number;
  like_count: number;
  comment_count: number;
  file_count: number;
  created_at: string;
  attachments?: Attachment[];
}

export interface Attachment {
  id: number;
  post_id: number;
  original_name: string;
  stored_name: string;
  file_path: string;
  file_size: number;
  mime_type: string;
  is_image: boolean;
  thumbnail_path: string | null;
  download_count: number;
}

export interface BoardFormData {
  board_code: string;
  board_name: string;
  board_type: BoardType;
  list_view_type: ListViewType;
  // ... 모든 설정 필드
}
```

---

## 의존성

### Backend (package.json)
```json
{
  "dependencies": {
    "express": "^4.19.x",
    "mysql2": "^3.x",
    "bcrypt": "^5.x",
    "multer": "^1.4.x",
    "sharp": "^0.33.x"
  }
}
```

### Frontend (package.json)
```json
{
  "dependencies": {
    "react": "^18.x",
    "@mui/material": "^5.x",
    "@mui/icons-material": "^5.x",
    "axios": "^1.x",
    "react-router-dom": "^6.x"
  }
}
```
