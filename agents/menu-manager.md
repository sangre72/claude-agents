---
name: menu-manager
description: 통합 메뉴 관리 시스템 생성기. user/site/admin 타입 선택 가능. 트리 구조, 드래그앤드롭, 권한 설정, 유틸리티 메뉴 지원.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide, refactor
---

# 통합 메뉴 관리 시스템 생성기

**user / site / admin** 메뉴를 통합 관리하는 시스템을 Full Stack으로 생성하는 에이전트입니다.

> **핵심 기능**:
> 1. **메뉴 타입 선택**: user(사용자), site(사이트 전체), admin(관리자)
> 2. **트리 구조** 메뉴 관리 (무한 depth)
> 3. **드래그 앤 드롭**으로 메뉴 순서/위치 변경
> 4. **권한 설정** (그룹별, 사용자별, 역할별)
> 5. **유틸리티 메뉴** (헤더/푸터 고정 영역)
> 6. **다양한 연동 방식** (URL, 새창, 모달)

---

## 사용법

```bash
# 최초 설치 (테이블 생성 및 기본 컴포넌트)
Use menu-manager --init

# 타입별 메뉴 시스템 생성
Use menu-manager --type=user     # 사용자 메뉴 (회원 전용)
Use menu-manager --type=site     # 사이트 메뉴 (전체 공개)
Use menu-manager --type=admin    # 관리자 메뉴

# 유틸리티 메뉴 생성
Use menu-manager --utility=header   # 헤더 유틸리티 (로그인/로그아웃 등)
Use menu-manager --utility=footer   # 푸터 유틸리티 (관련사이트/사이트맵 등)

# 메뉴 추가
Use menu-manager to add menu "서비스소개" --type=site
Use menu-manager to add submenu "회사소개" under "서비스소개"
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

### Step 2: 메뉴 테이블 존재 확인

```sql
-- 메뉴 테이블 확인
SELECT TABLE_NAME
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('menus', 'menu_permissions', 'related_sites', 'menu_audit_logs');
```

**결과가 4개 미만이면:**
```
⚠️ 메뉴 테이블이 초기화되지 않았습니다.
🔧 자동으로 메뉴 스키마를 초기화합니다...
```

→ 메뉴 스키마 생성 실행 (이 문서의 스키마 섹션)

### Step 3: 기술 스택 분석

> **중요**: 코드 생성 전 반드시 프로젝트 기술 스택을 분석합니다.

### 분석 순서

```bash
# 1. Backend 기술 스택 확인
ls package.json          # Node.js/Express
ls requirements.txt      # Python (Flask/FastAPI/Django)
ls pom.xml              # Java (Spring)
ls go.mod               # Go

# 2. Frontend 기술 스택 확인
ls frontend/package.json
grep -E "react|vue|angular|next|nuxt" frontend/package.json

# 3. 데이터베이스 확인
grep -E "mysql|postgres|mongodb|sqlite" package.json requirements.txt 2>/dev/null
ls docker-compose.yml

# 4. 기존 인증 패턴 확인
ls -la **/auth/**/*.js **/middleware/**/*.js 2>/dev/null | head -5
grep -r "jwt\|session\|passport" --include="*.js" | head -5

# 5. 기존 API 패턴 확인
head -50 server.js 2>/dev/null || head -50 app/main.py 2>/dev/null
```

### 지원 기술 스택

| Backend | Frontend | Database |
|---------|----------|----------|
| Node.js/Express | React | MySQL |
| Python/FastAPI | React + MUI | PostgreSQL |
| Python/Flask | Vue.js | SQLite |
| Python/Django | Next.js | MongoDB |
| Java/Spring | Angular | - |

### 스택 감지 로직

```javascript
const detectStack = async () => {
  let stack = { backend: null, frontend: null, ui: null, database: null, auth: null };

  // Backend 감지
  if (await fileExists('package.json')) {
    const pkg = await readJson('package.json');
    if (pkg.dependencies?.express) stack.backend = 'express';
    if (pkg.dependencies?.['@nestjs/core']) stack.backend = 'nestjs';
  } else if (await fileExists('requirements.txt')) {
    const req = await readFile('requirements.txt');
    if (req.includes('fastapi')) stack.backend = 'fastapi';
    else if (req.includes('flask')) stack.backend = 'flask';
    else if (req.includes('django')) stack.backend = 'django';
  }

  // Frontend 감지
  if (await fileExists('frontend/package.json')) {
    const pkg = await readJson('frontend/package.json');
    if (pkg.dependencies?.react) stack.frontend = 'react';
    if (pkg.dependencies?.vue) stack.frontend = 'vue';
    if (pkg.dependencies?.['@mui/material']) stack.ui = 'mui';
    if (pkg.dependencies?.bootstrap) stack.ui = 'bootstrap';
  }

  // 인증 방식 감지
  if (await grepFile('jwt', '**/*.js')) stack.auth = 'jwt';
  else if (await grepFile('session', '**/*.js')) stack.auth = 'session';

  return stack;
};
```

---

## 메뉴 타입 정의

| 타입 | 설명 | 대상 | 예시 |
|------|------|------|------|
| `site` | 사이트 전체 메뉴 | 모든 방문자 | GNB, 메인 네비게이션 |
| `user` | 사용자 전용 메뉴 | 로그인 회원 | 마이페이지, 주문내역 |
| `admin` | 관리자 메뉴 | 관리자 | 사용자관리, 시스템설정 |

### 유틸리티 메뉴 (고정 영역)

| 영역 | 위치 | 예시 메뉴 |
|------|------|---------|
| `header_utility` | 헤더 상단/우측 | 로그인, 로그아웃, 회원가입, 마이페이지, 장바구니 |
| `footer_utility` | 푸터 | 관련사이트, 사이트맵, 개인정보처리방침, 이용약관 |
| `quick_menu` | 플로팅/사이드 | 최근본상품, 장바구니, TOP |

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         menus 테이블                             │
│  (통합 메뉴: menu_type으로 구분)                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  [site] 사이트 메뉴                                              │
│  ├─ 📁 회사소개                                                  │
│  │   ├─ 📄 CEO 인사말                                            │
│  │   └─ 📄 오시는 길                                             │
│  ├─ 📁 서비스                                                    │
│  └─ 📁 고객센터                                                  │
│                                                                  │
│  [user] 사용자 메뉴                                              │
│  ├─ 📁 마이페이지                                                │
│  │   ├─ 📄 회원정보                                              │
│  │   └─ 📄 주문내역                                              │
│  └─ 📁 찜목록                                                    │
│                                                                  │
│  [admin] 관리자 메뉴                                             │
│  ├─ 📁 대시보드                                                  │
│  ├─ 📁 사용자관리                                                │
│  └─ 📁 시스템설정                                                │
│                                                                  │
│  [header_utility] 헤더 유틸리티                                   │
│  ├─ 📄 로그인 (비로그인 시)                                       │
│  ├─ 📄 로그아웃 (로그인 시)                                       │
│  ├─ 📄 회원가입                                                  │
│  └─ 📄 마이페이지                                                │
│                                                                  │
│  [footer_utility] 푸터 유틸리티                                   │
│  ├─ 📄 이용약관                                                  │
│  ├─ 📄 개인정보처리방침                                          │
│  ├─ 📄 사이트맵                                                  │
│  └─ 📁 관련사이트                                                │
│      ├─ 📄 네이버                                                │
│      └─ 📄 구글                                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ menu_permissions │  │   user_groups   │  │     roles       │
│  (메뉴-권한)      │  │  (사용자 그룹)   │  │   (역할)        │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

---

## 데이터베이스 스키마

### menus (통합 메뉴 테이블)

```sql
CREATE TABLE menus (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 메뉴 타입
  menu_type ENUM('site', 'user', 'admin', 'header_utility', 'footer_utility', 'quick_menu') NOT NULL,

  -- 트리 구조
  parent_id BIGINT NULL,                      -- 부모 메뉴 ID (NULL이면 최상위)
  depth INT DEFAULT 0,                        -- 메뉴 깊이 (0부터 시작)
  sort_order INT DEFAULT 0,                   -- 정렬 순서
  path VARCHAR(500) DEFAULT '',               -- 조상 경로 (예: "1/3/5")

  -- 기본 정보
  menu_name VARCHAR(100) NOT NULL,            -- 메뉴 이름 (표시용)
  menu_code VARCHAR(50) NOT NULL,             -- 메뉴 코드 (타입 내 고유)
  description VARCHAR(500),                   -- 메뉴 설명
  icon VARCHAR(100),                          -- 아이콘 클래스

  -- 가상 경로 설정
  virtual_path VARCHAR(200),                  -- 가상 경로명 (SEO)

  -- 연동 설정
  link_type ENUM('url', 'new_window', 'modal', 'external', 'none') DEFAULT 'url',
  link_url VARCHAR(1000),                     -- URL 또는 라우트
  external_url VARCHAR(1000),                 -- 외부 URL (link_type='external')
  modal_component VARCHAR(200),               -- 모달 컴포넌트명
  modal_width INT DEFAULT 800,
  modal_height INT DEFAULT 600,

  -- 권한 설정
  permission_type ENUM('public', 'member', 'groups', 'users', 'roles', 'admin') DEFAULT 'public',
  -- public: 모든 방문자
  -- member: 로그인 회원
  -- groups: 특정 그룹
  -- users: 특정 사용자
  -- roles: 특정 역할
  -- admin: 관리자만

  -- 표시 조건 (유틸리티 메뉴용)
  show_condition ENUM('always', 'logged_in', 'logged_out', 'custom') DEFAULT 'always',
  condition_expression VARCHAR(500),          -- custom 조건식

  -- 상태 설정
  is_visible BOOLEAN DEFAULT TRUE,
  is_enabled BOOLEAN DEFAULT TRUE,
  is_expandable BOOLEAN DEFAULT TRUE,
  default_expanded BOOLEAN DEFAULT FALSE,

  -- 스타일 설정
  css_class VARCHAR(200),
  highlight BOOLEAN DEFAULT FALSE,
  highlight_text VARCHAR(50),
  highlight_color VARCHAR(20),

  -- 배지 설정
  badge_type ENUM('none', 'count', 'dot', 'text', 'api') DEFAULT 'none',
  badge_value VARCHAR(200),
  badge_color VARCHAR(20) DEFAULT 'primary',

  -- SEO
  seo_title VARCHAR(200),
  seo_description VARCHAR(500),

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (parent_id) REFERENCES menus(id) ON DELETE SET NULL,
  UNIQUE KEY uk_type_code (menu_type, menu_code),
  INDEX idx_type_parent (menu_type, parent_id, sort_order),
  INDEX idx_path (path),
  INDEX idx_virtual_path (virtual_path)
);
```

### user_groups, user_group_members, roles, user_roles (공유 테이블)

> **참고**: 다음 테이블들은 `shared-schema.md`에서 정의됩니다:
> - `user_groups`: 사용자 그룹
> - `user_group_members`: 사용자-그룹 매핑
> - `roles`: 역할
> - `user_roles`: 사용자-역할 매핑
>
> 메뉴 관리 시스템은 해당 테이블을 참조만 합니다.
> 초기화 시 `shared-schema`가 먼저 실행되어야 합니다.

### menu_permissions (메뉴 권한 매핑)

```sql
CREATE TABLE menu_permissions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  menu_id BIGINT NOT NULL,

  -- 권한 대상 (하나만 값을 가짐)
  group_id BIGINT NULL,                       -- 그룹 ID
  user_id VARCHAR(50) NULL,                   -- 사용자 ID
  role_id BIGINT NULL,                        -- 역할 ID

  -- 권한 레벨
  permission_level ENUM('view', 'edit', 'delete', 'all') DEFAULT 'view',

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE,
  FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE,
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  INDEX idx_menu (menu_id),
  INDEX idx_group (group_id),
  INDEX idx_user (user_id),
  INDEX idx_role (role_id)
);
```

### related_sites (관련 사이트 - 푸터용)

```sql
CREATE TABLE related_sites (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  menu_id BIGINT NOT NULL,                    -- 부모 메뉴 ID

  site_name VARCHAR(100) NOT NULL,
  site_url VARCHAR(500) NOT NULL,
  site_icon VARCHAR(200),                     -- 파비콘/로고 URL
  sort_order INT DEFAULT 0,
  is_new_window BOOLEAN DEFAULT TRUE,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE
);
```

---

## API 엔드포인트

### 메뉴 조회 API (Public)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/menus?type=site` | 사이트 메뉴 트리 |
| GET | `/api/menus?type=user` | 사용자 메뉴 트리 |
| GET | `/api/menus?type=admin` | 관리자 메뉴 트리 |
| GET | `/api/menus/utility/header` | 헤더 유틸리티 |
| GET | `/api/menus/utility/footer` | 푸터 유틸리티 |
| GET | `/api/menus/sitemap` | 사이트맵 |

### 메뉴 관리 API (Admin)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/admin/menus` | 전체 메뉴 조회 |
| GET | `/api/admin/menus/:id` | 메뉴 상세 |
| POST | `/api/admin/menus` | 메뉴 생성 |
| PUT | `/api/admin/menus/:id` | 메뉴 수정 |
| DELETE | `/api/admin/menus/:id` | 메뉴 삭제 |
| PUT | `/api/admin/menus/reorder` | 순서 변경 |
| PUT | `/api/admin/menus/:id/move` | 메뉴 이동 |

### 그룹 관리 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/admin/groups` | 그룹 목록 |
| POST | `/api/admin/groups` | 그룹 생성 |
| PUT | `/api/admin/groups/:id` | 그룹 수정 |
| DELETE | `/api/admin/groups/:id` | 그룹 삭제 |
| GET | `/api/admin/groups/:id/members` | 그룹 멤버 조회 |
| POST | `/api/admin/groups/:id/members` | 멤버 추가 |
| DELETE | `/api/admin/groups/:id/members/:userId` | 멤버 제거 |

### 역할 관리 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/admin/roles` | 역할 목록 |
| POST | `/api/admin/roles` | 역할 생성 |
| PUT | `/api/admin/roles/:id` | 역할 수정 |
| DELETE | `/api/admin/roles/:id` | 역할 삭제 |

### 권한 관리 API

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/admin/menus/:id/permissions` | 메뉴 권한 조회 |
| POST | `/api/admin/menus/:id/permissions` | 권한 추가 |
| DELETE | `/api/admin/menus/:id/permissions/:permId` | 권한 삭제 |
| POST | `/api/admin/menus/:id/permissions/bulk` | 권한 일괄 설정 |

---

## 핵심 기능 구현

### 1. 타입별 메뉴 트리 조회

```javascript
// 메뉴 타입별 조회 (권한 필터링 포함)
async function getMenuTree(menuType, user = null) {
  // 1. 해당 타입의 활성 메뉴 조회
  const [menus] = await pool.execute(
    `SELECT * FROM menus
     WHERE menu_type = ?
       AND is_active = TRUE
       AND is_deleted = FALSE
     ORDER BY parent_id, sort_order`,
    [menuType]
  );

  // 2. 권한 필터링
  const accessibleMenus = await filterByPermission(menus, user);

  // 3. 표시 조건 필터링 (유틸리티 메뉴)
  const visibleMenus = filterByShowCondition(accessibleMenus, user);

  // 4. 트리 빌드
  return buildMenuTree(visibleMenus);
}

// 권한 필터링
async function filterByPermission(menus, user) {
  if (!user) {
    // 비로그인: public만
    return menus.filter(m => m.permission_type === 'public');
  }

  // 사용자의 그룹/역할 조회
  const userGroups = await getUserGroups(user.id);
  const userRoles = await getUserRoles(user.id);

  return menus.filter(menu => {
    switch (menu.permission_type) {
      case 'public':
        return true;
      case 'member':
        return true; // 로그인 상태
      case 'admin':
        return userRoles.some(r => ['super_admin', 'admin'].includes(r.role_code));
      case 'groups':
      case 'users':
      case 'roles':
        return hasMenuPermission(menu.id, user.id, userGroups, userRoles);
      default:
        return false;
    }
  });
}

// 표시 조건 필터링
function filterByShowCondition(menus, user) {
  return menus.filter(menu => {
    switch (menu.show_condition) {
      case 'always':
        return true;
      case 'logged_in':
        return user !== null;
      case 'logged_out':
        return user === null;
      case 'custom':
        return evaluateCondition(menu.condition_expression, { user });
      default:
        return true;
    }
  });
}
```

### 2. 유틸리티 메뉴 조회

```javascript
// 헤더 유틸리티 메뉴
async function getHeaderUtility(user) {
  return getMenuTree('header_utility', user);
}

// 푸터 유틸리티 메뉴 + 관련 사이트
async function getFooterUtility() {
  const menus = await getMenuTree('footer_utility');

  // 관련 사이트 메뉴 찾기
  const relatedSitesMenu = findMenuByCode(menus, 'related_sites');
  if (relatedSitesMenu) {
    const [sites] = await pool.execute(
      `SELECT * FROM related_sites
       WHERE menu_id = ? AND is_active = TRUE AND is_deleted = FALSE
       ORDER BY sort_order`,
      [relatedSitesMenu.id]
    );
    relatedSitesMenu.children = sites;
  }

  return menus;
}
```

### 3. 그룹/사용자 권한 체크

```javascript
// 메뉴 접근 권한 체크
async function hasMenuPermission(menuId, userId, userGroups, userRoles) {
  const groupIds = userGroups.map(g => g.id);
  const roleIds = userRoles.map(r => r.id);

  const [permissions] = await pool.execute(
    `SELECT * FROM menu_permissions
     WHERE menu_id = ?
       AND is_deleted = FALSE
       AND (
         user_id = ?
         OR group_id IN (${groupIds.map(() => '?').join(',') || 'NULL'})
         OR role_id IN (${roleIds.map(() => '?').join(',') || 'NULL'})
       )`,
    [menuId, userId, ...groupIds, ...roleIds]
  );

  return permissions.length > 0;
}

// 사용자의 그룹 조회
async function getUserGroups(userId) {
  const [groups] = await pool.execute(
    `SELECT g.* FROM user_groups g
     INNER JOIN user_group_members m ON g.id = m.group_id
     WHERE m.user_id = ? AND g.is_active = TRUE AND g.is_deleted = FALSE`,
    [userId]
  );
  return groups;
}

// 사용자의 역할 조회
async function getUserRoles(userId) {
  const [roles] = await pool.execute(
    `SELECT r.* FROM roles r
     INNER JOIN user_roles ur ON r.id = ur.role_id
     WHERE ur.user_id = ? AND r.is_active = TRUE AND r.is_deleted = FALSE`,
    [userId]
  );
  return roles;
}
```

### 4. 드래그앤드롭 순서 변경

```javascript
// 순서 변경 API
async function reorderMenus(req, res) {
  const { orderedIds, parentId } = req.body;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    for (let i = 0; i < orderedIds.length; i++) {
      await connection.execute(
        `UPDATE menus SET sort_order = ?, updated_by = ?, updated_at = NOW()
         WHERE id = ?`,
        [i, req.user.id, orderedIds[i]]
      );
    }

    await connection.commit();
    res.json({ success: true });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
```

---

## 인증/보안/오류 처리 (CRITICAL)

> **중요**: 모든 API에 반드시 적용해야 하는 보안 규칙입니다.

### 1. 인증 미들웨어

```javascript
// middleware/authMiddleware.js
const jwt = require('jsonwebtoken');

// JWT 인증 미들웨어
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

  if (!token) {
    return res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: '인증 토큰이 필요합니다.' }
    });
  }

  jwt.verify(token, process.env.JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: '유효하지 않은 토큰입니다.' }
      });
    }
    req.user = user;
    next();
  });
};

// 관리자 권한 검증
const requireAdmin = async (req, res, next) => {
  if (!req.user) {
    return res.status(401).json({
      success: false,
      error: { code: 'UNAUTHORIZED', message: '로그인이 필요합니다.' }
    });
  }

  const userRoles = await getUserRoles(req.user.id);
  const isAdmin = userRoles.some(r => ['super_admin', 'admin', 'manager'].includes(r.role_code));

  if (!isAdmin) {
    return res.status(403).json({
      success: false,
      error: { code: 'FORBIDDEN', message: '관리자 권한이 필요합니다.' }
    });
  }

  req.userRoles = userRoles;
  next();
};

// 특정 권한 검증
const requirePermission = (requiredLevel) => {
  return async (req, res, next) => {
    const menuId = req.params.id;
    const hasPermission = await checkMenuPermission(menuId, req.user.id, requiredLevel);

    if (!hasPermission) {
      return res.status(403).json({
        success: false,
        error: { code: 'FORBIDDEN', message: '해당 메뉴에 대한 권한이 없습니다.' }
      });
    }
    next();
  };
};

module.exports = { authenticateToken, requireAdmin, requirePermission };
```

### 2. 입력 검증 (Validation)

```javascript
// validators/menuValidator.js
const { body, param, query, validationResult } = require('express-validator');

// 검증 결과 처리
const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: '입력값이 올바르지 않습니다.',
        details: errors.array()
      }
    });
  }
  next();
};

// 메뉴 생성 검증
const validateCreateMenu = [
  body('menu_type')
    .isIn(['site', 'user', 'admin', 'header_utility', 'footer_utility', 'quick_menu'])
    .withMessage('유효한 메뉴 타입이 아닙니다.'),
  body('menu_name')
    .trim()
    .isLength({ min: 1, max: 100 })
    .withMessage('메뉴명은 1-100자 사이여야 합니다.')
    .escape(), // XSS 방지
  body('menu_code')
    .trim()
    .matches(/^[a-z0-9_]+$/)
    .withMessage('메뉴 코드는 영문 소문자, 숫자, 언더스코어만 허용됩니다.')
    .isLength({ min: 1, max: 50 }),
  body('link_url')
    .optional()
    .custom((value) => {
      // URL 또는 상대 경로만 허용
      if (value && !value.match(/^(\/|https?:\/\/)/)) {
        throw new Error('유효한 URL 형식이 아닙니다.');
      }
      return true;
    }),
  body('parent_id')
    .optional()
    .isInt({ min: 1 })
    .withMessage('부모 메뉴 ID는 양의 정수여야 합니다.'),
  validate
];

// 메뉴 순서 변경 검증
const validateReorder = [
  body('orderedIds')
    .isArray({ min: 1 })
    .withMessage('순서 배열이 필요합니다.'),
  body('orderedIds.*')
    .isInt({ min: 1 })
    .withMessage('메뉴 ID는 양의 정수여야 합니다.'),
  body('parentId')
    .optional({ nullable: true })
    .isInt({ min: 1 }),
  validate
];

// ID 파라미터 검증
const validateMenuId = [
  param('id')
    .isInt({ min: 1 })
    .withMessage('유효한 메뉴 ID가 필요합니다.'),
  validate
];

module.exports = { validateCreateMenu, validateReorder, validateMenuId };
```

### 3. 보안 설정

```javascript
// security/securityMiddleware.js
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const xss = require('xss-clean');

// Helmet 설정 (HTTP 헤더 보안)
const helmetConfig = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "'unsafe-inline'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
  xssFilter: true,
  noSniff: true,
  referrerPolicy: { policy: 'strict-origin-when-cross-origin' }
});

// Rate Limiting (API 호출 제한)
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100, // 최대 100회
  message: {
    success: false,
    error: { code: 'TOO_MANY_REQUESTS', message: '너무 많은 요청입니다. 잠시 후 다시 시도하세요.' }
  }
});

// 관리자 API Rate Limiting (더 엄격)
const adminLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 50,
  message: {
    success: false,
    error: { code: 'TOO_MANY_REQUESTS', message: '너무 많은 요청입니다.' }
  }
});

// SQL Injection 방지 (Parameterized Query 사용 강제)
// 아래처럼 절대 문자열 연결 금지!
// ❌ BAD: `SELECT * FROM menus WHERE id = ${id}`
// ✅ GOOD: `SELECT * FROM menus WHERE id = ?`, [id]

module.exports = { helmetConfig, apiLimiter, adminLimiter, xss };
```

### 4. 표준 에러 처리

```javascript
// errors/AppError.js
class AppError extends Error {
  constructor(code, message, statusCode = 500, details = null) {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    this.isOperational = true;

    Error.captureStackTrace(this, this.constructor);
  }
}

// 에러 코드 정의
const ErrorCodes = {
  // 인증/권한
  UNAUTHORIZED: { status: 401, message: '인증이 필요합니다.' },
  FORBIDDEN: { status: 403, message: '권한이 없습니다.' },
  TOKEN_EXPIRED: { status: 401, message: '토큰이 만료되었습니다.' },

  // 리소스
  NOT_FOUND: { status: 404, message: '리소스를 찾을 수 없습니다.' },
  ALREADY_EXISTS: { status: 409, message: '이미 존재합니다.' },
  CONFLICT: { status: 409, message: '충돌이 발생했습니다.' },

  // 입력
  VALIDATION_ERROR: { status: 400, message: '입력값이 올바르지 않습니다.' },
  INVALID_REQUEST: { status: 400, message: '잘못된 요청입니다.' },

  // 메뉴 관련
  CIRCULAR_REFERENCE: { status: 400, message: '순환 참조가 발생합니다.' },
  MENU_HAS_CHILDREN: { status: 400, message: '하위 메뉴가 있어 삭제할 수 없습니다.' },
  DUPLICATE_MENU_CODE: { status: 409, message: '이미 사용 중인 메뉴 코드입니다.' },

  // 서버
  INTERNAL_ERROR: { status: 500, message: '서버 오류가 발생했습니다.' },
  DATABASE_ERROR: { status: 500, message: '데이터베이스 오류가 발생했습니다.' }
};

module.exports = { AppError, ErrorCodes };
```

### 5. 글로벌 에러 핸들러

```javascript
// middleware/errorHandler.js
const { AppError } = require('../errors/AppError');

const errorHandler = (err, req, res, next) => {
  // 로깅
  console.error(`[${new Date().toISOString()}] ${err.code || 'ERROR'}: ${err.message}`);
  console.error(err.stack);

  // 운영 에러 (예측 가능)
  if (err.isOperational) {
    return res.status(err.statusCode).json({
      success: false,
      error: {
        code: err.code,
        message: err.message,
        details: err.details
      }
    });
  }

  // 프로그래밍 에러 (예측 불가)
  // 프로덕션에서는 상세 정보 숨김
  const isProduction = process.env.NODE_ENV === 'production';
  return res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_ERROR',
      message: isProduction ? '서버 오류가 발생했습니다.' : err.message,
      stack: isProduction ? undefined : err.stack
    }
  });
};

// 비동기 핸들러 래퍼
const asyncHandler = (fn) => {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
};

module.exports = { errorHandler, asyncHandler };
```

### 6. API 응답 표준

```javascript
// utils/response.js

// 성공 응답
const successResponse = (res, data, message = '성공', statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
    timestamp: new Date().toISOString()
  });
};

// 목록 응답 (페이지네이션)
const listResponse = (res, data, pagination) => {
  return res.status(200).json({
    success: true,
    data,
    pagination: {
      page: pagination.page,
      limit: pagination.limit,
      total: pagination.total,
      totalPages: Math.ceil(pagination.total / pagination.limit)
    },
    timestamp: new Date().toISOString()
  });
};

// 생성 응답
const createdResponse = (res, data, message = '생성되었습니다.') => {
  return successResponse(res, data, message, 201);
};

// 삭제 응답
const deletedResponse = (res, message = '삭제되었습니다.') => {
  return res.status(200).json({
    success: true,
    message,
    timestamp: new Date().toISOString()
  });
};

module.exports = { successResponse, listResponse, createdResponse, deletedResponse };
```

### 7. 메뉴 캐싱

```javascript
// cache/menuCache.js
const Redis = require('ioredis');

const redis = new Redis(process.env.REDIS_URL);
const CACHE_TTL = 60 * 5; // 5분

// 캐시 키 생성
const getCacheKey = (menuType, userId = 'anonymous') => {
  return `menu:${menuType}:${userId}`;
};

// 메뉴 캐시 조회
const getCachedMenu = async (menuType, userId) => {
  const key = getCacheKey(menuType, userId);
  const cached = await redis.get(key);
  return cached ? JSON.parse(cached) : null;
};

// 메뉴 캐시 저장
const setCachedMenu = async (menuType, userId, data) => {
  const key = getCacheKey(menuType, userId);
  await redis.setex(key, CACHE_TTL, JSON.stringify(data));
};

// 메뉴 캐시 삭제 (메뉴 변경 시)
const invalidateMenuCache = async (menuType = null) => {
  if (menuType) {
    // 특정 타입만 삭제
    const keys = await redis.keys(`menu:${menuType}:*`);
    if (keys.length > 0) await redis.del(...keys);
  } else {
    // 전체 메뉴 캐시 삭제
    const keys = await redis.keys('menu:*');
    if (keys.length > 0) await redis.del(...keys);
  }
};

// 캐시된 메뉴 조회 (with fallback)
const getMenuTreeWithCache = async (menuType, user) => {
  const userId = user?.id || 'anonymous';

  // 캐시 확인
  const cached = await getCachedMenu(menuType, userId);
  if (cached) return cached;

  // DB에서 조회
  const menus = await getMenuTree(menuType, user);

  // 캐시 저장
  await setCachedMenu(menuType, userId, menus);

  return menus;
};

module.exports = { getCachedMenu, setCachedMenu, invalidateMenuCache, getMenuTreeWithCache };
```

### 8. 감사 로그

```javascript
// logs/auditLog.js

// 메뉴 변경 이력 테이블
/*
CREATE TABLE menu_audit_logs (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  menu_id BIGINT NOT NULL,
  action ENUM('create', 'update', 'delete', 'reorder', 'move') NOT NULL,
  before_data JSON,
  after_data JSON,
  changed_by VARCHAR(100) NOT NULL,
  changed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  ip_address VARCHAR(50),
  user_agent VARCHAR(500),
  INDEX idx_menu (menu_id),
  INDEX idx_action (action),
  INDEX idx_changed_at (changed_at)
);
*/

const logMenuChange = async (menuId, action, beforeData, afterData, req) => {
  await pool.execute(
    `INSERT INTO menu_audit_logs
     (menu_id, action, before_data, after_data, changed_by, ip_address, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      menuId,
      action,
      beforeData ? JSON.stringify(beforeData) : null,
      afterData ? JSON.stringify(afterData) : null,
      req.user?.id || 'system',
      req.ip || req.connection?.remoteAddress,
      req.headers['user-agent']?.substring(0, 500)
    ]
  );
};

module.exports = { logMenuChange };
```

### 9. 라우트 적용 예시

```javascript
// routes/menuRoutes.js
const express = require('express');
const router = express.Router();

const { authenticateToken, requireAdmin } = require('../middleware/authMiddleware');
const { validateCreateMenu, validateMenuId, validateReorder } = require('../validators/menuValidator');
const { adminLimiter } = require('../security/securityMiddleware');
const { asyncHandler } = require('../middleware/errorHandler');
const menuController = require('../controllers/menuController');

// 공개 API (인증 불필요)
router.get('/menus', asyncHandler(menuController.getMenuTree));
router.get('/menus/utility/header', asyncHandler(menuController.getHeaderUtility));
router.get('/menus/utility/footer', asyncHandler(menuController.getFooterUtility));

// 관리자 API (인증 + 권한 필요)
router.use('/admin/menus', authenticateToken, requireAdmin, adminLimiter);

router.get('/admin/menus', asyncHandler(menuController.getAllMenus));
router.get('/admin/menus/:id', validateMenuId, asyncHandler(menuController.getMenuById));
router.post('/admin/menus', validateCreateMenu, asyncHandler(menuController.createMenu));
router.put('/admin/menus/:id', validateMenuId, validateCreateMenu, asyncHandler(menuController.updateMenu));
router.delete('/admin/menus/:id', validateMenuId, asyncHandler(menuController.deleteMenu));
router.put('/admin/menus/reorder', validateReorder, asyncHandler(menuController.reorderMenus));

module.exports = router;
```

---

## Frontend 컴포넌트

### 생성할 파일들

| 파일 | 설명 |
|------|------|
| `types/menu.ts` | 타입 정의 |
| `lib/menuApi.ts` | API 클라이언트 |
| `components/menu/SiteNavigation.tsx` | 사이트 GNB |
| `components/menu/UserNavigation.tsx` | 사용자 메뉴 |
| `components/menu/AdminSidebar.tsx` | 관리자 사이드바 |
| `components/menu/HeaderUtility.tsx` | 헤더 유틸리티 |
| `components/menu/FooterUtility.tsx` | 푸터 유틸리티 |
| `components/menu/RelatedSites.tsx` | 관련 사이트 드롭다운 |
| `components/menu/Sitemap.tsx` | 사이트맵 페이지 |
| `components/admin/menu/MenuManager.tsx` | 메뉴 관리 페이지 |
| `components/admin/menu/MenuTree.tsx` | 메뉴 트리 (DnD) |
| `components/admin/menu/MenuForm.tsx` | 메뉴 폼 |
| `components/admin/group/GroupManager.tsx` | 그룹 관리 |
| `components/admin/role/RoleManager.tsx` | 역할 관리 |

### TypeScript 타입 정의

```typescript
// types/menu.ts

export type MenuType = 'site' | 'user' | 'admin' | 'header_utility' | 'footer_utility' | 'quick_menu';
export type LinkType = 'url' | 'new_window' | 'modal' | 'external' | 'none';
export type PermissionType = 'public' | 'member' | 'groups' | 'users' | 'roles' | 'admin';
export type ShowCondition = 'always' | 'logged_in' | 'logged_out' | 'custom';
export type BadgeType = 'none' | 'count' | 'dot' | 'text' | 'api';

export interface Menu {
  id: number;
  menu_type: MenuType;
  parent_id: number | null;
  depth: number;
  sort_order: number;
  path: string;

  menu_name: string;
  menu_code: string;
  description?: string;
  icon?: string;
  virtual_path?: string;

  link_type: LinkType;
  link_url?: string;
  external_url?: string;
  modal_component?: string;

  permission_type: PermissionType;
  show_condition: ShowCondition;

  is_visible: boolean;
  is_enabled: boolean;

  highlight: boolean;
  highlight_text?: string;

  badge_type: BadgeType;
  badge_value?: string;

  children?: Menu[];
}

export interface UserGroup {
  id: number;
  group_name: string;
  group_code: string;
  description?: string;
  priority: number;
  group_type: 'system' | 'custom';
}

export interface Role {
  id: number;
  role_name: string;
  role_code: string;
  description?: string;
  priority: number;
  role_scope: 'admin' | 'user' | 'both';
}

export interface MenuPermission {
  id: number;
  menu_id: number;
  group_id?: number;
  user_id?: string;
  role_id?: number;
  permission_level: 'view' | 'edit' | 'delete' | 'all';
  // 조인 데이터
  group_name?: string;
  user_name?: string;
  role_name?: string;
}

export interface RelatedSite {
  id: number;
  menu_id: number;
  site_name: string;
  site_url: string;
  site_icon?: string;
  is_new_window: boolean;
}
```

### 헤더 유틸리티 컴포넌트

```tsx
// components/menu/HeaderUtility.tsx
import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { useAuth } from '@/hooks/useAuth';
import { menuApi } from '@/lib/menuApi';

export default function HeaderUtility() {
  const { user, logout } = useAuth();

  const { data: menus = [] } = useQuery({
    queryKey: ['headerUtility', user?.id],
    queryFn: () => menuApi.getHeaderUtility()
  });

  const handleClick = (menu) => {
    if (menu.menu_code === 'logout') {
      logout();
      return;
    }

    if (menu.link_type === 'new_window' || menu.link_type === 'external') {
      window.open(menu.external_url || menu.link_url, '_blank');
    } else {
      window.location.href = menu.link_url;
    }
  };

  return (
    <ul className="header-utility">
      {menus.map(menu => (
        <li key={menu.id}>
          <button onClick={() => handleClick(menu)}>
            {menu.icon && <i className={menu.icon} />}
            {menu.menu_name}
            {menu.highlight && (
              <span className="badge" style={{ backgroundColor: menu.highlight_color }}>
                {menu.highlight_text}
              </span>
            )}
          </button>
        </li>
      ))}
    </ul>
  );
}
```

---

## 한국형 Admin UI 패턴 (CRITICAL - 반드시 적용)

> **CRITICAL**: 메뉴 관리 화면 생성 시 **반드시** 아래 패턴을 적용해야 합니다.
> 모달 방식은 **절대 사용 금지**입니다.

### UI 디자인 요구사항

#### 1. Windows Explorer 스타일 트리 (MUST)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  🏠 메뉴 관리                                              [+ 새 메뉴]  │
├──────────────────────┬──────────────────────────────────────────────────┤
│                      │                                                   │
│  📂 사이트 메뉴       │   📝 메뉴 상세 정보                               │
│   ├─ 📁 회사소개     │   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━   │
│   │   ├─ 📄 CEO인사말│                                                   │
│   │   ├─ 📄 회사연혁 │   기본 정보                                       │
│   │   └─ 📄 오시는길 │   ┌─────────────────────────────────────────────┐ │
│   ├─ 📁 서비스  ←────┼───│ 메뉴명 *     [회사소개                    ] │ │
│   │   ├─ 📄 소개    │   │ 메뉴코드 *   [about                        ] │ │
│   │   └─ 📄 요금    │   │ 상위메뉴     [없음 (최상위)            ▼ ] │ │
│   └─ 📁 고객센터     │   │ 아이콘       [mdi-domain               ▼ ] │ │
│       ├─ 📄 FAQ     │   └─────────────────────────────────────────────┘ │
│       └─ 📄 문의    │                                                   │
│                      │   링크 설정                                       │
│  📂 사용자 메뉴       │   ┌─────────────────────────────────────────────┐ │
│   ├─ 📄 마이페이지   │   │ 링크 타입    ◉ URL ○ 새창 ○ 모달 ○ 없음    │ │
│   └─ 📄 주문내역     │   │ URL          [/about                      ] │ │
│                      │   │ 가상경로     [company                     ] │ │
│  📂 관리자 메뉴       │   └─────────────────────────────────────────────┘ │
│   ├─ 📄 대시보드     │                                                   │
│   └─ 📁 회원관리     │   권한 설정                                       │
│       ├─ 📄 회원목록 │   ┌─────────────────────────────────────────────┐ │
│       └─ 📄 그룹관리 │   │ 접근권한     ◉ 전체공개 ○ 회원만 ○ 관리자   │ │
│                      │   │ 표시조건     ◉ 항상 ○ 로그인시 ○ 로그아웃시  │ │
│ ─────────────────────│   └─────────────────────────────────────────────┘ │
│ [+ 사이트메뉴]       │                                                   │
│ [+ 사용자메뉴]       │   ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│ [+ 관리자메뉴]       │   │   저장    │ │   삭제    │ │   취소    │         │
│                      │   └──────────┘ └──────────┘ └──────────┘         │
└──────────────────────┴──────────────────────────────────────────────────┘
```

#### 2. 트리 동작 (Windows Explorer 수준)

| 기능 | 동작 | 구현 |
|------|------|------|
| **폴더 아이콘** | 하위 메뉴 있으면 📁, 없으면 📄 | `hasChildren ? FolderIcon : FileIcon` |
| **펼침/접힘** | 📁 클릭 시 하위 표시/숨김 | `TreeView` expanded 상태 관리 |
| **선택** | 항목 클릭 → 우측에 상세 폼 표시 | `onSelect` → `setSelectedMenu` |
| **드래그앤드롭** | 항목 드래그로 순서/위치 변경 | `@minoru/react-dnd-treeview` |
| **우클릭 메뉴** | 우클릭 → 컨텍스트 메뉴 (추가/삭제/복사) | `onContextMenu` |
| **더블클릭** | 이름 인라인 편집 | `onDoubleClick` → 편집 모드 |

#### 3. 우측 상세 폼 (MUST)

> **CRITICAL**: 트리에서 메뉴 클릭 시 **반드시** 우측에 상세 입력/수정 폼이 표시되어야 합니다.
> 모달로 띄우면 **안 됩니다**.

**상세 폼 필수 섹션:**

```
┌─────────────────────────────────────────────────────────────┐
│ 📝 메뉴 상세 정보                           [신규] / [수정] │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ ▼ 기본 정보                                                  │
│   • 메뉴명 (필수)                                            │
│   • 메뉴코드 (필수, 영문/숫자/언더스코어)                      │
│   • 상위메뉴 (트리 셀렉트)                                    │
│   • 아이콘 (아이콘 피커)                                      │
│   • 설명                                                     │
│                                                              │
│ ▼ 링크 설정                                                  │
│   • 링크 타입 (URL / 새창 / 모달 / 없음)                      │
│   • URL 또는 라우트                                          │
│   • 가상경로 (SEO용)                                         │
│                                                              │
│ ▼ 권한 설정                                                  │
│   • 접근권한 (전체공개 / 회원만 / 관리자)                      │
│   • 표시조건 (항상 / 로그인시 / 로그아웃시)                    │
│   • 허용 그룹 (멀티셀렉트)                                    │
│   • 허용 역할 (멀티셀렉트)                                    │
│                                                              │
│ ▼ 표시 설정                                                  │
│   • 사용여부 (스위치)                                        │
│   • 숨김여부 (스위치)                                        │
│   • 강조표시 (NEW, HOT 등)                                   │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│  [저장]  [삭제]  [취소]                                      │
└─────────────────────────────────────────────────────────────┘
```

### 핵심 원칙 (CRITICAL)

| 항목 | 규칙 | 위반 시 |
|------|------|---------|
| **모달 사용** | ❌ **절대 금지** | 모달로 폼 띄우면 안 됨 |
| **레이아웃** | 좌측 트리 + 우측 상세 폼 | 반드시 이 구조 |
| **트리 스타일** | Windows Explorer 수준 | 폴더/파일 아이콘, 펼침/접힘 |
| **클릭 동작** | 클릭 → 우측에 폼 표시 | 다른 동작 금지 |
| **드래그앤드롭** | 트리 내 순서/위치 변경 | 필수 구현 |
| **저장** | 우측 폼에서 저장 버튼 | 모달 확인 금지 |

### 컴포넌트 구조

```tsx
// pages/admin/menus/index.tsx
export default function MenuManagementPage() {
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);

  return (
    <Box sx={{ display: 'flex', height: 'calc(100vh - 64px)' }}>
      {/* 좌측: 트리 */}
      <Box sx={{ width: 280, borderRight: 1, borderColor: 'divider', overflow: 'auto' }}>
        <MenuTree
          onSelect={setSelectedMenu}
          selectedId={selectedMenu?.id}
        />
      </Box>

      {/* 우측: 상세 패널 */}
      <Box sx={{ flex: 1, p: 3, overflow: 'auto' }}>
        {selectedMenu ? (
          <MenuDetailPanel
            menu={selectedMenu}
            onSave={handleSave}
            onDelete={handleDelete}
          />
        ) : (
          <EmptyState message="좌측에서 메뉴를 선택하세요" />
        )}
      </Box>
    </Box>
  );
}
```

### 트리 컴포넌트 (드래그앤드롭 포함)

```tsx
// components/admin/menu/MenuTree.tsx
import { Tree } from '@minoru/react-dnd-treeview';

interface MenuTreeProps {
  onSelect: (menu: Menu) => void;
  selectedId?: number;
}

export function MenuTree({ onSelect, selectedId }: MenuTreeProps) {
  const { data: menus, refetch } = useQuery(['admin-menus'], fetchMenuTree);

  const handleDrop = async (newTree, { dragSourceId, dropTargetId }) => {
    // 순서 변경 API 호출
    await reorderMenus(dragSourceId, dropTargetId, newTree);
    refetch();
  };

  return (
    <Box>
      {/* 메뉴 타입 탭 */}
      <Tabs value={menuType} onChange={setMenuType}>
        <Tab label="사이트" value="site" />
        <Tab label="사용자" value="user" />
        <Tab label="관리자" value="admin" />
      </Tabs>

      {/* 트리 */}
      <Tree
        tree={menus}
        rootId={0}
        onDrop={handleDrop}
        render={(node, { depth, isOpen, onToggle }) => (
          <TreeNode
            node={node}
            depth={depth}
            isOpen={isOpen}
            isSelected={node.id === selectedId}
            onToggle={onToggle}
            onClick={() => onSelect(node.data)}
          />
        )}
      />

      {/* 새 메뉴 추가 버튼 */}
      <Button
        startIcon={<AddIcon />}
        onClick={() => onSelect({ id: 0, menu_type: menuType } as Menu)}
        sx={{ m: 2 }}
      >
        새 메뉴 추가
      </Button>
    </Box>
  );
}
```

### 상세 패널 (인라인 편집)

```tsx
// components/admin/menu/MenuDetailPanel.tsx
interface MenuDetailPanelProps {
  menu: Menu;
  onSave: (menu: Menu) => Promise<void>;
  onDelete: (id: number) => Promise<void>;
}

export function MenuDetailPanel({ menu, onSave, onDelete }: MenuDetailPanelProps) {
  const [formData, setFormData] = useState(menu);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  return (
    <Paper sx={{ p: 3 }}>
      <Typography variant="h6" gutterBottom>
        {menu.id ? '메뉴 수정' : '새 메뉴 추가'}
      </Typography>

      <Grid container spacing={2}>
        <Grid item xs={6}>
          <TextField
            label="메뉴명"
            value={formData.menu_name}
            onChange={(e) => setFormData({ ...formData, menu_name: e.target.value })}
            fullWidth
            required
          />
        </Grid>
        <Grid item xs={6}>
          <TextField
            label="메뉴 코드"
            value={formData.menu_code}
            onChange={(e) => setFormData({ ...formData, menu_code: e.target.value })}
            fullWidth
            required
            disabled={!!menu.id}  // 수정 시 코드 변경 불가
          />
        </Grid>
        {/* ... 기타 필드들 */}
      </Grid>

      {/* 버튼 영역 */}
      <Box sx={{ mt: 3, display: 'flex', gap: 1 }}>
        <Button variant="contained" onClick={() => onSave(formData)}>
          저장
        </Button>
        {menu.id && (
          <>
            <Button
              color="error"
              onClick={() => setShowDeleteConfirm(true)}
            >
              삭제
            </Button>

            {/* 인라인 삭제 확인 (모달 아님) */}
            <Collapse in={showDeleteConfirm}>
              <Alert
                severity="warning"
                action={
                  <>
                    <Button size="small" onClick={() => onDelete(menu.id)}>
                      확인
                    </Button>
                    <Button size="small" onClick={() => setShowDeleteConfirm(false)}>
                      취소
                    </Button>
                  </>
                }
              >
                정말 삭제하시겠습니까?
              </Alert>
            </Collapse>
          </>
        )}
      </Box>
    </Paper>
  );
}
```

### 스타일 가이드

```tsx
// 한국형 Admin 테마 설정
const adminTheme = createTheme({
  palette: {
    primary: { main: '#1976d2' },      // 파란색 계열
    background: {
      default: '#f5f5f5',               // 밝은 회색 배경
      paper: '#ffffff',
    },
  },
  components: {
    MuiButton: {
      defaultProps: { size: 'small' },  // 버튼 작게
    },
    MuiTextField: {
      defaultProps: { size: 'small' },  // 입력 필드 작게
    },
    MuiTable: {
      defaultProps: { size: 'small' },  // 테이블 조밀하게
    },
  },
});
```

---

## 기본 메뉴 데이터

### 사이트 메뉴 (GNB)

```sql
-- 1차 메뉴 (depth: 0)
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, permission_type, sort_order, created_by) VALUES
('site', '회사소개', 'about', 'mdi-domain', 'none', NULL, 'public', 1, 'system'),
('site', '서비스', 'service', 'mdi-briefcase', 'none', NULL, 'public', 2, 'system'),
('site', '커뮤니티', 'community', 'mdi-forum', 'none', NULL, 'public', 3, 'system'),
('site', '고객센터', 'support', 'mdi-headset', 'none', NULL, 'public', 4, 'system');

-- 2차 메뉴 (depth: 1) - 회사소개 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, 'CEO 인사말', 'about_ceo', 'url', '/about/ceo', 1, 1, 'system' FROM menus WHERE menu_code = 'about' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '회사연혁', 'about_history', 'url', '/about/history', 1, 2, 'system' FROM menus WHERE menu_code = 'about' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '조직도', 'about_organization', 'url', '/about/organization', 1, 3, 'system' FROM menus WHERE menu_code = 'about' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '오시는 길', 'about_location', 'url', '/about/location', 1, 4, 'system' FROM menus WHERE menu_code = 'about' AND menu_type = 'site';

-- 2차 메뉴 - 서비스 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '서비스 소개', 'service_intro', 'url', '/service/intro', 1, 1, 'system' FROM menus WHERE menu_code = 'service' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '요금안내', 'service_pricing', 'url', '/service/pricing', 1, 2, 'system' FROM menus WHERE menu_code = 'service' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '이용방법', 'service_guide', 'url', '/service/guide', 1, 3, 'system' FROM menus WHERE menu_code = 'service' AND menu_type = 'site';

-- 2차 메뉴 - 커뮤니티 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '공지사항', 'community_notice', 'url', '/community/notice', 1, 1, 'system' FROM menus WHERE menu_code = 'community' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '자유게시판', 'community_free', 'url', '/community/free', 1, 2, 'system' FROM menus WHERE menu_code = 'community' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'site', id, '이용후기', 'community_review', 'url', '/community/review', 1, 'member', 3, 'system' FROM menus WHERE menu_code = 'community' AND menu_type = 'site';

-- 2차 메뉴 - 고객센터 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, 'FAQ', 'support_faq', 'url', '/support/faq', 1, 1, 'system' FROM menus WHERE menu_code = 'support' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'site', id, '1:1 문의', 'support_inquiry', 'url', '/support/inquiry', 1, 'member', 2, 'system' FROM menus WHERE menu_code = 'support' AND menu_type = 'site';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, sort_order, created_by)
SELECT 'site', id, '자료실', 'support_download', 'url', '/support/download', 1, 3, 'system' FROM menus WHERE menu_code = 'support' AND menu_type = 'site';
```

### 사용자 메뉴 (마이페이지)

```sql
-- 1차 메뉴 (depth: 0)
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, permission_type, sort_order, created_by) VALUES
('user', '마이페이지', 'mypage', 'mdi-account-circle', 'none', NULL, 'member', 1, 'system'),
('user', '주문/배송', 'orders', 'mdi-package-variant', 'none', NULL, 'member', 2, 'system'),
('user', '활동내역', 'activity', 'mdi-history', 'none', NULL, 'member', 3, 'system'),
('user', '고객지원', 'my_support', 'mdi-help-circle', 'none', NULL, 'member', 4, 'system');

-- 2차 메뉴 - 마이페이지 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '회원정보 수정', 'mypage_profile', 'url', '/mypage/profile', 1, 'member', 1, 'system' FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '비밀번호 변경', 'mypage_password', 'url', '/mypage/password', 1, 'member', 2, 'system' FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '회원등급/혜택', 'mypage_grade', 'url', '/mypage/grade', 1, 'member', 3, 'system' FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '회원탈퇴', 'mypage_withdraw', 'url', '/mypage/withdraw', 1, 'member', 4, 'system' FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user';

-- 2차 메뉴 - 주문/배송 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '주문내역', 'orders_list', 'url', '/mypage/orders', 1, 'member', 1, 'system' FROM menus WHERE menu_code = 'orders' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '배송조회', 'orders_delivery', 'url', '/mypage/delivery', 1, 'member', 2, 'system' FROM menus WHERE menu_code = 'orders' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '취소/반품/교환', 'orders_cancel', 'url', '/mypage/cancel', 1, 'member', 3, 'system' FROM menus WHERE menu_code = 'orders' AND menu_type = 'user';

-- 2차 메뉴 - 활동내역 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '찜목록', 'activity_wishlist', 'url', '/mypage/wishlist', 1, 'member', 1, 'system' FROM menus WHERE menu_code = 'activity' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '최근 본 상품', 'activity_recent', 'url', '/mypage/recent', 1, 'member', 2, 'system' FROM menus WHERE menu_code = 'activity' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '내가 쓴 글', 'activity_posts', 'url', '/mypage/posts', 1, 'member', 3, 'system' FROM menus WHERE menu_code = 'activity' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '포인트/쿠폰', 'activity_point', 'url', '/mypage/point', 1, 'member', 4, 'system' FROM menus WHERE menu_code = 'activity' AND menu_type = 'user';

-- 2차 메뉴 - 고객지원 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '1:1 문의내역', 'my_support_inquiry', 'url', '/mypage/inquiry', 1, 'member', 1, 'system' FROM menus WHERE menu_code = 'my_support' AND menu_type = 'user';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '상품 Q&A', 'my_support_qna', 'url', '/mypage/qna', 1, 'member', 2, 'system' FROM menus WHERE menu_code = 'my_support' AND menu_type = 'user';
```

### 헤더 유틸리티

```sql
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, show_condition, sort_order, created_by) VALUES
('header_utility', '로그인', 'login', 'mdi-login', 'url', '/login', 'logged_out', 1, 'system'),
('header_utility', '회원가입', 'register', 'mdi-account-plus', 'url', '/register', 'logged_out', 2, 'system'),
('header_utility', '마이페이지', 'header_mypage', 'mdi-account', 'url', '/mypage', 'logged_in', 3, 'system'),
('header_utility', '장바구니', 'cart', 'mdi-cart', 'url', '/cart', 'logged_in', 4, 'system'),
('header_utility', '주문조회', 'order_check', 'mdi-truck-delivery', 'url', '/order/check', 'always', 5, 'system'),
('header_utility', '고객센터', 'header_support', 'mdi-headset', 'url', '/support', 'always', 6, 'system'),
('header_utility', '로그아웃', 'logout', 'mdi-logout', 'url', '/logout', 'logged_in', 7, 'system');
```

### 푸터 유틸리티

```sql
INSERT INTO menus (menu_type, menu_name, menu_code, link_type, link_url, sort_order, css_class, created_by) VALUES
('footer_utility', '회사소개', 'footer_about', 'url', '/about', 1, NULL, 'system'),
('footer_utility', '이용약관', 'terms', 'url', '/terms', 2, NULL, 'system'),
('footer_utility', '개인정보처리방침', 'privacy', 'url', '/privacy', 3, 'bold', 'system'),
('footer_utility', '이메일무단수집거부', 'email_policy', 'url', '/email-policy', 4, NULL, 'system'),
('footer_utility', '사이트맵', 'sitemap', 'url', '/sitemap', 5, NULL, 'system'),
('footer_utility', '관련사이트', 'related_sites', 'none', NULL, 6, NULL, 'system');

-- 관련 사이트 데이터
INSERT INTO related_sites (menu_id, site_name, site_url, sort_order, is_new_window, created_by)
SELECT id, '네이버', 'https://www.naver.com', 1, TRUE, 'system' FROM menus WHERE menu_code = 'related_sites' AND menu_type = 'footer_utility';
INSERT INTO related_sites (menu_id, site_name, site_url, sort_order, is_new_window, created_by)
SELECT id, '다음', 'https://www.daum.net', 2, TRUE, 'system' FROM menus WHERE menu_code = 'related_sites' AND menu_type = 'footer_utility';
INSERT INTO related_sites (menu_id, site_name, site_url, sort_order, is_new_window, created_by)
SELECT id, '구글', 'https://www.google.com', 3, TRUE, 'system' FROM menus WHERE menu_code = 'related_sites' AND menu_type = 'footer_utility';
INSERT INTO related_sites (menu_id, site_name, site_url, sort_order, is_new_window, created_by)
SELECT id, '정부24', 'https://www.gov.kr', 4, TRUE, 'system' FROM menus WHERE menu_code = 'related_sites' AND menu_type = 'footer_utility';
```

### 관리자 메뉴

```sql
-- 1차 메뉴 (depth: 0)
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, permission_type, sort_order, created_by) VALUES
('admin', '대시보드', 'dashboard', 'mdi-view-dashboard', 'url', '/admin', 'admin', 1, 'system'),
('admin', '회원관리', 'admin_users', 'mdi-account-group', 'none', NULL, 'admin', 2, 'system'),
('admin', '컨텐츠관리', 'admin_contents', 'mdi-file-document-multiple', 'none', NULL, 'admin', 3, 'system'),
('admin', '주문관리', 'admin_orders', 'mdi-cart', 'none', NULL, 'admin', 4, 'system'),
('admin', '통계/리포트', 'admin_stats', 'mdi-chart-bar', 'none', NULL, 'admin', 5, 'system'),
('admin', '시스템설정', 'admin_settings', 'mdi-cog', 'none', NULL, 'admin', 6, 'system');

-- 2차 메뉴 - 회원관리 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '회원목록', 'admin_users_list', 'mdi-account-multiple', 'url', '/admin/users', 1, 'admin', 1, 'system' FROM menus WHERE menu_code = 'admin_users' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '회원등급관리', 'admin_users_grade', 'mdi-medal', 'url', '/admin/users/grade', 1, 'admin', 2, 'system' FROM menus WHERE menu_code = 'admin_users' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '그룹관리', 'admin_users_groups', 'mdi-account-group', 'url', '/admin/groups', 1, 'admin', 3, 'system' FROM menus WHERE menu_code = 'admin_users' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '역할관리', 'admin_users_roles', 'mdi-shield-account', 'url', '/admin/roles', 1, 'admin', 4, 'system' FROM menus WHERE menu_code = 'admin_users' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '탈퇴회원', 'admin_users_withdrawn', 'mdi-account-off', 'url', '/admin/users/withdrawn', 1, 'admin', 5, 'system' FROM menus WHERE menu_code = 'admin_users' AND menu_type = 'admin';

-- 2차 메뉴 - 컨텐츠관리 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '메뉴관리', 'admin_menus', 'mdi-menu', 'url', '/admin/menus', 1, 'admin', 1, 'system' FROM menus WHERE menu_code = 'admin_contents' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '게시판관리', 'admin_boards', 'mdi-view-list', 'url', '/admin/boards', 1, 'admin', 2, 'system' FROM menus WHERE menu_code = 'admin_contents' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '배너관리', 'admin_banners', 'mdi-image', 'url', '/admin/banners', 1, 'admin', 3, 'system' FROM menus WHERE menu_code = 'admin_contents' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '팝업관리', 'admin_popups', 'mdi-window-maximize', 'url', '/admin/popups', 1, 'admin', 4, 'system' FROM menus WHERE menu_code = 'admin_contents' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '약관관리', 'admin_terms', 'mdi-file-document', 'url', '/admin/terms', 1, 'admin', 5, 'system' FROM menus WHERE menu_code = 'admin_contents' AND menu_type = 'admin';

-- 2차 메뉴 - 주문관리 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '주문목록', 'admin_orders_list', 'mdi-clipboard-list', 'url', '/admin/orders', 1, 'admin', 1, 'system' FROM menus WHERE menu_code = 'admin_orders' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '배송관리', 'admin_orders_delivery', 'mdi-truck', 'url', '/admin/orders/delivery', 1, 'admin', 2, 'system' FROM menus WHERE menu_code = 'admin_orders' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '취소/반품/교환', 'admin_orders_cancel', 'mdi-undo', 'url', '/admin/orders/cancel', 1, 'admin', 3, 'system' FROM menus WHERE menu_code = 'admin_orders' AND menu_type = 'admin';

-- 2차 메뉴 - 통계/리포트 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '방문자 통계', 'admin_stats_visitor', 'mdi-account-clock', 'url', '/admin/stats/visitor', 1, 'admin', 1, 'system' FROM menus WHERE menu_code = 'admin_stats' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '매출 통계', 'admin_stats_sales', 'mdi-chart-line', 'url', '/admin/stats/sales', 1, 'admin', 2, 'system' FROM menus WHERE menu_code = 'admin_stats' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '회원 통계', 'admin_stats_member', 'mdi-chart-pie', 'url', '/admin/stats/member', 1, 'admin', 3, 'system' FROM menus WHERE menu_code = 'admin_stats' AND menu_type = 'admin';

-- 2차 메뉴 - 시스템설정 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '기본설정', 'admin_settings_basic', 'mdi-cog', 'url', '/admin/settings/basic', 1, 'admin', 1, 'system' FROM menus WHERE menu_code = 'admin_settings' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '관리자 계정', 'admin_settings_admins', 'mdi-account-key', 'url', '/admin/settings/admins', 1, 'admin', 2, 'system' FROM menus WHERE menu_code = 'admin_settings' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '로그관리', 'admin_settings_logs', 'mdi-text-box-search', 'url', '/admin/settings/logs', 1, 'admin', 3, 'system' FROM menus WHERE menu_code = 'admin_settings' AND menu_type = 'admin';
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, icon, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'admin', id, '백업/복원', 'admin_settings_backup', 'mdi-backup-restore', 'url', '/admin/settings/backup', 1, 'admin', 4, 'system' FROM menus WHERE menu_code = 'admin_settings' AND menu_type = 'admin';
```

### 퀵메뉴 (플로팅)

```sql
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, show_condition, sort_order, created_by) VALUES
('quick_menu', '최근 본 상품', 'quick_recent', 'mdi-history', 'url', '/mypage/recent', 'logged_in', 1, 'system'),
('quick_menu', '장바구니', 'quick_cart', 'mdi-cart', 'url', '/cart', 'logged_in', 2, 'system'),
('quick_menu', '찜목록', 'quick_wishlist', 'mdi-heart', 'url', '/mypage/wishlist', 'logged_in', 3, 'system'),
('quick_menu', '1:1 문의', 'quick_inquiry', 'mdi-message-text', 'url', '/support/inquiry', 'always', 4, 'system'),
('quick_menu', 'TOP', 'quick_top', 'mdi-chevron-up', 'url', '#top', 'always', 5, 'system');
```

---

## 실행 액션 (CRITICAL)

### Action 1: 프로젝트 분석

```bash
ls -la
cat package.json 2>/dev/null | head -30
ls frontend/src/ 2>/dev/null
```

### Action 2: DB 스키마 생성

**생성 파일**: `db/schema/menu_schema.sql`

포함 테이블:
- menus
- user_groups
- user_group_members
- roles
- user_roles
- menu_permissions
- related_sites

### Action 3: Backend API 생성

| 파일 | 역할 |
|------|------|
| `api/menuHandler.js` | 메뉴 조회 |
| `api/menuAdminHandler.js` | 메뉴 관리 |
| `api/groupHandler.js` | 그룹 관리 |
| `api/roleHandler.js` | 역할 관리 |

### Action 4: Frontend 컴포넌트 생성

위 "Frontend 컴포넌트" 섹션 참조

---

## 완료 메시지

```
✅ 통합 메뉴 관리 시스템 초기화 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

생성된 테이블:
  - menus: 통합 메뉴 (site/user/admin/utility)
  - user_groups: 사용자 그룹
  - user_group_members: 사용자-그룹 매핑
  - roles: 역할
  - user_roles: 사용자-역할 매핑
  - menu_permissions: 메뉴 권한
  - related_sites: 관련 사이트

메뉴 타입:
  - site: 사이트 메뉴 (GNB)
  - user: 사용자 메뉴
  - admin: 관리자 메뉴
  - header_utility: 헤더 유틸리티
  - footer_utility: 푸터 유틸리티

주요 기능:
  ✓ 트리 구조 메뉴 관리
  ✓ 드래그 앤 드롭
  ✓ 그룹/사용자/역할별 권한
  ✓ 로그인 상태별 표시 조건
  ✓ 관련 사이트 관리

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
