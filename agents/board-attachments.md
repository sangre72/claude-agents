---
name: board-attachments
description: 게시판 파일 첨부 기능. 업로드/다운로드 API, 이미지 썸네일 생성, 파일 검증. board-generator와 병렬 실행 가능.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 파일 첨부 기능

게시판의 **파일 첨부 기능**을 구현하는 에이전트입니다.

> **병렬 실행**: board-backend-api, board-frontend-components와 병렬로 실행 가능

---

## 기능 개요

| 기능 | 설명 |
|------|------|
| 파일 업로드 | 게시글에 파일 첨부 |
| 파일 다운로드 | 첨부파일 다운로드 |
| 이미지 썸네일 | 이미지 파일 썸네일 자동 생성 |
| 파일 검증 | 확장자, 크기, MIME 타입 검증 |
| 파일 삭제 | 첨부파일 삭제 |

---

## 파일 저장 구조

```
uploads/
└── boards/
    └── {board_code}/
        └── {year}/
            └── {month}/
                ├── 20240102_abc123.jpg           # 원본
                └── thumb_20240102_abc123.jpg     # 썸네일
```

---

## API 엔드포인트

### 파일 업로드

```javascript
// POST /api/boards/:code/posts/:postId/attachments
// Content-Type: multipart/form-data

// Request: FormData with 'file' field

// Response
{
  success: true,
  data: {
    id: 1,
    original_name: "photo.jpg",
    stored_name: "20240102_abc123.jpg",
    file_path: "/uploads/boards/review/2024/01/20240102_abc123.jpg",
    file_size: 1024000,
    mime_type: "image/jpeg",
    file_ext: "jpg",
    is_image: true,
    image_width: 1920,
    image_height: 1080,
    thumbnail_path: "/uploads/boards/review/2024/01/thumb_20240102_abc123.jpg"
  }
}
```

### 파일 다운로드

```javascript
// GET /api/attachments/:id/download

// Response: File stream with appropriate headers
// Content-Disposition: attachment; filename="original_name.jpg"
```

### 파일 삭제

```javascript
// DELETE /api/attachments/:id

// Response
{
  success: true,
  message: "파일이 삭제되었습니다."
}
```

### 파일 목록 조회

```javascript
// GET /api/boards/:code/posts/:postId/attachments

// Response
{
  success: true,
  data: [
    {
      id: 1,
      original_name: "photo.jpg",
      file_size: 1024000,
      is_image: true,
      thumbnail_path: "/uploads/boards/..."
    }
  ]
}
```

---

## Backend 구현 (Express.js)

### 파일 업로드 라우터

**파일**: `api/attachments.js`

```javascript
const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const sharp = require('sharp');
const { v4: uuidv4 } = require('uuid');
const { pool } = require('../db');
const { authenticateToken } = require('../middleware/auth');

// Multer 설정
const storage = multer.diskStorage({
  destination: async (req, file, cb) => {
    const boardCode = req.params.code;
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');

    const uploadDir = path.join(
      process.cwd(),
      'uploads/boards',
      boardCode,
      String(year),
      month
    );

    await fs.mkdir(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const now = new Date();
    const dateStr = now.toISOString().slice(0, 10).replace(/-/g, '');
    const uuid = uuidv4().split('-')[0];
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, `${dateStr}_${uuid}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: 50 * 1024 * 1024 }, // 50MB (게시판별 설정은 별도 검증)
});

// 파일 업로드
router.post(
  '/boards/:code/posts/:postId/attachments',
  authenticateToken,
  upload.single('file'),
  async (req, res) => {
    const { code, postId } = req.params;
    const file = req.file;

    try {
      // 1. 게시판 설정 조회
      const [boards] = await pool.execute(
        'SELECT * FROM boards WHERE board_code = ? AND tenant_id = ?',
        [code, req.tenantId]
      );

      if (boards.length === 0) {
        await fs.unlink(file.path); // 업로드된 파일 삭제
        return res.status(404).json({ error: '게시판을 찾을 수 없습니다.' });
      }

      const board = boards[0];

      // 2. 파일 검증
      try {
        validateFile(file, board);
      } catch (error) {
        await fs.unlink(file.path);
        return res.status(400).json({ error: error.message });
      }

      // 3. 첨부파일 수 확인
      const [attachments] = await pool.execute(
        'SELECT COUNT(*) as count FROM board_attachments WHERE post_id = ? AND is_deleted = FALSE',
        [postId]
      );

      if (attachments[0].count >= board.max_file_count) {
        await fs.unlink(file.path);
        return res.status(400).json({
          error: `첨부파일은 최대 ${board.max_file_count}개까지 가능합니다.`
        });
      }

      // 4. 이미지 처리
      let isImage = false;
      let imageWidth = null;
      let imageHeight = null;
      let thumbnailPath = null;

      if (file.mimetype.startsWith('image/')) {
        isImage = true;

        // 이미지 메타데이터
        const metadata = await sharp(file.path).metadata();
        imageWidth = metadata.width;
        imageHeight = metadata.height;

        // 썸네일 생성
        if (board.use_thumbnail) {
          thumbnailPath = await createThumbnail(file.path, board);
        }
      }

      // 5. DB 저장
      const relativePath = file.path.replace(process.cwd(), '');
      const relativeThumbPath = thumbnailPath
        ? thumbnailPath.replace(process.cwd(), '')
        : null;

      const [result] = await pool.execute(`
        INSERT INTO board_attachments
          (post_id, original_name, stored_name, file_path, file_size,
           mime_type, file_ext, is_image, image_width, image_height,
           thumbnail_path, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        postId,
        file.originalname,
        file.filename,
        relativePath,
        file.size,
        file.mimetype,
        path.extname(file.originalname).slice(1).toLowerCase(),
        isImage,
        imageWidth,
        imageHeight,
        relativeThumbPath,
        req.user?.userId || 'system'
      ]);

      // 6. 게시글 file_count 업데이트
      await pool.execute(
        'UPDATE board_posts SET file_count = file_count + 1 WHERE id = ?',
        [postId]
      );

      res.status(201).json({
        success: true,
        data: {
          id: result.insertId,
          original_name: file.originalname,
          stored_name: file.filename,
          file_path: relativePath,
          file_size: file.size,
          mime_type: file.mimetype,
          file_ext: path.extname(file.originalname).slice(1).toLowerCase(),
          is_image: isImage,
          image_width: imageWidth,
          image_height: imageHeight,
          thumbnail_path: relativeThumbPath
        }
      });
    } catch (error) {
      console.error('파일 업로드 실패:', error);
      if (file) await fs.unlink(file.path).catch(() => {});
      res.status(500).json({ error: '파일 업로드에 실패했습니다.' });
    }
  }
);

// 파일 다운로드
router.get('/attachments/:id/download', async (req, res) => {
  const { id } = req.params;

  try {
    const [attachments] = await pool.execute(
      'SELECT * FROM board_attachments WHERE id = ? AND is_deleted = FALSE',
      [id]
    );

    if (attachments.length === 0) {
      return res.status(404).json({ error: '파일을 찾을 수 없습니다.' });
    }

    const attachment = attachments[0];
    const filePath = path.join(process.cwd(), attachment.file_path);

    // 다운로드 카운트 증가
    await pool.execute(
      'UPDATE board_attachments SET download_count = download_count + 1 WHERE id = ?',
      [id]
    );

    // 파일명 인코딩 (한글 파일명 지원)
    const encodedFilename = encodeURIComponent(attachment.original_name);

    res.setHeader(
      'Content-Disposition',
      `attachment; filename*=UTF-8''${encodedFilename}`
    );
    res.setHeader('Content-Type', attachment.mime_type);

    res.sendFile(filePath);
  } catch (error) {
    console.error('파일 다운로드 실패:', error);
    res.status(500).json({ error: '파일 다운로드에 실패했습니다.' });
  }
});

// 파일 삭제
router.delete(
  '/attachments/:id',
  authenticateToken,
  async (req, res) => {
    const { id } = req.params;

    try {
      const [attachments] = await pool.execute(
        'SELECT * FROM board_attachments WHERE id = ? AND is_deleted = FALSE',
        [id]
      );

      if (attachments.length === 0) {
        return res.status(404).json({ error: '파일을 찾을 수 없습니다.' });
      }

      const attachment = attachments[0];

      // 소프트 삭제
      await pool.execute(
        'UPDATE board_attachments SET is_deleted = TRUE WHERE id = ?',
        [id]
      );

      // 게시글 file_count 감소
      await pool.execute(
        'UPDATE board_posts SET file_count = file_count - 1 WHERE id = ?',
        [attachment.post_id]
      );

      // 실제 파일 삭제 (선택)
      // await fs.unlink(path.join(process.cwd(), attachment.file_path));
      // if (attachment.thumbnail_path) {
      //   await fs.unlink(path.join(process.cwd(), attachment.thumbnail_path));
      // }

      res.json({ success: true, message: '파일이 삭제되었습니다.' });
    } catch (error) {
      console.error('파일 삭제 실패:', error);
      res.status(500).json({ error: '파일 삭제에 실패했습니다.' });
    }
  }
);

// 파일 목록 조회
router.get('/boards/:code/posts/:postId/attachments', async (req, res) => {
  const { postId } = req.params;

  try {
    const [attachments] = await pool.execute(`
      SELECT id, original_name, file_size, mime_type, file_ext,
             is_image, thumbnail_path, download_count, created_at
      FROM board_attachments
      WHERE post_id = ? AND is_deleted = FALSE
      ORDER BY created_at
    `, [postId]);

    res.json({ success: true, data: attachments });
  } catch (error) {
    console.error('파일 목록 조회 실패:', error);
    res.status(500).json({ error: '파일 목록을 가져오는데 실패했습니다.' });
  }
});

module.exports = router;
```

---

## 파일 검증 함수

```javascript
// utils/fileValidation.js

// MIME 타입 매핑
const MIME_TYPES = {
  // 이미지
  jpg: ['image/jpeg'],
  jpeg: ['image/jpeg'],
  png: ['image/png'],
  gif: ['image/gif'],
  webp: ['image/webp'],
  svg: ['image/svg+xml'],

  // 문서
  pdf: ['application/pdf'],
  doc: ['application/msword'],
  docx: ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  xls: ['application/vnd.ms-excel'],
  xlsx: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  ppt: ['application/vnd.ms-powerpoint'],
  pptx: ['application/vnd.openxmlformats-officedocument.presentationml.presentation'],

  // 압축
  zip: ['application/zip', 'application/x-zip-compressed'],
  rar: ['application/x-rar-compressed'],

  // 텍스트
  txt: ['text/plain'],
  csv: ['text/csv'],
};

function getMimeTypes(extensions) {
  const mimes = [];
  for (const ext of extensions) {
    const extMimes = MIME_TYPES[ext.toLowerCase()];
    if (extMimes) {
      mimes.push(...extMimes);
    }
  }
  return mimes;
}

function validateFile(file, board) {
  // 1. 확장자 검증
  const ext = file.originalname.split('.').pop().toLowerCase();
  const allowedTypes = board.allowed_file_types.split(',').map(t => t.trim());

  if (!allowedTypes.includes(ext)) {
    throw new Error(`허용되지 않는 파일 형식입니다. (허용: ${allowedTypes.join(', ')})`);
  }

  // 2. 파일 크기 검증
  if (file.size > board.max_file_size) {
    const maxSizeMB = Math.round(board.max_file_size / 1024 / 1024);
    throw new Error(`파일 크기가 ${maxSizeMB}MB를 초과합니다.`);
  }

  // 3. MIME 타입 검증 (보안)
  const allowedMimes = getMimeTypes(allowedTypes);
  if (allowedMimes.length > 0 && !allowedMimes.includes(file.mimetype)) {
    throw new Error('유효하지 않은 파일입니다.');
  }

  // 4. 파일명 보안 검증
  if (file.originalname.includes('..') || file.originalname.includes('/')) {
    throw new Error('유효하지 않은 파일명입니다.');
  }

  return true;
}

module.exports = { validateFile, getMimeTypes, MIME_TYPES };
```

---

## 썸네일 생성

```javascript
// utils/thumbnail.js
const sharp = require('sharp');
const path = require('path');

async function createThumbnail(imagePath, board) {
  const dir = path.dirname(imagePath);
  const ext = path.extname(imagePath);
  const name = path.basename(imagePath, ext);
  const thumbnailPath = path.join(dir, `thumb_${name}${ext}`);

  await sharp(imagePath)
    .resize(board.thumbnail_width || 200, board.thumbnail_height || 200, {
      fit: 'cover',
      position: 'center',
    })
    .toFile(thumbnailPath);

  return thumbnailPath;
}

module.exports = { createThumbnail };
```

---

## Frontend 컴포넌트

### 파일 업로드 컴포넌트

```tsx
// components/board/FileUpload.tsx
'use client';

import { useState, useRef } from 'react';
import {
  Box, Button, Typography, LinearProgress, IconButton, List,
  ListItem, ListItemIcon, ListItemText, ListItemSecondaryAction,
} from '@mui/material';
import {
  CloudUpload, InsertDriveFile, Image, Delete, Download,
} from '@mui/icons-material';

interface FileUploadProps {
  postId: number;
  boardCode: string;
  maxFiles: number;
  maxSize: number;        // bytes
  allowedTypes: string;   // 'jpg,png,pdf'
  onUpload?: (file: any) => void;
  onDelete?: (id: number) => void;
}

export default function FileUpload({
  postId,
  boardCode,
  maxFiles,
  maxSize,
  allowedTypes,
  onUpload,
  onDelete,
}: FileUploadProps) {
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [files, setFiles] = useState<any[]>([]);
  const inputRef = useRef<HTMLInputElement>(null);

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    // 클라이언트 검증
    const ext = file.name.split('.').pop()?.toLowerCase();
    const allowed = allowedTypes.split(',').map(t => t.trim());

    if (!allowed.includes(ext || '')) {
      alert(`허용되지 않는 파일 형식입니다. (허용: ${allowedTypes})`);
      return;
    }

    if (file.size > maxSize) {
      alert(`파일 크기가 ${Math.round(maxSize / 1024 / 1024)}MB를 초과합니다.`);
      return;
    }

    if (files.length >= maxFiles) {
      alert(`최대 ${maxFiles}개까지 첨부 가능합니다.`);
      return;
    }

    // 업로드
    setUploading(true);
    setProgress(0);

    const formData = new FormData();
    formData.append('file', file);

    try {
      const response = await fetch(
        `/api/boards/${boardCode}/posts/${postId}/attachments`,
        {
          method: 'POST',
          body: formData,
        }
      );

      const result = await response.json();

      if (result.success) {
        setFiles([...files, result.data]);
        onUpload?.(result.data);
      } else {
        alert(result.error || '업로드에 실패했습니다.');
      }
    } catch (error) {
      alert('업로드에 실패했습니다.');
    } finally {
      setUploading(false);
      setProgress(0);
      if (inputRef.current) inputRef.current.value = '';
    }
  };

  const handleDelete = async (id: number) => {
    if (!confirm('파일을 삭제하시겠습니까?')) return;

    try {
      const response = await fetch(`/api/attachments/${id}`, {
        method: 'DELETE',
      });

      if (response.ok) {
        setFiles(files.filter(f => f.id !== id));
        onDelete?.(id);
      }
    } catch (error) {
      alert('삭제에 실패했습니다.');
    }
  };

  const formatSize = (bytes: number) => {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
  };

  return (
    <Box>
      <input
        ref={inputRef}
        type="file"
        hidden
        accept={allowedTypes.split(',').map(t => `.${t}`).join(',')}
        onChange={handleFileSelect}
      />

      <Button
        variant="outlined"
        startIcon={<CloudUpload />}
        onClick={() => inputRef.current?.click()}
        disabled={uploading || files.length >= maxFiles}
      >
        파일 첨부 ({files.length}/{maxFiles})
      </Button>

      {uploading && (
        <Box sx={{ mt: 2 }}>
          <LinearProgress variant="determinate" value={progress} />
        </Box>
      )}

      {files.length > 0 && (
        <List sx={{ mt: 2 }}>
          {files.map((file) => (
            <ListItem key={file.id} divider>
              <ListItemIcon>
                {file.is_image ? <Image /> : <InsertDriveFile />}
              </ListItemIcon>
              <ListItemText
                primary={file.original_name}
                secondary={formatSize(file.file_size)}
              />
              <ListItemSecondaryAction>
                <IconButton
                  href={`/api/attachments/${file.id}/download`}
                  target="_blank"
                >
                  <Download />
                </IconButton>
                <IconButton onClick={() => handleDelete(file.id)} color="error">
                  <Delete />
                </IconButton>
              </ListItemSecondaryAction>
            </ListItem>
          ))}
        </List>
      )}

      <Typography variant="caption" color="text.secondary" sx={{ mt: 1, display: 'block' }}>
        허용 형식: {allowedTypes} / 최대 크기: {Math.round(maxSize / 1024 / 1024)}MB
      </Typography>
    </Box>
  );
}
```

---

## 보안 고려사항

| 항목 | 대응 방법 |
|------|-----------|
| 경로 탐색 공격 | 파일명에서 `..`, `/` 검증 |
| MIME 스푸핑 | 확장자와 MIME 타입 모두 검증 |
| 악성 파일 업로드 | 확장자 화이트리스트, MIME 검증 |
| 용량 공격 | 파일 크기, 개수 제한 |
| XSS (SVG 등) | Content-Type 헤더 설정, CSP |

---

## 참고

- sharp 라이브러리로 이미지 처리
- multer로 파일 업로드 처리
- 소프트 삭제로 파일 복구 가능
- 게시판별 파일 설정 적용 (크기, 개수, 타입)
