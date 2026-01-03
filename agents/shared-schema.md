---
name: shared-schema
description: 공유 데이터베이스 스키마. user_groups, roles 등 여러 에이전트가 공통으로 사용하는 테이블 정의. board-generator, menu-manager 등이 의존.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 공유 데이터베이스 스키마

여러 에이전트가 **공통으로 사용하는 테이블**을 정의하고 생성하는 에이전트입니다.

> **의존하는 에이전트들:**
> - `board-generator`: 게시판 시스템
> - `menu-manager`: 메뉴 관리 시스템
> - 기타 사용자/권한 관련 에이전트

---

## 사용법

```bash
# 공유 테이블 초기화 (필수 - 다른 에이전트 실행 전)
Use shared-schema --init

# 테이블 존재 여부 확인
Use shared-schema --check

# 특정 테이블만 생성
Use shared-schema --table=user_groups
Use shared-schema --table=roles
```

---

## 공유 테이블 목록

| 테이블 | 설명 | 사용하는 에이전트 |
|--------|------|------------------|
| `tenants` | 테넌트 (멀티사이트) | 전체 |
| `user_groups` | 사용자 그룹 | board-generator, menu-manager |
| `user_group_members` | 사용자-그룹 매핑 | board-generator, menu-manager |
| `roles` | 역할 | menu-manager |
| `user_roles` | 사용자-역할 매핑 | menu-manager |

---

## 멀티 테넌트 아키텍처

> **테넌트**: 하나의 시스템에서 여러 사이트/조직을 독립적으로 운영하기 위한 개념

### 테넌트 식별 방식

| 방식 | 예시 | 사용 시나리오 |
|------|------|--------------|
| **도메인** | `siteA.com`, `siteB.com` | 완전 독립 사이트 |
| **서브도메인** | `siteA.example.com`, `siteB.example.com` | SaaS 플랫폼 |
| **경로** | `example.com/siteA`, `example.com/siteB` | 단일 도메인 멀티사이트 |
| **헤더** | `X-Tenant-ID: siteA` | API 기반 |

### 테넌트 적용 테이블

```
┌─────────────────────────────────────────────────────────────┐
│                      tenants 테이블                          │
│  (사이트/조직 정의: tenant_code, domain, settings)           │
├─────────────────────────────────────────────────────────────┤
│  siteA (쇼핑몰)  │  siteB (커뮤니티)  │  siteC (기업)        │
└─────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│     menus       │  │     boards      │  │   user_groups   │
│  (tenant_id)    │  │  (tenant_id)    │  │  (tenant_id)    │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

### 테넌트 미들웨어

```javascript
// middleware/tenantMiddleware.js
const tenantMiddleware = async (req, res, next) => {
  // 1. 테넌트 식별 (도메인, 헤더, 세션 등)
  const tenantCode = req.hostname.split('.')[0]  // 서브도메인 방식
    || req.headers['x-tenant-id']                // 헤더 방식
    || req.session?.tenantCode                   // 세션 방식
    || 'default';                                // 기본값

  // 2. 테넌트 정보 조회
  const [tenants] = await pool.execute(
    'SELECT * FROM tenants WHERE tenant_code = ? AND is_active = TRUE',
    [tenantCode]
  );

  if (tenants.length === 0) {
    return res.status(404).json({ error: '테넌트를 찾을 수 없습니다.' });
  }

  // 3. 요청에 테넌트 정보 추가
  req.tenant = tenants[0];
  req.tenantId = tenants[0].id;

  next();
};
```

---

## Phase 0: 데이터베이스 생성 (CRITICAL - 최우선)

> **중요**: 테이블 생성 전 반드시 데이터베이스가 존재해야 합니다.
> **DB 이름**: 현재 프로젝트 디렉토리 이름 사용 (예: `myproject` → DB명 `myproject`)

### Step 1: 프로젝트 이름 확인

```bash
# 현재 프로젝트 디렉토리명 확인
PROJECT_NAME=$(basename $(pwd) | tr '-' '_')
echo "DB Name: ${PROJECT_NAME}"
```

---

### Step 2: 로컬 데이터베이스 설치 (필수)

#### PostgreSQL 설치

```bash
# macOS (Homebrew)
brew install postgresql@16
brew services start postgresql@16

# Ubuntu/Debian
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Windows
# https://www.postgresql.org/download/windows/ 에서 다운로드
```

#### MySQL 설치

```bash
# macOS (Homebrew)
brew install mysql
brew services start mysql

# Ubuntu/Debian
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Windows
# https://dev.mysql.com/downloads/mysql/ 에서 다운로드
```

---

### Step 3: 데이터베이스 생성

#### PostgreSQL

```bash
PROJECT_NAME=$(basename $(pwd) | tr '-' '_')

# 데이터베이스 생성
psql -U postgres -c "CREATE DATABASE ${PROJECT_NAME} WITH ENCODING 'UTF8';"

# 사용자 생성 및 권한 부여 (선택)
psql -U postgres -c "CREATE USER app_user WITH PASSWORD 'your_password';"
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${PROJECT_NAME} TO app_user;"
```

#### MySQL / MariaDB

```bash
PROJECT_NAME=$(basename $(pwd) | tr '-' '_')

# 데이터베이스 생성
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS ${PROJECT_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 사용자 생성 및 권한 부여 (선택)
mysql -u root -p -e "CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'your_password';"
mysql -u root -p -e "GRANT ALL PRIVILEGES ON ${PROJECT_NAME}.* TO 'app_user'@'localhost';"
mysql -u root -p -e "FLUSH PRIVILEGES;"
```

---

### Step 4: Docker 사용 (선택사항)

> **참고**: 로컬 설치 대신 Docker 사용 시

```bash
# PostgreSQL
docker run -d \
  --name ${PROJECT_NAME}_db \
  -e POSTGRES_DB=${PROJECT_NAME} \
  -e POSTGRES_USER=app_user \
  -e POSTGRES_PASSWORD=your_password \
  -p 5432:5432 \
  postgres:16

# MySQL
docker run -d \
  --name ${PROJECT_NAME}_db \
  -e MYSQL_DATABASE=${PROJECT_NAME} \
  -e MYSQL_USER=app_user \
  -e MYSQL_PASSWORD=your_password \
  -e MYSQL_ROOT_PASSWORD=root_password \
  -p 3306:3306 \
  mysql:8
```

또는 docker-compose.yml:

```yaml
services:
  db:
    image: postgres:16
    environment:
      POSTGRES_DB: ${PROJECT_NAME}
      POSTGRES_USER: app_user
      POSTGRES_PASSWORD: your_password
    ports:
      - "5432:5432"
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

---

### Step 5: 환경변수 설정 (.env)

```bash
# PostgreSQL (로컬)
DATABASE_URL="postgresql://postgres:password@localhost:5432/${PROJECT_NAME}"

# PostgreSQL (Docker)
DATABASE_URL="postgresql://app_user:your_password@localhost:5432/${PROJECT_NAME}"

# MySQL (로컬)
DATABASE_URL="mysql://root:password@localhost:3306/${PROJECT_NAME}"

# SQLite (개발용 - DB 서버 불필요)
DATABASE_URL="file:./${PROJECT_NAME}.db"
```

---

### Step 6: ORM 마이그레이션

#### SQLAlchemy + Alembic

```bash
cd backend
alembic upgrade head
```

#### Prisma (Next.js)

```bash
npx prisma db push
# 또는
npx prisma migrate dev --name init
```

---

## Phase 1: 테이블 존재 확인 (CRITICAL)

> **중요**: 모든 에이전트는 실행 전 이 체크를 수행해야 합니다.

### 확인 쿼리

```sql
-- MySQL/MariaDB
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tenants', 'user_groups', 'user_group_members', 'roles', 'user_roles');

-- 결과가 5개 미만이면 초기화 필요
```

### Bash로 확인

```bash
# MySQL 테이블 존재 확인
mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} -e "
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tenants', 'user_groups', 'user_group_members', 'roles', 'user_roles');
" 2>/dev/null | wc -l

# 결과가 6 미만이면 (헤더 1줄 + 테이블 5개) 초기화 필요
```

### Node.js로 확인

```javascript
async function checkSharedTables(pool) {
  const requiredTables = ['tenants', 'user_groups', 'user_group_members', 'roles', 'user_roles'];

  const [rows] = await pool.execute(`
    SELECT TABLE_NAME
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME IN (${requiredTables.map(() => '?').join(',')})
  `, requiredTables);

  const existingTables = rows.map(r => r.TABLE_NAME);
  const missingTables = requiredTables.filter(t => !existingTables.includes(t));

  return {
    initialized: missingTables.length === 0,
    existingTables,
    missingTables
  };
}
```

---

## 데이터베이스 스키마

### tenants (테넌트/사이트)

> **가장 먼저 생성**해야 하는 테이블입니다. 다른 테이블들이 tenant_id를 참조합니다.

```sql
CREATE TABLE IF NOT EXISTS tenants (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 기본 정보
  tenant_code VARCHAR(50) NOT NULL UNIQUE,      -- 테넌트 코드 (서브도메인 등)
  tenant_name VARCHAR(100) NOT NULL,            -- 테넌트명 (사이트명)
  description VARCHAR(500),                     -- 설명

  -- 도메인 설정
  domain VARCHAR(255),                          -- 커스텀 도메인 (예: siteA.com)
  subdomain VARCHAR(100),                       -- 서브도메인 (예: siteA)

  -- 설정 (JSON)
  settings JSON,                                -- 테넌트별 설정
  -- {
  --   "theme": "default",
  --   "logo": "/uploads/logo.png",
  --   "language": "ko",
  --   "timezone": "Asia/Seoul"
  -- }

  -- 연락처
  admin_email VARCHAR(255),                     -- 관리자 이메일
  admin_name VARCHAR(100),                      -- 관리자 이름

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  INDEX idx_tenant_code (tenant_code),
  INDEX idx_domain (domain),
  INDEX idx_subdomain (subdomain)
);
```

### user_groups (사용자 그룹)

```sql
CREATE TABLE IF NOT EXISTS user_groups (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 테넌트 (멀티사이트)
  tenant_id BIGINT,                           -- NULL이면 전체 사이트 공통

  -- 기본 정보
  group_name VARCHAR(100) NOT NULL,           -- 그룹명
  group_code VARCHAR(50) NOT NULL,            -- 그룹 코드 (시스템 식별용)
  description VARCHAR(500),                   -- 설명

  -- 그룹 설정
  priority INT DEFAULT 0,                     -- 우선순위 (높을수록 상위)
  group_type ENUM('system', 'custom') DEFAULT 'custom',
  -- system: 시스템 기본 그룹 (수정 불가)
  -- custom: 관리자 생성 그룹

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  -- 테넌트별로 동일 group_code 허용
  UNIQUE KEY uk_tenant_group (tenant_id, group_code),
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
  INDEX idx_tenant (tenant_id),
  INDEX idx_group_code (group_code),
  INDEX idx_priority (priority)
);
```

### user_group_members (사용자-그룹 매핑)

```sql
CREATE TABLE IF NOT EXISTS user_group_members (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,               -- 사용자 ID
  group_id BIGINT NOT NULL,                   -- 그룹 ID

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),

  UNIQUE KEY uk_user_group (user_id, group_id),
  FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_group (group_id)
);
```

### roles (역할)

```sql
CREATE TABLE IF NOT EXISTS roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 기본 정보
  role_name VARCHAR(100) NOT NULL,            -- 역할명
  role_code VARCHAR(50) NOT NULL UNIQUE,      -- 역할 코드
  description VARCHAR(500),                   -- 설명

  -- 역할 설정
  priority INT DEFAULT 0,                     -- 우선순위
  role_scope ENUM('admin', 'user', 'both') DEFAULT 'both',
  -- admin: 관리자 전용
  -- user: 사용자 전용
  -- both: 모두 사용

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  INDEX idx_role_code (role_code),
  INDEX idx_priority (priority)
);
```

### user_roles (사용자-역할 매핑)

```sql
CREATE TABLE IF NOT EXISTS user_roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  role_id BIGINT NOT NULL,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),

  UNIQUE KEY uk_user_role (user_id, role_id),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_role (role_id)
);
```

---

## 기본 데이터 (Initial Data)

### 기본 그룹

```sql
INSERT INTO user_groups (group_name, group_code, priority, group_type, created_by) VALUES
('전체 회원', 'all_members', 0, 'system', 'system'),
('일반 회원', 'regular', 10, 'system', 'system'),
('VIP 회원', 'vip', 50, 'system', 'system'),
('프리미엄 회원', 'premium', 80, 'system', 'system')
ON DUPLICATE KEY UPDATE updated_at = NOW();
```

### 기본 역할

```sql
INSERT INTO roles (role_name, role_code, priority, role_scope, created_by) VALUES
('슈퍼관리자', 'super_admin', 100, 'admin', 'system'),
('관리자', 'admin', 50, 'admin', 'system'),
('매니저', 'manager', 30, 'admin', 'system'),
('에디터', 'editor', 20, 'both', 'system'),
('뷰어', 'viewer', 10, 'both', 'system')
ON DUPLICATE KEY UPDATE updated_at = NOW();
```

---

## 전체 스키마 파일 생성

### Action: 스키마 파일 생성

**파일 경로**: `db/schema/shared_schema.sql` 또는 프로젝트 구조에 맞게

```sql
-- ============================================
-- Shared Schema for Multi-Agent System
-- 공유 테이블: tenants, user_groups, roles 등
-- ============================================

-- 0. tenants (테넌트/사이트) - 가장 먼저 생성
CREATE TABLE IF NOT EXISTS tenants (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  tenant_code VARCHAR(50) NOT NULL UNIQUE,
  tenant_name VARCHAR(100) NOT NULL,
  description VARCHAR(500),
  domain VARCHAR(255),
  subdomain VARCHAR(100),
  settings JSON,
  admin_email VARCHAR(255),
  admin_name VARCHAR(100),
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,
  INDEX idx_tenant_code (tenant_code),
  INDEX idx_domain (domain),
  INDEX idx_subdomain (subdomain)
);

-- 1. user_groups (사용자 그룹)
CREATE TABLE IF NOT EXISTS user_groups (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  tenant_id BIGINT,
  group_name VARCHAR(100) NOT NULL,
  group_code VARCHAR(50) NOT NULL,
  description VARCHAR(500),
  priority INT DEFAULT 0,
  group_type ENUM('system', 'custom') DEFAULT 'custom',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,
  UNIQUE KEY uk_tenant_group (tenant_id, group_code),
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
  INDEX idx_tenant (tenant_id),
  INDEX idx_group_code (group_code),
  INDEX idx_priority (priority)
);

-- 2. user_group_members (사용자-그룹 매핑)
CREATE TABLE IF NOT EXISTS user_group_members (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  group_id BIGINT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  UNIQUE KEY uk_user_group (user_id, group_id),
  FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_group (group_id)
);

-- 3. roles (역할)
CREATE TABLE IF NOT EXISTS roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(100) NOT NULL,
  role_code VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(500),
  priority INT DEFAULT 0,
  role_scope ENUM('admin', 'user', 'both') DEFAULT 'both',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,
  INDEX idx_role_code (role_code),
  INDEX idx_priority (priority)
);

-- 4. user_roles (사용자-역할 매핑)
CREATE TABLE IF NOT EXISTS user_roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  role_id BIGINT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  UNIQUE KEY uk_user_role (user_id, role_id),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_role (role_id)
);

-- ============================================
-- 기본 데이터 삽입
-- ============================================

-- 기본 테넌트 (default)
INSERT INTO tenants (tenant_code, tenant_name, description, created_by) VALUES
('default', '기본 사이트', '기본 테넌트 (단일 사이트 운영 시 사용)', 'system')
ON DUPLICATE KEY UPDATE updated_at = NOW();

-- 기본 그룹 (default 테넌트용)
INSERT INTO user_groups (tenant_id, group_name, group_code, priority, group_type, created_by)
SELECT t.id, g.group_name, g.group_code, g.priority, g.group_type, 'system'
FROM tenants t
CROSS JOIN (
  SELECT '전체 회원' as group_name, 'all_members' as group_code, 0 as priority, 'system' as group_type
  UNION SELECT '일반 회원', 'regular', 10, 'system'
  UNION SELECT 'VIP 회원', 'vip', 50, 'system'
  UNION SELECT '프리미엄 회원', 'premium', 80, 'system'
) g
WHERE t.tenant_code = 'default'
ON DUPLICATE KEY UPDATE updated_at = NOW();

-- 기본 역할
INSERT INTO roles (role_name, role_code, priority, role_scope, created_by) VALUES
('슈퍼관리자', 'super_admin', 100, 'admin', 'system'),
('관리자', 'admin', 50, 'admin', 'system'),
('매니저', 'manager', 30, 'admin', 'system'),
('에디터', 'editor', 20, 'both', 'system'),
('뷰어', 'viewer', 10, 'both', 'system')
ON DUPLICATE KEY UPDATE updated_at = NOW();
```

---

## 다른 에이전트에서 사용하기

### 의존성 확인 코드 (다른 에이전트에 추가)

```javascript
// 다른 에이전트의 Phase 0에서 실행
async function ensureSharedSchemaInitialized(pool) {
  const check = await checkSharedTables(pool);

  if (!check.initialized) {
    console.log('⚠️ 공유 테이블이 초기화되지 않았습니다.');
    console.log(`   누락된 테이블: ${check.missingTables.join(', ')}`);
    console.log('');
    console.log('🔧 자동으로 공유 스키마를 초기화합니다...');

    // 공유 스키마 생성 실행
    await initializeSharedSchema(pool);

    console.log('✅ 공유 스키마 초기화 완료');
  }

  return true;
}
```

---

## 완료 메시지

```
✅ 공유 스키마 초기화 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

생성된 테이블:
  ✓ tenants: 테넌트 (멀티사이트)
  ✓ user_groups: 사용자 그룹
  ✓ user_group_members: 사용자-그룹 매핑
  ✓ roles: 역할
  ✓ user_roles: 사용자-역할 매핑

기본 데이터:
  ✓ 테넌트 1개: default (기본 사이트)
  ✓ 그룹 4개: 전체회원, 일반회원, VIP, 프리미엄
  ✓ 역할 5개: 슈퍼관리자, 관리자, 매니저, 에디터, 뷰어

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

이제 다음 에이전트를 사용할 수 있습니다:
  - Use board-generator --init
  - Use menu-manager --init
```
