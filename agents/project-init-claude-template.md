---
name: project-init-claude-template
description: CLAUDE.md 템플릿 및 환경변수 설정. project-init에서 참조.
tools: Read
model: haiku
---

# CLAUDE.md 템플릿

project-init 에이전트가 생성하는 CLAUDE.md 파일의 템플릿입니다.

---

## 템플릿 내용

```markdown
# [프로젝트명] - Claude Code 가이드

## 프로젝트 정보

- **프로젝트명**: {프로젝트 디렉토리명}
- **기술 스택**: {감지된 스택}
- **데이터베이스**: {DB명} (프로젝트명과 동일)
- **생성일**: {오늘 날짜}

---

## 데이터베이스 설정

> **DB명 규칙**: 프로젝트 디렉토리명 사용 (하이픈은 언더스코어로 변환)
> 예: `my-project` → DB명 `my_project`

### 초기 설정 명령

```bash
# 프로젝트명 확인
PROJECT_NAME=$(basename $(pwd) | tr '-' '_')
echo "DB Name: $PROJECT_NAME"

# MySQL
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# PostgreSQL
psql -U postgres -c "CREATE DATABASE ${PROJECT_NAME} WITH ENCODING 'UTF8';"

# Prisma (Next.js)
npx prisma db push
```

### 환경변수 (.env)

```bash
# 프로젝트명에 맞게 수정
DATABASE_URL="mysql://user:password@localhost:3306/{프로젝트명}"
# 또는
DATABASE_URL="postgresql://user:password@localhost:5432/{프로젝트명}"
```

---

## 개발 원칙

### Security First (보안 우선)
- 모든 사용자 입력 검증 (SQL Injection, XSS 방지)
- Parameterized Query 필수
- 비밀번호는 bcrypt로 해싱 (SALT_ROUNDS >= 12)
- JWT는 python-jose[cryptography] 또는 jose 사용
- API 키는 환경변수로 관리 (.env.local)
- httpOnly 쿠키로 토큰 저장 (XSS 방지)
- 인증번호는 개발모드에서 000000 고정 허용

### Error Handling First (오류 처리 우선)
- 모든 외부 호출에 try-catch
- 적절한 에러 응답 (error_code, message)
- 로깅 (민감 정보 제외)
- 프로덕션에서 스택 트레이스 노출 금지

### API 응답 표준 형식

// 성공: { "success": true, "data": { ... } }
// 실패: { "success": false, "error_code": "INVALID_INPUT", "message": "..." }

| Error Code | HTTP Status | 설명 |
|------------|-------------|------|
| `DATABASE_UNAVAILABLE` | 503 | DB 연결 실패 |
| `ACCESS_DENIED` | 403 | 권한 없음 |
| `INVALID_INPUT` | 400 | 입력값 검증 실패 |
| `NOT_FOUND` | 404 | 리소스 없음 |
| `INVALID_CREDENTIALS` | 401 | 인증 실패 |
| `INTERNAL_ERROR` | 500 | 서버 내부 오류 |

---

## 사용 가능한 Skills

| 스킬 | 설명 | 사용법 |
|------|------|--------|
| `gitpush` | 자동 커밋 + push | `/gitpush` |
| `gitpull` | dev merge + pull | `/gitpull` |
| `coding-guide` | 코드 품질, 보안 규칙 | 자동 적용 |
| `refactor` | 모듈화/타입 리팩토링 | `/refactor` |

---

## 사용 가능한 Agents

### 최우선 (순서대로)
| 순서 | 에이전트 | 설명 |
|------|----------|------|
| 1 | `shared-schema` | 공유 테이블 초기화 |
| 2 | `tenant-manager` | 테넌트(멀티사이트) 관리 |
| 3 | `category-manager` | 카테고리 관리 |

### 인증
| 에이전트 | 설명 |
|----------|------|
| `auth-backend` | 인증 Backend API |
| `auth-frontend` | 인증 Frontend UI |

### 메뉴 관리
| 에이전트 | 설명 |
|----------|------|
| `menu-manager` | 통합 메뉴 관리 |
| `menu-backend` | 메뉴 Backend API |
| `menu-frontend` | 메뉴 Frontend UI |

### 게시판
| 에이전트 | 설명 |
|----------|------|
| `board-generator` | 멀티게시판 오케스트레이터 |
| `board-schema` | DB 스키마 (참조용) |
| `board-templates` | 템플릿 (참조용) |

---

## 코딩 규칙

### 네이밍 컨벤션
| 구분 | 규칙 | 예시 |
|------|------|------|
| 컴포넌트/클래스 | PascalCase | `MenuManager` |
| 변수/함수 | camelCase | `getAllMenus` |
| 상수 | UPPER_SNAKE_CASE | `API_BASE_URL` |
| Boolean | is/has/should | `isActive` |

### 필수 감사 컬럼
created_at, created_by, updated_at, updated_by, is_active, is_deleted

### SQLAlchemy 예약어 주의 (CRITICAL)

> 다음 이름은 SQLAlchemy Declarative API에서 예약됨 - **컬럼명으로 사용 금지**

| 예약어 | 대안 |
|--------|------|
| `metadata` | `meta_data`, `extra_data`, `item_metadata` |
| `registry` | `item_registry`, `data_registry` |
| `__table__` | 사용 불가 |
| `__tablename__` | 테이블명 정의에만 사용 |
| `__mapper__` | 사용 불가 |

```python
# 잘못된 예
class Menu(Base):
    metadata = Column(JSON)  # ERROR!

# 올바른 예
class Menu(Base):
    menu_metadata = Column(JSON)  # OK
    extra_data = Column(JSON)     # OK
```

---

## 실행 가이드

### Backend (FastAPI)

# 1. 가상환경 설정
cd backend
python -m venv venv
source venv/bin/activate  # macOS/Linux
# .\venv\Scripts\activate  # Windows

# 2. 의존성 설치
pip install -r requirements.txt

# 3. 환경변수 설정
cp .env.example .env

# 4. DB 마이그레이션
alembic upgrade head

# 5. 서버 실행
uvicorn app.main:app --reload

# 접속: http://localhost:8000/docs

### Frontend (Next.js)

# 1. 의존성 설치
cd frontend
npm install

# 2. 개발 서버
npm run dev

# 접속: http://localhost:3000
```

---

## 환경 변수 설정

### Backend (.env)

```bash
# Database
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/mydb

# Redis
REDIS_URL=redis://localhost:6379/0

# JWT
SECRET_KEY=your-secret-key-change-in-production-min-32-chars
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d

# SMS (프로덕션 전용)
SMS_API_KEY=
SMS_SENDER_NUMBER=

# 소셜 로그인
KAKAO_CLIENT_ID=
KAKAO_CLIENT_SECRET=
NAVER_CLIENT_ID=
NAVER_CLIENT_SECRET=
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# 개발 모드
DEV_MODE=true
DEV_VERIFICATION_CODE=000000
```

### Frontend (.env.local)

```bash
# API URL
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1

# 소셜 로그인
NEXT_PUBLIC_KAKAO_CLIENT_ID=
NEXT_PUBLIC_NAVER_CLIENT_ID=
NEXT_PUBLIC_GOOGLE_CLIENT_ID=

# 지도
NEXT_PUBLIC_KAKAO_MAP_KEY=
```
