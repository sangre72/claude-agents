---
name: category-manager
description: 게시판 카테고리 관리 에이전트. 게시판별 카테고리 CRUD, 계층형 카테고리, 순서 관리. 최우선 순위 - tenant-manager 다음으로 실행.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 카테고리 관리 에이전트

**게시판별 카테고리**를 관리하는 에이전트입니다.

> **최우선 순위**: shared-schema → tenant-manager → **category-manager** → board-generator

---

## 사용법

```bash
# 카테고리 관리 시스템 초기화
Use category-manager --init

# 게시판에 카테고리 추가
Use category-manager to add category "공지" to board "notice"

# 카테고리 목록 조회
Use category-manager --list --board=notice
```

---

## 카테고리 개념

```
┌─────────────────────────────────────────────────────────────┐
│                       게시판 (boards)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  공지사항    │  │  자유게시판  │  │  Q&A        │         │
│  │  board_id=1 │  │  board_id=2 │  │  board_id=3 │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │
│         │                │                │                 │
│    ┌────▼────┐      ┌────▼────┐      ┌────▼────┐           │
│    │카테고리  │      │카테고리  │      │카테고리  │           │
│    ├─────────┤      ├─────────┤      ├─────────┤           │
│    │ - 일반   │      │ - 잡담   │      │ - 기술   │           │
│    │ - 긴급   │      │ - 정보   │      │ - 일반   │           │
│    │ - 이벤트 │      │ - 유머   │      │ - 결제   │           │
│    └─────────┘      └─────────┘      └─────────┘           │
└─────────────────────────────────────────────────────────────┘
```

### 계층형 카테고리

```
공지사항
├── 일반 공지
│   ├── 서비스 안내
│   └── 점검 안내
├── 긴급 공지
└── 이벤트
    ├── 진행중
    └── 종료
```

---

## Phase 0: 사전 검증 (CRITICAL)

> **중요**: categories 테이블은 tenants와 boards 테이블에 의존합니다!

### Step 1: 기술 스택 감지

```bash
# Backend 확인
ls package.json requirements.txt pom.xml 2>/dev/null

# Database 확인
grep -E "mysql|postgres|mongodb" package.json requirements.txt 2>/dev/null
```

### Step 2: 의존 테이블 존재 확인

```sql
-- MySQL/MariaDB: tenants, boards 테이블 확인
SELECT TABLE_NAME FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME IN ('tenants', 'boards');
```

**결과가 2개 미만이면:**
```
⚠️ 필수 테이블이 존재하지 않습니다!

누락된 테이블에 따라:
- tenants 없음 → Use shared-schema --init
- boards 없음 → Use board-generator --init

초기화 순서:
1. Use shared-schema --init     # tenants 테이블 생성
2. Use tenant-manager --init    # 테넌트 관리 (선택)
3. Use board-generator --init   # boards 테이블 생성
4. Use category-manager --init  # 카테고리 관리
```

### Step 3: API 시작 전 테이블 확인 미들웨어

```javascript
// middleware/checkCategoryTables.js
const { pool } = require('../db');

const checkCategoryTablesExist = async (req, res, next) => {
  try {
    const [rows] = await pool.execute(`
      SELECT TABLE_NAME FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME IN ('tenants', 'boards', 'categories')
    `);

    const existingTables = rows.map(r => r.TABLE_NAME);
    const requiredTables = ['tenants', 'boards'];
    const missingTables = requiredTables.filter(t => !existingTables.includes(t));

    if (missingTables.length > 0) {
      return res.status(500).json({
        error: '필수 테이블이 존재하지 않습니다.',
        missingTables,
        solution: {
          tenants: 'Use shared-schema --init',
          boards: 'Use board-generator --init'
        }
      });
    }

    // categories 테이블이 없으면 자동 생성 가능
    if (!existingTables.includes('categories')) {
      // 자동 생성 또는 에러 반환
      console.warn('categories 테이블이 없습니다. 자동 생성을 시도합니다.');
    }

    next();
  } catch (error) {
    console.error('테이블 확인 오류:', error);
    res.status(500).json({ error: '데이터베이스 연결 오류' });
  }
};

module.exports = { checkCategoryTablesExist };
```

### Step 4: 라우터에 미들웨어 적용

```javascript
// api/categories.js
const { checkCategoryTablesExist } = require('../middleware/checkCategoryTables');

// 모든 카테고리 API에 테이블 확인 미들웨어 적용
router.use(checkCategoryTablesExist);
```

---

## Phase 1: DB 스키마

> **의존성**: tenants, boards 테이블이 먼저 존재해야 함!

### categories 테이블

```sql
CREATE TABLE IF NOT EXISTS categories (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 테넌트 연결
  tenant_id BIGINT NOT NULL,

  -- 게시판 연결
  board_id BIGINT NOT NULL,

  -- 계층 구조
  parent_id BIGINT NULL,                    -- 상위 카테고리 (NULL이면 최상위)
  depth INT DEFAULT 0,                      -- 깊이 (0=최상위)
  path VARCHAR(500),                        -- 경로 (예: /1/3/7/)

  -- 기본 정보
  category_name VARCHAR(100) NOT NULL,      -- 카테고리명
  category_code VARCHAR(50) NOT NULL,       -- 카테고리 코드 (시스템용)
  description VARCHAR(500),                 -- 설명

  -- 표시 설정
  sort_order INT DEFAULT 0,                 -- 정렬 순서
  icon VARCHAR(50),                         -- 아이콘 (예: 'folder', 'star')
  color VARCHAR(20),                        -- 색상 (예: '#ff0000')

  -- 권한
  read_permission VARCHAR(50) DEFAULT 'all',   -- 읽기 권한 (all, members, admin)
  write_permission VARCHAR(50) DEFAULT 'all',  -- 쓰기 권한

  -- 게시글 수 (캐시)
  post_count INT DEFAULT 0,

  -- 필수 감사 컬럼
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  -- 제약 조건
  FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE,
  FOREIGN KEY (board_id) REFERENCES boards(id) ON DELETE CASCADE,
  FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL,

  -- 동일 게시판 내 카테고리 코드 유일
  UNIQUE KEY uk_board_category (board_id, category_code),

  INDEX idx_tenant (tenant_id),
  INDEX idx_board (board_id),
  INDEX idx_parent (parent_id),
  INDEX idx_sort (sort_order)
);
```

### 초기 데이터

```sql
-- 기본 카테고리 예시 (게시판 생성 시 선택적 추가)
-- board_generator에서 게시판 생성 시 호출됨
```

---

## Phase 2: Backend API

### Express.js

**파일**: `api/categories.js`

```javascript
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken, requireRole } = require('../middleware/auth');

// 카테고리 목록 조회 (게시판별)
router.get('/board/:boardId', async (req, res) => {
  const { boardId } = req.params;
  const tenantId = req.tenantId;

  try {
    const [categories] = await pool.execute(`
      SELECT id, parent_id, category_name, category_code, description,
             depth, path, sort_order, icon, color,
             read_permission, write_permission, post_count,
             is_active
      FROM categories
      WHERE board_id = ? AND tenant_id = ? AND is_deleted = FALSE
      ORDER BY sort_order, category_name
    `, [boardId, tenantId]);

    // 계층형 트리로 변환
    const tree = buildCategoryTree(categories);

    res.json(tree);
  } catch (error) {
    console.error('카테고리 목록 조회 실패:', error);
    res.status(500).json({ error: '카테고리 목록을 가져오는데 실패했습니다.' });
  }
});

// 카테고리 목록 조회 (flat)
router.get('/board/:boardId/flat', async (req, res) => {
  const { boardId } = req.params;
  const tenantId = req.tenantId;

  try {
    const [categories] = await pool.execute(`
      SELECT id, parent_id, category_name, category_code, description,
             depth, path, sort_order, icon, color,
             read_permission, write_permission, post_count,
             is_active
      FROM categories
      WHERE board_id = ? AND tenant_id = ? AND is_deleted = FALSE
      ORDER BY path, sort_order
    `, [boardId, tenantId]);

    res.json(categories);
  } catch (error) {
    console.error('카테고리 목록 조회 실패:', error);
    res.status(500).json({ error: '카테고리 목록을 가져오는데 실패했습니다.' });
  }
});

// 카테고리 상세 조회
router.get('/:id', async (req, res) => {
  const { id } = req.params;
  const tenantId = req.tenantId;

  try {
    const [categories] = await pool.execute(`
      SELECT c.*, b.board_name
      FROM categories c
      JOIN boards b ON c.board_id = b.id
      WHERE c.id = ? AND c.tenant_id = ? AND c.is_deleted = FALSE
    `, [id, tenantId]);

    if (categories.length === 0) {
      return res.status(404).json({ error: '카테고리를 찾을 수 없습니다.' });
    }

    res.json(categories[0]);
  } catch (error) {
    console.error('카테고리 조회 실패:', error);
    res.status(500).json({ error: '카테고리를 가져오는데 실패했습니다.' });
  }
});

// 카테고리 생성
router.post('/', authenticateToken, requireRole(['admin', 'manager']), async (req, res) => {
  const {
    board_id, parent_id, category_name, category_code,
    description, sort_order, icon, color,
    read_permission, write_permission
  } = req.body;
  const tenantId = req.tenantId;

  // 유효성 검사
  if (!board_id || !category_name || !category_code) {
    return res.status(400).json({
      error: '게시판 ID, 카테고리명, 카테고리 코드는 필수입니다.'
    });
  }

  // category_code 형식 검사
  if (!/^[a-z0-9_]+$/.test(category_code)) {
    return res.status(400).json({
      error: '카테고리 코드는 영문 소문자, 숫자, 언더스코어만 사용 가능합니다.'
    });
  }

  try {
    // 중복 체크
    const [existing] = await pool.execute(
      'SELECT id FROM categories WHERE board_id = ? AND category_code = ? AND is_deleted = FALSE',
      [board_id, category_code]
    );

    if (existing.length > 0) {
      return res.status(409).json({ error: '이미 존재하는 카테고리 코드입니다.' });
    }

    // depth와 path 계산
    let depth = 0;
    let path = '/';

    if (parent_id) {
      const [parent] = await pool.execute(
        'SELECT depth, path FROM categories WHERE id = ?',
        [parent_id]
      );

      if (parent.length > 0) {
        depth = parent[0].depth + 1;
        path = parent[0].path;
      }
    }

    // 생성
    const [result] = await pool.execute(`
      INSERT INTO categories
        (tenant_id, board_id, parent_id, category_name, category_code,
         description, depth, sort_order, icon, color,
         read_permission, write_permission, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      tenantId, board_id, parent_id || null,
      category_name, category_code, description || null,
      depth, sort_order || 0, icon || null, color || null,
      read_permission || 'all', write_permission || 'all',
      req.user?.userId || 'system'
    ]);

    // path 업데이트 (자신의 id 포함)
    const newId = result.insertId;
    const newPath = `${path}${newId}/`;

    await pool.execute(
      'UPDATE categories SET path = ? WHERE id = ?',
      [newPath, newId]
    );

    res.status(201).json({
      id: newId,
      category_code,
      category_name,
      path: newPath,
      message: '카테고리가 생성되었습니다.'
    });
  } catch (error) {
    console.error('카테고리 생성 실패:', error);
    res.status(500).json({ error: '카테고리 생성에 실패했습니다.' });
  }
});

// 카테고리 수정
router.put('/:id', authenticateToken, requireRole(['admin', 'manager']), async (req, res) => {
  const { id } = req.params;
  const {
    parent_id, category_name, description,
    sort_order, icon, color,
    read_permission, write_permission, is_active
  } = req.body;
  const tenantId = req.tenantId;

  try {
    // 부모 변경 시 depth, path 재계산
    let depth = 0;
    let path = '/';

    if (parent_id !== undefined) {
      // 자기 자신을 부모로 설정 불가
      if (parent_id === parseInt(id)) {
        return res.status(400).json({ error: '자기 자신을 상위 카테고리로 설정할 수 없습니다.' });
      }

      // 자신의 하위 카테고리를 부모로 설정 불가
      if (parent_id) {
        const [current] = await pool.execute(
          'SELECT path FROM categories WHERE id = ?',
          [id]
        );
        const [newParent] = await pool.execute(
          'SELECT path FROM categories WHERE id = ?',
          [parent_id]
        );

        if (current.length > 0 && newParent.length > 0) {
          if (newParent[0].path.startsWith(current[0].path)) {
            return res.status(400).json({
              error: '하위 카테고리를 상위로 설정할 수 없습니다.'
            });
          }
        }

        depth = newParent.length > 0 ? newParent[0].depth + 1 : 0;
        path = newParent.length > 0 ? `${newParent[0].path}` : '/';
      }
    }

    const [result] = await pool.execute(`
      UPDATE categories SET
        parent_id = COALESCE(?, parent_id),
        category_name = COALESCE(?, category_name),
        description = ?,
        depth = CASE WHEN ? IS NOT NULL THEN ? ELSE depth END,
        sort_order = COALESCE(?, sort_order),
        icon = ?,
        color = ?,
        read_permission = COALESCE(?, read_permission),
        write_permission = COALESCE(?, write_permission),
        is_active = COALESCE(?, is_active),
        updated_by = ?
      WHERE id = ? AND tenant_id = ? AND is_deleted = FALSE
    `, [
      parent_id, category_name, description || null,
      parent_id !== undefined ? depth : null, depth,
      sort_order, icon || null, color || null,
      read_permission, write_permission, is_active,
      req.user?.userId || 'system',
      id, tenantId
    ]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '카테고리를 찾을 수 없습니다.' });
    }

    // path 업데이트
    if (parent_id !== undefined) {
      const newPath = `${path}${id}/`;
      await pool.execute('UPDATE categories SET path = ? WHERE id = ?', [newPath, id]);

      // 하위 카테고리들의 path도 업데이트
      await updateChildrenPath(id, newPath);
    }

    res.json({ message: '카테고리가 수정되었습니다.' });
  } catch (error) {
    console.error('카테고리 수정 실패:', error);
    res.status(500).json({ error: '카테고리 수정에 실패했습니다.' });
  }
});

// 카테고리 삭제 (소프트 삭제)
router.delete('/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
  const { id } = req.params;
  const tenantId = req.tenantId;

  try {
    // 하위 카테고리가 있는지 확인
    const [children] = await pool.execute(
      'SELECT id FROM categories WHERE parent_id = ? AND is_deleted = FALSE',
      [id]
    );

    if (children.length > 0) {
      return res.status(400).json({
        error: '하위 카테고리가 있어 삭제할 수 없습니다. 먼저 하위 카테고리를 삭제하세요.'
      });
    }

    // 게시글이 있는지 확인
    const [posts] = await pool.execute(
      'SELECT COUNT(*) as count FROM posts WHERE category_id = ? AND is_deleted = FALSE',
      [id]
    );

    if (posts[0].count > 0) {
      return res.status(400).json({
        error: `이 카테고리에 ${posts[0].count}개의 게시글이 있습니다. 먼저 게시글을 이동하거나 삭제하세요.`
      });
    }

    const [result] = await pool.execute(`
      UPDATE categories SET
        is_deleted = TRUE,
        updated_by = ?
      WHERE id = ? AND tenant_id = ?
    `, [req.user?.userId || 'system', id, tenantId]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '카테고리를 찾을 수 없습니다.' });
    }

    res.json({ message: '카테고리가 삭제되었습니다.' });
  } catch (error) {
    console.error('카테고리 삭제 실패:', error);
    res.status(500).json({ error: '카테고리 삭제에 실패했습니다.' });
  }
});

// 카테고리 순서 변경 (드래그앤드롭)
router.put('/reorder', authenticateToken, requireRole(['admin', 'manager']), async (req, res) => {
  const { categoryId, newParentId, newOrder } = req.body;
  const tenantId = req.tenantId;

  try {
    // 트랜잭션으로 순서 업데이트
    const connection = await pool.getConnection();
    await connection.beginTransaction();

    try {
      // 현재 카테고리 조회
      const [current] = await connection.execute(
        'SELECT * FROM categories WHERE id = ? AND tenant_id = ?',
        [categoryId, tenantId]
      );

      if (current.length === 0) {
        await connection.rollback();
        return res.status(404).json({ error: '카테고리를 찾을 수 없습니다.' });
      }

      const category = current[0];
      const oldParentId = category.parent_id;

      // 부모가 변경된 경우
      if (newParentId !== oldParentId) {
        // depth, path 재계산
        let depth = 0;
        let path = '/';

        if (newParentId) {
          const [parent] = await connection.execute(
            'SELECT depth, path FROM categories WHERE id = ?',
            [newParentId]
          );
          if (parent.length > 0) {
            depth = parent[0].depth + 1;
            path = parent[0].path;
          }
        }

        const newPath = `${path}${categoryId}/`;

        await connection.execute(`
          UPDATE categories SET
            parent_id = ?,
            depth = ?,
            path = ?,
            sort_order = ?,
            updated_by = ?
          WHERE id = ?
        `, [newParentId || null, depth, newPath, newOrder, req.user?.userId || 'system', categoryId]);

        // 하위 카테고리 path 업데이트
        await updateChildrenPathWithConnection(connection, categoryId, newPath);
      } else {
        // 같은 부모 내에서 순서만 변경
        await connection.execute(`
          UPDATE categories SET
            sort_order = ?,
            updated_by = ?
          WHERE id = ?
        `, [newOrder, req.user?.userId || 'system', categoryId]);
      }

      await connection.commit();
      res.json({ message: '카테고리 순서가 변경되었습니다.' });
    } catch (error) {
      await connection.rollback();
      throw error;
    } finally {
      connection.release();
    }
  } catch (error) {
    console.error('카테고리 순서 변경 실패:', error);
    res.status(500).json({ error: '카테고리 순서 변경에 실패했습니다.' });
  }
});

// 헬퍼 함수: 계층형 트리 빌드
function buildCategoryTree(categories, parentId = null) {
  return categories
    .filter(c => c.parent_id === parentId)
    .map(category => ({
      ...category,
      children: buildCategoryTree(categories, category.id)
    }));
}

// 헬퍼 함수: 하위 카테고리 path 업데이트
async function updateChildrenPath(parentId, parentPath) {
  const [children] = await pool.execute(
    'SELECT id FROM categories WHERE parent_id = ?',
    [parentId]
  );

  for (const child of children) {
    const childPath = `${parentPath}${child.id}/`;
    await pool.execute(
      'UPDATE categories SET path = ?, depth = ? WHERE id = ?',
      [childPath, parentPath.split('/').length - 2, child.id]
    );
    await updateChildrenPath(child.id, childPath);
  }
}

async function updateChildrenPathWithConnection(connection, parentId, parentPath) {
  const [children] = await connection.execute(
    'SELECT id FROM categories WHERE parent_id = ?',
    [parentId]
  );

  for (const child of children) {
    const childPath = `${parentPath}${child.id}/`;
    await connection.execute(
      'UPDATE categories SET path = ?, depth = ? WHERE id = ?',
      [childPath, parentPath.split('/').length - 2, child.id]
    );
    await updateChildrenPathWithConnection(connection, child.id, childPath);
  }
}

module.exports = router;
```

---

## Phase 3: Frontend 타입

### TypeScript 타입

**파일**: `src/types/category.ts`

```typescript
// 카테고리 타입
export interface Category {
  id: number;
  tenant_id: number;
  board_id: number;
  parent_id: number | null;
  depth: number;
  path: string;
  category_name: string;
  category_code: string;
  description?: string;
  sort_order: number;
  icon?: string;
  color?: string;
  read_permission: 'all' | 'members' | 'admin';
  write_permission: 'all' | 'members' | 'admin';
  post_count: number;
  is_active: boolean;
  children?: Category[];
}

// 카테고리 생성 요청
export interface CreateCategoryRequest {
  board_id: number;
  parent_id?: number | null;
  category_name: string;
  category_code: string;
  description?: string;
  sort_order?: number;
  icon?: string;
  color?: string;
  read_permission?: 'all' | 'members' | 'admin';
  write_permission?: 'all' | 'members' | 'admin';
}

// 카테고리 수정 요청
export interface UpdateCategoryRequest {
  parent_id?: number | null;
  category_name?: string;
  description?: string;
  sort_order?: number;
  icon?: string;
  color?: string;
  read_permission?: 'all' | 'members' | 'admin';
  write_permission?: 'all' | 'members' | 'admin';
  is_active?: boolean;
}

// 카테고리 순서 변경 요청
export interface ReorderCategoryRequest {
  categoryId: number;
  newParentId: number | null;
  newOrder: number;
}
```

### API 클라이언트

**파일**: `src/lib/api/categories.ts`

```typescript
import { apiClient } from './client';
import type {
  Category,
  CreateCategoryRequest,
  UpdateCategoryRequest,
  ReorderCategoryRequest
} from '@/types/category';

// 카테고리 목록 조회 (트리)
export const fetchCategories = async (boardId: number): Promise<Category[]> => {
  const response = await apiClient.get(`/api/categories/board/${boardId}`);
  return response.data;
};

// 카테고리 목록 조회 (flat)
export const fetchCategoriesFlat = async (boardId: number): Promise<Category[]> => {
  const response = await apiClient.get(`/api/categories/board/${boardId}/flat`);
  return response.data;
};

// 카테고리 상세 조회
export const fetchCategory = async (id: number): Promise<Category> => {
  const response = await apiClient.get(`/api/categories/${id}`);
  return response.data;
};

// 카테고리 생성
export const createCategory = async (data: CreateCategoryRequest): Promise<Category> => {
  const response = await apiClient.post('/api/categories', data);
  return response.data;
};

// 카테고리 수정
export const updateCategory = async (id: number, data: UpdateCategoryRequest): Promise<void> => {
  await apiClient.put(`/api/categories/${id}`, data);
};

// 카테고리 삭제
export const deleteCategory = async (id: number): Promise<void> => {
  await apiClient.delete(`/api/categories/${id}`);
};

// 카테고리 순서 변경
export const reorderCategory = async (data: ReorderCategoryRequest): Promise<void> => {
  await apiClient.put('/api/categories/reorder', data);
};
```

---

## Phase 4: Admin UI

### React + MUI 버전

**파일**: `src/components/admin/CategoryManagement.tsx`

```tsx
'use client';

import React, { useState, useCallback } from 'react';
import {
  Box,
  Paper,
  Typography,
  TextField,
  Button,
  IconButton,
  Switch,
  FormControlLabel,
  Select,
  MenuItem,
  FormControl,
  InputLabel,
  Divider,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Chip,
  Alert,
  Breadcrumbs,
  Link,
} from '@mui/material';
import {
  Add as AddIcon,
  Folder as FolderIcon,
  FolderOpen as FolderOpenIcon,
  Delete as DeleteIcon,
  Save as SaveIcon,
  Cancel as CancelIcon,
  ChevronRight as ChevronRightIcon,
  ExpandMore as ExpandMoreIcon,
  DragIndicator as DragIndicatorIcon,
} from '@mui/icons-material';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import {
  Tree,
  NodeModel,
  DragLayerMonitorProps,
} from '@minoru/react-dnd-treeview';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  fetchCategories,
  fetchCategoriesFlat,
  createCategory,
  updateCategory,
  deleteCategory,
  reorderCategory,
} from '@/lib/api/categories';
import type { Category, CreateCategoryRequest, UpdateCategoryRequest } from '@/types/category';

interface CategoryManagementProps {
  boardId: number;
  boardName?: string;
}

// =====================================
// 카테고리 트리 컴포넌트
// =====================================
interface CategoryTreeProps {
  categories: Category[];
  selectedId: number | null;
  onSelect: (id: number | null, isAddMode?: boolean, parentId?: number | null) => void;
  onReorder: (categoryId: number, newParentId: number | null, newOrder: number) => void;
}

function CategoryTree({ categories, selectedId, onSelect, onReorder }: CategoryTreeProps) {
  const [expandedIds, setExpandedIds] = useState<Set<number>>(new Set());

  // Category를 NodeModel로 변환
  const treeData: NodeModel<Category>[] = React.useMemo(() => {
    const flattenCategories = (cats: Category[]): NodeModel<Category>[] => {
      const result: NodeModel<Category>[] = [];
      const flatten = (items: Category[], parentId: number | string = 0) => {
        for (const cat of items) {
          result.push({
            id: cat.id,
            parent: cat.parent_id || 0,
            text: cat.category_name,
            droppable: true,
            data: cat,
          });
          if (cat.children && cat.children.length > 0) {
            flatten(cat.children, cat.id);
          }
        }
      };
      flatten(cats);
      return result;
    };
    return flattenCategories(categories);
  }, [categories]);

  const handleDrop = (newTree: NodeModel<Category>[], options: any) => {
    const { dragSourceId, dropTargetId, destinationIndex } = options;
    onReorder(
      dragSourceId as number,
      dropTargetId === 0 ? null : dropTargetId as number,
      destinationIndex || 0
    );
  };

  const handleToggle = (nodeId: number) => {
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(nodeId)) {
        next.delete(nodeId);
      } else {
        next.add(nodeId);
      }
      return next;
    });
  };

  const renderNode = useCallback(
    (node: NodeModel<Category>, { depth, isOpen, onToggle }: any) => {
      const hasChildren = treeData.some((n) => n.parent === node.id);
      const isSelected = selectedId === node.id;
      const category = node.data!;

      return (
        <Box
          sx={(theme) => ({
            display: 'flex',
            alignItems: 'center',
            py: 0.5,
            px: 1,
            ml: depth * 2,
            cursor: 'pointer',
            borderRadius: 1,
            bgcolor: isSelected ? theme.palette.action.selected : 'transparent',
            border: isSelected ? `1px solid ${theme.palette.primary.light}` : '1px solid transparent',
            '&:hover': {
              bgcolor: theme.palette.action.hover,
            },
          })}
          onClick={() => onSelect(node.id as number)}
        >
          {/* 드래그 핸들 */}
          <DragIndicatorIcon
            sx={(theme) => ({
              fontSize: 16,
              color: theme.palette.text.disabled,
              mr: 0.5,
              cursor: 'grab',
            })}
          />

          {/* 확장/축소 아이콘 */}
          {hasChildren ? (
            <IconButton
              size="small"
              onClick={(e) => {
                e.stopPropagation();
                onToggle();
              }}
              sx={{ p: 0.25 }}
            >
              {isOpen ? <ExpandMoreIcon fontSize="small" /> : <ChevronRightIcon fontSize="small" />}
            </IconButton>
          ) : (
            <Box sx={{ width: 24 }} />
          )}

          {/* 폴더 아이콘 */}
          {hasChildren || category.children?.length ? (
            isOpen ? (
              <FolderOpenIcon sx={(theme) => ({ fontSize: 18, color: theme.palette.warning.main, mr: 1 })} />
            ) : (
              <FolderIcon sx={(theme) => ({ fontSize: 18, color: theme.palette.warning.main, mr: 1 })} />
            )
          ) : (
            <FolderIcon sx={(theme) => ({ fontSize: 18, color: theme.palette.grey[400], mr: 1 })} />
          )}

          {/* 카테고리 색상 표시 */}
          {category.color && (
            <Box
              sx={{
                width: 12,
                height: 12,
                borderRadius: '50%',
                bgcolor: category.color,
                mr: 1,
              }}
            />
          )}

          {/* 카테고리명 */}
          <Typography
            variant="body2"
            sx={(theme) => ({
              flex: 1,
              color: category.is_active ? theme.palette.text.primary : theme.palette.text.disabled,
            })}
          >
            {node.text}
          </Typography>

          {/* 게시글 수 */}
          {category.post_count > 0 && (
            <Chip
              size="small"
              label={category.post_count}
              sx={{ height: 20, fontSize: 11 }}
            />
          )}
        </Box>
      );
    },
    [treeData, selectedId, onSelect]
  );

  return (
    <DndProvider backend={HTML5Backend}>
      <Tree
        tree={treeData}
        rootId={0}
        onDrop={handleDrop}
        render={renderNode}
        dragPreviewRender={(monitorProps: DragLayerMonitorProps<Category>) => (
          <Box sx={{ p: 1, bgcolor: 'background.paper', boxShadow: 2, borderRadius: 1 }}>
            {monitorProps.item.text}
          </Box>
        )}
        canDrop={(tree, { dragSource, dropTargetId }) => {
          if (dragSource?.id === dropTargetId) return false;
          return true;
        }}
        sort={false}
        insertDroppableFirst={false}
        dropTargetOffset={10}
        placeholderRender={(node, { depth }) => (
          <Box
            sx={(theme) => ({
              height: 4,
              ml: depth * 2,
              bgcolor: theme.palette.primary.main,
              borderRadius: 1,
            })}
          />
        )}
      />
    </DndProvider>
  );
}

// =====================================
// 카테고리 상세 패널
// =====================================
interface CategoryDetailPanelProps {
  category: Category | null;
  isAddMode: boolean;
  parentId: number | null;
  boardId: number;
  parentCategories: Category[];
  onSave: (data: CreateCategoryRequest | UpdateCategoryRequest) => Promise<void>;
  onDelete: (id: number) => Promise<void>;
  onCancel: () => void;
}

function CategoryDetailPanel({
  category,
  isAddMode,
  parentId,
  boardId,
  parentCategories,
  onSave,
  onDelete,
  onCancel,
}: CategoryDetailPanelProps) {
  const [formData, setFormData] = useState<CreateCategoryRequest>({
    board_id: boardId,
    parent_id: null,
    category_name: '',
    category_code: '',
    description: '',
    sort_order: 0,
    icon: '',
    color: '#1976d2',
    read_permission: 'all',
    write_permission: 'all',
  });
  const [isActive, setIsActive] = useState(true);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  // 폼 초기화
  React.useEffect(() => {
    if (category && !isAddMode) {
      setFormData({
        board_id: category.board_id,
        parent_id: category.parent_id,
        category_name: category.category_name,
        category_code: category.category_code,
        description: category.description || '',
        sort_order: category.sort_order,
        icon: category.icon || '',
        color: category.color || '#1976d2',
        read_permission: category.read_permission,
        write_permission: category.write_permission,
      });
      setIsActive(category.is_active);
    } else if (isAddMode) {
      setFormData({
        board_id: boardId,
        parent_id: parentId,
        category_name: '',
        category_code: '',
        description: '',
        sort_order: 0,
        icon: '',
        color: '#1976d2',
        read_permission: 'all',
        write_permission: 'all',
      });
      setIsActive(true);
    }
    setErrors({});
    setShowDeleteConfirm(false);
  }, [category, isAddMode, parentId, boardId]);

  const handleChange = (field: keyof CreateCategoryRequest, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => {
        const next = { ...prev };
        delete next[field];
        return next;
      });
    }
  };

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.category_name.trim()) {
      newErrors.category_name = '카테고리명을 입력하세요.';
    }

    if (!formData.category_code.trim()) {
      newErrors.category_code = '카테고리 코드를 입력하세요.';
    } else if (!/^[a-z0-9_]+$/.test(formData.category_code)) {
      newErrors.category_code = '영문 소문자, 숫자, 언더스코어만 사용 가능합니다.';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async () => {
    if (!validate()) return;

    try {
      if (isAddMode) {
        await onSave(formData);
      } else {
        await onSave({
          parent_id: formData.parent_id,
          category_name: formData.category_name,
          description: formData.description,
          sort_order: formData.sort_order,
          icon: formData.icon,
          color: formData.color,
          read_permission: formData.read_permission,
          write_permission: formData.write_permission,
          is_active: isActive,
        });
      }
    } catch (error) {
      console.error('저장 실패:', error);
    }
  };

  const handleDelete = async () => {
    if (!category) return;
    try {
      await onDelete(category.id);
      setShowDeleteConfirm(false);
    } catch (error) {
      console.error('삭제 실패:', error);
    }
  };

  // 빈 상태
  if (!category && !isAddMode) {
    return (
      <Box sx={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <Typography color="text.secondary">
          카테고리를 선택하거나 새로 추가하세요.
        </Typography>
      </Box>
    );
  }

  // 상위 카테고리로 선택 가능한 목록 (자기 자신과 하위 제외)
  const availableParents = parentCategories.filter((c) => {
    if (!category) return true;
    // 자기 자신 제외
    if (c.id === category.id) return false;
    // 자신의 하위 카테고리 제외
    if (c.path && category.path && c.path.includes(`/${category.id}/`)) return false;
    return true;
  });

  return (
    <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* 헤더 */}
      <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Typography variant="h6">
            {isAddMode ? '카테고리 추가' : '카테고리 수정'}
          </Typography>
          <Box sx={{ display: 'flex', gap: 1 }}>
            <Button variant="outlined" startIcon={<CancelIcon />} onClick={onCancel}>
              취소
            </Button>
            <Button variant="contained" startIcon={<SaveIcon />} onClick={handleSubmit}>
              저장
            </Button>
          </Box>
        </Box>
      </Box>

      {/* 폼 */}
      <Box sx={{ flex: 1, overflow: 'auto', p: 3 }}>
        <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, maxWidth: 500 }}>
          <TextField
            label="카테고리 코드"
            value={formData.category_code}
            onChange={(e) => handleChange('category_code', e.target.value.toLowerCase())}
            error={!!errors.category_code}
            helperText={errors.category_code || '영문 소문자, 숫자, 언더스코어만 (예: general)'}
            disabled={!isAddMode}
            required
          />

          <TextField
            label="카테고리명"
            value={formData.category_name}
            onChange={(e) => handleChange('category_name', e.target.value)}
            error={!!errors.category_name}
            helperText={errors.category_name}
            required
          />

          <FormControl fullWidth>
            <InputLabel>상위 카테고리</InputLabel>
            <Select
              value={formData.parent_id || ''}
              onChange={(e) => handleChange('parent_id', e.target.value || null)}
              label="상위 카테고리"
            >
              <MenuItem value="">
                <em>없음 (최상위)</em>
              </MenuItem>
              {availableParents.map((c) => (
                <MenuItem key={c.id} value={c.id}>
                  {'　'.repeat(c.depth)}{c.category_name}
                </MenuItem>
              ))}
            </Select>
          </FormControl>

          <TextField
            label="설명"
            value={formData.description}
            onChange={(e) => handleChange('description', e.target.value)}
            multiline
            rows={2}
          />

          <Box sx={{ display: 'flex', gap: 2 }}>
            <Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                색상
              </Typography>
              <input
                type="color"
                value={formData.color || '#1976d2'}
                onChange={(e) => handleChange('color', e.target.value)}
                style={{ width: 50, height: 40, cursor: 'pointer' }}
              />
            </Box>
            <TextField
              label="아이콘"
              value={formData.icon}
              onChange={(e) => handleChange('icon', e.target.value)}
              placeholder="예: folder, star"
              sx={{ flex: 1 }}
            />
          </Box>

          <Box sx={{ display: 'flex', gap: 2 }}>
            <FormControl sx={{ flex: 1 }}>
              <InputLabel>읽기 권한</InputLabel>
              <Select
                value={formData.read_permission}
                onChange={(e) => handleChange('read_permission', e.target.value)}
                label="읽기 권한"
              >
                <MenuItem value="all">전체</MenuItem>
                <MenuItem value="members">회원만</MenuItem>
                <MenuItem value="admin">관리자만</MenuItem>
              </Select>
            </FormControl>
            <FormControl sx={{ flex: 1 }}>
              <InputLabel>쓰기 권한</InputLabel>
              <Select
                value={formData.write_permission}
                onChange={(e) => handleChange('write_permission', e.target.value)}
                label="쓰기 권한"
              >
                <MenuItem value="all">전체</MenuItem>
                <MenuItem value="members">회원만</MenuItem>
                <MenuItem value="admin">관리자만</MenuItem>
              </Select>
            </FormControl>
          </Box>

          <TextField
            label="정렬 순서"
            type="number"
            value={formData.sort_order}
            onChange={(e) => handleChange('sort_order', parseInt(e.target.value) || 0)}
          />

          {!isAddMode && (
            <FormControlLabel
              control={
                <Switch
                  checked={isActive}
                  onChange={(e) => setIsActive(e.target.checked)}
                />
              }
              label="활성화"
            />
          )}

          {/* 삭제 영역 */}
          {!isAddMode && category && (
            <>
              <Divider sx={{ my: 2 }} />
              <Box>
                <Typography variant="subtitle2" color="error" gutterBottom>
                  위험 영역
                </Typography>
                {!showDeleteConfirm ? (
                  <Button
                    variant="outlined"
                    color="error"
                    startIcon={<DeleteIcon />}
                    onClick={() => setShowDeleteConfirm(true)}
                    size="small"
                  >
                    카테고리 삭제
                  </Button>
                ) : (
                  <Alert
                    severity="error"
                    action={
                      <Box sx={{ display: 'flex', gap: 1 }}>
                        <Button size="small" onClick={() => setShowDeleteConfirm(false)}>
                          취소
                        </Button>
                        <Button size="small" color="error" variant="contained" onClick={handleDelete}>
                          삭제
                        </Button>
                      </Box>
                    }
                  >
                    정말 삭제하시겠습니까?
                  </Alert>
                )}
              </Box>
            </>
          )}
        </Box>
      </Box>
    </Box>
  );
}

// =====================================
// 메인 컴포넌트
// =====================================
export default function CategoryManagement({ boardId, boardName }: CategoryManagementProps) {
  const queryClient = useQueryClient();
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [isAddMode, setIsAddMode] = useState(false);
  const [parentIdForNew, setParentIdForNew] = useState<number | null>(null);

  // 카테고리 목록 (트리)
  const { data: categories = [] } = useQuery({
    queryKey: ['categories', boardId],
    queryFn: () => fetchCategories(boardId),
  });

  // 카테고리 목록 (flat) - 상위 선택용
  const { data: categoriesFlat = [] } = useQuery({
    queryKey: ['categories-flat', boardId],
    queryFn: () => fetchCategoriesFlat(boardId),
  });

  // 선택된 카테고리 찾기
  const findCategory = (cats: Category[], id: number): Category | null => {
    for (const cat of cats) {
      if (cat.id === id) return cat;
      if (cat.children) {
        const found = findCategory(cat.children, id);
        if (found) return found;
      }
    }
    return null;
  };

  const selectedCategory = selectedId ? findCategory(categories, selectedId) : null;

  // Mutations
  const createMutation = useMutation({
    mutationFn: createCategory,
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['categories', boardId] });
      queryClient.invalidateQueries({ queryKey: ['categories-flat', boardId] });
      setSelectedId(data.id);
      setIsAddMode(false);
    },
  });

  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: number; data: UpdateCategoryRequest }) => updateCategory(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories', boardId] });
      queryClient.invalidateQueries({ queryKey: ['categories-flat', boardId] });
    },
  });

  const deleteMutation = useMutation({
    mutationFn: deleteCategory,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories', boardId] });
      queryClient.invalidateQueries({ queryKey: ['categories-flat', boardId] });
      setSelectedId(null);
      setIsAddMode(false);
    },
  });

  const reorderMutation = useMutation({
    mutationFn: reorderCategory,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['categories', boardId] });
      queryClient.invalidateQueries({ queryKey: ['categories-flat', boardId] });
    },
  });

  const handleSelect = useCallback((id: number | null, addMode = false, parentId: number | null = null) => {
    setSelectedId(id);
    setIsAddMode(addMode);
    setParentIdForNew(parentId);
  }, []);

  const handleSave = async (data: CreateCategoryRequest | UpdateCategoryRequest) => {
    if (isAddMode) {
      await createMutation.mutateAsync(data as CreateCategoryRequest);
    } else if (selectedId) {
      await updateMutation.mutateAsync({ id: selectedId, data: data as UpdateCategoryRequest });
    }
  };

  const handleDelete = async (id: number) => {
    await deleteMutation.mutateAsync(id);
  };

  const handleReorder = (categoryId: number, newParentId: number | null, newOrder: number) => {
    reorderMutation.mutate({ categoryId, newParentId, newOrder });
  };

  const handleCancel = () => {
    setSelectedId(null);
    setIsAddMode(false);
    setParentIdForNew(null);
  };

  return (
    <Box sx={{ display: 'flex', height: '100%' }}>
      {/* 좌측: 카테고리 트리 */}
      <Paper
        sx={(theme) => ({
          width: 320,
          display: 'flex',
          flexDirection: 'column',
          borderRight: `1px solid ${theme.palette.divider}`,
        })}
      >
        {/* 헤더 */}
        <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
          <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <Box>
              <Typography variant="h6">카테고리</Typography>
              {boardName && (
                <Typography variant="caption" color="text.secondary">
                  {boardName}
                </Typography>
              )}
            </Box>
            <Button
              variant="contained"
              size="small"
              startIcon={<AddIcon />}
              onClick={() => handleSelect(null, true, null)}
            >
              추가
            </Button>
          </Box>
        </Box>

        {/* 트리 */}
        <Box sx={{ flex: 1, overflow: 'auto', p: 1 }}>
          {categories.length === 0 ? (
            <Typography color="text.secondary" sx={{ p: 2, textAlign: 'center' }}>
              카테고리가 없습니다.
            </Typography>
          ) : (
            <CategoryTree
              categories={categories}
              selectedId={selectedId}
              onSelect={handleSelect}
              onReorder={handleReorder}
            />
          )}
        </Box>
      </Paper>

      {/* 우측: 상세 패널 */}
      <CategoryDetailPanel
        category={selectedCategory}
        isAddMode={isAddMode}
        parentId={parentIdForNew}
        boardId={boardId}
        parentCategories={categoriesFlat}
        onSave={handleSave}
        onDelete={handleDelete}
        onCancel={handleCancel}
      />
    </Box>
  );
}
```

---

## Phase 5: 게시판 생성/수정 시 카테고리 연동

### board-generator 연동

게시판 생성/수정 시 카테고리 사용 여부와 기본 카테고리를 설정할 수 있습니다.

```typescript
// board-generator의 게시판 설정에 추가
interface BoardConfig {
  // ... 기존 설정
  use_category: boolean;           // 카테고리 사용 여부
  category_required: boolean;      // 글 작성 시 카테고리 필수 여부
  default_categories?: string[];   // 기본 생성할 카테고리 코드 목록
}

// 게시판 생성 후 기본 카테고리 생성
async function createDefaultCategories(boardId: number, tenantId: number, categories: string[]) {
  for (let i = 0; i < categories.length; i++) {
    await createCategory({
      board_id: boardId,
      category_name: categories[i],
      category_code: categories[i].toLowerCase().replace(/\s+/g, '_'),
      sort_order: i * 10,
    });
  }
}
```

---

## 라우트 등록

### Express

```javascript
const categoriesRouter = require('./api/categories');

// 카테고리 API 라우트
app.use('/api/categories', categoriesRouter);
```

### Next.js

**파일**: `app/admin/boards/[boardId]/categories/page.tsx`

```tsx
import CategoryManagement from '@/components/admin/CategoryManagement';

export default function CategoriesPage({ params }: { params: { boardId: string } }) {
  return <CategoryManagement boardId={parseInt(params.boardId)} />;
}
```

---

## 완료 메시지

```
✅ 카테고리 관리 시스템 초기화 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

생성된 파일:
  DB:
    ✓ categories 테이블

  Backend:
    ✓ api/categories.js - 카테고리 API

  Frontend:
    ✓ src/types/category.ts - 타입 정의
    ✓ src/lib/api/categories.ts - API 클라이언트
    ✓ src/components/admin/CategoryManagement.tsx - Admin UI

기능:
  ✓ 카테고리 CRUD (생성, 조회, 수정, 삭제)
  ✓ 계층형 카테고리 (무한 depth)
  ✓ 드래그앤드롭 순서/계층 변경
  ✓ 카테고리별 색상/아이콘
  ✓ 읽기/쓰기 권한 설정

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

다음 단계:
  1. 게시판 생성 시 카테고리 사용 설정
  2. 게시글 작성 시 카테고리 선택 UI 추가
```

---

## 참고

- categories 테이블은 boards 테이블에 의존 (FK)
- 게시판별로 독립적인 카테고리 관리
- path 컬럼으로 빠른 계층 조회 가능
