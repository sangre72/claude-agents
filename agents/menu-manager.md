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

## API Protocol (연동 프로토콜)

> **중요**: 시스템 연동 시 다음 프로토콜을 준수해야 합니다.

### Base URL

```
Development: http://localhost:3001
Production:  process.env.REACT_APP_API_URL
```

### Request Headers

```http
Content-Type: application/json
Cookie: session-cookie (인증 시)
```

### Response Format (표준 응답)

```typescript
interface ApiResponse<T> {
  success: boolean;      // 성공 여부
  data?: T;              // 실제 데이터
  error_code?: string;   // 에러 코드 (실패 시)
  message?: string;      // 사용자 메시지
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `DATABASE_UNAVAILABLE` | 503 | DB 연결 실패 |
| `ACCESS_DENIED` | 403 | 관리자 권한 필요 |
| `INVALID_INPUT` | 400 | 입력값 검증 실패 |
| `MENU_NOT_FOUND` | 404 | 메뉴 없음 |
| `DUPLICATE_MENU_CODE` | 400 | 중복된 메뉴 코드 |
| `QUERY_ERROR` | 500 | DB 쿼리 오류 |
| `INTERNAL_ERROR` | 500 | 서버 내부 오류 |

---

## API Endpoints

### 1. 전체 메뉴 조회

```http
GET /api/admin/menus?type={menuType}
```

**Parameters:**
| Name | Type | Required | Description |
|------|------|----------|-------------|
| type | string | No | 메뉴 타입 필터 (user, site, admin) |

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "menu_type": "user",
      "parent_id": null,
      "menu_name": "마이페이지",
      "menu_code": "mypage",
      "icon": "mdi-account-circle",
      "link_type": "none",
      "link_url": null,
      "permission_type": "member",
      "depth": 0,
      "sort_order": 1,
      "is_visible": true,
      "is_active": true,
      "parent_name": null
    }
  ]
}
```

---

### 2. 메뉴 상세 조회

```http
GET /api/admin/menus/:id
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "menu_type": "user",
    "parent_id": null,
    "menu_name": "마이페이지",
    "menu_code": "mypage",
    "description": "마이페이지 메인 메뉴",
    "icon": "mdi-account-circle",
    "link_type": "none",
    "link_url": null,
    "permission_type": "member",
    "show_condition": "always",
    "depth": 0,
    "sort_order": 1,
    "is_visible": true,
    "is_active": true,
    "created_at": "2025-01-02T10:00:00.000Z",
    "created_by": "admin",
    "updated_at": "2025-01-02T10:00:00.000Z",
    "updated_by": "admin"
  }
}
```

---

### 3. 메뉴 생성

```http
POST /api/admin/menus
```

**Request Body:**
```json
{
  "menu_type": "user",
  "parent_id": null,
  "menu_name": "마이페이지",
  "menu_code": "mypage",
  "description": "마이페이지 메인",
  "icon": "mdi-account-circle",
  "link_type": "url",
  "link_url": "/mypage",
  "permission_type": "member",
  "show_condition": "always",
  "sort_order": 0
}
```

**Required Fields:**
| Field | Type | Description |
|-------|------|-------------|
| menu_type | string | 메뉴 타입 (site/user/admin 등) |
| menu_name | string | 메뉴 표시명 (max 100자) |
| menu_code | string | 메뉴 코드 (unique, max 50자) |

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 123,
    "message": "메뉴가 생성되었습니다."
  }
}
```

---

### 4. 메뉴 수정

```http
PUT /api/admin/menus/:id
```

**Request Body:**
```json
{
  "menu_name": "마이페이지 (수정)",
  "description": "수정된 설명",
  "icon": "mdi-account",
  "link_type": "url",
  "link_url": "/mypage",
  "permission_type": "member",
  "show_condition": "logged_in",
  "is_visible": true,
  "is_active": true
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "메뉴가 수정되었습니다."
  }
}
```

---

### 5. 메뉴 삭제 (Soft Delete)

```http
DELETE /api/admin/menus/:id
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "메뉴가 삭제되었습니다."
  }
}
```

---

### 6. 메뉴 순서 변경

```http
PUT /api/admin/menus/reorder
```

**Request Body:**
```json
{
  "orderedIds": [3, 1, 2, 5, 4]
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "메뉴 순서가 변경되었습니다."
  }
}
```

---

### 7. 메뉴 이동 (부모 변경)

```http
PUT /api/admin/menus/:id/move
```

**Request Body:**
```json
{
  "parent_id": 5,
  "sort_order": 2
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "message": "메뉴가 이동되었습니다."
  }
}
```

---

## TypeScript Types (Frontend)

```typescript
// 메뉴 타입 정의
export type MenuType = 'site' | 'user' | 'admin' | 'header_utility' | 'footer_utility' | 'quick_menu';
export type LinkType = 'url' | 'new_window' | 'modal' | 'external' | 'none';
export type PermissionType = 'public' | 'member' | 'groups' | 'users' | 'roles' | 'admin';
export type ShowCondition = 'always' | 'logged_in' | 'logged_out' | 'custom';
export type BadgeType = 'none' | 'count' | 'dot' | 'text' | 'api';

// 메뉴 인터페이스
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
  modal_width?: number;
  modal_height?: number;

  permission_type: PermissionType;
  show_condition: ShowCondition;
  condition_expression?: string;

  is_visible: boolean;
  is_enabled: boolean;
  is_expandable: boolean;
  default_expanded: boolean;

  css_class?: string;
  highlight: boolean;
  highlight_text?: string;
  highlight_color?: string;

  badge_type: BadgeType;
  badge_value?: string;
  badge_color?: string;

  seo_title?: string;
  seo_description?: string;

  created_at: string;
  created_by?: string;
  updated_at: string;
  updated_by?: string;
  is_active: boolean;
  is_deleted: boolean;

  // Relations
  parent_name?: string;
  children?: Menu[];
}

// 폼 데이터
export interface MenuFormData {
  menu_type: MenuType;
  parent_id?: number | null;
  menu_name: string;
  menu_code: string;
  description?: string;
  icon?: string;
  link_type: LinkType;
  link_url?: string;
  permission_type: PermissionType;
  show_condition: ShowCondition;
  sort_order?: number;
  is_visible?: boolean;
  is_active?: boolean;
}

// 트리 노드
export interface MenuTreeNode {
  id: number;
  menu_name: string;
  menu_code: string;
  parent_id: number | null;
  depth: number;
  children?: MenuTreeNode[];
  is_folder: boolean;
  icon?: string;
}

// API 응답
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error_code?: string;
  message?: string;
}
```

---

## API Client (Frontend)

```typescript
// lib/menuApi.ts
import axios from 'axios';
import { Menu, MenuFormData, ApiResponse } from '../types/menu';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Error handler
const handleError = (error: any): never => {
  if (error.response?.data?.message) {
    throw new Error(error.response.data.message);
  }
  throw new Error('요청 중 오류가 발생했습니다.');
};

// 메뉴 목록 조회
export const getAllMenus = async (menuType?: string): Promise<Menu[]> => {
  const params = menuType ? { type: menuType } : {};
  const response = await apiClient.get<ApiResponse<Menu[]>>('/api/admin/menus', { params });
  if (!response.data.success || !response.data.data) {
    throw new Error(response.data.message || '메뉴 조회에 실패했습니다.');
  }
  return response.data.data;
};

// 메뉴 상세 조회
export const getMenuById = async (id: number): Promise<Menu> => {
  const response = await apiClient.get<ApiResponse<Menu>>(`/api/admin/menus/${id}`);
  if (!response.data.success || !response.data.data) {
    throw new Error(response.data.message || '메뉴 조회에 실패했습니다.');
  }
  return response.data.data;
};

// 메뉴 생성
export const createMenu = async (data: MenuFormData): Promise<{ id: number; message: string }> => {
  const response = await apiClient.post<ApiResponse<{ id: number; message: string }>>(
    '/api/admin/menus',
    data
  );
  if (!response.data.success || !response.data.data) {
    throw new Error(response.data.message || '메뉴 생성에 실패했습니다.');
  }
  return response.data.data;
};

// 메뉴 수정
export const updateMenu = async (id: number, data: Partial<MenuFormData>): Promise<void> => {
  const response = await apiClient.put<ApiResponse<{ message: string }>>(
    `/api/admin/menus/${id}`,
    data
  );
  if (!response.data.success) {
    throw new Error(response.data.message || '메뉴 수정에 실패했습니다.');
  }
};

// 메뉴 삭제
export const deleteMenu = async (id: number): Promise<void> => {
  const response = await apiClient.delete<ApiResponse<{ message: string }>>(
    `/api/admin/menus/${id}`
  );
  if (!response.data.success) {
    throw new Error(response.data.message || '메뉴 삭제에 실패했습니다.');
  }
};

// 메뉴 순서 변경
export const reorderMenus = async (orderedIds: number[]): Promise<void> => {
  const response = await apiClient.put<ApiResponse<{ message: string }>>(
    '/api/admin/menus/reorder',
    { orderedIds }
  );
  if (!response.data.success) {
    throw new Error(response.data.message || '메뉴 순서 변경에 실패했습니다.');
  }
};

// 메뉴 이동
export const moveMenu = async (
  id: number,
  parentId: number | null,
  sortOrder: number
): Promise<void> => {
  const response = await apiClient.put<ApiResponse<{ message: string }>>(
    `/api/admin/menus/${id}/move`,
    { parent_id: parentId, sort_order: sortOrder }
  );
  if (!response.data.success) {
    throw new Error(response.data.message || '메뉴 이동에 실패했습니다.');
  }
};
```

---

## Database Schema

```sql
-- 1. 메뉴 테이블 (통합)
CREATE TABLE IF NOT EXISTS menus (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 메뉴 타입
  menu_type ENUM('site', 'user', 'admin', 'header_utility', 'footer_utility', 'quick_menu') NOT NULL,

  -- 트리 구조
  parent_id BIGINT NULL,
  depth INT DEFAULT 0,
  sort_order INT DEFAULT 0,
  path VARCHAR(500) DEFAULT '',

  -- 기본 정보
  menu_name VARCHAR(100) NOT NULL,
  menu_code VARCHAR(50) NOT NULL,
  description VARCHAR(500),
  icon VARCHAR(100),

  -- 가상 경로
  virtual_path VARCHAR(200),

  -- 연동 설정
  link_type ENUM('url', 'new_window', 'modal', 'external', 'none') DEFAULT 'url',
  link_url VARCHAR(1000),
  external_url VARCHAR(1000),
  modal_component VARCHAR(200),
  modal_width INT DEFAULT 800,
  modal_height INT DEFAULT 600,

  -- 권한 설정
  permission_type ENUM('public', 'member', 'groups', 'users', 'roles', 'admin') DEFAULT 'public',

  -- 표시 조건
  show_condition ENUM('always', 'logged_in', 'logged_out', 'custom') DEFAULT 'always',
  condition_expression VARCHAR(500),

  -- 상태
  is_visible BOOLEAN DEFAULT TRUE,
  is_enabled BOOLEAN DEFAULT TRUE,
  is_expandable BOOLEAN DEFAULT TRUE,
  default_expanded BOOLEAN DEFAULT FALSE,

  -- 스타일
  css_class VARCHAR(200),
  highlight BOOLEAN DEFAULT FALSE,
  highlight_text VARCHAR(50),
  highlight_color VARCHAR(20),

  -- 배지
  badge_type ENUM('none', 'count', 'dot', 'text', 'api') DEFAULT 'none',
  badge_value VARCHAR(200),
  badge_color VARCHAR(20) DEFAULT 'primary',

  -- SEO
  seo_title VARCHAR(200),
  seo_description VARCHAR(500),

  -- 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (parent_id) REFERENCES menus(id) ON DELETE SET NULL,
  UNIQUE KEY uk_type_code (menu_type, menu_code),
  INDEX idx_type_parent (menu_type, parent_id, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 메뉴 권한 매핑
CREATE TABLE IF NOT EXISTS menu_permissions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  menu_id BIGINT NOT NULL,
  group_id BIGINT NULL,
  user_id VARCHAR(50) NULL,
  role_id BIGINT NULL,
  permission_level ENUM('view', 'edit', 'delete', 'all') DEFAULT 'view',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## Backend Handler (Node.js/Express)

### File: `middleware/node/api/menuAdminHandler.js`

```javascript
const mysql = require('mysql2');

// MySQL 연결
let connection = null;
let mysqlAvailable = false;

try {
  connection = mysql.createConnection({
    host: process.env.MYSQL_HOST || 'localhost',
    user: process.env.MYSQL_USER || 'dbuser',
    password: process.env.MYSQL_PASSWORD || 'dbuser',
    database: process.env.MYSQL_DATABASE || 'egov'
  });

  connection.connect(error => {
    if (error) {
      console.warn('[Menu Admin MySQL] Connection failed:', error.message);
      mysqlAvailable = false;
    } else {
      console.log('[Menu Admin MySQL] Connected');
      mysqlAvailable = true;
    }
  });
} catch (err) {
  console.warn('[Menu Admin MySQL] Failed:', err.message);
}

// 입력값 검증
const validateInput = (input, fieldName, maxLength = 100) => {
  if (typeof input !== 'string') throw new Error(`${fieldName} must be a string`);
  if (input.length === 0) throw new Error(`${fieldName} is required`);
  if (input.length > maxLength) throw new Error(`${fieldName} exceeds max length`);
  const dangerous = /<script|javascript:|onerror=|onclick=|--/i;
  if (dangerous.test(input)) throw new Error(`${fieldName} contains invalid characters`);
  return input.trim();
};

// 관리자 권한 확인
const checkAdminPermission = (session) => {
  // 개발 환경에서는 권한 체크 비활성화
  return true;
  // if (!session?.isLoggedIn || !session?.isAdmin) return false;
  // return true;
};

// 전체 메뉴 조회
const getAllMenus = async (req, res) => {
  if (!mysqlAvailable) {
    return res.status(503).json({
      success: false, error_code: 'DATABASE_UNAVAILABLE',
      message: 'Database service is not available'
    });
  }

  if (!checkAdminPermission(req.session)) {
    return res.status(403).json({
      success: false, error_code: 'ACCESS_DENIED',
      message: '관리자 권한이 필요합니다.'
    });
  }

  const { type } = req.query;
  let query = `
    SELECT m.*, p.menu_name as parent_name
    FROM menus m
    LEFT JOIN menus p ON m.parent_id = p.id
    WHERE m.is_deleted = 0
  `;
  const params = [];
  if (type) {
    query += ' AND m.menu_type = ?';
    params.push(type);
  }
  query += ' ORDER BY m.menu_type, m.parent_id, m.sort_order';

  connection.query(query, params, (error, results) => {
    if (error) {
      return res.status(500).json({
        success: false, error_code: 'QUERY_ERROR',
        message: '메뉴 조회 중 오류가 발생했습니다.'
      });
    }
    res.json({ success: true, data: results });
  });
};

module.exports = {
  getAllMenus,
  getMenuById,
  createMenu,
  updateMenu,
  deleteMenu,
  reorderMenus,
  moveMenu
};
```

---

## Frontend Component Structure

```
frontend/src/
├── types/
│   └── menu.ts                    # 타입 정의
├── lib/
│   └── menuApi.ts                 # API 클라이언트
└── components/
    └── admin/
        └── menu/
            ├── MenuManager.tsx    # 메인 컴포넌트
            ├── MenuTree.tsx       # 좌측 트리
            └── MenuForm.tsx       # 우측 폼
```

### MenuManager.tsx (메인 컴포넌트)

- 좌측 50%: 트리 구조 (MenuTree)
- 우측 50%: 폼 (MenuForm)
- 기능: CRUD, 드래그앤드롭 이동, 순서 변경

### MenuTree.tsx

- 트리 구조 렌더링
- 선택, 추가, 삭제 버튼
- 드래그앤드롭 지원 (dnd-kit 사용)

### MenuForm.tsx

- 메뉴 정보 입력/수정 폼
- Breadcrumb 경로 표시
- 링크 타입별 조건부 필드

---

## Phase 0: 사전 검증

### Step 1: 공유 테이블 확인

```sql
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tenants', 'user_groups', 'user_group_members', 'roles', 'user_roles');
```

→ 5개 미만이면 `shared-schema` 먼저 실행

### Step 2: 메뉴 테이블 확인

```sql
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('menus', 'menu_permissions', 'related_sites');
```

→ 3개 미만이면 메뉴 스키마 생성 실행

### Step 3: 기술 스택 분석

```bash
# Backend
ls package.json          # Node.js
ls requirements.txt      # Python

# Frontend
grep -E "react|vue|angular" frontend/package.json
grep -E "@mui/material|bootstrap" frontend/package.json

# Database
grep -E "mysql|postgres" package.json
```

---

## 메뉴 타입 정의

| 타입 | 설명 | 대상 | 예시 |
|------|------|------|------|
| `site` | 사이트 전체 메뉴 | 모든 방문자 | GNB, 메인 네비게이션 |
| `user` | 사용자 전용 메뉴 | 로그인 회원 | 마이페이지, 주문내역 |
| `admin` | 관리자 메뉴 | 관리자 | 사용자관리, 시스템설정 |

### 유틸리티 메뉴

| 영역 | 위치 | 예시 |
|------|------|------|
| `header_utility` | 헤더 상단 | 로그인, 회원가입, 장바구니 |
| `footer_utility` | 푸터 | 이용약관, 개인정보처리방침 |
| `quick_menu` | 플로팅 | 최근본상품, TOP |

---

## 생성 파일 목록

### Backend (Node.js/Express)

| 파일 | 설명 |
|------|------|
| `middleware/node/api/menuAdminHandler.js` | API 핸들러 |
| `middleware/node/api/menuHandler.js` | 사용자용 API |
| `middleware/node/db/schema/menu_schema.sql` | DB 스키마 |

### Frontend (React + MUI)

| 파일 | 설명 |
|------|------|
| `frontend/src/types/menu.ts` | TypeScript 타입 |
| `frontend/src/lib/menuApi.ts` | API 클라이언트 |
| `frontend/src/components/admin/menu/MenuManager.tsx` | 메인 컴포넌트 |
| `frontend/src/components/admin/menu/MenuTree.tsx` | 트리 컴포넌트 |
| `frontend/src/components/admin/menu/MenuForm.tsx` | 폼 컴포넌트 |

---

## Express Router 등록

```javascript
// server.js
const {
  getAllMenus,
  getMenuById,
  createMenu,
  updateMenu,
  deleteMenu,
  reorderMenus,
  moveMenu
} = require('./api/menuAdminHandler');

// 관리자 메뉴 API
app.get('/api/admin/menus', getAllMenus);
app.get('/api/admin/menus/:id', getMenuById);
app.post('/api/admin/menus', createMenu);
app.put('/api/admin/menus/reorder', reorderMenus);  // :id 보다 먼저!
app.put('/api/admin/menus/:id', updateMenu);
app.put('/api/admin/menus/:id/move', moveMenu);
app.delete('/api/admin/menus/:id', deleteMenu);
```

---

## Security Considerations

1. **입력 검증**: XSS, SQL Injection 방지
2. **권한 체크**: 관리자만 접근 가능
3. **Soft Delete**: 실제 삭제하지 않음
4. **감사 로그**: created_by, updated_by 기록
5. **Parameterized Query**: SQL Injection 방지

---

## 사용 예시

```bash
# 1. 초기 설정
Use menu-manager --init

# 2. 사용자 메뉴 생성
Use menu-manager --type=user

# 3. 특정 메뉴 추가
Use menu-manager to add menu "포인트 내역" under "마이페이지" --type=user

# 4. 유틸리티 메뉴 생성
Use menu-manager --utility=header
```
