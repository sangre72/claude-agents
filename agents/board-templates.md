---
name: board-templates
description: 게시판 템플릿 정의. notice, free, qna, gallery, faq, review 등 미리 정의된 게시판 설정. board-generator가 참조하는 공유 모듈.
tools: Read, Write, Bash, Glob, Grep
model: haiku
---

# 게시판 템플릿 정의

게시판 생성 시 사용하는 **미리 정의된 템플릿**을 관리하는 공유 모듈입니다.

> **사용처**: board-generator가 `--template` 옵션으로 이 템플릿들을 참조합니다.

---

## 사용법

```bash
# 템플릿으로 게시판 생성
Use board-generator --template notice
Use board-generator --template free
Use board-generator --template qna
Use board-generator --template gallery
Use board-generator --template faq
Use board-generator --template review
```

---

## 템플릿 비교표

| 템플릿 | 읽기 | 쓰기 | 댓글 | 카테고리 | 파일 | 좋아요 | 비밀글 | 보기 |
|--------|------|------|------|----------|------|--------|--------|------|
| notice | public | admin | X | X | O | X | X | list |
| free | public | member | member | X | O | O | O | list |
| qna | public | member | member | O | O | X | O | list |
| gallery | public | member | member | O | O | O | X | gallery |
| faq | public | admin | X | O | X | X | X | list |
| review | public | member | member | O | O | O | X | webzine |

---

## 템플릿 상세

### notice (공지사항)

> 관리자만 작성, 댓글 없음, 노출 기간 설정 가능

```javascript
{
  board_code: 'notice',
  board_name: '공지사항',
  description: '중요한 공지사항을 알려드립니다.',
  board_type: 'notice',

  // 보기 설정
  list_view_type: 'list',
  posts_per_page: 20,

  // 권한 설정
  read_permission: 'public',      // 누구나 읽기
  write_permission: 'admin',       // 관리자만 작성
  comment_permission: 'disabled',  // 댓글 비활성

  // 기능 설정
  use_category: false,
  use_notice: true,               // 공지 기능
  use_secret: false,
  use_attachment: true,
  use_like: false,
  use_comment: false,
  use_thumbnail: false,
  use_top_fixed: true,            // 상위 고정
  use_display_period: true        // 노출 기간 설정
}
```

**특징:**
- 관리자만 작성 가능
- 댓글 기능 없음
- 상위 고정 기능 활성화
- 노출 기간 설정 가능 (이벤트 공지 등)

---

### free (자유게시판)

> 회원 누구나 작성, 댓글/좋아요/비밀글 모두 활성

```javascript
{
  board_code: 'free',
  board_name: '자유게시판',
  description: '자유롭게 의견을 나눠보세요.',
  board_type: 'free',

  // 보기 설정
  list_view_type: 'list',
  posts_per_page: 20,

  // 권한 설정
  read_permission: 'public',      // 누구나 읽기
  write_permission: 'member',      // 회원만 작성
  comment_permission: 'member',    // 회원만 댓글

  // 기능 설정
  use_category: false,
  use_notice: true,
  use_secret: true,               // 비밀글 허용
  use_attachment: true,
  use_like: true,                 // 좋아요
  use_comment: true,              // 댓글
  use_thumbnail: false,
  use_top_fixed: true,
  use_display_period: false
}
```

**특징:**
- 가장 범용적인 게시판
- 비밀글 기능 활성화
- 좋아요, 댓글 모두 활성

---

### qna (Q&A)

> 질문/답변 형태, 카테고리별 분류, 비밀 질문 가능

```javascript
{
  board_code: 'qna',
  board_name: '질문과 답변',
  description: '궁금한 점을 질문해주세요.',
  board_type: 'qna',

  // 보기 설정
  list_view_type: 'list',
  posts_per_page: 20,

  // 권한 설정
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',

  // 기능 설정
  use_category: true,             // 카테고리 사용
  categories: ['서비스문의', '결제문의', '기타'],
  use_notice: true,
  use_secret: true,               // 비밀 질문
  use_attachment: true,
  use_like: false,
  use_comment: true,
  use_thumbnail: false,
  use_top_fixed: false,
  use_display_period: false
}
```

**특징:**
- 카테고리별 질문 분류
- 비밀 질문 기능 (개인정보 포함 질문)
- 좋아요 비활성 (Q&A 특성)

---

### gallery (갤러리)

> 이미지 중심, 갤러리 보기, 썸네일 자동 생성

```javascript
{
  board_code: 'gallery',
  board_name: '갤러리',
  description: '사진을 공유해보세요.',
  board_type: 'gallery',

  // 보기 설정
  list_view_type: 'gallery',      // 갤러리 보기
  gallery_cols: 4,                 // 4열 표시
  posts_per_page: 20,

  // 권한 설정
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',

  // 기능 설정
  use_category: true,
  categories: ['풍경', '인물', '일상', '기타'],
  use_notice: false,
  use_secret: false,
  use_attachment: true,
  use_like: true,
  use_comment: true,
  use_thumbnail: true,            // 썸네일 사용
  thumbnail_width: 300,
  thumbnail_height: 300,
  use_top_fixed: false,
  use_display_period: false,

  // 파일 설정 (이미지만)
  allowed_file_types: 'jpg,jpeg,png,gif,webp',
  max_file_size: 20971520         // 20MB
}
```

**특징:**
- 갤러리 레이아웃 (그리드)
- 썸네일 자동 생성
- 이미지 파일만 허용

---

### faq (FAQ)

> 자주 묻는 질문, 관리자만 작성, 아코디언 형태

```javascript
{
  board_code: 'faq',
  board_name: 'FAQ',
  description: '자주 묻는 질문입니다.',
  board_type: 'faq',

  // 보기 설정
  list_view_type: 'list',
  posts_per_page: 50,             // 한 페이지에 많이 표시

  // 권한 설정
  read_permission: 'public',
  write_permission: 'admin',       // 관리자만 작성
  comment_permission: 'disabled',

  // 기능 설정
  use_category: true,             // 카테고리별 분류
  categories: ['회원', '서비스', '결제', '기타'],
  use_notice: false,
  use_secret: false,
  use_attachment: false,
  use_like: false,
  use_comment: false,
  use_thumbnail: false,
  use_top_fixed: false,
  use_display_period: false
}
```

**특징:**
- 관리자만 FAQ 등록
- 카테고리별 분류
- 아코디언 UI로 표시 권장
- 첨부파일, 댓글, 좋아요 모두 비활성

---

### review (후기게시판)

> 서비스 후기, 웹진 스타일, 썸네일 표시

```javascript
{
  board_code: 'review',
  board_name: '이용후기',
  description: '이용 후기를 남겨주세요.',
  board_type: 'review',

  // 보기 설정
  list_view_type: 'webzine',      // 웹진 스타일 (썸네일 + 내용 미리보기)
  posts_per_page: 10,

  // 권한 설정
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'member',

  // 기능 설정
  use_category: true,
  categories: ['병원후기', '매니저후기', '서비스후기'],
  use_notice: true,
  use_secret: false,
  use_attachment: true,
  use_like: true,
  use_comment: true,
  use_thumbnail: true,
  thumbnail_width: 200,
  thumbnail_height: 150,
  use_top_fixed: true,
  use_display_period: false
}
```

**특징:**
- 웹진 레이아웃 (썸네일 + 미리보기)
- 서비스별 카테고리 분류
- 베스트 후기 상위 고정 가능

---

## 커스텀 템플릿 생성

새로운 템플릿을 추가하려면:

```javascript
// 템플릿 이름: product_qna (상품 Q&A)
{
  board_code: 'product_qna',
  board_name: '상품 Q&A',
  description: '상품에 대해 궁금한 점을 질문해주세요.',
  board_type: 'qna',

  list_view_type: 'list',
  read_permission: 'public',
  write_permission: 'member',
  comment_permission: 'admin',     // 관리자만 답변

  use_category: false,
  use_secret: true,               // 비밀 질문
  use_attachment: true,
  use_like: false,
  use_comment: true,
}
```

---

## 템플릿 기본값

모든 템플릿에 적용되는 기본값:

```javascript
const defaultBoardSettings = {
  posts_per_page: 20,
  gallery_cols: 4,
  max_file_size: 10485760,        // 10MB
  max_file_count: 5,
  allowed_file_types: 'jpg,jpeg,png,gif,pdf,zip,doc,docx,xls,xlsx,ppt,pptx',
  thumbnail_width: 200,
  thumbnail_height: 200,
  display_order: 0,
  is_active: true,
  is_deleted: false
};
```

---

## 참고

- 템플릿은 `board-generator --template {name}`으로 사용
- 커스텀 게시판은 `board-generator to create {이름}`으로 생성
- 카테고리 고급 관리는 `category-manager` 사용
