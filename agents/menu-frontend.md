---
name: menu-frontend
description: 메뉴 관리 Frontend 컴포넌트 생성. React/TypeScript + MUI 기반. Security First, Error Handling First 원칙 준수. coding-guide, modular, refactor 스킬 연동.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide, modular-check, refactor
---

# 메뉴 관리 Frontend 컴포넌트 생성기

메뉴 관리 시스템의 Frontend 컴포넌트를 생성하는 에이전트입니다.

> **핵심 원칙**:
> 1. **Security First**: XSS 방지, 안전한 렌더링
> 2. **Error Handling First**: 모든 API 호출에 에러 처리
> 3. **coding-guide 준수**: 네이밍 컨벤션, Import 순서
> 4. **modular 구조**: 컴포넌트 분리, 커스텀 훅 추출
> 5. **refactor 적용**: 타입 중복 제거, 공통 로직 추출

---

## 사용법

```bash
# 전체 Frontend 생성
Use menu-frontend --init

# 컴포넌트만 생성
Use menu-frontend --components

# 타입만 생성
Use menu-frontend --types

# API 클라이언트만 생성
Use menu-frontend --api
```

---

## CRITICAL: Security First Principle

> **중요**: 모든 사용자 입력과 렌더링에 보안 원칙을 적용합니다.

### 1. XSS 방지

```typescript
// 절대 금지 - dangerouslySetInnerHTML
<div dangerouslySetInnerHTML={{ __html: userInput }} />  // NEVER!

// 항상 사용 - JSX 기본 이스케이프
<div>{userInput}</div>  // React가 자동으로 이스케이프
```

### 2. 입력 검증 (Frontend)

```typescript
/**
 * 클라이언트 입력 검증
 */
const validateMenuInput = (data: MenuFormData): string[] => {
  const errors: string[] = [];

  // 필수 필드 검증
  if (!data.menu_name?.trim()) {
    errors.push('메뉴 이름은 필수입니다.');
  }

  if (!data.menu_code?.trim()) {
    errors.push('메뉴 코드는 필수입니다.');
  }

  // 길이 검증
  if (data.menu_name && data.menu_name.length > 100) {
    errors.push('메뉴 이름은 100자 이하여야 합니다.');
  }

  if (data.menu_code && data.menu_code.length > 50) {
    errors.push('메뉴 코드는 50자 이하여야 합니다.');
  }

  // 패턴 검증 (영문, 숫자, 언더스코어만)
  if (data.menu_code && !/^[a-zA-Z0-9_]+$/.test(data.menu_code)) {
    errors.push('메뉴 코드는 영문, 숫자, 언더스코어만 사용 가능합니다.');
  }

  // URL 검증 (link_type이 url인 경우)
  if (data.link_type === 'url' && data.link_url) {
    if (!data.link_url.startsWith('/') && !data.link_url.startsWith('http')) {
      errors.push('URL은 /로 시작하거나 http(s)://로 시작해야 합니다.');
    }
  }

  return errors;
};
```

### 3. 안전한 URL 처리

```typescript
/**
 * 안전한 URL 검증
 */
const isSafeUrl = (url: string): boolean => {
  // javascript: 프로토콜 차단
  if (url.toLowerCase().startsWith('javascript:')) {
    return false;
  }

  // data: 프로토콜 차단
  if (url.toLowerCase().startsWith('data:')) {
    return false;
  }

  return true;
};

// 사용
const handleLinkClick = (url: string) => {
  if (!isSafeUrl(url)) {
    console.warn('Blocked unsafe URL:', url);
    return;
  }
  window.open(url, '_blank', 'noopener,noreferrer');
};
```

---

## CRITICAL: Error Handling First Principle

> **중요**: 모든 API 호출과 비동기 작업에 에러 처리를 적용합니다.

### 1. API 호출 에러 처리

```typescript
/**
 * 에러 핸들러 (API 클라이언트용)
 */
const handleError = (error: any): never => {
  // API 응답 에러
  if (error.response?.data?.message) {
    throw new Error(error.response.data.message);
  }

  // 네트워크 에러
  if (error.code === 'NETWORK_ERROR' || error.code === 'ERR_NETWORK') {
    throw new Error('네트워크 연결을 확인해주세요.');
  }

  // 타임아웃
  if (error.code === 'ECONNABORTED') {
    throw new Error('요청 시간이 초과되었습니다.');
  }

  // 일반 에러
  if (error.message) {
    throw new Error(error.message);
  }

  throw new Error('요청 중 오류가 발생했습니다.');
};
```

### 2. 컴포넌트 에러 처리

```typescript
const MenuManager: React.FC = () => {
  const [menus, setMenus] = useState<Menu[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const loadMenus = async () => {
    try {
      setIsLoading(true);
      setError(null);  // 에러 초기화

      const data = await menuApi.getAllMenus('user');
      setMenus(data);
    } catch (err: any) {
      // 에러 메시지 설정
      setError(err.message || '메뉴 목록을 불러오는데 실패했습니다.');
      console.error('Failed to load menus:', err);
    } finally {
      setIsLoading(false);
    }
  };

  // 에러 표시
  {error && (
    <Alert severity="error" onClose={() => setError(null)}>
      {error}
    </Alert>
  )}
};
```

### 3. Form 제출 에러 처리

```typescript
const handleSave = async (formData: MenuFormData) => {
  // 클라이언트 검증
  const errors = validateMenuInput(formData);
  if (errors.length > 0) {
    setValidationErrors(errors);
    return;
  }

  try {
    setIsSaving(true);
    setError(null);

    if (isAddMode) {
      await menuApi.createMenu(formData);
      setSuccessMessage('메뉴가 추가되었습니다.');
    } else if (selectedMenu) {
      await menuApi.updateMenu(selectedMenu.id, formData);
      setSuccessMessage('메뉴가 수정되었습니다.');
    }

    await loadMenus();  // 목록 새로고침
    handleCancelEdit();
  } catch (err: any) {
    setError(err.message || '저장 중 오류가 발생했습니다.');
  } finally {
    setIsSaving(false);
  }
};
```

---

## TypeScript Types

### 타입 정의 파일: `types/menu.ts`

```typescript
/**
 * Menu Management Types
 * 메뉴 관리 시스템 타입 정의
 */

// ENUM 타입들
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

  // 감사 컬럼
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

// 폼 데이터 (생성/수정용)
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

// 트리 노드 (트리 컴포넌트용)
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

// API 응답 (표준)
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error_code?: string;
  message?: string;
}
```

---

## API Client

### 파일: `lib/menuApi.ts`

```typescript
/**
 * Menu API Client
 * 메뉴 관리 API 호출 함수
 */

import axios, { AxiosError } from 'axios';
import { Menu, MenuFormData, ApiResponse } from '../types/menu';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000, // 10초 타임아웃
});

// Error handler
const handleError = (error: AxiosError | any): never => {
  if (error.response?.data?.message) {
    throw new Error(error.response.data.message);
  }
  if (error.code === 'ECONNABORTED') {
    throw new Error('요청 시간이 초과되었습니다.');
  }
  if (error.message) {
    throw new Error(error.message);
  }
  throw new Error('요청 중 오류가 발생했습니다.');
};

/**
 * 메뉴 목록 조회 (관리자)
 */
export const getAllMenus = async (menuType?: string): Promise<Menu[]> => {
  try {
    const params = menuType ? { type: menuType } : {};
    const response = await apiClient.get<ApiResponse<Menu[]>>('/api/admin/menus', { params });

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '메뉴 조회에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 메뉴 상세 조회
 */
export const getMenuById = async (id: number): Promise<Menu> => {
  try {
    const response = await apiClient.get<ApiResponse<Menu>>(`/api/admin/menus/${id}`);

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '메뉴 조회에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 메뉴 생성
 */
export const createMenu = async (data: MenuFormData): Promise<{ id: number; message: string }> => {
  try {
    const response = await apiClient.post<ApiResponse<{ id: number; message: string }>>(
      '/api/admin/menus',
      data
    );

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '메뉴 생성에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 메뉴 수정
 */
export const updateMenu = async (id: number, data: Partial<MenuFormData>): Promise<void> => {
  try {
    const response = await apiClient.put<ApiResponse<{ message: string }>>(
      `/api/admin/menus/${id}`,
      data
    );

    if (!response.data.success) {
      throw new Error(response.data.message || '메뉴 수정에 실패했습니다.');
    }
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 메뉴 삭제
 */
export const deleteMenu = async (id: number): Promise<void> => {
  try {
    const response = await apiClient.delete<ApiResponse<{ message: string }>>(
      `/api/admin/menus/${id}`
    );

    if (!response.data.success) {
      throw new Error(response.data.message || '메뉴 삭제에 실패했습니다.');
    }
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 메뉴 순서 변경
 */
export const reorderMenus = async (orderedIds: number[]): Promise<void> => {
  try {
    const response = await apiClient.put<ApiResponse<{ message: string }>>(
      '/api/admin/menus/reorder',
      { orderedIds }
    );

    if (!response.data.success) {
      throw new Error(response.data.message || '메뉴 순서 변경에 실패했습니다.');
    }
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 메뉴 이동 (부모 변경)
 */
export const moveMenu = async (
  id: number,
  parentId: number | null,
  sortOrder: number
): Promise<void> => {
  try {
    const response = await apiClient.put<ApiResponse<{ message: string }>>(
      `/api/admin/menus/${id}/move`,
      { parent_id: parentId, sort_order: sortOrder }
    );

    if (!response.data.success) {
      throw new Error(response.data.message || '메뉴 이동에 실패했습니다.');
    }
  } catch (error) {
    return handleError(error);
  }
};
```

---

## Component Structure (Modular)

```
frontend/src/
├── types/
│   └── menu.ts                    # 타입 정의
├── lib/
│   └── menuApi.ts                 # API 클라이언트
├── hooks/
│   └── useMenu.ts                 # 메뉴 커스텀 훅 (선택)
└── components/
    └── admin/
        └── menu/
            ├── MenuManager.tsx    # 메인 컨테이너
            ├── MenuTree.tsx       # 좌측 트리
            └── MenuForm.tsx       # 우측 폼
```

---

## Component: MenuManager.tsx

```typescript
/**
 * Menu Manager Component
 * 메뉴 관리 메인 컴포넌트 (좌측 트리 + 우측 폼)
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  Typography,
  Alert,
  Snackbar,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogContentText,
  DialogActions,
  Button,
  CircularProgress,
} from '@mui/material';
import MenuTree from './MenuTree';
import MenuForm from './MenuForm';
import { Menu, MenuFormData } from '../../../types/menu';
import * as menuApi from '../../../lib/menuApi';

// 트리 → flat list 변환 헬퍼
const flattenMenuTree = (menuList: Menu[], parentId: number | null = null): Menu[] => {
  const result: Menu[] = [];
  for (const menu of menuList) {
    result.push({ ...menu, parent_id: parentId });
    if (menu.children?.length) {
      result.push(...flattenMenuTree(menu.children, menu.id));
    }
  }
  return result;
};

// flat list → 트리 변환 헬퍼
const buildMenuTree = (flatMenus: Menu[]): Menu[] => {
  const menuMap = new Map<number, Menu>();
  const rootMenus: Menu[] = [];

  flatMenus.forEach((menu) => {
    menuMap.set(menu.id, { ...menu, children: [] });
  });

  flatMenus.forEach((menu) => {
    const menuNode = menuMap.get(menu.id)!;
    if (menu.parent_id === null) {
      rootMenus.push(menuNode);
    } else {
      const parent = menuMap.get(menu.parent_id);
      if (parent) {
        parent.children = parent.children || [];
        parent.children.push(menuNode);
      }
    }
  });

  // 정렬
  const sortMenus = (menus: Menu[]) => {
    menus.sort((a, b) => a.sort_order - b.sort_order);
    menus.forEach((menu) => {
      if (menu.children?.length) sortMenus(menu.children);
    });
  };

  sortMenus(rootMenus);
  return rootMenus;
};

const MenuManager: React.FC = () => {
  // 상태
  const [menus, setMenus] = useState<Menu[]>([]);
  const [flatMenus, setFlatMenus] = useState<Menu[]>([]);
  const [selectedMenu, setSelectedMenu] = useState<Menu | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // 추가 모드
  const [isAddMode, setIsAddMode] = useState(false);
  const [parentId, setParentId] = useState<number | null>(null);
  const [parentMenuName, setParentMenuName] = useState<string | undefined>();

  // 삭제 확인
  const [deleteConfirmOpen, setDeleteConfirmOpen] = useState(false);
  const [menuToDelete, setMenuToDelete] = useState<number | null>(null);

  // 메뉴 로드
  const loadMenus = useCallback(async () => {
    try {
      setIsLoading(true);
      setError(null);

      const data = await menuApi.getAllMenus('user');
      const treeData = buildMenuTree(data);
      setMenus(treeData);
      setFlatMenus(flattenMenuTree(treeData));
    } catch (err: any) {
      setError(err.message || '메뉴 목록을 불러오는데 실패했습니다.');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMenus();
  }, [loadMenus]);

  // 메뉴 선택
  const handleSelectMenu = (menu: Menu) => {
    setSelectedMenu(menu);
    setIsAddMode(false);
    setParentId(null);
    setParentMenuName(undefined);
  };

  // 메뉴 추가 모드
  const handleAddMenu = (parentIdParam: number | null) => {
    setIsAddMode(true);
    setParentId(parentIdParam);
    setSelectedMenu(null);

    if (parentIdParam) {
      const findMenu = (list: Menu[], id: number): Menu | undefined => {
        for (const m of list) {
          if (m.id === id) return m;
          if (m.children) {
            const found = findMenu(m.children, id);
            if (found) return found;
          }
        }
        return undefined;
      };
      const parent = findMenu(menus, parentIdParam);
      setParentMenuName(parent?.menu_name);
    } else {
      setParentMenuName(undefined);
    }
  };

  // 메뉴 저장
  const handleSaveMenu = async (formData: MenuFormData) => {
    try {
      if (isAddMode) {
        await menuApi.createMenu({ ...formData, parent_id: parentId });
        setSuccessMessage('메뉴가 추가되었습니다.');
      } else if (selectedMenu) {
        await menuApi.updateMenu(selectedMenu.id, formData);
        setSuccessMessage('메뉴가 수정되었습니다.');
      }

      await loadMenus();
      setIsAddMode(false);
      setSelectedMenu(null);
      setParentId(null);
      setParentMenuName(undefined);
    } catch (err: any) {
      throw err;  // Form에서 처리
    }
  };

  // 편집 취소
  const handleCancelEdit = () => {
    setIsAddMode(false);
    setSelectedMenu(null);
    setParentId(null);
    setParentMenuName(undefined);
  };

  // 메뉴 삭제
  const handleDeleteMenu = (menuId: number) => {
    setMenuToDelete(menuId);
    setDeleteConfirmOpen(true);
  };

  const confirmDeleteMenu = async () => {
    if (menuToDelete === null) return;

    try {
      await menuApi.deleteMenu(menuToDelete);
      setSuccessMessage('메뉴가 삭제되었습니다.');
      setDeleteConfirmOpen(false);
      setMenuToDelete(null);

      if (selectedMenu?.id === menuToDelete) {
        setSelectedMenu(null);
      }

      await loadMenus();
    } catch (err: any) {
      setError(err.message || '메뉴 삭제에 실패했습니다.');
      setDeleteConfirmOpen(false);
      setMenuToDelete(null);
    }
  };

  // 메뉴 이동
  const handleMoveMenu = async (menuId: number, newParentId: number | null, newIndex: number) => {
    try {
      await menuApi.moveMenu(menuId, newParentId, newIndex);
      setSuccessMessage('메뉴가 이동되었습니다.');
      await loadMenus();
    } catch (err: any) {
      setError(err.message || '메뉴 이동에 실패했습니다.');
    }
  };

  // 로딩 표시
  if (isLoading) {
    return (
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%' }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Box sx={{ height: 'calc(100vh - 180px)', display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <Box sx={{ mb: 2 }}>
        <Typography variant="h5" fontWeight={600} gutterBottom>
          사용자 메뉴 관리
        </Typography>
        <Typography variant="body2" color="text.secondary">
          마이페이지 메뉴를 관리합니다.
        </Typography>
      </Box>

      {/* Error Alert */}
      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {/* Main Content */}
      <Box sx={{
        flex: 1,
        display: 'grid',
        gridTemplateColumns: '1fr 1fr',
        gap: 0,
        border: 1,
        borderColor: 'divider',
        borderRadius: 1,
        overflow: 'hidden',
        bgcolor: 'background.paper',
      }}>
        {/* Left: Tree */}
        <MenuTree
          menus={menus}
          selectedMenuId={selectedMenu?.id || null}
          onSelectMenu={handleSelectMenu}
          onAddMenu={handleAddMenu}
          onDeleteMenu={handleDeleteMenu}
          onMoveMenu={handleMoveMenu}
        />

        {/* Right: Form */}
        <MenuForm
          menu={isAddMode ? null : selectedMenu}
          parentMenuName={parentMenuName}
          isAddMode={isAddMode}
          onSave={handleSaveMenu}
          onCancel={handleCancelEdit}
        />
      </Box>

      {/* Success Snackbar */}
      <Snackbar
        open={!!successMessage}
        autoHideDuration={3000}
        onClose={() => setSuccessMessage(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      >
        <Alert severity="success" onClose={() => setSuccessMessage(null)}>
          {successMessage}
        </Alert>
      </Snackbar>

      {/* Delete Confirmation */}
      <Dialog open={deleteConfirmOpen} onClose={() => setDeleteConfirmOpen(false)}>
        <DialogTitle>메뉴 삭제 확인</DialogTitle>
        <DialogContent>
          <DialogContentText>
            선택한 메뉴를 삭제하시겠습니까?
          </DialogContentText>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDeleteConfirmOpen(false)} color="inherit">
            취소
          </Button>
          <Button onClick={confirmDeleteMenu} color="error" variant="contained">
            삭제
          </Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
};

export default MenuManager;
```

---

## Coding Guide Checklist

### 네이밍 컨벤션

| 구분 | 규칙 | 예시 |
|------|------|------|
| 컴포넌트 | PascalCase | `MenuManager`, `MenuTree` |
| 변수/함수 | camelCase | `selectedMenu`, `handleSave` |
| 상수 | UPPER_SNAKE_CASE | `API_BASE_URL` |
| Boolean | is/has/should | `isLoading`, `hasPermission` |
| 이벤트 핸들러 | handle 접두사 | `handleClick`, `handleSubmit` |

### Import 순서

```typescript
// 1. 외부 라이브러리
import React, { useState, useEffect } from 'react';
import { Box, Typography, Alert } from '@mui/material';

// 2. 내부 패키지/컴포넌트
import MenuTree from './MenuTree';
import MenuForm from './MenuForm';

// 3. 타입
import { Menu, MenuFormData } from '../../../types/menu';

// 4. API/유틸
import * as menuApi from '../../../lib/menuApi';
```

### 컴포넌트 크기 제한

- 단일 컴포넌트: **최대 200줄**
- 200줄 초과 시: 하위 컴포넌트로 분리
- 복잡한 로직: 커스텀 훅으로 추출

---

## UX 필수 요소

| 상황 | 필수 요소 |
|------|----------|
| 폼 | "취소" 버튼 |
| 삭제 | 확인 다이얼로그 |
| 로딩 | CircularProgress 표시 |
| 에러 | Alert 표시 + 닫기 버튼 |
| 성공 | Snackbar 자동 숨김 |

---

## Security Checklist

- [ ] dangerouslySetInnerHTML 미사용
- [ ] 사용자 입력 검증
- [ ] URL 안전성 검증
- [ ] XSS 패턴 차단
- [ ] API 에러 적절히 처리

---

## 사용 예시

```bash
# Frontend 전체 생성
Use menu-frontend --init

# 특정 컴포넌트 추가
Use menu-frontend to add component "MenuBreadcrumb"
```
