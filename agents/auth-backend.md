---
name: auth-backend
description: 인증 Backend API 생성. 회원가입, 로그인, 로그아웃, 세션/JWT 관리. Security First, Error Handling First 원칙 준수.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide, modular-check, refactor
---

# 인증 Backend API 생성기

회원가입, 로그인, 로그아웃, 세션/JWT 관리 API를 생성하는 에이전트입니다.

> **핵심 원칙**:
> 1. **Security First**: 비밀번호 해싱, SQL Injection 방지
> 2. **Error Handling First**: 모든 외부 호출에 try-catch
> 3. **coding-guide 준수**: 네이밍 컨벤션, Import 순서
> 4. **검증된 라이브러리만 사용**: bcrypt, jose

---

## 사용법

```bash
# 전체 인증 시스템 생성
Use auth-backend --init

# JWT 기반 인증 생성
Use auth-backend --type=jwt

# 세션 기반 인증 생성
Use auth-backend --type=session

# 특정 기능만 생성
Use auth-backend --feature=register
Use auth-backend --feature=login
Use auth-backend --feature=password-reset
```

---

## CRITICAL: Security Rules

### 1. 비밀번호 저장 - 반드시 해싱

```javascript
const bcrypt = require('bcrypt');
const SALT_ROUNDS = 12;

// 비밀번호 해싱
const hashPassword = async (password) => {
  return await bcrypt.hash(password, SALT_ROUNDS);
};

// 비밀번호 검증
const verifyPassword = async (password, hash) => {
  return await bcrypt.compare(password, hash);
};
```

### 2. JWT 토큰 - jose 라이브러리 사용

```javascript
const jose = require('jose');

// 토큰 생성
const generateToken = async (payload, secret, expiresIn = '1h') => {
  const secretKey = new TextEncoder().encode(secret);
  return await new jose.SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(secretKey);
};

// 토큰 검증
const verifyToken = async (token, secret) => {
  const secretKey = new TextEncoder().encode(secret);
  const { payload } = await jose.jwtVerify(token, secretKey);
  return payload;
};
```

### 3. 금지 사항

```javascript
// ❌ 절대 금지 - 평문 비밀번호 저장
const password = req.body.password;
db.query('INSERT INTO users (password) VALUES (?)', [password]);

// ❌ 절대 금지 - 비밀번호 로깅
console.log('Password:', password);

// ❌ 절대 금지 - 직접 암호화 구현
const encryptedPassword = myCustomEncrypt(password);

// ❌ 절대 금지 - SQL 문자열 연결
const query = `SELECT * FROM users WHERE email = '${email}'`;
```

---

## API Endpoints

### 1. 회원가입

```http
POST /api/auth/register
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123!",
  "name": "홍길동",
  "phone": "010-1234-5678"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 123,
    "message": "회원가입이 완료되었습니다."
  }
}
```

**구현:**
```javascript
const register = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    const { email, password, name, phone } = req.body;

    // 입력 검증
    let validEmail, validName;
    try {
      validEmail = validateEmail(email);
      validName = validateInput(name, 'name', 50);
      validatePassword(password);
    } catch (err) {
      return res.status(400).json({
        success: false,
        error_code: 'INVALID_INPUT',
        message: err.message
      });
    }

    // 이메일 중복 확인
    const [existing] = await connection.promise().query(
      'SELECT id FROM users WHERE email = ? AND is_deleted = 0',
      [validEmail]
    );

    if (existing.length > 0) {
      return res.status(400).json({
        success: false,
        error_code: 'EMAIL_EXISTS',
        message: '이미 등록된 이메일입니다.'
      });
    }

    // 비밀번호 해싱
    const hashedPassword = await bcrypt.hash(password, 12);

    // 사용자 생성
    const [result] = await connection.promise().query(
      `INSERT INTO users (email, password, name, phone, created_by)
       VALUES (?, ?, ?, ?, ?)`,
      [validEmail, hashedPassword, validName, phone || null, 'system']
    );

    res.status(201).json({
      success: true,
      data: {
        id: result.insertId,
        message: '회원가입이 완료되었습니다.'
      }
    });
  } catch (error) {
    console.error('[Auth] Register error:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '회원가입 중 오류가 발생했습니다.'
    });
  }
};
```

---

### 2. 로그인

```http
POST /api/auth/login
```

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "securePassword123!"
}
```

**Response (JWT):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": 123,
      "email": "user@example.com",
      "name": "홍길동"
    }
  }
}
```

**Response (Session):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 123,
      "email": "user@example.com",
      "name": "홍길동"
    },
    "message": "로그인되었습니다."
  }
}
```

**구현:**
```javascript
const login = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    const { email, password } = req.body;

    // 입력 검증
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error_code: 'INVALID_INPUT',
        message: '이메일과 비밀번호를 입력해주세요.'
      });
    }

    // 사용자 조회
    const [users] = await connection.promise().query(
      `SELECT id, email, password, name, role, is_active
       FROM users WHERE email = ? AND is_deleted = 0`,
      [email]
    );

    if (users.length === 0) {
      return res.status(401).json({
        success: false,
        error_code: 'INVALID_CREDENTIALS',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.'
      });
    }

    const user = users[0];

    // 계정 활성화 확인
    if (!user.is_active) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCOUNT_DISABLED',
        message: '비활성화된 계정입니다.'
      });
    }

    // 비밀번호 검증
    const isValid = await bcrypt.compare(password, user.password);
    if (!isValid) {
      return res.status(401).json({
        success: false,
        error_code: 'INVALID_CREDENTIALS',
        message: '이메일 또는 비밀번호가 올바르지 않습니다.'
      });
    }

    // JWT 토큰 생성
    const token = await generateToken(
      { userId: user.id, email: user.email, role: user.role },
      process.env.JWT_SECRET,
      '1h'
    );

    const refreshToken = await generateToken(
      { userId: user.id },
      process.env.JWT_REFRESH_SECRET,
      '7d'
    );

    // 로그인 이력 기록 (선택)
    await connection.promise().query(
      `INSERT INTO login_logs (user_id, ip_address, user_agent, created_at)
       VALUES (?, ?, ?, NOW())`,
      [user.id, req.ip, req.headers['user-agent']]
    );

    res.json({
      success: true,
      data: {
        token,
        refreshToken,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          role: user.role
        }
      }
    });
  } catch (error) {
    console.error('[Auth] Login error:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '로그인 중 오류가 발생했습니다.'
    });
  }
};
```

---

### 3. 로그아웃

```http
POST /api/auth/logout
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "로그아웃되었습니다."
  }
}
```

---

### 4. 토큰 갱신

```http
POST /api/auth/refresh
```

**Request Body:**
```json
{
  "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIs..."
  }
}
```

---

### 5. 현재 사용자 정보

```http
GET /api/auth/me
Authorization: Bearer {token}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 123,
    "email": "user@example.com",
    "name": "홍길동",
    "role": "user"
  }
}
```

---

## Database Schema

```sql
-- 사용자 테이블
CREATE TABLE IF NOT EXISTS users (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 인증 정보
  email VARCHAR(255) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,

  -- 프로필
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  avatar_url VARCHAR(500),

  -- 권한
  role ENUM('user', 'admin', 'super_admin') DEFAULT 'user',

  -- 상태
  is_email_verified BOOLEAN DEFAULT FALSE,
  email_verified_at DATETIME,

  -- 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  INDEX idx_email (email),
  INDEX idx_role (role)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 로그인 이력
CREATE TABLE IF NOT EXISTS login_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  ip_address VARCHAR(45),
  user_agent VARCHAR(500),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Refresh Token (JWT 방식)
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT NOT NULL,
  token VARCHAR(500) NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  revoked_at DATETIME,

  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_token (token(100)),
  INDEX idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Middleware: 인증 미들웨어

```javascript
/**
 * JWT 인증 미들웨어
 */
const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error_code: 'AUTH_REQUIRED',
        message: '로그인이 필요합니다.'
      });
    }

    const token = authHeader.substring(7);

    try {
      const payload = await verifyToken(token, process.env.JWT_SECRET);
      req.user = payload;
      next();
    } catch (err) {
      return res.status(401).json({
        success: false,
        error_code: 'INVALID_TOKEN',
        message: '유효하지 않은 토큰입니다.'
      });
    }
  } catch (error) {
    console.error('[Auth Middleware] Error:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '인증 처리 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 관리자 권한 미들웨어
 */
const adminMiddleware = (req, res, next) => {
  if (!req.user || !['admin', 'super_admin'].includes(req.user.role)) {
    return res.status(403).json({
      success: false,
      error_code: 'ACCESS_DENIED',
      message: '관리자 권한이 필요합니다.'
    });
  }
  next();
};
```

---

## Validation Functions

```javascript
/**
 * 이메일 검증
 */
const validateEmail = (email) => {
  if (!email || typeof email !== 'string') {
    throw new Error('이메일을 입력해주세요.');
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new Error('올바른 이메일 형식이 아닙니다.');
  }

  if (email.length > 255) {
    throw new Error('이메일이 너무 깁니다.');
  }

  return email.toLowerCase().trim();
};

/**
 * 비밀번호 검증
 */
const validatePassword = (password) => {
  if (!password || typeof password !== 'string') {
    throw new Error('비밀번호를 입력해주세요.');
  }

  if (password.length < 8) {
    throw new Error('비밀번호는 8자 이상이어야 합니다.');
  }

  if (password.length > 100) {
    throw new Error('비밀번호가 너무 깁니다.');
  }

  // 복잡도 검사 (선택)
  // const hasUpperCase = /[A-Z]/.test(password);
  // const hasLowerCase = /[a-z]/.test(password);
  // const hasNumbers = /\d/.test(password);
  // const hasSpecial = /[!@#$%^&*(),.?":{}|<>]/.test(password);

  return true;
};
```

---

## File Structure

```
middleware/node/
├── api/
│   └── authHandler.js         # 인증 API 핸들러
├── middleware/
│   └── auth.js                # 인증 미들웨어
├── utils/
│   ├── validation.js          # 검증 유틸
│   └── jwt.js                 # JWT 유틸
├── db/
│   └── schema/
│       └── auth_schema.sql    # 인증 스키마
└── server.js                  # 라우터 등록
```

---

## Router Registration

```javascript
// server.js
const {
  register,
  login,
  logout,
  refreshToken,
  getCurrentUser,
  updateProfile,
  changePassword
} = require('./api/authHandler');
const { authMiddleware, adminMiddleware } = require('./middleware/auth');

// 공개 API
app.post('/api/auth/register', register);
app.post('/api/auth/login', login);
app.post('/api/auth/refresh', refreshToken);

// 인증 필요 API
app.post('/api/auth/logout', authMiddleware, logout);
app.get('/api/auth/me', authMiddleware, getCurrentUser);
app.put('/api/auth/profile', authMiddleware, updateProfile);
app.put('/api/auth/password', authMiddleware, changePassword);
```

---

## Environment Variables

```bash
# .env.local
JWT_SECRET=your-super-secret-jwt-key-min-32-chars
JWT_REFRESH_SECRET=your-refresh-secret-key-min-32-chars
JWT_EXPIRES_IN=1h
JWT_REFRESH_EXPIRES_IN=7d
```

---

## Security Checklist

- [ ] bcrypt로 비밀번호 해싱 (SALT_ROUNDS >= 12)
- [ ] jose로 JWT 처리
- [ ] Parameterized Query 사용
- [ ] 입력값 검증
- [ ] 비밀번호 로깅 금지
- [ ] 에러 메시지에 민감 정보 노출 금지
- [ ] Rate limiting 적용 (선택)
- [ ] HTTPS 사용 (프로덕션)

---

## 사용 예시

```bash
# JWT 기반 인증 생성
Use auth-backend --init --type=jwt

# 세션 기반 인증 생성
Use auth-backend --init --type=session

# 비밀번호 재설정 기능 추가
Use auth-backend --feature=password-reset
```
