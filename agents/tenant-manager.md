---
name: tenant-manager
description: 테넌트(멀티사이트) 관리 에이전트. 테넌트 CRUD, 도메인 설정, 테마/로고 설정 등. 최우선 순위 - shared-schema 다음으로 실행.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 테넌트 관리 에이전트

**멀티 테넌시** 환경에서 테넌트(사이트/조직)를 관리하는 에이전트입니다.

> **최우선 순위**: shared-schema → **tenant-manager** → category-manager → 기타

---

## 사용법

```bash
# 테넌트 관리 시스템 초기화
Use tenant-manager --init

# 테넌트 추가
Use tenant-manager to create tenant "쇼핑몰A" with code: shopA

# 테넌트 목록 조회
Use tenant-manager --list
```

---

## 테넌트 개념

```
┌─────────────────────────────────────────────────────────────┐
│                     하나의 시스템                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  테넌트 A   │  │  테넌트 B   │  │  테넌트 C   │         │
│  │  (쇼핑몰)   │  │ (커뮤니티)  │  │  (기업)     │         │
│  │             │  │             │  │             │         │
│  │ - 게시판    │  │ - 게시판    │  │ - 게시판    │         │
│  │ - 메뉴      │  │ - 메뉴      │  │ - 메뉴      │         │
│  │ - 사용자    │  │ - 사용자    │  │ - 사용자    │         │
│  │ - 설정      │  │ - 설정      │  │ - 설정      │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

### 테넌트 식별 방식

| 방식 | 예시 | 설명 |
|------|------|------|
| 도메인 | `shopA.com` | 완전 독립 사이트 |
| 서브도메인 | `shopA.example.com` | SaaS 플랫폼 |
| 경로 | `example.com/shopA` | 단일 도메인 멀티사이트 |
| 헤더 | `X-Tenant-ID: shopA` | API 기반 |

---

## Phase 0: 사전 검증 (CRITICAL)

> **중요**: tenants 테이블이 없으면 API가 실행되지 않습니다!

### Step 1: 기술 스택 감지

```bash
# Backend 확인
ls package.json requirements.txt pom.xml 2>/dev/null

# Database 확인
grep -E "mysql|postgres|mongodb" package.json requirements.txt 2>/dev/null
```

### Step 2: tenants 테이블 존재 확인

```sql
-- MySQL/MariaDB
SELECT COUNT(*) FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tenants';
```

**결과가 0이면:**
```
⚠️ tenants 테이블이 존재하지 않습니다!
🔧 shared-schema를 먼저 실행해야 합니다.

Use shared-schema --init
```

### Step 3: API 시작 전 테이블 확인 미들웨어

```javascript
// middleware/checkTenantTable.js
const { pool } = require('../db');

const checkTenantTableExists = async (req, res, next) => {
  try {
    const [rows] = await pool.execute(`
      SELECT COUNT(*) as cnt FROM information_schema.TABLES
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tenants'
    `);

    if (rows[0].cnt === 0) {
      return res.status(500).json({
        error: 'tenants 테이블이 존재하지 않습니다.',
        solution: 'shared-schema를 먼저 실행하세요: Use shared-schema --init'
      });
    }

    next();
  } catch (error) {
    console.error('테이블 확인 오류:', error);
    res.status(500).json({ error: '데이터베이스 연결 오류' });
  }
};

module.exports = { checkTenantTableExists };
```

### Step 4: 라우터에 미들웨어 적용

```javascript
// api/tenants.js
const { checkTenantTableExists } = require('../middleware/checkTenantTable');

// 모든 테넌트 API에 테이블 확인 미들웨어 적용
router.use(checkTenantTableExists);

// 또는 개별 라우트에 적용
router.get('/', checkTenantTableExists, async (req, res) => { ... });
```

---

## Phase 1: DB 스키마 (shared-schema에서 생성됨)

> **참고**: tenants 테이블은 `shared-schema`에서 이미 생성됩니다.
> **테이블이 없으면**: `Use shared-schema --init` 먼저 실행!

```sql
-- shared-schema에서 생성되는 테이블
CREATE TABLE IF NOT EXISTS tenants (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 기본 정보
  tenant_code VARCHAR(50) NOT NULL UNIQUE,
  tenant_name VARCHAR(100) NOT NULL,
  description VARCHAR(500),

  -- 도메인 설정
  domain VARCHAR(255),
  subdomain VARCHAR(100),

  -- 설정 (JSON)
  settings JSON,
  -- {
  --   "theme": "default",
  --   "logo": "/uploads/logo.png",
  --   "favicon": "/uploads/favicon.ico",
  --   "language": "ko",
  --   "timezone": "Asia/Seoul",
  --   "primaryColor": "#1976d2",
  --   "companyName": "회사명"
  -- }

  -- 연락처
  admin_email VARCHAR(255),
  admin_name VARCHAR(100),

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

---

## Phase 2: Backend API

### Express.js

**파일**: `api/tenants.js` 또는 `routes/tenants.js`

```javascript
const express = require('express');
const router = express.Router();
const { pool } = require('../db');
const { authenticateToken, requireRole } = require('../middleware/auth');

// 테넌트 목록 조회
router.get('/', authenticateToken, requireRole(['super_admin']), async (req, res) => {
  try {
    const [tenants] = await pool.execute(`
      SELECT id, tenant_code, tenant_name, description,
             domain, subdomain, settings,
             admin_email, admin_name,
             is_active, created_at, updated_at
      FROM tenants
      WHERE is_deleted = FALSE
      ORDER BY created_at DESC
    `);

    // settings JSON 파싱
    const result = tenants.map(t => ({
      ...t,
      settings: t.settings ? JSON.parse(t.settings) : {}
    }));

    res.json(result);
  } catch (error) {
    console.error('테넌트 목록 조회 실패:', error);
    res.status(500).json({ error: '테넌트 목록을 가져오는데 실패했습니다.' });
  }
});

// 테넌트 상세 조회
router.get('/:id', authenticateToken, requireRole(['super_admin', 'admin']), async (req, res) => {
  try {
    const [tenants] = await pool.execute(`
      SELECT * FROM tenants
      WHERE id = ? AND is_deleted = FALSE
    `, [req.params.id]);

    if (tenants.length === 0) {
      return res.status(404).json({ error: '테넌트를 찾을 수 없습니다.' });
    }

    const tenant = tenants[0];
    tenant.settings = tenant.settings ? JSON.parse(tenant.settings) : {};

    res.json(tenant);
  } catch (error) {
    console.error('테넌트 조회 실패:', error);
    res.status(500).json({ error: '테넌트를 가져오는데 실패했습니다.' });
  }
});

// 테넌트 생성
router.post('/', authenticateToken, requireRole(['super_admin']), async (req, res) => {
  const {
    tenant_code, tenant_name, description,
    domain, subdomain, settings,
    admin_email, admin_name
  } = req.body;

  // 유효성 검사
  if (!tenant_code || !tenant_name) {
    return res.status(400).json({ error: '테넌트 코드와 이름은 필수입니다.' });
  }

  // tenant_code 형식 검사 (영문, 숫자, 언더스코어만)
  if (!/^[a-z0-9_]+$/.test(tenant_code)) {
    return res.status(400).json({
      error: '테넌트 코드는 영문 소문자, 숫자, 언더스코어만 사용 가능합니다.'
    });
  }

  try {
    // 중복 체크
    const [existing] = await pool.execute(
      'SELECT id FROM tenants WHERE tenant_code = ?',
      [tenant_code]
    );

    if (existing.length > 0) {
      return res.status(409).json({ error: '이미 존재하는 테넌트 코드입니다.' });
    }

    const [result] = await pool.execute(`
      INSERT INTO tenants
        (tenant_code, tenant_name, description, domain, subdomain,
         settings, admin_email, admin_name, created_by)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    `, [
      tenant_code, tenant_name, description || null,
      domain || null, subdomain || null,
      settings ? JSON.stringify(settings) : null,
      admin_email || null, admin_name || null,
      req.user?.userId || 'system'
    ]);

    res.status(201).json({
      id: result.insertId,
      tenant_code,
      tenant_name,
      message: '테넌트가 생성되었습니다.'
    });
  } catch (error) {
    console.error('테넌트 생성 실패:', error);
    res.status(500).json({ error: '테넌트 생성에 실패했습니다.' });
  }
});

// 테넌트 수정
router.put('/:id', authenticateToken, requireRole(['super_admin']), async (req, res) => {
  const { id } = req.params;
  const {
    tenant_name, description,
    domain, subdomain, settings,
    admin_email, admin_name, is_active
  } = req.body;

  try {
    const [result] = await pool.execute(`
      UPDATE tenants SET
        tenant_name = COALESCE(?, tenant_name),
        description = ?,
        domain = ?,
        subdomain = ?,
        settings = ?,
        admin_email = ?,
        admin_name = ?,
        is_active = COALESCE(?, is_active),
        updated_by = ?
      WHERE id = ? AND is_deleted = FALSE
    `, [
      tenant_name,
      description || null,
      domain || null,
      subdomain || null,
      settings ? JSON.stringify(settings) : null,
      admin_email || null,
      admin_name || null,
      is_active,
      req.user?.userId || 'system',
      id
    ]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '테넌트를 찾을 수 없습니다.' });
    }

    res.json({ message: '테넌트가 수정되었습니다.' });
  } catch (error) {
    console.error('테넌트 수정 실패:', error);
    res.status(500).json({ error: '테넌트 수정에 실패했습니다.' });
  }
});

// 테넌트 삭제 (소프트 삭제)
router.delete('/:id', authenticateToken, requireRole(['super_admin']), async (req, res) => {
  const { id } = req.params;

  // default 테넌트는 삭제 불가
  try {
    const [tenant] = await pool.execute(
      'SELECT tenant_code FROM tenants WHERE id = ?',
      [id]
    );

    if (tenant.length > 0 && tenant[0].tenant_code === 'default') {
      return res.status(400).json({ error: '기본 테넌트는 삭제할 수 없습니다.' });
    }

    const [result] = await pool.execute(`
      UPDATE tenants SET
        is_deleted = TRUE,
        updated_by = ?
      WHERE id = ?
    `, [req.user?.userId || 'system', id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '테넌트를 찾을 수 없습니다.' });
    }

    res.json({ message: '테넌트가 삭제되었습니다.' });
  } catch (error) {
    console.error('테넌트 삭제 실패:', error);
    res.status(500).json({ error: '테넌트 삭제에 실패했습니다.' });
  }
});

// 현재 테넌트 정보 조회 (미들웨어에서 설정된)
router.get('/current/info', authenticateToken, async (req, res) => {
  if (!req.tenant) {
    return res.status(400).json({ error: '테넌트 정보가 없습니다.' });
  }

  res.json({
    id: req.tenant.id,
    tenant_code: req.tenant.tenant_code,
    tenant_name: req.tenant.tenant_name,
    settings: req.tenant.settings ? JSON.parse(req.tenant.settings) : {}
  });
});

module.exports = router;
```

### 테넌트 미들웨어

**파일**: `middleware/tenantMiddleware.js`

```javascript
const { pool } = require('../db');

/**
 * 테넌트 식별 미들웨어
 * 요청에서 테넌트를 식별하고 req.tenant, req.tenantId에 설정
 */
const tenantMiddleware = async (req, res, next) => {
  try {
    // 1. 테넌트 식별 (우선순위: 헤더 > 서브도메인 > 세션 > 기본값)
    let tenantCode = null;

    // 헤더에서 확인
    if (req.headers['x-tenant-id']) {
      tenantCode = req.headers['x-tenant-id'];
    }
    // 서브도메인에서 확인
    else if (req.hostname) {
      const parts = req.hostname.split('.');
      if (parts.length >= 3) {
        tenantCode = parts[0];
      }
    }
    // 세션에서 확인
    else if (req.session?.tenantCode) {
      tenantCode = req.session.tenantCode;
    }

    // 기본값
    if (!tenantCode) {
      tenantCode = 'default';
    }

    // 2. 테넌트 정보 조회
    const [tenants] = await pool.execute(`
      SELECT * FROM tenants
      WHERE tenant_code = ? AND is_active = TRUE AND is_deleted = FALSE
    `, [tenantCode]);

    if (tenants.length === 0) {
      // 테넌트를 찾을 수 없으면 기본 테넌트로 폴백
      const [defaultTenants] = await pool.execute(`
        SELECT * FROM tenants
        WHERE tenant_code = 'default' AND is_active = TRUE AND is_deleted = FALSE
      `);

      if (defaultTenants.length === 0) {
        return res.status(500).json({
          error: '시스템 오류: 기본 테넌트가 설정되지 않았습니다.'
        });
      }

      req.tenant = defaultTenants[0];
    } else {
      req.tenant = tenants[0];
    }

    // 3. 요청에 테넌트 정보 추가
    req.tenantId = req.tenant.id;
    req.tenantCode = req.tenant.tenant_code;

    // settings JSON 파싱
    if (req.tenant.settings && typeof req.tenant.settings === 'string') {
      req.tenant.settings = JSON.parse(req.tenant.settings);
    }

    next();
  } catch (error) {
    console.error('테넌트 미들웨어 오류:', error);
    res.status(500).json({ error: '테넌트 처리 중 오류가 발생했습니다.' });
  }
};

/**
 * 슈퍼 관리자용 테넌트 전환 미들웨어
 * 슈퍼 관리자가 특정 테넌트로 전환하여 관리할 수 있음
 */
const tenantSwitchMiddleware = async (req, res, next) => {
  // 슈퍼 관리자이고 X-Switch-Tenant 헤더가 있는 경우
  if (req.user?.role === 'super_admin' && req.headers['x-switch-tenant']) {
    const switchToCode = req.headers['x-switch-tenant'];

    const [tenants] = await pool.execute(`
      SELECT * FROM tenants
      WHERE tenant_code = ? AND is_deleted = FALSE
    `, [switchToCode]);

    if (tenants.length > 0) {
      req.tenant = tenants[0];
      req.tenantId = tenants[0].id;
      req.tenantCode = tenants[0].tenant_code;
      req.isSwitchedTenant = true;
    }
  }

  next();
};

module.exports = { tenantMiddleware, tenantSwitchMiddleware };
```

---

## Phase 3: Frontend 타입

### TypeScript 타입

**파일**: `src/types/tenant.ts`

```typescript
// 테넌트 설정 타입
export interface TenantSettings {
  theme?: 'default' | 'dark' | 'light';
  logo?: string;
  favicon?: string;
  language?: 'ko' | 'en' | 'ja' | 'zh';
  timezone?: string;
  primaryColor?: string;
  companyName?: string;
  // 추가 설정
  [key: string]: any;
}

// 테넌트 타입
export interface Tenant {
  id: number;
  tenant_code: string;
  tenant_name: string;
  description?: string;
  domain?: string;
  subdomain?: string;
  settings?: TenantSettings;
  admin_email?: string;
  admin_name?: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

// 테넌트 생성 요청
export interface CreateTenantRequest {
  tenant_code: string;
  tenant_name: string;
  description?: string;
  domain?: string;
  subdomain?: string;
  settings?: TenantSettings;
  admin_email?: string;
  admin_name?: string;
}

// 테넌트 수정 요청
export interface UpdateTenantRequest {
  tenant_name?: string;
  description?: string;
  domain?: string;
  subdomain?: string;
  settings?: TenantSettings;
  admin_email?: string;
  admin_name?: string;
  is_active?: boolean;
}
```

### API 클라이언트

**파일**: `src/lib/api/tenants.ts`

```typescript
import { apiClient } from './client';
import type { Tenant, CreateTenantRequest, UpdateTenantRequest } from '@/types/tenant';

// 테넌트 목록 조회
export const fetchTenants = async (): Promise<Tenant[]> => {
  const response = await apiClient.get('/api/tenants');
  return response.data;
};

// 테넌트 상세 조회
export const fetchTenant = async (id: number): Promise<Tenant> => {
  const response = await apiClient.get(`/api/tenants/${id}`);
  return response.data;
};

// 테넌트 생성
export const createTenant = async (data: CreateTenantRequest): Promise<Tenant> => {
  const response = await apiClient.post('/api/tenants', data);
  return response.data;
};

// 테넌트 수정
export const updateTenant = async (id: number, data: UpdateTenantRequest): Promise<void> => {
  await apiClient.put(`/api/tenants/${id}`, data);
};

// 테넌트 삭제
export const deleteTenant = async (id: number): Promise<void> => {
  await apiClient.delete(`/api/tenants/${id}`);
};

// 현재 테넌트 정보
export const fetchCurrentTenant = async (): Promise<Tenant> => {
  const response = await apiClient.get('/api/tenants/current/info');
  return response.data;
};
```

---

## Phase 4: Admin UI

### React + MUI 버전

**파일**: `src/components/admin/TenantManagement.tsx`

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
  Divider,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Chip,
  Alert,
  Breadcrumbs,
  Link,
  InputAdornment,
  Tabs,
  Tab,
} from '@mui/material';
import {
  Add as AddIcon,
  Business as BusinessIcon,
  Delete as DeleteIcon,
  Save as SaveIcon,
  Cancel as CancelIcon,
  Language as LanguageIcon,
  Settings as SettingsIcon,
  Palette as PaletteIcon,
} from '@mui/icons-material';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  fetchTenants,
  createTenant,
  updateTenant,
  deleteTenant,
} from '@/lib/api/tenants';
import type { Tenant, CreateTenantRequest, UpdateTenantRequest, TenantSettings } from '@/types/tenant';

// =====================================
// 테넌트 목록 패널
// =====================================
interface TenantListPanelProps {
  tenants: Tenant[];
  selectedId: number | null;
  onSelect: (id: number | null, isAddMode?: boolean) => void;
}

function TenantListPanel({ tenants, selectedId, onSelect }: TenantListPanelProps) {
  const [searchQuery, setSearchQuery] = useState('');

  const filteredTenants = tenants.filter((t) =>
    t.tenant_name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.tenant_code.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <Paper
      sx={(theme) => ({
        width: 300,
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        borderRight: `1px solid ${theme.palette.divider}`,
      })}
    >
      {/* 헤더 */}
      <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
          <Typography variant="h6">테넌트 관리</Typography>
          <Button
            variant="contained"
            size="small"
            startIcon={<AddIcon />}
            onClick={() => onSelect(null, true)}
          >
            추가
          </Button>
        </Box>
        <TextField
          fullWidth
          size="small"
          placeholder="검색..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </Box>

      {/* 테넌트 목록 */}
      <List sx={{ flex: 1, overflow: 'auto' }}>
        {filteredTenants.map((tenant) => (
          <ListItemButton
            key={tenant.id}
            selected={selectedId === tenant.id}
            onClick={() => onSelect(tenant.id)}
            sx={(theme) => ({
              borderBottom: `1px solid ${theme.palette.divider}`,
              bgcolor: selectedId === tenant.id ? theme.palette.action.selected : 'transparent',
            })}
          >
            <ListItemIcon>
              <BusinessIcon sx={(theme) => ({ color: theme.palette.primary.main })} />
            </ListItemIcon>
            <ListItemText
              primary={tenant.tenant_name}
              secondary={tenant.tenant_code}
            />
            <Chip
              size="small"
              label={tenant.is_active ? '활성' : '비활성'}
              color={tenant.is_active ? 'success' : 'default'}
            />
          </ListItemButton>
        ))}
      </List>
    </Paper>
  );
}

// =====================================
// 테넌트 상세/편집 패널
// =====================================
interface TenantDetailPanelProps {
  tenant: Tenant | null;
  isAddMode: boolean;
  onSave: (data: CreateTenantRequest | UpdateTenantRequest) => Promise<void>;
  onDelete: (id: number) => Promise<void>;
  onCancel: () => void;
}

function TenantDetailPanel({ tenant, isAddMode, onSave, onDelete, onCancel }: TenantDetailPanelProps) {
  const [tabIndex, setTabIndex] = useState(0);
  const [formData, setFormData] = useState<CreateTenantRequest>({
    tenant_code: '',
    tenant_name: '',
    description: '',
    domain: '',
    subdomain: '',
    admin_email: '',
    admin_name: '',
    settings: {
      theme: 'default',
      language: 'ko',
      timezone: 'Asia/Seoul',
      primaryColor: '#1976d2',
      companyName: '',
    },
  });
  const [isActive, setIsActive] = useState(true);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [errors, setErrors] = useState<Record<string, string>>({});

  // 테넌트 선택 시 폼 데이터 초기화
  React.useEffect(() => {
    if (tenant && !isAddMode) {
      setFormData({
        tenant_code: tenant.tenant_code,
        tenant_name: tenant.tenant_name,
        description: tenant.description || '',
        domain: tenant.domain || '',
        subdomain: tenant.subdomain || '',
        admin_email: tenant.admin_email || '',
        admin_name: tenant.admin_name || '',
        settings: tenant.settings || {
          theme: 'default',
          language: 'ko',
          timezone: 'Asia/Seoul',
          primaryColor: '#1976d2',
          companyName: '',
        },
      });
      setIsActive(tenant.is_active);
    } else if (isAddMode) {
      setFormData({
        tenant_code: '',
        tenant_name: '',
        description: '',
        domain: '',
        subdomain: '',
        admin_email: '',
        admin_name: '',
        settings: {
          theme: 'default',
          language: 'ko',
          timezone: 'Asia/Seoul',
          primaryColor: '#1976d2',
          companyName: '',
        },
      });
      setIsActive(true);
    }
    setErrors({});
    setShowDeleteConfirm(false);
    setTabIndex(0);
  }, [tenant, isAddMode]);

  const handleChange = (field: keyof CreateTenantRequest, value: any) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
    if (errors[field]) {
      setErrors((prev) => {
        const next = { ...prev };
        delete next[field];
        return next;
      });
    }
  };

  const handleSettingsChange = (key: string, value: any) => {
    setFormData((prev) => ({
      ...prev,
      settings: { ...prev.settings, [key]: value },
    }));
  };

  const validate = (): boolean => {
    const newErrors: Record<string, string> = {};

    if (!formData.tenant_code.trim()) {
      newErrors.tenant_code = '테넌트 코드를 입력하세요.';
    } else if (!/^[a-z0-9_]+$/.test(formData.tenant_code)) {
      newErrors.tenant_code = '영문 소문자, 숫자, 언더스코어만 사용 가능합니다.';
    }

    if (!formData.tenant_name.trim()) {
      newErrors.tenant_name = '테넌트 이름을 입력하세요.';
    }

    if (formData.admin_email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.admin_email)) {
      newErrors.admin_email = '올바른 이메일 형식이 아닙니다.';
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
          tenant_name: formData.tenant_name,
          description: formData.description,
          domain: formData.domain,
          subdomain: formData.subdomain,
          admin_email: formData.admin_email,
          admin_name: formData.admin_name,
          settings: formData.settings,
          is_active: isActive,
        });
      }
    } catch (error) {
      console.error('저장 실패:', error);
    }
  };

  const handleDelete = async () => {
    if (!tenant) return;

    if (tenant.tenant_code === 'default') {
      alert('기본 테넌트는 삭제할 수 없습니다.');
      return;
    }

    try {
      await onDelete(tenant.id);
      setShowDeleteConfirm(false);
    } catch (error) {
      console.error('삭제 실패:', error);
    }
  };

  // 빈 상태
  if (!tenant && !isAddMode) {
    return (
      <Box
        sx={{
          flex: 1,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Typography color="text.secondary">
          테넌트를 선택하거나 새로 추가하세요.
        </Typography>
      </Box>
    );
  }

  return (
    <Box sx={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
      {/* 헤더 */}
      <Box sx={{ p: 2, borderBottom: 1, borderColor: 'divider' }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box>
            <Breadcrumbs>
              <Link underline="hover" color="inherit" href="#" onClick={(e) => { e.preventDefault(); onCancel(); }}>
                테넌트 목록
              </Link>
              <Typography color="text.primary">
                {isAddMode ? '새 테넌트' : formData.tenant_name || '(이름 없음)'}
              </Typography>
            </Breadcrumbs>
            <Typography variant="h6" sx={{ mt: 1 }}>
              {isAddMode ? '테넌트 추가' : '테넌트 수정'}
            </Typography>
          </Box>

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

      {/* 탭 */}
      <Tabs value={tabIndex} onChange={(_, v) => setTabIndex(v)} sx={{ borderBottom: 1, borderColor: 'divider', px: 2 }}>
        <Tab icon={<BusinessIcon />} label="기본 정보" iconPosition="start" />
        <Tab icon={<LanguageIcon />} label="도메인 설정" iconPosition="start" />
        <Tab icon={<SettingsIcon />} label="테넌트 설정" iconPosition="start" />
      </Tabs>

      {/* 컨텐츠 */}
      <Box sx={{ flex: 1, overflow: 'auto', p: 3 }}>
        {/* 기본 정보 탭 */}
        {tabIndex === 0 && (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, maxWidth: 600 }}>
            <TextField
              label="테넌트 코드"
              value={formData.tenant_code}
              onChange={(e) => handleChange('tenant_code', e.target.value.toLowerCase())}
              error={!!errors.tenant_code}
              helperText={errors.tenant_code || '영문 소문자, 숫자, 언더스코어만 사용 (예: shop_a)'}
              disabled={!isAddMode}
              required
            />

            <TextField
              label="테넌트 이름"
              value={formData.tenant_name}
              onChange={(e) => handleChange('tenant_name', e.target.value)}
              error={!!errors.tenant_name}
              helperText={errors.tenant_name}
              required
            />

            <TextField
              label="설명"
              value={formData.description}
              onChange={(e) => handleChange('description', e.target.value)}
              multiline
              rows={3}
            />

            <Divider />

            <Typography variant="subtitle1">관리자 정보</Typography>

            <TextField
              label="관리자 이름"
              value={formData.admin_name}
              onChange={(e) => handleChange('admin_name', e.target.value)}
            />

            <TextField
              label="관리자 이메일"
              value={formData.admin_email}
              onChange={(e) => handleChange('admin_email', e.target.value)}
              error={!!errors.admin_email}
              helperText={errors.admin_email}
            />

            {!isAddMode && (
              <>
                <Divider />
                <FormControlLabel
                  control={
                    <Switch
                      checked={isActive}
                      onChange={(e) => setIsActive(e.target.checked)}
                    />
                  }
                  label="활성화"
                />
              </>
            )}
          </Box>
        )}

        {/* 도메인 설정 탭 */}
        {tabIndex === 1 && (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, maxWidth: 600 }}>
            <Alert severity="info">
              테넌트를 식별하는 도메인을 설정합니다. 서브도메인 또는 커스텀 도메인 중 하나를 사용할 수 있습니다.
            </Alert>

            <TextField
              label="서브도메인"
              value={formData.subdomain}
              onChange={(e) => handleChange('subdomain', e.target.value)}
              helperText="예: shop-a (shop-a.example.com으로 접속)"
              InputProps={{
                endAdornment: <InputAdornment position="end">.example.com</InputAdornment>,
              }}
            />

            <TextField
              label="커스텀 도메인"
              value={formData.domain}
              onChange={(e) => handleChange('domain', e.target.value)}
              helperText="예: www.shop-a.com (완전한 도메인 주소)"
            />
          </Box>
        )}

        {/* 테넌트 설정 탭 */}
        {tabIndex === 2 && (
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 3, maxWidth: 600 }}>
            <TextField
              label="회사명"
              value={formData.settings?.companyName || ''}
              onChange={(e) => handleSettingsChange('companyName', e.target.value)}
            />

            <TextField
              select
              label="테마"
              value={formData.settings?.theme || 'default'}
              onChange={(e) => handleSettingsChange('theme', e.target.value)}
              SelectProps={{ native: true }}
            >
              <option value="default">기본</option>
              <option value="light">라이트</option>
              <option value="dark">다크</option>
            </TextField>

            <TextField
              select
              label="언어"
              value={formData.settings?.language || 'ko'}
              onChange={(e) => handleSettingsChange('language', e.target.value)}
              SelectProps={{ native: true }}
            >
              <option value="ko">한국어</option>
              <option value="en">English</option>
              <option value="ja">日本語</option>
              <option value="zh">中文</option>
            </TextField>

            <TextField
              label="시간대"
              value={formData.settings?.timezone || 'Asia/Seoul'}
              onChange={(e) => handleSettingsChange('timezone', e.target.value)}
            />

            <Box>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                기본 색상
              </Typography>
              <Box sx={{ display: 'flex', alignItems: 'center', gap: 2 }}>
                <input
                  type="color"
                  value={formData.settings?.primaryColor || '#1976d2'}
                  onChange={(e) => handleSettingsChange('primaryColor', e.target.value)}
                  style={{ width: 50, height: 40, cursor: 'pointer' }}
                />
                <TextField
                  size="small"
                  value={formData.settings?.primaryColor || '#1976d2'}
                  onChange={(e) => handleSettingsChange('primaryColor', e.target.value)}
                  sx={{ width: 120 }}
                />
              </Box>
            </Box>
          </Box>
        )}

        {/* 삭제 영역 */}
        {!isAddMode && tenant && tenant.tenant_code !== 'default' && (
          <>
            <Divider sx={{ my: 4 }} />
            <Box>
              <Typography variant="subtitle1" color="error" gutterBottom>
                위험 영역
              </Typography>

              {!showDeleteConfirm ? (
                <Button
                  variant="outlined"
                  color="error"
                  startIcon={<DeleteIcon />}
                  onClick={() => setShowDeleteConfirm(true)}
                >
                  테넌트 삭제
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
                  정말 삭제하시겠습니까? 이 테넌트와 연결된 모든 데이터가 삭제됩니다.
                </Alert>
              )}
            </Box>
          </>
        )}
      </Box>
    </Box>
  );
}

// =====================================
// 메인 컴포넌트
// =====================================
export default function TenantManagement() {
  const queryClient = useQueryClient();
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [isAddMode, setIsAddMode] = useState(false);

  // 테넌트 목록 조회
  const { data: tenants = [], isLoading } = useQuery({
    queryKey: ['tenants'],
    queryFn: fetchTenants,
  });

  // 선택된 테넌트
  const selectedTenant = tenants.find((t) => t.id === selectedId) || null;

  // 생성 Mutation
  const createMutation = useMutation({
    mutationFn: createTenant,
    onSuccess: (data) => {
      queryClient.invalidateQueries({ queryKey: ['tenants'] });
      setSelectedId(data.id);
      setIsAddMode(false);
    },
  });

  // 수정 Mutation
  const updateMutation = useMutation({
    mutationFn: ({ id, data }: { id: number; data: UpdateTenantRequest }) => updateTenant(id, data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tenants'] });
    },
  });

  // 삭제 Mutation
  const deleteMutation = useMutation({
    mutationFn: deleteTenant,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tenants'] });
      setSelectedId(null);
      setIsAddMode(false);
    },
  });

  const handleSelect = useCallback((id: number | null, addMode = false) => {
    setSelectedId(id);
    setIsAddMode(addMode);
  }, []);

  const handleSave = async (data: CreateTenantRequest | UpdateTenantRequest) => {
    if (isAddMode) {
      await createMutation.mutateAsync(data as CreateTenantRequest);
    } else if (selectedId) {
      await updateMutation.mutateAsync({ id: selectedId, data: data as UpdateTenantRequest });
    }
  };

  const handleDelete = async (id: number) => {
    await deleteMutation.mutateAsync(id);
  };

  const handleCancel = () => {
    setSelectedId(null);
    setIsAddMode(false);
  };

  if (isLoading) {
    return <Typography>로딩 중...</Typography>;
  }

  return (
    <Box sx={{ display: 'flex', height: 'calc(100vh - 64px)' }}>
      <TenantListPanel
        tenants={tenants}
        selectedId={selectedId}
        onSelect={handleSelect}
      />
      <TenantDetailPanel
        tenant={selectedTenant}
        isAddMode={isAddMode}
        onSave={handleSave}
        onDelete={handleDelete}
        onCancel={handleCancel}
      />
    </Box>
  );
}
```

---

## Phase 5: 라우트 등록

### Express 라우트

**파일**: `server.js` 또는 `app.js`

```javascript
const tenantsRouter = require('./api/tenants');
const { tenantMiddleware, tenantSwitchMiddleware } = require('./middleware/tenantMiddleware');

// 테넌트 미들웨어 적용 (인증 후)
app.use(tenantMiddleware);
app.use(tenantSwitchMiddleware);

// 테넌트 API 라우트
app.use('/api/tenants', tenantsRouter);
```

### Next.js App Router

**파일**: `app/admin/tenants/page.tsx`

```tsx
import TenantManagement from '@/components/admin/TenantManagement';

export default function TenantsPage() {
  return <TenantManagement />;
}
```

---

## 완료 메시지

```
✅ 테넌트 관리 시스템 초기화 완료!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

생성된 파일:
  Backend:
    ✓ api/tenants.js - 테넌트 API
    ✓ middleware/tenantMiddleware.js - 테넌트 미들웨어

  Frontend:
    ✓ src/types/tenant.ts - 타입 정의
    ✓ src/lib/api/tenants.ts - API 클라이언트
    ✓ src/components/admin/TenantManagement.tsx - Admin UI

기능:
  ✓ 테넌트 CRUD (생성, 조회, 수정, 삭제)
  ✓ 도메인/서브도메인 설정
  ✓ 테넌트별 설정 (테마, 로고, 언어 등)
  ✓ 관리자 지정
  ✓ 테넌트 전환 (슈퍼 관리자)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

다음 단계:
  1. 라우트 등록 확인
  2. Use category-manager --init (카테고리 관리)
  3. Use board-generator --init (게시판 생성)
```

---

## 참고

- 테넌트 테이블은 `shared-schema`에서 생성됨
- 다른 테이블(menus, boards 등)은 `tenant_id`를 FK로 참조
- 슈퍼 관리자만 테넌트 생성/삭제 가능
