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
  AND TABLE_NAME IN ('tenants', 'user_groups', 'user_group_members', 'roles', 'user_roles');
```

**결과가 5개 미만이면:**
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

  -- 테넌트 (멀티사이트)
  tenant_id BIGINT NOT NULL,                  -- 테넌트 ID (shared-schema.tenants 참조)

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

  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES menus(id) ON DELETE SET NULL,
  UNIQUE KEY uk_tenant_type_code (tenant_id, menu_type, menu_code),
  INDEX idx_tenant (tenant_id),
  INDEX idx_type_parent (tenant_id, menu_type, parent_id, sort_order),
  INDEX idx_path (path),
  INDEX idx_virtual_path (virtual_path)
);
```

### tenants, user_groups, roles 등 (공유 테이블)

> **참고**: 다음 테이블들은 `shared-schema.md`에서 정의됩니다:
> - `tenants`: 테넌트 (멀티사이트) - **menus.tenant_id가 참조**
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

### 4. 드래그앤드롭 순서 변경 (CRITICAL - 반드시 구현)

> **CRITICAL**: 드래그앤드롭은 메뉴 관리의 핵심 기능입니다. 반드시 구현해야 합니다.

#### 필수 구현 체크리스트

| 항목 | 설명 | 필수 |
|------|------|:----:|
| **순서 변경 API** | 같은 부모 내에서 순서 변경 | ✅ |
| **메뉴 이동 API** | 다른 부모로 메뉴 이동 | ✅ |
| **프론트엔드 DnD** | 환경에 맞는 라이브러리 사용 | ✅ |
| **실시간 UI 반영** | 드롭 후 즉시 트리 갱신 | ✅ |
| **에러 롤백** | 실패 시 원래 위치로 복원 | ✅ |

#### Backend API (Express)

```javascript
// controllers/menuController.js

/**
 * 메뉴 순서 변경 API (같은 부모 내)
 * PUT /api/admin/menus/reorder
 */
async function reorderMenus(req, res) {
  const { menuType, parentId, orderedIds } = req.body;
  // orderedIds: [5, 3, 7, 2] - 새로운 순서대로 메뉴 ID 배열

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // 순서 일괄 업데이트
    for (let i = 0; i < orderedIds.length; i++) {
      await connection.execute(
        `UPDATE menus
         SET sort_order = ?, updated_by = ?, updated_at = NOW()
         WHERE id = ? AND tenant_id = ?`,
        [i, req.user.id, orderedIds[i], req.tenantId]
      );
    }

    // 감사 로그
    await connection.execute(
      `INSERT INTO menu_audit_logs (menu_id, user_id, action, changes, created_at)
       VALUES (?, ?, 'reorder', ?, NOW())`,
      [parentId || 0, req.user.id, JSON.stringify({ orderedIds })]
    );

    await connection.commit();
    res.json({ success: true, message: '순서가 변경되었습니다.' });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

/**
 * 메뉴 이동 API (다른 부모로 이동)
 * PUT /api/admin/menus/:id/move
 */
async function moveMenu(req, res) {
  const { id } = req.params;
  const { newParentId, newIndex } = req.body;
  // newParentId: 새 부모 ID (null이면 최상위)
  // newIndex: 새 부모 내에서의 위치

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // 1. 현재 메뉴 정보 조회
    const [[menu]] = await connection.execute(
      'SELECT * FROM menus WHERE id = ? AND tenant_id = ?',
      [id, req.tenantId]
    );

    if (!menu) {
      return res.status(404).json({ error: '메뉴를 찾을 수 없습니다.' });
    }

    // 2. 새 부모의 depth 계산
    let newDepth = 0;
    let newPath = '';
    if (newParentId) {
      const [[parent]] = await connection.execute(
        'SELECT depth, path FROM menus WHERE id = ?',
        [newParentId]
      );
      newDepth = parent.depth + 1;
      newPath = parent.path ? `${parent.path}/${newParentId}` : `${newParentId}`;
    }

    // 3. 기존 위치의 형제들 순서 재정렬
    await connection.execute(
      `UPDATE menus
       SET sort_order = sort_order - 1
       WHERE tenant_id = ? AND menu_type = ? AND parent_id <=> ? AND sort_order > ?`,
      [req.tenantId, menu.menu_type, menu.parent_id, menu.sort_order]
    );

    // 4. 새 위치의 형제들 순서 밀기
    await connection.execute(
      `UPDATE menus
       SET sort_order = sort_order + 1
       WHERE tenant_id = ? AND menu_type = ? AND parent_id <=> ? AND sort_order >= ?`,
      [req.tenantId, menu.menu_type, newParentId, newIndex]
    );

    // 5. 메뉴 이동
    await connection.execute(
      `UPDATE menus
       SET parent_id = ?, depth = ?, path = ?, sort_order = ?,
           updated_by = ?, updated_at = NOW()
       WHERE id = ?`,
      [newParentId, newDepth, newPath, newIndex, req.user.id, id]
    );

    // 6. 하위 메뉴들의 depth, path 재계산 (재귀)
    await updateChildrenDepthPath(connection, id, newDepth, newPath ? `${newPath}/${id}` : `${id}`);

    // 7. 감사 로그
    await connection.execute(
      `INSERT INTO menu_audit_logs (menu_id, user_id, action, changes, created_at)
       VALUES (?, ?, 'move', ?, NOW())`,
      [id, req.user.id, JSON.stringify({
        from: { parentId: menu.parent_id, sortOrder: menu.sort_order },
        to: { parentId: newParentId, sortOrder: newIndex }
      })]
    );

    await connection.commit();
    res.json({ success: true, message: '메뉴가 이동되었습니다.' });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}

// 하위 메뉴 depth/path 재귀 업데이트
async function updateChildrenDepthPath(connection, parentId, parentDepth, parentPath) {
  const [children] = await connection.execute(
    'SELECT id FROM menus WHERE parent_id = ?',
    [parentId]
  );

  for (const child of children) {
    const newDepth = parentDepth + 1;
    const newPath = `${parentPath}/${child.id}`;

    await connection.execute(
      'UPDATE menus SET depth = ?, path = ? WHERE id = ?',
      [newDepth, newPath, child.id]
    );

    await updateChildrenDepthPath(connection, child.id, newDepth, newPath);
  }
}
```

#### 라우터 등록 (필수)

```javascript
// routes/adminMenuRoutes.js
router.put('/admin/menus/reorder', authenticateToken, isAdmin, validateReorder, asyncHandler(reorderMenus));
router.put('/admin/menus/:id/move', authenticateToken, isAdmin, validateMove, asyncHandler(moveMenu));
```

#### 검증 미들웨어 (필수)

```javascript
// validators/menuValidator.js
const validateReorder = [
  body('menuType').isIn(['site', 'user', 'admin', 'header_utility', 'footer_utility', 'quick_menu']),
  body('orderedIds').isArray({ min: 1 }),
  body('orderedIds.*').isInt({ min: 1 }),
];

const validateMove = [
  param('id').isInt({ min: 1 }),
  body('newParentId').optional({ nullable: true }).isInt({ min: 1 }),
  body('newIndex').isInt({ min: 0 }),
];
```

#### Frontend API 클라이언트 (필수)

```typescript
// lib/api/menuApi.ts

/**
 * 메뉴 순서 변경 (같은 부모 내)
 */
export async function reorderMenus(
  menuType: string,
  parentId: number | null,
  orderedIds: number[]
): Promise<void> {
  await api.put('/api/admin/menus/reorder', {
    menuType,
    parentId,
    orderedIds,
  });
}

/**
 * 메뉴 이동 (다른 부모로)
 */
export async function moveMenu(
  menuId: number,
  newParentId: number | null,
  newIndex: number
): Promise<void> {
  await api.put(`/api/admin/menus/${menuId}/move`, {
    newParentId,
    newIndex,
  });
}
```

### 5. 메뉴 생성/수정/삭제 API (CRITICAL - 반드시 구현)

> **CRITICAL**: 메뉴 CRUD는 핵심 기능입니다. 반드시 구현해야 합니다.

#### 메뉴 생성 API

```javascript
// controllers/menuController.js

/**
 * 메뉴 생성 API
 * POST /api/admin/menus
 */
async function createMenu(req, res) {
  const {
    menu_type,
    parent_id,
    menu_name,
    menu_code,
    description,
    icon,
    virtual_path,
    link_type,
    link_url,
    external_url,
    modal_component,
    modal_width,
    modal_height,
    permission_type,
    show_condition,
    condition_expression,
    is_visible,
    is_enabled,
    is_expandable,
    default_expanded,
    css_class,
    highlight,
    highlight_text,
    highlight_color,
    badge_type,
    badge_value,
    badge_color,
    seo_title,
    seo_description,
  } = req.body;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // 1. 부모 메뉴 정보 조회 (depth, path 계산용)
    let depth = 0;
    let path = '';
    if (parent_id) {
      const [[parent]] = await connection.execute(
        'SELECT depth, path FROM menus WHERE id = ? AND tenant_id = ?',
        [parent_id, req.tenantId]
      );
      if (!parent) {
        return res.status(400).json({ error: '상위 메뉴를 찾을 수 없습니다.' });
      }
      depth = parent.depth + 1;
      path = parent.path ? `${parent.path}/${parent_id}` : `${parent_id}`;
    }

    // 2. 같은 부모 내 마지막 순서 조회
    const [[lastOrder]] = await connection.execute(
      `SELECT COALESCE(MAX(sort_order), -1) + 1 as next_order
       FROM menus
       WHERE tenant_id = ? AND menu_type = ? AND parent_id <=> ?`,
      [req.tenantId, menu_type, parent_id]
    );
    const sort_order = lastOrder.next_order;

    // 3. 메뉴 코드 중복 검사
    const [[existing]] = await connection.execute(
      'SELECT id FROM menus WHERE tenant_id = ? AND menu_type = ? AND menu_code = ?',
      [req.tenantId, menu_type, menu_code]
    );
    if (existing) {
      return res.status(400).json({ error: '이미 사용 중인 메뉴 코드입니다.' });
    }

    // 4. 메뉴 생성
    const [result] = await connection.execute(
      `INSERT INTO menus (
        tenant_id, menu_type, parent_id, depth, sort_order, path,
        menu_name, menu_code, description, icon, virtual_path,
        link_type, link_url, external_url, modal_component, modal_width, modal_height,
        permission_type, show_condition, condition_expression,
        is_visible, is_enabled, is_expandable, default_expanded,
        css_class, highlight, highlight_text, highlight_color,
        badge_type, badge_value, badge_color,
        seo_title, seo_description,
        created_by, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())`,
      [
        req.tenantId, menu_type, parent_id, depth, sort_order, path,
        menu_name, menu_code, description, icon, virtual_path,
        link_type || 'url', link_url, external_url, modal_component, modal_width || 800, modal_height || 600,
        permission_type || 'public', show_condition || 'always', condition_expression,
        is_visible !== false, is_enabled !== false, is_expandable !== false, default_expanded || false,
        css_class, highlight || false, highlight_text, highlight_color,
        badge_type || 'none', badge_value, badge_color || 'primary',
        seo_title, seo_description,
        req.user.id
      ]
    );

    const newMenuId = result.insertId;

    // 5. path 업데이트 (자기 자신 포함)
    const newPath = path ? `${path}/${newMenuId}` : `${newMenuId}`;
    await connection.execute(
      'UPDATE menus SET path = ? WHERE id = ?',
      [newPath, newMenuId]
    );

    // 6. 감사 로그
    await connection.execute(
      `INSERT INTO menu_audit_logs (menu_id, user_id, action, changes, created_at)
       VALUES (?, ?, 'create', ?, NOW())`,
      [newMenuId, req.user.id, JSON.stringify(req.body)]
    );

    await connection.commit();

    // 7. 생성된 메뉴 반환
    const [[newMenu]] = await pool.execute(
      'SELECT * FROM menus WHERE id = ?',
      [newMenuId]
    );

    res.status(201).json({
      success: true,
      message: '메뉴가 생성되었습니다.',
      data: newMenu
    });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
```

#### 메뉴 수정 API

```javascript
/**
 * 메뉴 수정 API
 * PUT /api/admin/menus/:id
 */
async function updateMenu(req, res) {
  const { id } = req.params;
  const updateData = req.body;

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // 1. 기존 메뉴 조회
    const [[existingMenu]] = await connection.execute(
      'SELECT * FROM menus WHERE id = ? AND tenant_id = ?',
      [id, req.tenantId]
    );

    if (!existingMenu) {
      return res.status(404).json({ error: '메뉴를 찾을 수 없습니다.' });
    }

    // 2. 메뉴 코드 중복 검사 (변경된 경우만)
    if (updateData.menu_code && updateData.menu_code !== existingMenu.menu_code) {
      const [[duplicate]] = await connection.execute(
        'SELECT id FROM menus WHERE tenant_id = ? AND menu_type = ? AND menu_code = ? AND id != ?',
        [req.tenantId, existingMenu.menu_type, updateData.menu_code, id]
      );
      if (duplicate) {
        return res.status(400).json({ error: '이미 사용 중인 메뉴 코드입니다.' });
      }
    }

    // 3. 부모 변경 시 depth/path 재계산
    if (updateData.parent_id !== undefined && updateData.parent_id !== existingMenu.parent_id) {
      let newDepth = 0;
      let newPath = '';

      if (updateData.parent_id) {
        // 자기 자신이나 하위로 이동 금지
        if (updateData.parent_id === parseInt(id)) {
          return res.status(400).json({ error: '자기 자신을 상위 메뉴로 설정할 수 없습니다.' });
        }

        const [[parent]] = await connection.execute(
          'SELECT id, depth, path FROM menus WHERE id = ?',
          [updateData.parent_id]
        );

        if (parent.path && parent.path.includes(`/${id}/`)) {
          return res.status(400).json({ error: '하위 메뉴를 상위 메뉴로 설정할 수 없습니다.' });
        }

        newDepth = parent.depth + 1;
        newPath = parent.path ? `${parent.path}/${updateData.parent_id}` : `${updateData.parent_id}`;
      }

      updateData.depth = newDepth;
      updateData.path = newPath ? `${newPath}/${id}` : `${id}`;
    }

    // 4. 업데이트할 필드 구성
    const allowedFields = [
      'menu_name', 'menu_code', 'description', 'icon', 'virtual_path',
      'link_type', 'link_url', 'external_url', 'modal_component', 'modal_width', 'modal_height',
      'permission_type', 'show_condition', 'condition_expression',
      'is_visible', 'is_enabled', 'is_expandable', 'default_expanded',
      'css_class', 'highlight', 'highlight_text', 'highlight_color',
      'badge_type', 'badge_value', 'badge_color',
      'seo_title', 'seo_description',
      'parent_id', 'depth', 'path'
    ];

    const updates = [];
    const values = [];

    for (const field of allowedFields) {
      if (updateData[field] !== undefined) {
        updates.push(`${field} = ?`);
        values.push(updateData[field]);
      }
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: '수정할 내용이 없습니다.' });
    }

    updates.push('updated_by = ?', 'updated_at = NOW()');
    values.push(req.user.id, id);

    // 5. 메뉴 업데이트
    await connection.execute(
      `UPDATE menus SET ${updates.join(', ')} WHERE id = ?`,
      values
    );

    // 6. 감사 로그
    await connection.execute(
      `INSERT INTO menu_audit_logs (menu_id, user_id, action, changes, created_at)
       VALUES (?, ?, 'update', ?, NOW())`,
      [id, req.user.id, JSON.stringify({ before: existingMenu, after: updateData })]
    );

    await connection.commit();

    // 7. 수정된 메뉴 반환
    const [[updatedMenu]] = await pool.execute(
      'SELECT * FROM menus WHERE id = ?',
      [id]
    );

    res.json({
      success: true,
      message: '메뉴가 수정되었습니다.',
      data: updatedMenu
    });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
```

#### 메뉴 삭제 API

```javascript
/**
 * 메뉴 삭제 API
 * DELETE /api/admin/menus/:id
 */
async function deleteMenu(req, res) {
  const { id } = req.params;
  const { force } = req.query; // force=true면 하위 메뉴도 함께 삭제

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // 1. 메뉴 조회
    const [[menu]] = await connection.execute(
      'SELECT * FROM menus WHERE id = ? AND tenant_id = ?',
      [id, req.tenantId]
    );

    if (!menu) {
      return res.status(404).json({ error: '메뉴를 찾을 수 없습니다.' });
    }

    // 2. 하위 메뉴 확인
    const [children] = await connection.execute(
      'SELECT id FROM menus WHERE parent_id = ? AND is_deleted = FALSE',
      [id]
    );

    if (children.length > 0 && force !== 'true') {
      return res.status(400).json({
        error: '하위 메뉴가 있습니다. 먼저 하위 메뉴를 삭제하거나 force=true 옵션을 사용하세요.',
        childCount: children.length
      });
    }

    // 3. 하위 메뉴 함께 삭제 (force=true인 경우)
    if (force === 'true' && children.length > 0) {
      await connection.execute(
        `UPDATE menus SET is_deleted = TRUE, updated_by = ?, updated_at = NOW()
         WHERE path LIKE ? OR id = ?`,
        [req.user.id, `%/${id}/%`, id]
      );
    } else {
      // 4. 소프트 삭제
      await connection.execute(
        `UPDATE menus SET is_deleted = TRUE, updated_by = ?, updated_at = NOW()
         WHERE id = ?`,
        [req.user.id, id]
      );
    }

    // 5. 형제 메뉴들의 순서 재정렬
    await connection.execute(
      `UPDATE menus
       SET sort_order = sort_order - 1
       WHERE tenant_id = ? AND menu_type = ? AND parent_id <=> ? AND sort_order > ? AND is_deleted = FALSE`,
      [req.tenantId, menu.menu_type, menu.parent_id, menu.sort_order]
    );

    // 6. 감사 로그
    await connection.execute(
      `INSERT INTO menu_audit_logs (menu_id, user_id, action, changes, created_at)
       VALUES (?, ?, 'delete', ?, NOW())`,
      [id, req.user.id, JSON.stringify({ force: force === 'true', childCount: children.length })]
    );

    await connection.commit();

    res.json({
      success: true,
      message: force === 'true' && children.length > 0
        ? `메뉴와 하위 ${children.length}개 메뉴가 삭제되었습니다.`
        : '메뉴가 삭제되었습니다.'
    });
  } catch (error) {
    await connection.rollback();
    throw error;
  } finally {
    connection.release();
  }
}
```

#### 라우터 등록 (필수)

```javascript
// routes/adminMenuRoutes.js
router.post('/admin/menus', authenticateToken, isAdmin, validateCreateMenu, asyncHandler(createMenu));
router.put('/admin/menus/:id', authenticateToken, isAdmin, validateMenuId, asyncHandler(updateMenu));
router.delete('/admin/menus/:id', authenticateToken, isAdmin, validateMenuId, asyncHandler(deleteMenu));
```

#### Frontend API 클라이언트 (필수)

```typescript
// lib/api/menuApi.ts

/**
 * 메뉴 생성
 */
export async function createMenu(menuData: Partial<Menu>): Promise<Menu> {
  const { data } = await api.post('/api/admin/menus', menuData);
  return data.data;
}

/**
 * 메뉴 수정
 */
export async function updateMenu(id: number, menuData: Partial<Menu>): Promise<Menu> {
  const { data } = await api.put(`/api/admin/menus/${id}`, menuData);
  return data.data;
}

/**
 * 메뉴 삭제
 */
export async function deleteMenu(id: number, force: boolean = false): Promise<void> {
  await api.delete(`/api/admin/menus/${id}?force=${force}`);
}

/**
 * 메뉴 저장 (생성 또는 수정)
 */
export async function saveMenu(menu: Partial<Menu>): Promise<Menu> {
  if (menu.id && menu.id > 0) {
    return updateMenu(menu.id, menu);
  } else {
    return createMenu(menu);
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
// CRITICAL: isAddMode 상태를 반드시 사용해야 함
export default function MenuManagementPage() {
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);
  const [isAddMode, setIsAddMode] = useState(false);  // 추가 모드 상태
  const [currentMenuType, setCurrentMenuType] = useState('site');

  // 메뉴 선택/추가 핸들러
  const handleSelect = (menu: Menu | null, isNewMenu = false) => {
    if (isNewMenu) {
      setSelectedMenu(null);
      setIsAddMode(true);
      if (menu?.menu_type) setCurrentMenuType(menu.menu_type);
    } else {
      setSelectedMenu(menu);
      setIsAddMode(false);
    }
  };

  const showPanel = selectedMenu !== null || isAddMode;

  return (
    <Box sx={{ display: 'flex', height: 'calc(100vh - 64px)' }}>
      {/* 좌측: 트리 */}
      <Box sx={{ width: 280, borderRight: 1, borderColor: 'divider', overflow: 'auto' }}>
        <MenuTree
          onSelect={handleSelect}
          onMenuTypeChange={setCurrentMenuType}
          selectedId={selectedMenu?.id}
        />
      </Box>

      {/* 우측: 상세 패널 */}
      <Box sx={{ flex: 1, p: 3, overflow: 'auto' }}>
        {showPanel ? (
          <MenuDetailPanel
            menu={selectedMenu}
            isAddMode={isAddMode}           // CRITICAL: 추가 모드 전달
            defaultMenuType={currentMenuType}
            onSuccess={() => { setSelectedMenu(null); setIsAddMode(false); }}
            onCancel={() => { setSelectedMenu(null); setIsAddMode(false); }}
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

> **CRITICAL**: 드래그앤드롭 라이브러리는 프로젝트 환경에 맞게 선택해야 합니다.

#### 환경별 드래그앤드롭 라이브러리 (MUST CHECK)

| Frontend | UI Library | 추천 DnD 라이브러리 | 설치 |
|----------|------------|-------------------|------|
| **React** | MUI | `@minoru/react-dnd-treeview` | `npm i @minoru/react-dnd-treeview react-dnd react-dnd-html5-backend` |
| **React** | Ant Design | `antd` 내장 Tree | 별도 설치 불필요 (`<Tree draggable>`) |
| **React** | Bootstrap | `react-sortable-tree` | `npm i @nosferatu500/react-sortable-tree` |
| **Vue 3** | Element Plus | `vue-draggable-plus` | `npm i vue-draggable-plus` |
| **Vue 3** | Vuetify | `vuedraggable` | `npm i vuedraggable@next` |
| **Angular** | Angular Material | `@angular/cdk/drag-drop` | 내장 모듈 |
| **Next.js** | MUI | `@minoru/react-dnd-treeview` | React와 동일 |

#### 설치 전 확인 (CRITICAL)

```bash
# 1. 프로젝트 환경 확인
cat frontend/package.json | grep -E '"react"|"vue"|"@angular"'

# 2. UI 라이브러리 확인
cat frontend/package.json | grep -E '"@mui|"antd"|"element-plus"|"vuetify"|"bootstrap"'

# 3. 이미 설치된 DnD 라이브러리 확인
cat frontend/package.json | grep -E '"react-dnd"|"vuedraggable"|"sortable"|"dnd"'
```

#### React + MUI (완전한 구현 - MUST COPY)

> **CRITICAL**: 아래 코드를 그대로 복사하여 사용하세요. 수정 시 드래그앤드롭이 작동하지 않을 수 있습니다.

```tsx
// components/admin/menu/MenuTree.tsx
import { useState, useCallback } from 'react';
import { Tree, NodeModel, DragLayerMonitorProps } from '@minoru/react-dnd-treeview';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { Box, Tabs, Tab, Button, Typography, CircularProgress } from '@mui/material';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import FolderIcon from '@mui/icons-material/Folder';
import FolderOpenIcon from '@mui/icons-material/FolderOpen';
import DescriptionIcon from '@mui/icons-material/Description';
import AddIcon from '@mui/icons-material/Add';
import { reorderMenus, moveMenu, fetchMenuTree } from '@/lib/api/menuApi';
import type { Menu, MenuTreeNode } from '@/types/menu';

interface MenuTreeProps {
  onSelect: (menu: Menu | null, isNewMenu?: boolean) => void;  // CRITICAL: isNewMenu 파라미터 추가
  onMenuTypeChange?: (menuType: string) => void;  // 메뉴 타입 변경 콜백
  selectedId?: number;
}

export function MenuTree({ onSelect, onMenuTypeChange, selectedId }: MenuTreeProps) {
  const [menuType, setMenuType] = useState<string>('site');
  const queryClient = useQueryClient();

  // 메뉴 트리 데이터 조회
  const { data: treeData = [], isLoading, error } = useQuery({
    queryKey: ['admin-menus', menuType],
    queryFn: () => fetchMenuTree(menuType),
  });

  // 순서 변경 뮤테이션
  const reorderMutation = useMutation({
    mutationFn: ({ parentId, orderedIds }: { parentId: number | null; orderedIds: number[] }) =>
      reorderMenus(menuType, parentId, orderedIds),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-menus', menuType] });
    },
    onError: (error) => {
      console.error('순서 변경 실패:', error);
      alert('순서 변경에 실패했습니다. 다시 시도해주세요.');
      queryClient.invalidateQueries({ queryKey: ['admin-menus', menuType] });
    },
  });

  // 메뉴 이동 뮤테이션
  const moveMutation = useMutation({
    mutationFn: ({ menuId, newParentId, newIndex }: { menuId: number; newParentId: number | null; newIndex: number }) =>
      moveMenu(menuId, newParentId, newIndex),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-menus', menuType] });
    },
    onError: (error) => {
      console.error('메뉴 이동 실패:', error);
      alert('메뉴 이동에 실패했습니다. 다시 시도해주세요.');
      queryClient.invalidateQueries({ queryKey: ['admin-menus', menuType] });
    },
  });

  // 드롭 핸들러 (CRITICAL - 이 로직을 수정하지 마세요)
  const handleDrop = useCallback(
    (newTree: NodeModel<Menu>[], options: { dragSourceId: string | number; dropTargetId: string | number; destinationIndex: number }) => {
      const { dragSourceId, dropTargetId, destinationIndex } = options;

      // 드래그한 노드 찾기
      const draggedNode = treeData.find((node) => node.id === dragSourceId);
      if (!draggedNode) return;

      const oldParentId = draggedNode.parent;
      const newParentId = dropTargetId === 0 ? null : Number(dropTargetId);

      // 같은 부모 내에서 순서 변경
      if (oldParentId === (newParentId ?? 0)) {
        const siblings = newTree
          .filter((node) => node.parent === (newParentId ?? 0))
          .map((node) => Number(node.id));

        reorderMutation.mutate({
          parentId: newParentId,
          orderedIds: siblings,
        });
      }
      // 다른 부모로 이동
      else {
        moveMutation.mutate({
          menuId: Number(dragSourceId),
          newParentId: newParentId,
          newIndex: destinationIndex,
        });
      }
    },
    [treeData, menuType, reorderMutation, moveMutation]
  );

  // 트리 노드 렌더링
  const renderNode = useCallback(
    (node: NodeModel<Menu>, { depth, isOpen, onToggle }: { depth: number; isOpen: boolean; onToggle: () => void }) => {
      const hasChildren = treeData.some((n) => n.parent === node.id);
      const isSelected = node.id === selectedId;

      return (
        <Box
          onClick={() => onSelect(node.data ?? null, false)}  // 수정 모드
          sx={{
            display: 'flex',
            alignItems: 'center',
            py: 0.5,
            px: 1,
            ml: depth * 2,
            cursor: 'pointer',
            borderRadius: 1,
            bgcolor: isSelected ? 'primary.light' : 'transparent',
            '&:hover': { bgcolor: isSelected ? 'primary.light' : 'action.hover' },
          }}
        >
          {/* 펼침/접힘 아이콘 */}
          <Box
            onClick={(e) => { e.stopPropagation(); onToggle(); }}
            sx={{ mr: 0.5, display: 'flex', cursor: 'pointer' }}
          >
            {hasChildren ? (
              isOpen ? <FolderOpenIcon color="primary" /> : <FolderIcon color="primary" />
            ) : (
              <DescriptionIcon color="action" />
            )}
          </Box>

          {/* 메뉴명 */}
          <Typography
            variant="body2"
            sx={{ fontWeight: isSelected ? 600 : 400, color: isSelected ? 'primary.main' : 'text.primary' }}
          >
            {node.text}
          </Typography>
        </Box>
      );
    },
    [treeData, selectedId, onSelect]
  );

  // 드래그 프리뷰
  const dragPreviewRender = (monitorProps: DragLayerMonitorProps<Menu>) => (
    <Box sx={{ p: 1, bgcolor: 'background.paper', borderRadius: 1, boxShadow: 2 }}>
      <Typography variant="body2">{monitorProps.item.text}</Typography>
    </Box>
  );

  if (isLoading) return <CircularProgress />;
  if (error) return <Typography color="error">메뉴 로딩 실패</Typography>;

  return (
    <Box sx={{ height: '100%', display: 'flex', flexDirection: 'column' }}>
      {/* 메뉴 타입 탭 */}
      <Tabs
        value={menuType}
        onChange={(_, v) => {
          setMenuType(v);
          onSelect(null, false);         // 메뉴 선택 해제
          onMenuTypeChange?.(v);          // 상위 컴포넌트에 메뉴 타입 알림
        }}
        sx={{ borderBottom: 1, borderColor: 'divider' }}
      >
        <Tab label="사이트" value="site" />
        <Tab label="사용자" value="user" />
        <Tab label="관리자" value="admin" />
      </Tabs>

      {/* 드래그앤드롭 트리 */}
      <Box sx={{ flex: 1, overflow: 'auto', p: 1 }}>
        <DndProvider backend={HTML5Backend}>
          <Tree
            tree={treeData}
            rootId={0}
            onDrop={handleDrop}
            render={renderNode}
            dragPreviewRender={dragPreviewRender}
            sort={false}
            insertDroppableFirst={false}
            canDrop={(tree, { dragSource, dropTargetId }) => {
              // 자기 자신이나 하위로 드롭 금지
              if (dragSource?.parent === dropTargetId) return true;
              return true;
            }}
            dropTargetOffset={5}
            placeholderRender={(node, { depth }) => (
              <Box sx={{ ml: depth * 2, height: 2, bgcolor: 'primary.main', borderRadius: 1 }} />
            )}
          />
        </DndProvider>
      </Box>

      {/* 새 메뉴 추가 버튼 - CRITICAL: isNewMenu = true 전달 */}
      <Button
        startIcon={<AddIcon />}
        onClick={() => onSelect({ menu_type: menuType } as Menu, true)}
        sx={{ m: 2 }}
        variant="outlined"
      >
        새 메뉴 추가
      </Button>
    </Box>
  );
}
```

#### 필수 패키지 설치

```bash
npm install @minoru/react-dnd-treeview react-dnd react-dnd-html5-backend @tanstack/react-query
```

#### Vue 3 + Element Plus (완전한 구현)

```vue
<!-- components/admin/menu/MenuTree.vue -->
<template>
  <div class="menu-tree">
    <!-- 메뉴 타입 탭 -->
    <el-tabs v-model="menuType" @tab-change="handleTabChange">
      <el-tab-pane label="사이트" name="site" />
      <el-tab-pane label="사용자" name="user" />
      <el-tab-pane label="관리자" name="admin" />
    </el-tabs>

    <!-- 로딩 -->
    <el-skeleton v-if="loading" :rows="5" animated />

    <!-- 트리 (드래그앤드롭 지원) -->
    <el-tree
      v-else
      ref="treeRef"
      :data="menus"
      :props="{ label: 'menu_name', children: 'children' }"
      draggable
      :allow-drag="allowDrag"
      :allow-drop="allowDrop"
      @node-drop="handleDrop"
      @node-click="handleSelect"
      node-key="id"
      :highlight-current="true"
      :default-expand-all="true"
      :expand-on-click-node="false"
    >
      <template #default="{ node, data }">
        <span class="tree-node" :class="{ selected: data.id === selectedId }">
          <el-icon v-if="data.children?.length" class="folder-icon">
            <FolderOpened v-if="node.expanded" />
            <Folder v-else />
          </el-icon>
          <el-icon v-else class="file-icon">
            <Document />
          </el-icon>
          <span class="node-label">{{ node.label }}</span>
        </span>
      </template>
    </el-tree>

    <!-- 새 메뉴 추가 -->
    <el-button @click="handleAddNew" type="primary" plain style="margin: 16px; width: calc(100% - 32px)">
      <el-icon><Plus /></el-icon>
      새 메뉴 추가
    </el-button>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Folder, FolderOpened, Document, Plus } from '@element-plus/icons-vue'
import type { Menu } from '@/types/menu'
import { fetchMenuTree, reorderMenus, moveMenu } from '@/api/menu'

interface Props {
  selectedId?: number
}

const props = defineProps<Props>()

const emit = defineEmits<{
  (e: 'select', menu: Menu | null, isNewMenu: boolean): void  // CRITICAL: isNewMenu 추가
  (e: 'menu-type-change', menuType: string): void  // 메뉴 타입 변경 이벤트
}>()

const menuType = ref('site')
const menus = ref<Menu[]>([])
const loading = ref(false)
const treeRef = ref()

// 메뉴 목록 조회
const loadMenus = async () => {
  loading.value = true
  try {
    menus.value = await fetchMenuTree(menuType.value)
  } catch (error) {
    ElMessage.error('메뉴 목록을 불러오는데 실패했습니다.')
  } finally {
    loading.value = false
  }
}

// 탭 변경
const handleTabChange = () => {
  emit('select', null, false)  // 메뉴 선택 해제
  emit('menu-type-change', menuType.value)  // 메뉴 타입 변경 알림
  loadMenus()
}

// 드래그 허용 조건
const allowDrag = (draggingNode: any) => {
  return true
}

// 드롭 허용 조건
const allowDrop = (draggingNode: any, dropNode: any, type: string) => {
  // 자기 자신의 하위로 드롭 금지
  if (type === 'inner') {
    return dropNode.data.id !== draggingNode.data.id
  }
  return true
}

// 드롭 핸들러 (CRITICAL)
const handleDrop = async (draggingNode: any, dropNode: any, dropType: string) => {
  try {
    const draggedMenu = draggingNode.data
    const targetMenu = dropNode.data

    if (dropType === 'inner') {
      // 다른 부모로 이동 (폴더 안으로)
      await moveMenu(draggedMenu.id, targetMenu.id, 0)
      ElMessage.success('메뉴가 이동되었습니다.')
    } else {
      // 같은 레벨에서 순서 변경
      const parentId = dropNode.parent?.data?.id || null
      const siblings = dropNode.parent?.childNodes || treeRef.value?.root?.childNodes || []
      const orderedIds = siblings.map((node: any) => node.data.id)

      await reorderMenus(menuType.value, parentId, orderedIds)
      ElMessage.success('순서가 변경되었습니다.')
    }

    // 목록 새로고침
    await loadMenus()
  } catch (error) {
    ElMessage.error('변경에 실패했습니다. 다시 시도해주세요.')
    await loadMenus() // 롤백을 위해 다시 로드
  }
}

// 메뉴 선택 (수정 모드)
const handleSelect = (data: Menu) => {
  emit('select', data, false)  // isNewMenu = false
}

// 새 메뉴 추가 - CRITICAL: isNewMenu = true 전달
const handleAddNew = () => {
  emit('select', { menu_type: menuType.value } as Menu, true)  // isNewMenu = true
}

onMounted(() => {
  loadMenus()
})
</script>

<style scoped>
.menu-tree {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.tree-node {
  display: flex;
  align-items: center;
  padding: 4px 8px;
  border-radius: 4px;
}

.tree-node.selected {
  background-color: var(--el-color-primary-light-9);
}

.tree-node:hover {
  background-color: var(--el-fill-color-light);
}

.folder-icon {
  color: var(--el-color-primary);
  margin-right: 6px;
}

.file-icon {
  color: var(--el-text-color-secondary);
  margin-right: 6px;
}

.node-label {
  font-size: 14px;
}
</style>
```

#### Vue API 클라이언트

```typescript
// api/menu.ts
import request from '@/utils/request'

export async function fetchMenuTree(menuType: string) {
  const { data } = await request.get(`/api/admin/menus/tree?type=${menuType}`)
  return data
}

export async function reorderMenus(menuType: string, parentId: number | null, orderedIds: number[]) {
  await request.put('/api/admin/menus/reorder', { menuType, parentId, orderedIds })
}

export async function moveMenu(menuId: number, newParentId: number | null, newIndex: number) {
  await request.put(`/api/admin/menus/${menuId}/move`, { newParentId, newIndex })
}
```

#### Ant Design Tree (드래그앤드롭 내장)

```tsx
// components/admin/menu/MenuTree.tsx (Ant Design)
import { Tree } from 'antd';
import type { DataNode, TreeProps } from 'antd/es/tree';
import { FolderOutlined, FileOutlined, PlusOutlined } from '@ant-design/icons';

export function MenuTree({ onSelect, selectedId }: MenuTreeProps) {
  const { data: menus } = useQuery(['admin-menus'], fetchMenuTree);

  const onDrop: TreeProps['onDrop'] = async (info) => {
    const dragKey = info.dragNode.key;
    const dropKey = info.node.key;
    const dropPos = info.node.pos.split('-');
    const dropPosition = info.dropPosition - Number(dropPos[dropPos.length - 1]);

    await reorderMenus(dragKey, dropKey, dropPosition);
  };

  return (
    <div>
      <Tree
        showIcon
        draggable
        onDrop={onDrop}
        onSelect={(keys) => onSelect(findMenu(keys[0]))}
        selectedKeys={[selectedId]}
        treeData={menus}
        icon={(nodeProps) =>
          nodeProps.children ? <FolderOutlined /> : <FileOutlined />
        }
      />
    </div>
  );
}
```

### 상세 패널 (인라인 편집) - 완전한 구현 (MUST COPY)

> **CRITICAL**: 아래 코드를 그대로 복사하여 사용하세요. 모든 필드가 포함되어 있습니다.

```tsx
// components/admin/menu/MenuDetailPanel.tsx
import { useState, useEffect } from 'react';
import {
  Paper, Typography, Grid, TextField, Button, Box,
  FormControl, InputLabel, Select, MenuItem, Switch,
  FormControlLabel, Collapse, Alert, Accordion, AccordionSummary,
  AccordionDetails, Autocomplete, Chip, CircularProgress
} from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { saveMenu, deleteMenu, fetchMenuTree } from '@/lib/api/menuApi';
import { fetchUserGroups, fetchRoles } from '@/lib/api/commonApi';
import type { Menu } from '@/types/menu';

interface MenuDetailPanelProps {
  menu: Menu | null;          // 선택된 메뉴 (null일 수 있음)
  isAddMode: boolean;         // 새 메뉴 추가 모드 여부 (CRITICAL)
  defaultMenuType?: string;   // 추가 모드에서 기본 메뉴 타입
  onSuccess: () => void;
  onCancel: () => void;
}

// CRITICAL: isAddMode를 반드시 전달받아야 함
// menu가 null이고 isAddMode가 true면 새 메뉴 추가 폼 표시
// menu가 있고 isAddMode가 false면 메뉴 수정 폼 표시
export function MenuDetailPanel({ menu, isAddMode, defaultMenuType = 'site', onSuccess, onCancel }: MenuDetailPanelProps) {
  const queryClient = useQueryClient();

  // CRITICAL: isAddMode와 menu 상태에 따른 초기값 설정
  const getInitialFormData = (): Partial<Menu> => {
    if (isAddMode) {
      // 새 메뉴 추가 모드: 빈 폼 데이터
      return {
        menu_type: defaultMenuType,
        parent_id: null,
        menu_name: '',
        menu_code: '',
        icon: '',
        description: '',
        link_type: 'url',
        link_url: '',
        permission_type: 'public',
        is_active: true,
        is_visible: true,
        open_new_window: false,
      };
    }
    // 수정 모드: 기존 메뉴 데이터
    return menu || {};
  };

  const [formData, setFormData] = useState<Partial<Menu>>(getInitialFormData);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  // 부모 메뉴 목록 조회
  const { data: parentMenus = [] } = useQuery({
    queryKey: ['parent-menus', formData.menu_type],
    queryFn: () => fetchMenuTree(formData.menu_type || defaultMenuType),
    enabled: !!formData.menu_type,
  });

  // 사용자 그룹 목록
  const { data: userGroups = [] } = useQuery({
    queryKey: ['user-groups'],
    queryFn: fetchUserGroups,
  });

  // 역할 목록
  const { data: roles = [] } = useQuery({
    queryKey: ['roles'],
    queryFn: fetchRoles,
  });

  // 메뉴 저장
  const saveMutation = useMutation({
    mutationFn: (data: Partial<Menu>) => saveMenu(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-menus'] });
      onSuccess();
    },
    onError: (error: any) => {
      setErrors({ submit: error.response?.data?.error || '저장에 실패했습니다.' });
    },
  });

  // 메뉴 삭제
  const deleteMutation = useMutation({
    mutationFn: (id: number) => deleteMenu(id, false),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-menus'] });
      onSuccess();
    },
    onError: (error: any) => {
      setErrors({ submit: error.response?.data?.error || '삭제에 실패했습니다.' });
    },
  });

  // CRITICAL: isAddMode 또는 menu 변경 시 폼 초기화
  useEffect(() => {
    setFormData(getInitialFormData());
    setErrors({});
    setShowDeleteConfirm(false);
  }, [menu, isAddMode, defaultMenuType]);

  // 필드 업데이트 핸들러
  const handleChange = (field: keyof Menu, value: any) => {
    setFormData(prev => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors(prev => ({ ...prev, [field]: '' }));
    }
  };

  // 유효성 검사
  const validate = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.menu_name?.trim()) {
      newErrors.menu_name = '메뉴명을 입력하세요.';
    }
    if (!formData.menu_code?.trim()) {
      newErrors.menu_code = '메뉴 코드를 입력하세요.';
    } else if (!/^[a-z0-9_]+$/.test(formData.menu_code)) {
      newErrors.menu_code = '영문 소문자, 숫자, 언더스코어만 사용 가능합니다.';
    }
    if (formData.link_type === 'url' && !formData.link_url?.trim()) {
      newErrors.link_url = 'URL을 입력하세요.';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  // 저장 핸들러
  const handleSave = () => {
    if (!validate()) return;
    saveMutation.mutate(formData);
  };

  // 삭제 핸들러 (수정 모드에서만 동작)
  const handleDelete = () => {
    if (!isAddMode && menu?.id) {
      deleteMutation.mutate(menu.id);
    }
  };

  const isLoading = saveMutation.isPending || deleteMutation.isPending;

  return (
    <Paper sx={{ p: 3, height: '100%', overflow: 'auto' }}>
      {/* 헤더 */}
      <Typography variant="h6" gutterBottom>
        {isAddMode ? '새 메뉴 추가' : '메뉴 수정'}
      </Typography>

      {/* 에러 메시지 */}
      {errors.submit && (
        <Alert severity="error" sx={{ mb: 2 }}>{errors.submit}</Alert>
      )}

      {/* 기본 정보 */}
      <Accordion defaultExpanded>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography fontWeight={600}>기본 정보</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Grid container spacing={2}>
            <Grid item xs={6}>
              <TextField
                label="메뉴명"
                value={formData.menu_name || ''}
                onChange={(e) => handleChange('menu_name', e.target.value)}
                fullWidth
                required
                error={!!errors.menu_name}
                helperText={errors.menu_name}
              />
            </Grid>
            <Grid item xs={6}>
              <TextField
                label="메뉴 코드"
                value={formData.menu_code || ''}
                onChange={(e) => handleChange('menu_code', e.target.value.toLowerCase())}
                fullWidth
                required
                error={!!errors.menu_code}
                helperText={errors.menu_code || '영문 소문자, 숫자, 언더스코어'}
                disabled={!!menu.id}
              />
            </Grid>
            <Grid item xs={6}>
              <FormControl fullWidth>
                <InputLabel>상위 메뉴</InputLabel>
                <Select
                  value={formData.parent_id || ''}
                  onChange={(e) => handleChange('parent_id', e.target.value || null)}
                  label="상위 메뉴"
                >
                  <MenuItem value="">없음 (최상위)</MenuItem>
                  {parentMenus
                    .filter((m: any) => m.id !== menu.id)
                    .map((m: any) => (
                      <MenuItem key={m.id} value={m.id}>
                        {'　'.repeat(m.depth || 0)}{m.text || m.menu_name}
                      </MenuItem>
                    ))}
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={6}>
              <TextField
                label="아이콘"
                value={formData.icon || ''}
                onChange={(e) => handleChange('icon', e.target.value)}
                fullWidth
                placeholder="mdi-home, mdi-account 등"
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                label="설명"
                value={formData.description || ''}
                onChange={(e) => handleChange('description', e.target.value)}
                fullWidth
                multiline
                rows={2}
              />
            </Grid>
          </Grid>
        </AccordionDetails>
      </Accordion>

      {/* 링크 설정 */}
      <Accordion defaultExpanded>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography fontWeight={600}>링크 설정</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Grid container spacing={2}>
            <Grid item xs={6}>
              <FormControl fullWidth>
                <InputLabel>링크 타입</InputLabel>
                <Select
                  value={formData.link_type || 'url'}
                  onChange={(e) => handleChange('link_type', e.target.value)}
                  label="링크 타입"
                >
                  <MenuItem value="url">일반 URL</MenuItem>
                  <MenuItem value="new_window">새 창</MenuItem>
                  <MenuItem value="external">외부 링크</MenuItem>
                  <MenuItem value="modal">모달</MenuItem>
                  <MenuItem value="none">링크 없음</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={6}>
              <TextField
                label="URL / 라우트"
                value={formData.link_url || ''}
                onChange={(e) => handleChange('link_url', e.target.value)}
                fullWidth
                error={!!errors.link_url}
                helperText={errors.link_url}
                placeholder="/about, /products"
              />
            </Grid>
            {formData.link_type === 'external' && (
              <Grid item xs={12}>
                <TextField
                  label="외부 URL"
                  value={formData.external_url || ''}
                  onChange={(e) => handleChange('external_url', e.target.value)}
                  fullWidth
                  placeholder="https://example.com"
                />
              </Grid>
            )}
            <Grid item xs={12}>
              <TextField
                label="가상 경로 (SEO)"
                value={formData.virtual_path || ''}
                onChange={(e) => handleChange('virtual_path', e.target.value)}
                fullWidth
                placeholder="/company/about"
              />
            </Grid>
          </Grid>
        </AccordionDetails>
      </Accordion>

      {/* 권한 설정 */}
      <Accordion>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography fontWeight={600}>권한 설정</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Grid container spacing={2}>
            <Grid item xs={6}>
              <FormControl fullWidth>
                <InputLabel>접근 권한</InputLabel>
                <Select
                  value={formData.permission_type || 'public'}
                  onChange={(e) => handleChange('permission_type', e.target.value)}
                  label="접근 권한"
                >
                  <MenuItem value="public">전체 공개</MenuItem>
                  <MenuItem value="member">회원만</MenuItem>
                  <MenuItem value="groups">특정 그룹</MenuItem>
                  <MenuItem value="roles">특정 역할</MenuItem>
                  <MenuItem value="admin">관리자만</MenuItem>
                </Select>
              </FormControl>
            </Grid>
            <Grid item xs={6}>
              <FormControl fullWidth>
                <InputLabel>표시 조건</InputLabel>
                <Select
                  value={formData.show_condition || 'always'}
                  onChange={(e) => handleChange('show_condition', e.target.value)}
                  label="표시 조건"
                >
                  <MenuItem value="always">항상 표시</MenuItem>
                  <MenuItem value="logged_in">로그인 시만</MenuItem>
                  <MenuItem value="logged_out">로그아웃 시만</MenuItem>
                </Select>
              </FormControl>
            </Grid>
          </Grid>
        </AccordionDetails>
      </Accordion>

      {/* 표시 설정 */}
      <Accordion>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography fontWeight={600}>표시 설정</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Grid container spacing={2}>
            <Grid item xs={4}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.is_visible !== false}
                    onChange={(e) => handleChange('is_visible', e.target.checked)}
                  />
                }
                label="메뉴 표시"
              />
            </Grid>
            <Grid item xs={4}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.is_enabled !== false}
                    onChange={(e) => handleChange('is_enabled', e.target.checked)}
                  />
                }
                label="메뉴 활성화"
              />
            </Grid>
            <Grid item xs={4}>
              <FormControlLabel
                control={
                  <Switch
                    checked={formData.highlight === true}
                    onChange={(e) => handleChange('highlight', e.target.checked)}
                  />
                }
                label="강조 표시"
              />
            </Grid>
            {formData.highlight && (
              <>
                <Grid item xs={6}>
                  <TextField
                    label="강조 텍스트"
                    value={formData.highlight_text || ''}
                    onChange={(e) => handleChange('highlight_text', e.target.value)}
                    fullWidth
                    placeholder="NEW, HOT"
                  />
                </Grid>
                <Grid item xs={6}>
                  <TextField
                    label="강조 색상"
                    value={formData.highlight_color || ''}
                    onChange={(e) => handleChange('highlight_color', e.target.value)}
                    fullWidth
                    placeholder="#ff0000"
                  />
                </Grid>
              </>
            )}
          </Grid>
        </AccordionDetails>
      </Accordion>

      {/* SEO 설정 */}
      <Accordion>
        <AccordionSummary expandIcon={<ExpandMoreIcon />}>
          <Typography fontWeight={600}>SEO 설정</Typography>
        </AccordionSummary>
        <AccordionDetails>
          <Grid container spacing={2}>
            <Grid item xs={12}>
              <TextField
                label="SEO 제목"
                value={formData.seo_title || ''}
                onChange={(e) => handleChange('seo_title', e.target.value)}
                fullWidth
              />
            </Grid>
            <Grid item xs={12}>
              <TextField
                label="SEO 설명"
                value={formData.seo_description || ''}
                onChange={(e) => handleChange('seo_description', e.target.value)}
                fullWidth
                multiline
                rows={2}
              />
            </Grid>
          </Grid>
        </AccordionDetails>
      </Accordion>

      {/* 버튼 영역 */}
      <Box sx={{ mt: 3, display: 'flex', gap: 1, flexWrap: 'wrap' }}>
        <Button
          variant="contained"
          onClick={handleSave}
          disabled={isLoading}
          startIcon={isLoading ? <CircularProgress size={16} /> : null}
        >
          {isLoading ? '저장 중...' : '저장'}
        </Button>
        <Button variant="outlined" onClick={onCancel} disabled={isLoading}>
          취소
        </Button>

        {/* 삭제 버튼은 수정 모드에서만 표시 */}
        {!isAddMode && menu?.id && (
          <>
            <Box sx={{ flex: 1 }} />
            <Button
              color="error"
              onClick={() => setShowDeleteConfirm(true)}
              disabled={isLoading}
            >
              삭제
            </Button>
          </>
        )}
      </Box>

      {/* 인라인 삭제 확인 (모달 아님!) */}
      <Collapse in={showDeleteConfirm}>
        <Alert
          severity="warning"
          sx={{ mt: 2 }}
          action={
            <Box sx={{ display: 'flex', gap: 1 }}>
              <Button size="small" color="inherit" onClick={handleDelete} disabled={isLoading}>
                삭제 확인
              </Button>
              <Button size="small" color="inherit" onClick={() => setShowDeleteConfirm(false)}>
                취소
              </Button>
            </Box>
          }
        >
          정말 이 메뉴를 삭제하시겠습니까?
        </Alert>
      </Collapse>
    </Paper>
  );
}
```

### 메인 페이지 (트리 + 상세 패널 통합)

```tsx
// pages/admin/menus/index.tsx
import { useState, useCallback } from 'react';
import { Box } from '@mui/material';
import { MenuTree } from '@/components/admin/menu/MenuTree';
import { MenuDetailPanel } from '@/components/admin/menu/MenuDetailPanel';
import type { Menu } from '@/types/menu';

export default function MenuManagementPage() {
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);
  const [isAddMode, setIsAddMode] = useState(false);  // CRITICAL: 추가 모드 상태
  const [currentMenuType, setCurrentMenuType] = useState<string>('site');

  // CRITICAL: 메뉴 선택 핸들러
  // isNewMenu가 true면 새 메뉴 추가 모드
  const handleSelectMenu = useCallback((menu: Menu | null, isNewMenu = false) => {
    if (isNewMenu) {
      // 새 메뉴 추가 모드
      setSelectedMenu(null);
      setIsAddMode(true);
      if (menu?.menu_type) {
        setCurrentMenuType(menu.menu_type);
      }
    } else {
      // 기존 메뉴 선택 (수정 모드)
      setSelectedMenu(menu);
      setIsAddMode(false);
    }
  }, []);

  // 성공 핸들러: 폼 닫기
  const handleSuccess = useCallback(() => {
    setSelectedMenu(null);
    setIsAddMode(false);
  }, []);

  // 취소 핸들러: 폼 닫기
  const handleCancel = useCallback(() => {
    setSelectedMenu(null);
    setIsAddMode(false);
  }, []);

  // 메뉴 타입 변경 핸들러
  const handleMenuTypeChange = useCallback((menuType: string) => {
    setCurrentMenuType(menuType);
  }, []);

  // 패널 표시 여부: 메뉴 선택됨 OR 추가 모드
  const showPanel = selectedMenu !== null || isAddMode;

  return (
    <Box sx={{ display: 'flex', height: 'calc(100vh - 64px)' }}>
      {/* 좌측: 메뉴 트리 (280px) */}
      <Box sx={{ width: 280, borderRight: 1, borderColor: 'divider', overflow: 'hidden' }}>
        <MenuTree
          onSelect={handleSelectMenu}
          onMenuTypeChange={handleMenuTypeChange}
          selectedId={selectedMenu?.id}
        />
      </Box>

      {/* 우측: 상세 패널 */}
      <Box sx={{ flex: 1, overflow: 'hidden' }}>
        {showPanel ? (
          <MenuDetailPanel
            menu={selectedMenu}
            isAddMode={isAddMode}           // CRITICAL: 추가 모드 전달
            defaultMenuType={currentMenuType}
            onSuccess={handleSuccess}
            onCancel={handleCancel}
          />
        ) : (
          <Box sx={{ p: 4, textAlign: 'center', color: 'text.secondary' }}>
            좌측 트리에서 메뉴를 선택하거나<br />
            "새 메뉴 추가" 버튼을 클릭하세요.
          </Box>
        )}
      </Box>
    </Box>
  );
}
```

**CRITICAL: isAddMode 패턴 필수 사용**

새 메뉴 추가 시 반드시 `isAddMode` 상태를 사용해야 합니다.
`{ id: 0 }` 객체를 전달하는 방식은 JavaScript의 falsy 체크 문제로 버그가 발생합니다.

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
