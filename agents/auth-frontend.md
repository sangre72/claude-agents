---
name: auth-frontend
description: 인증 Frontend 컴포넌트 생성. 로그인, 회원가입, 비밀번호 변경 페이지. React/TypeScript + MUI 기반. Security First 원칙 준수.
tools: Read, Edit, Write, Bash, Glob, Grep
model: sonnet
skills: coding-guide, modular-check, refactor
---

# 인증 Frontend 컴포넌트 생성기

로그인, 회원가입, 비밀번호 변경 등 인증 관련 컴포넌트를 생성하는 에이전트입니다.

> **핵심 원칙**:
> 1. **Security First**: 토큰 안전 저장, XSS 방지
> 2. **Error Handling First**: 모든 API 호출에 에러 처리
> 3. **UX 필수 요소**: 로딩 상태, 에러 표시, 폼 검증
> 4. **coding-guide 준수**: 네이밍 컨벤션, Import 순서

---

## 사용법

```bash
# 전체 인증 UI 생성
Use auth-frontend --init

# 특정 페이지만 생성
Use auth-frontend --page=login
Use auth-frontend --page=register
Use auth-frontend --page=forgot-password

# Context/Provider 생성
Use auth-frontend --context
```

---

## CRITICAL: Security Rules

### 1. 토큰 저장 - httpOnly Cookie 권장

```typescript
// ❌ 금지 - localStorage (XSS 취약)
localStorage.setItem('token', token);

// ✅ 권장 - httpOnly Cookie (서버에서 설정)
// 또는 메모리 저장 (새로고침 시 재인증)

// React Context에서 메모리 저장 예시
const [token, setToken] = useState<string | null>(null);
```

### 2. 비밀번호 필드

```typescript
// ✅ 항상 type="password" 사용
<TextField type="password" autoComplete="new-password" />

// ✅ 비밀번호 표시/숨기기 토글
const [showPassword, setShowPassword] = useState(false);
<TextField
  type={showPassword ? 'text' : 'password'}
  InputProps={{
    endAdornment: (
      <IconButton onClick={() => setShowPassword(!showPassword)}>
        {showPassword ? <VisibilityOff /> : <Visibility />}
      </IconButton>
    )
  }}
/>
```

### 3. 폼 제출 보안

```typescript
// ✅ 폼 제출 시 비밀번호 초기화
const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault();
  try {
    await login(email, password);
  } catch (err) {
    // 에러 처리
  } finally {
    setPassword('');  // 비밀번호 초기화
  }
};
```

---

## TypeScript Types

### 파일: `types/auth.ts`

```typescript
/**
 * Auth Types
 * 인증 관련 타입 정의
 */

// 사용자 정보
export interface User {
  id: number;
  email: string;
  name: string;
  role: 'user' | 'admin' | 'super_admin';
  avatarUrl?: string;
  isEmailVerified?: boolean;
}

// 로그인 요청
export interface LoginRequest {
  email: string;
  password: string;
}

// 로그인 응답
export interface LoginResponse {
  token: string;
  refreshToken: string;
  user: User;
}

// 회원가입 요청
export interface RegisterRequest {
  email: string;
  password: string;
  passwordConfirm: string;
  name: string;
  phone?: string;
}

// 회원가입 응답
export interface RegisterResponse {
  id: number;
  message: string;
}

// 인증 Context
export interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  isAuthenticated: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  register: (data: RegisterRequest) => Promise<void>;
  refreshUser: () => Promise<void>;
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

## API Client

### 파일: `lib/authApi.ts`

```typescript
/**
 * Auth API Client
 * 인증 API 호출 함수
 */

import axios, { AxiosError } from 'axios';
import {
  LoginRequest,
  LoginResponse,
  RegisterRequest,
  RegisterResponse,
  User,
  ApiResponse
} from '../types/auth';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:3001';

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: 10000,
});

// 토큰 설정 함수
export const setAuthToken = (token: string | null) => {
  if (token) {
    apiClient.defaults.headers.common['Authorization'] = `Bearer ${token}`;
  } else {
    delete apiClient.defaults.headers.common['Authorization'];
  }
};

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
 * 로그인
 */
export const login = async (data: LoginRequest): Promise<LoginResponse> => {
  try {
    const response = await apiClient.post<ApiResponse<LoginResponse>>(
      '/api/auth/login',
      data
    );

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '로그인에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 회원가입
 */
export const register = async (data: RegisterRequest): Promise<RegisterResponse> => {
  try {
    const response = await apiClient.post<ApiResponse<RegisterResponse>>(
      '/api/auth/register',
      {
        email: data.email,
        password: data.password,
        name: data.name,
        phone: data.phone
      }
    );

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '회원가입에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 로그아웃
 */
export const logout = async (): Promise<void> => {
  try {
    await apiClient.post<ApiResponse<{ message: string }>>('/api/auth/logout');
  } catch (error) {
    // 로그아웃 실패해도 클라이언트에서 토큰 삭제
    console.error('Logout error:', error);
  }
};

/**
 * 현재 사용자 정보 조회
 */
export const getCurrentUser = async (): Promise<User> => {
  try {
    const response = await apiClient.get<ApiResponse<User>>('/api/auth/me');

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '사용자 정보 조회에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 토큰 갱신
 */
export const refreshToken = async (token: string): Promise<{ token: string; refreshToken: string }> => {
  try {
    const response = await apiClient.post<ApiResponse<{ token: string; refreshToken: string }>>(
      '/api/auth/refresh',
      { refreshToken: token }
    );

    if (!response.data.success || !response.data.data) {
      throw new Error(response.data.message || '토큰 갱신에 실패했습니다.');
    }

    return response.data.data;
  } catch (error) {
    return handleError(error);
  }
};

/**
 * 비밀번호 변경
 */
export const changePassword = async (
  currentPassword: string,
  newPassword: string
): Promise<void> => {
  try {
    const response = await apiClient.put<ApiResponse<{ message: string }>>(
      '/api/auth/password',
      { currentPassword, newPassword }
    );

    if (!response.data.success) {
      throw new Error(response.data.message || '비밀번호 변경에 실패했습니다.');
    }
  } catch (error) {
    return handleError(error);
  }
};
```

---

## Auth Context

### 파일: `contexts/AuthContext.tsx`

```typescript
/**
 * Auth Context
 * 전역 인증 상태 관리
 */

import React, { createContext, useContext, useState, useEffect, useCallback, ReactNode } from 'react';
import * as authApi from '../lib/authApi';
import { User, RegisterRequest, AuthContextType } from '../types/auth';

const AuthContext = createContext<AuthContextType | undefined>(undefined);

interface AuthProviderProps {
  children: ReactNode;
}

export const AuthProvider: React.FC<AuthProviderProps> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [token, setToken] = useState<string | null>(null);

  // 초기 로드 - 저장된 토큰으로 사용자 정보 조회
  useEffect(() => {
    const initAuth = async () => {
      const savedToken = sessionStorage.getItem('token');
      if (savedToken) {
        try {
          authApi.setAuthToken(savedToken);
          const userData = await authApi.getCurrentUser();
          setUser(userData);
          setToken(savedToken);
        } catch (err) {
          // 토큰이 유효하지 않으면 삭제
          sessionStorage.removeItem('token');
          sessionStorage.removeItem('refreshToken');
          authApi.setAuthToken(null);
        }
      }
      setIsLoading(false);
    };

    initAuth();
  }, []);

  // 로그인
  const login = useCallback(async (email: string, password: string) => {
    setIsLoading(true);
    try {
      const response = await authApi.login({ email, password });

      // 토큰 저장 (sessionStorage - 탭 닫으면 삭제)
      sessionStorage.setItem('token', response.token);
      sessionStorage.setItem('refreshToken', response.refreshToken);

      authApi.setAuthToken(response.token);
      setToken(response.token);
      setUser(response.user);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // 로그아웃
  const logout = useCallback(async () => {
    try {
      await authApi.logout();
    } finally {
      sessionStorage.removeItem('token');
      sessionStorage.removeItem('refreshToken');
      authApi.setAuthToken(null);
      setToken(null);
      setUser(null);
    }
  }, []);

  // 회원가입
  const register = useCallback(async (data: RegisterRequest) => {
    setIsLoading(true);
    try {
      await authApi.register(data);
      // 회원가입 후 자동 로그인
      await login(data.email, data.password);
    } finally {
      setIsLoading(false);
    }
  }, [login]);

  // 사용자 정보 새로고침
  const refreshUser = useCallback(async () => {
    if (!token) return;

    try {
      const userData = await authApi.getCurrentUser();
      setUser(userData);
    } catch (err) {
      // 토큰 만료 시 로그아웃
      await logout();
    }
  }, [token, logout]);

  const value: AuthContextType = {
    user,
    isLoading,
    isAuthenticated: !!user,
    login,
    logout,
    register,
    refreshUser,
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

// Custom hook
export const useAuth = (): AuthContextType => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
```

---

## Component: LoginPage.tsx

```typescript
/**
 * Login Page Component
 * 로그인 페이지
 */

import React, { useState } from 'react';
import { useNavigate, Link as RouterLink } from 'react-router-dom';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Link,
  Alert,
  CircularProgress,
  IconButton,
  InputAdornment,
} from '@mui/material';
import { Visibility, VisibilityOff } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';

const LoginPage: React.FC = () => {
  const navigate = useNavigate();
  const { login, isLoading } = useAuth();

  // 폼 상태
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  // 에러/검증 상태
  const [error, setError] = useState<string | null>(null);
  const [emailError, setEmailError] = useState<string | null>(null);
  const [passwordError, setPasswordError] = useState<string | null>(null);

  // 이메일 검증
  const validateEmail = (value: string): boolean => {
    if (!value) {
      setEmailError('이메일을 입력해주세요.');
      return false;
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(value)) {
      setEmailError('올바른 이메일 형식이 아닙니다.');
      return false;
    }
    setEmailError(null);
    return true;
  };

  // 비밀번호 검증
  const validatePassword = (value: string): boolean => {
    if (!value) {
      setPasswordError('비밀번호를 입력해주세요.');
      return false;
    }
    if (value.length < 8) {
      setPasswordError('비밀번호는 8자 이상이어야 합니다.');
      return false;
    }
    setPasswordError(null);
    return true;
  };

  // 폼 제출
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    // 검증
    const isEmailValid = validateEmail(email);
    const isPasswordValid = validatePassword(password);

    if (!isEmailValid || !isPasswordValid) {
      return;
    }

    try {
      await login(email, password);
      navigate('/');  // 로그인 성공 시 홈으로
    } catch (err: any) {
      setError(err.message || '로그인에 실패했습니다.');
      setPassword('');  // 비밀번호 초기화 (보안)
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'grey.100',
        p: 2,
      }}
    >
      <Card sx={{ maxWidth: 400, width: '100%' }}>
        <CardContent sx={{ p: 4 }}>
          <Typography variant="h5" fontWeight={600} textAlign="center" gutterBottom>
            로그인
          </Typography>
          <Typography variant="body2" color="text.secondary" textAlign="center" sx={{ mb: 3 }}>
            계정에 로그인하세요
          </Typography>

          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
              {error}
            </Alert>
          )}

          <Box component="form" onSubmit={handleSubmit}>
            {/* 이메일 */}
            <TextField
              fullWidth
              label="이메일"
              type="email"
              value={email}
              onChange={(e) => {
                setEmail(e.target.value);
                if (emailError) validateEmail(e.target.value);
              }}
              onBlur={() => validateEmail(email)}
              error={!!emailError}
              helperText={emailError}
              margin="normal"
              autoComplete="email"
              autoFocus
            />

            {/* 비밀번호 */}
            <TextField
              fullWidth
              label="비밀번호"
              type={showPassword ? 'text' : 'password'}
              value={password}
              onChange={(e) => {
                setPassword(e.target.value);
                if (passwordError) validatePassword(e.target.value);
              }}
              onBlur={() => validatePassword(password)}
              error={!!passwordError}
              helperText={passwordError}
              margin="normal"
              autoComplete="current-password"
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton
                      onClick={() => setShowPassword(!showPassword)}
                      edge="end"
                    >
                      {showPassword ? <VisibilityOff /> : <Visibility />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />

            {/* 로그인 버튼 */}
            <Button
              type="submit"
              fullWidth
              variant="contained"
              size="large"
              disabled={isLoading}
              sx={{ mt: 3, mb: 2 }}
            >
              {isLoading ? <CircularProgress size={24} /> : '로그인'}
            </Button>

            {/* 링크 */}
            <Box sx={{ textAlign: 'center' }}>
              <Link component={RouterLink} to="/forgot-password" variant="body2">
                비밀번호를 잊으셨나요?
              </Link>
            </Box>

            <Box sx={{ textAlign: 'center', mt: 2 }}>
              <Typography variant="body2" color="text.secondary">
                계정이 없으신가요?{' '}
                <Link component={RouterLink} to="/register">
                  회원가입
                </Link>
              </Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
};

export default LoginPage;
```

---

## Component: RegisterPage.tsx

```typescript
/**
 * Register Page Component
 * 회원가입 페이지
 */

import React, { useState } from 'react';
import { useNavigate, Link as RouterLink } from 'react-router-dom';
import {
  Box,
  Card,
  CardContent,
  TextField,
  Button,
  Typography,
  Link,
  Alert,
  CircularProgress,
  IconButton,
  InputAdornment,
} from '@mui/material';
import { Visibility, VisibilityOff } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';

const RegisterPage: React.FC = () => {
  const navigate = useNavigate();
  const { register, isLoading } = useAuth();

  // 폼 상태
  const [formData, setFormData] = useState({
    email: '',
    password: '',
    passwordConfirm: '',
    name: '',
    phone: '',
  });
  const [showPassword, setShowPassword] = useState(false);

  // 에러 상태
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<Record<string, string>>({});

  // 필드 변경
  const handleChange = (field: string) => (e: React.ChangeEvent<HTMLInputElement>) => {
    setFormData({ ...formData, [field]: e.target.value });
    // 에러 초기화
    if (fieldErrors[field]) {
      setFieldErrors({ ...fieldErrors, [field]: '' });
    }
  };

  // 검증
  const validate = (): boolean => {
    const errors: Record<string, string> = {};

    if (!formData.email) {
      errors.email = '이메일을 입력해주세요.';
    } else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email)) {
      errors.email = '올바른 이메일 형식이 아닙니다.';
    }

    if (!formData.password) {
      errors.password = '비밀번호를 입력해주세요.';
    } else if (formData.password.length < 8) {
      errors.password = '비밀번호는 8자 이상이어야 합니다.';
    }

    if (!formData.passwordConfirm) {
      errors.passwordConfirm = '비밀번호 확인을 입력해주세요.';
    } else if (formData.password !== formData.passwordConfirm) {
      errors.passwordConfirm = '비밀번호가 일치하지 않습니다.';
    }

    if (!formData.name) {
      errors.name = '이름을 입력해주세요.';
    }

    setFieldErrors(errors);
    return Object.keys(errors).length === 0;
  };

  // 폼 제출
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!validate()) {
      return;
    }

    try {
      await register(formData);
      navigate('/');  // 성공 시 홈으로
    } catch (err: any) {
      setError(err.message || '회원가입에 실패했습니다.');
    }
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'grey.100',
        p: 2,
      }}
    >
      <Card sx={{ maxWidth: 450, width: '100%' }}>
        <CardContent sx={{ p: 4 }}>
          <Typography variant="h5" fontWeight={600} textAlign="center" gutterBottom>
            회원가입
          </Typography>
          <Typography variant="body2" color="text.secondary" textAlign="center" sx={{ mb: 3 }}>
            새 계정을 만드세요
          </Typography>

          {error && (
            <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError(null)}>
              {error}
            </Alert>
          )}

          <Box component="form" onSubmit={handleSubmit}>
            {/* 이메일 */}
            <TextField
              fullWidth
              label="이메일"
              type="email"
              value={formData.email}
              onChange={handleChange('email')}
              error={!!fieldErrors.email}
              helperText={fieldErrors.email}
              margin="normal"
              autoComplete="email"
              required
            />

            {/* 이름 */}
            <TextField
              fullWidth
              label="이름"
              value={formData.name}
              onChange={handleChange('name')}
              error={!!fieldErrors.name}
              helperText={fieldErrors.name}
              margin="normal"
              autoComplete="name"
              required
            />

            {/* 전화번호 */}
            <TextField
              fullWidth
              label="전화번호"
              value={formData.phone}
              onChange={handleChange('phone')}
              margin="normal"
              autoComplete="tel"
              placeholder="010-1234-5678"
            />

            {/* 비밀번호 */}
            <TextField
              fullWidth
              label="비밀번호"
              type={showPassword ? 'text' : 'password'}
              value={formData.password}
              onChange={handleChange('password')}
              error={!!fieldErrors.password}
              helperText={fieldErrors.password || '8자 이상 입력해주세요'}
              margin="normal"
              autoComplete="new-password"
              required
              InputProps={{
                endAdornment: (
                  <InputAdornment position="end">
                    <IconButton onClick={() => setShowPassword(!showPassword)} edge="end">
                      {showPassword ? <VisibilityOff /> : <Visibility />}
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />

            {/* 비밀번호 확인 */}
            <TextField
              fullWidth
              label="비밀번호 확인"
              type={showPassword ? 'text' : 'password'}
              value={formData.passwordConfirm}
              onChange={handleChange('passwordConfirm')}
              error={!!fieldErrors.passwordConfirm}
              helperText={fieldErrors.passwordConfirm}
              margin="normal"
              autoComplete="new-password"
              required
            />

            {/* 회원가입 버튼 */}
            <Button
              type="submit"
              fullWidth
              variant="contained"
              size="large"
              disabled={isLoading}
              sx={{ mt: 3, mb: 2 }}
            >
              {isLoading ? <CircularProgress size={24} /> : '회원가입'}
            </Button>

            {/* 링크 */}
            <Box sx={{ textAlign: 'center' }}>
              <Typography variant="body2" color="text.secondary">
                이미 계정이 있으신가요?{' '}
                <Link component={RouterLink} to="/login">
                  로그인
                </Link>
              </Typography>
            </Box>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
};

export default RegisterPage;
```

---

## File Structure

```
frontend/src/
├── types/
│   └── auth.ts                    # 인증 타입
├── lib/
│   └── authApi.ts                 # API 클라이언트
├── contexts/
│   └── AuthContext.tsx            # 인증 Context
└── components/
    └── auth/
        ├── LoginPage.tsx          # 로그인 페이지
        ├── RegisterPage.tsx       # 회원가입 페이지
        └── ForgotPasswordPage.tsx # 비밀번호 찾기 (선택)
```

---

## UX Checklist

- [ ] 폼 검증 (실시간 + 제출 시)
- [ ] 에러 메시지 표시
- [ ] 로딩 상태 표시
- [ ] 비밀번호 표시/숨기기 토글
- [ ] 페이지 간 이동 링크
- [ ] 제출 후 비밀번호 초기화

---

## Security Checklist

- [ ] 비밀번호 필드 type="password"
- [ ] 토큰 안전 저장 (sessionStorage 또는 httpOnly Cookie)
- [ ] 로그아웃 시 토큰 삭제
- [ ] XSS 방지 (dangerouslySetInnerHTML 미사용)
- [ ] CSRF 토큰 (필요 시)

---

## 사용 예시

```bash
# 전체 인증 UI 생성
Use auth-frontend --init

# 특정 페이지만 생성
Use auth-frontend --page=login
```
