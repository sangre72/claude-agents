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

## Phase 0: 기술 스택 분석 (CRITICAL)

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

## 데이터베이스 스키마

> **중요**: 데이터베이스 종류에 맞게 문법 조정 (MySQL, PostgreSQL, SQLite 등)

### boards (게시판 설정)

```sql
CREATE TABLE boards (
  id INT AUTO_INCREMENT PRIMARY KEY,
  code VARCHAR(50) NOT NULL UNIQUE,           -- 게시판 코드 (URL에 사용)
  name VARCHAR(100) NOT NULL,                 -- 게시판 이름
  description TEXT,                           -- 게시판 설명

  -- 권한 설정
  read_permission ENUM('public', 'member', 'admin') DEFAULT 'public',
  write_permission ENUM('public', 'member', 'admin') DEFAULT 'member',
  comment_permission ENUM('disabled', 'public', 'member', 'admin') DEFAULT 'member',

  -- 기능 설정
  use_category BOOLEAN DEFAULT FALSE,
  categories JSON,                            -- ["카테고리1", "카테고리2"]
  use_notice BOOLEAN DEFAULT TRUE,            -- 공지 기능
  use_secret BOOLEAN DEFAULT FALSE,           -- 비밀글 기능
  use_attachment BOOLEAN DEFAULT TRUE,        -- 파일첨부
  use_like BOOLEAN DEFAULT TRUE,              -- 좋아요
  use_comment BOOLEAN DEFAULT TRUE,           -- 댓글

  -- 필수 감사 컬럼 (coding-guide 준수)
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE
);
```

### posts (게시글)

```sql
CREATE TABLE posts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  board_code VARCHAR(50) NOT NULL,            -- 게시판 코드 (FK)

  title VARCHAR(200) NOT NULL,
  content TEXT NOT NULL,
  author VARCHAR(100) NOT NULL,
  category VARCHAR(50),

  is_notice BOOLEAN DEFAULT FALSE,
  is_secret BOOLEAN DEFAULT FALSE,
  secret_password VARCHAR(255),

  view_count INT DEFAULT 0,
  like_count INT DEFAULT 0,
  comment_count INT DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (board_code) REFERENCES boards(code) ON DELETE CASCADE
);
```

### comments (댓글)

```sql
CREATE TABLE comments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  post_id INT NOT NULL,
  parent_id INT,                              -- 대댓글용

  content TEXT NOT NULL,
  author VARCHAR(100) NOT NULL,
  like_count INT DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES comments(id) ON DELETE SET NULL
);
```

### attachments (첨부파일)

```sql
CREATE TABLE attachments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  post_id INT NOT NULL,

  original_name VARCHAR(255) NOT NULL,
  stored_name VARCHAR(255) NOT NULL,
  file_path VARCHAR(500) NOT NULL,
  file_size INT NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  download_count INT DEFAULT 0,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
);
```

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
  code: 'notice',
  name: '공지사항',
  description: '중요한 공지사항을 알려드립니다.',
  read_permission: 'public',
  write_permission: 'admin',
  comment_permission: 'disabled',
  use_category: false,
  use_notice: true,
  use_secret: false,
  use_attachment: true,
  use_like: false,
  use_comment: false
}
```

### free (자유게시판)
```javascript
{
  code: 'free',
  name: '자유게시판',
  description: '자유롭게 의견을 나눠보세요.',
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',
  use_category: false,
  use_notice: true,
  use_secret: true,
  use_attachment: true,
  use_like: true,
  use_comment: true
}
```

### qna (Q&A)
```javascript
{
  code: 'qna',
  name: '질문과 답변',
  description: '궁금한 점을 질문해주세요.',
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',
  use_category: true,
  categories: ['서비스문의', '결제문의', '기타'],
  use_notice: true,
  use_secret: true,
  use_attachment: true,
  use_like: false,
  use_comment: true
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

### Phase 3: 게시판 추가

boards 테이블에 레코드 추가 (INSERT 쿼리 또는 API 호출)

---

## 코드 생성 원칙

### 1. 기존 패턴 따르기

```bash
# 기존 API 핸들러 패턴 분석
head -100 middleware/node/api/noticeHandler.js    # Express 예시
head -100 app/api/v1/endpoints/users.py           # FastAPI 예시
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
