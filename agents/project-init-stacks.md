---
name: project-init-stacks
description: 스택별 프로젝트 구조 및 설정. project-init에서 참조.
tools: Read
model: haiku
---

# 스택별 프로젝트 구조

project-init 에이전트가 참조하는 스택별 설정입니다.

---

## Next.js Full Stack (권장)

```
src/
├── app/                           # App Router
│   ├── (auth)/                    # 인증 그룹
│   │   ├── login/page.tsx
│   │   └── register/page.tsx
│   ├── (main)/                    # 메인 그룹
│   │   ├── page.tsx               # 홈
│   │   └── mypage/page.tsx        # 마이페이지
│   ├── admin/                     # 관리자
│   │   ├── menus/page.tsx
│   │   └── boards/page.tsx
│   ├── api/                       # API Routes
│   │   ├── auth/
│   │   │   ├── [...nextauth]/route.ts
│   │   │   ├── send-code/route.ts
│   │   │   └── verify-code/route.ts
│   │   ├── menus/route.ts
│   │   └── posts/route.ts
│   └── layout.tsx
├── components/
│   ├── auth/
│   ├── admin/menu/
│   └── board/
├── lib/
│   ├── auth.ts                    # 인증 유틸
│   ├── db.ts                      # Prisma/Drizzle
│   └── api.ts                     # API 클라이언트
├── stores/
│   └── authStore.ts               # Zustand
└── types/
    ├── auth.ts
    ├── menu.ts
    └── post.ts

prisma/
├── schema.prisma                  # DB 스키마
└── migrations/
```

---

## Express + React + MySQL

```
middleware/node/
├── api/
│   ├── authHandler.js      # 인증 API
│   └── menuAdminHandler.js # 메뉴 API
├── middleware/
│   └── auth.js             # JWT 미들웨어
├── db/
│   └── schema/
│       ├── auth_schema.sql
│       └── menu_schema.sql
└── server.js               # 라우터 등록

frontend/
├── src/
│   ├── types/
│   │   ├── auth.ts
│   │   └── menu.ts
│   ├── lib/
│   │   ├── authApi.ts
│   │   └── menuApi.ts
│   ├── contexts/
│   │   └── AuthContext.tsx
│   └── components/
│       ├── auth/
│       │   ├── LoginPage.tsx
│       │   └── RegisterPage.tsx
│       └── admin/
│           └── menu/
│               ├── MenuManager.tsx
│               ├── MenuTree.tsx
│               └── MenuForm.tsx
```

---

## FastAPI + React + PostgreSQL (권장)

```
backend/
├── alembic/                     # DB 마이그레이션
│   ├── versions/
│   └── env.py
├── app/
│   ├── api/
│   │   ├── deps.py              # 의존성 (인증, DB 세션)
│   │   └── v1/endpoints/
│   │       ├── auth.py
│   │       ├── users.py
│   │       └── menus.py
│   ├── core/
│   │   ├── config.py
│   │   └── security.py
│   ├── db/
│   │   ├── base.py
│   │   └── session.py
│   ├── models/
│   │   ├── user.py
│   │   ├── menu.py
│   │   └── verification.py
│   ├── schemas/
│   │   ├── auth.py
│   │   ├── user.py
│   │   └── menu.py
│   ├── services/
│   │   ├── auth.py
│   │   └── sms.py
│   └── main.py
├── requirements.txt
└── .env

frontend/
├── src/
│   ├── app/                     # Next.js App Router
│   │   ├── (auth)/
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── mypage/
│   │   └── admin/menus/
│   ├── components/
│   │   ├── auth/
│   │   └── admin/menu/
│   ├── hooks/
│   │   ├── useAuth.ts
│   │   └── useMenu.ts
│   ├── lib/api.ts
│   ├── stores/authStore.ts
│   └── types/
│       ├── auth.ts
│       ├── user.ts
│       └── menu.ts
└── package.json
```

---

## FastAPI 필수 의존성

```txt
# requirements.txt
fastapi>=0.109.0
uvicorn[standard]>=0.27.0
sqlalchemy[asyncio]>=2.0.0
asyncpg>=0.29.0
alembic>=1.13.0
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
pydantic>=2.5.0
pydantic-settings>=2.1.0
python-multipart>=0.0.6
httpx>=0.26.0
redis>=5.0.0
```

---

## FastAPI 감사 컬럼 Mixin (필수)

```python
# app/db/base.py
from sqlalchemy import Column, DateTime, String, Boolean
from sqlalchemy.sql import func

class TimestampMixin:
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    created_by = Column(String(100), nullable=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    updated_by = Column(String(100), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)
```

---

## FastAPI 인증 예시

```python
# app/api/v1/endpoints/auth.py
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db

router = APIRouter()

@router.post("/send-code")
async def send_verification_code(request: SendCodeRequest, db: AsyncSession = Depends(get_db)):
    """휴대폰 인증번호 발송 (개발모드: 000000)"""
    ...

@router.post("/verify-code")
async def verify_code(request: VerifyCodeRequest, db: AsyncSession = Depends(get_db)):
    """인증번호 확인 → verification_token 발급"""
    ...

@router.post("/register")
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    """회원가입 (verification_token 필요)"""
    ...

@router.post("/login")
async def login(request: LoginRequest, db: AsyncSession = Depends(get_db)):
    """로그인 (휴대폰 + 인증번호)"""
    ...
```
