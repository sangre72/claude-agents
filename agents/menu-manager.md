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

### user_groups (사용자 그룹)

```sql
CREATE TABLE user_groups (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  group_name VARCHAR(100) NOT NULL,           -- 그룹명
  group_code VARCHAR(50) NOT NULL UNIQUE,     -- 그룹 코드
  description VARCHAR(500),                   -- 설명
  priority INT DEFAULT 0,                     -- 우선순위 (높을수록 상위)

  -- 그룹 타입
  group_type ENUM('system', 'custom') DEFAULT 'custom',
  -- system: 시스템 기본 그룹 (수정 불가)
  -- custom: 관리자 생성 그룹

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE
);

-- 기본 그룹 INSERT
INSERT INTO user_groups (group_name, group_code, priority, group_type, created_by) VALUES
('전체 회원', 'all_members', 0, 'system', 'system'),
('일반 회원', 'regular', 10, 'system', 'system'),
('VIP 회원', 'vip', 50, 'system', 'system'),
('프리미엄 회원', 'premium', 80, 'system', 'system');
```

### user_group_members (사용자-그룹 매핑)

```sql
CREATE TABLE user_group_members (
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
CREATE TABLE roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(100) NOT NULL,            -- 역할명
  role_code VARCHAR(50) NOT NULL UNIQUE,      -- 역할 코드
  description VARCHAR(500),                   -- 설명
  priority INT DEFAULT 0,                     -- 우선순위

  -- 역할 범위
  role_scope ENUM('admin', 'user', 'both') DEFAULT 'both',
  -- admin: 관리자 전용
  -- user: 사용자 전용
  -- both: 모두 사용

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE
);

-- 기본 역할 INSERT
INSERT INTO roles (role_name, role_code, priority, role_scope, created_by) VALUES
('슈퍼관리자', 'super_admin', 100, 'admin', 'system'),
('관리자', 'admin', 50, 'admin', 'system'),
('매니저', 'manager', 30, 'admin', 'system'),
('에디터', 'editor', 20, 'both', 'system'),
('뷰어', 'viewer', 10, 'both', 'system');
```

### user_roles (사용자-역할 매핑)

```sql
CREATE TABLE user_roles (
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

## 기본 메뉴 데이터

### 헤더 유틸리티

```sql
INSERT INTO menus (menu_type, menu_name, menu_code, link_type, link_url, show_condition, sort_order, created_by) VALUES
('header_utility', '로그인', 'login', 'url', '/login', 'logged_out', 1, 'system'),
('header_utility', '회원가입', 'register', 'url', '/register', 'logged_out', 2, 'system'),
('header_utility', '마이페이지', 'mypage', 'url', '/mypage', 'logged_in', 3, 'system'),
('header_utility', '장바구니', 'cart', 'url', '/cart', 'logged_in', 4, 'system'),
('header_utility', '로그아웃', 'logout', 'url', '/logout', 'logged_in', 5, 'system');
```

### 푸터 유틸리티

```sql
INSERT INTO menus (menu_type, menu_name, menu_code, link_type, link_url, sort_order, created_by) VALUES
('footer_utility', '이용약관', 'terms', 'url', '/terms', 1, 'system'),
('footer_utility', '개인정보처리방침', 'privacy', 'url', '/privacy', 2, 'system'),
('footer_utility', '사이트맵', 'sitemap', 'url', '/sitemap', 3, 'system'),
('footer_utility', '관련사이트', 'related_sites', 'none', NULL, 4, 'system');
```

### 관리자 메뉴

```sql
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, permission_type, sort_order, created_by) VALUES
('admin', '대시보드', 'dashboard', 'mdi-view-dashboard', 'url', '/admin', 'admin', 1, 'system'),
('admin', '사용자관리', 'users', 'mdi-account-group', 'none', NULL, 'admin', 2, 'system'),
('admin', '메뉴관리', 'menus', 'mdi-menu', 'url', '/admin/menus', 'admin', 3, 'system'),
('admin', '그룹관리', 'groups', 'mdi-account-multiple', 'url', '/admin/groups', 'admin', 4, 'system'),
('admin', '시스템설정', 'settings', 'mdi-cog', 'url', '/admin/settings', 'admin', 5, 'system');
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
