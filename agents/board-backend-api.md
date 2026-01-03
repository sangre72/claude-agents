---
name: board-backend-api
description: 게시판 Backend API 생성. 프로젝트의 기술 스택을 감지하여 엔드포인트 + 서비스 레이어 생성. board-shared 완료 후 병렬 실행 가능.
tools: Read, Edit, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 Backend API 에이전트

프로젝트의 **기존 기술 스택을 분석**하여 Backend API를 생성합니다.
**board-shared 완료 후** 다른 에이전트와 **병렬 실행** 가능합니다.

## 멀티게시판 구조

> **핵심**: 하나의 테이블 세트(boards, posts, comments, attachments)로 여러 게시판을 관리합니다.
> 모든 API는 `board_code`로 게시판을 구분합니다.

---

## Phase 0: 기술 스택 분석 (CRITICAL)

### 모듈 분리 규칙 (CRITICAL)

> **중요**: 각 에이전트는 **별도의 모델 파일**을 생성합니다.

| 모듈 파일 | 담당 에이전트 | 포함 모델 |
|-----------|--------------|-----------|
| `app/models/shared.py` | shared-schema | Tenant, UserGroup, Role |
| `app/models/board.py` | board-backend-model | Board, Post, Comment, Attachment |
| `app/services/board.py` | **이 에이전트** | BoardService |

**올바른 import:**
```python
# services/board.py
from app.models.board import Board, Post, Comment  # ✅ board.py에서
from app.models.shared import Tenant  # ✅ shared.py에서 (필요시)
```

**잘못된 import:**
```python
# ❌ Board는 shared에 없음!
from app.models.shared import Board, Post, Comment
```

### 기술 스택 감지

```bash
# Backend 프레임워크 감지
ls package.json && grep -E "express|fastify|koa|hapi" package.json
ls requirements.txt && grep -E "fastapi|flask|django" requirements.txt
ls pom.xml                 # Java Spring
ls go.mod                  # Go
ls Gemfile                 # Ruby on Rails

# 기존 API 패턴 분석
ls -la **/api/**/*.{js,ts,py}
head -100 {기존API파일}      # 패턴 분석
```

### 스택별 생성 파일

| 스택 | 생성 경로 | 파일명 |
|------|----------|--------|
| Express (JS) | `api/board/` | `boardHandler.js`, `postHandler.js`, ... |
| Express (TS) | `src/api/board/` | `boardHandler.ts`, `postHandler.ts`, ... |
| FastAPI | `app/api/v1/endpoints/` | `boards.py` |
| Flask | `routes/` | `boards.py` |
| Django | `boards/` | `views.py`, `urls.py` |
| Spring | `src/main/java/.../controller/` | `BoardController.java` |

---

## API 설계 (공통)

> 기술 스택에 관계없이 동일한 API 설계를 따릅니다.

### 게시판 설정 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/boards` | 게시판 목록 |
| GET | `/api/boards/:code` | 게시판 상세 |
| POST | `/api/boards` | 게시판 생성 (관리자) |
| PUT | `/api/boards/:code` | 게시판 수정 (관리자) |
| DELETE | `/api/boards/:code` | 게시판 삭제 (관리자) |

### 게시글 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/boards/:code/posts` | 게시글 목록 |
| GET | `/api/boards/:code/posts/:id` | 게시글 상세 |
| POST | `/api/boards/:code/posts` | 게시글 작성 |
| PUT | `/api/boards/:code/posts/:id` | 게시글 수정 |
| DELETE | `/api/boards/:code/posts/:id` | 게시글 삭제 |
| POST | `/api/boards/:code/posts/:id/like` | 좋아요 |

### 댓글 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/posts/:postId/comments` | 댓글 목록 |
| POST | `/api/posts/:postId/comments` | 댓글 작성 |
| PUT | `/api/comments/:id` | 댓글 수정 |
| DELETE | `/api/comments/:id` | 댓글 삭제 |

### 첨부파일 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/posts/:postId/attachments` | 첨부파일 목록 |
| POST | `/api/posts/:postId/attachments` | 파일 업로드 |
| GET | `/api/attachments/:id/download` | 파일 다운로드 |
| DELETE | `/api/attachments/:id` | 파일 삭제 |

---

## 권한 체크 로직 (공통)

```
// 게시판 설정 기반 권한 체크 (언어 무관 의사코드)
function checkPermission(board, user, action):
    permission = board[action + "_permission"]

    switch permission:
        case "public":
            return true
        case "member":
            return user != null
        case "admin":
            return user != null AND user.isAdmin == true
        case "disabled":
            return false
        default:
            return false
```

---

## 구현 원칙

### 1. 기존 패턴 따르기

- 기존 API 핸들러 파일의 **네이밍 컨벤션** 유지
- 기존 코드의 **에러 처리 패턴** 유지
- 기존 코드의 **인증/인가 방식** 그대로 사용
- 기존 코드의 **DB 연결 방식** 그대로 사용

### 2. 보안 규칙 (CRITICAL)

- **입력 검증**: 모든 사용자 입력 검증
- **SQL Injection 방지**: Parameterized Query / ORM 사용
- **권한 검증**: 게시판 설정에 따른 read/write/comment 권한 체크
- **비밀글 접근 제어**: 작성자/관리자만 열람
- **파일 업로드 검증**: MIME 타입, 크기, 확장자 검사

### 3. 응답 형식 (기존 패턴 따름)

기존 API의 응답 형식을 분석하여 동일하게 적용

```javascript
// 예: success 필드 사용 패턴
{
  success: true,
  data: { ... }
}

// 예: 에러 응답 패턴
{
  success: false,
  error_code: 'NOT_FOUND',
  message: 'Resource not found'
}
```

---

## 생성 단계

### Step 1: 기존 API 분석

```bash
# 기존 API 핸들러 파일 찾기
find . -name "*Handler.js" -o -name "*Controller.*" -o -name "*.py" | head -5

# 기존 패턴 분석
head -100 {기존파일}
```

### Step 2: 핸들러 생성

기존 패턴을 기반으로 다음 핸들러 생성:

1. **boardHandler**: 게시판 CRUD
2. **postHandler**: 게시글 CRUD
3. **commentHandler**: 댓글 CRUD
4. **attachmentHandler**: 파일 업로드/다운로드

### Step 3: 라우터 등록

기존 라우터 파일에 새 API 경로 추가

---

## 핵심 기능 구현

### 게시글 목록 (board_code 기반)

```
GET /api/boards/:code/posts?page=1&limit=20&search=&category=

1. board_code로 게시판 조회 → 없으면 404
2. 게시판의 read_permission 확인 → 권한 없으면 403
3. 페이지네이션 적용하여 게시글 조회
4. 공지글(is_notice=true) 먼저 정렬
5. 결과 반환
```

### 게시글 상세 (비밀글 처리)

```
GET /api/boards/:code/posts/:id?password=

1. board_code, post_id로 게시글 조회
2. is_secret == true일 경우:
   - 작성자 또는 관리자면 허용
   - 아니면 password 확인
3. 조회수 증가
4. 첨부파일 목록 포함하여 반환
```

### 게시글 작성 (권한 체크)

```
POST /api/boards/:code/posts

1. board_code로 게시판 조회
2. write_permission 확인
3. is_notice는 관리자만 설정 가능
4. 게시글 생성
5. 첨부파일이 있으면 저장
```

---

## 완료 조건

1. 기술 스택 분석 완료
2. 기존 API 패턴 분석 완료
3. 게시판 핸들러 생성됨 (boardHandler)
4. 게시글 핸들러 생성됨 (postHandler)
5. 댓글 핸들러 생성됨 (commentHandler)
6. 첨부파일 핸들러 생성됨 (attachmentHandler)
7. 라우터에 API 경로 등록됨
8. 기존 코드 패턴과 일관성 유지됨
