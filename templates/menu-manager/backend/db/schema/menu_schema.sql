-- =====================================================
-- 통합 메뉴 관리 시스템 스키마
-- Type: user, site, admin, header_utility, footer_utility
-- =====================================================

-- 1. 메뉴 테이블 (통합)
CREATE TABLE IF NOT EXISTS menus (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,

  -- 메뉴 타입 (user, site, admin, header_utility, footer_utility, quick_menu)
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

  -- 가상 경로 설정
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

  -- 표시 조건 (유틸리티 메뉴용)
  show_condition ENUM('always', 'logged_in', 'logged_out', 'custom') DEFAULT 'always',
  condition_expression VARCHAR(500),

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. 사용자 그룹 테이블
CREATE TABLE IF NOT EXISTS user_groups (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  group_name VARCHAR(100) NOT NULL,
  group_code VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(500),
  priority INT DEFAULT 0,

  -- 그룹 타입
  group_type ENUM('system', 'custom') DEFAULT 'custom',

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. 사용자-그룹 매핑 테이블
CREATE TABLE IF NOT EXISTS user_group_members (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  group_id BIGINT NOT NULL,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),

  UNIQUE KEY uk_user_group (user_id, group_id),
  FOREIGN KEY (group_id) REFERENCES user_groups(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_group (group_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. 역할 테이블
CREATE TABLE IF NOT EXISTS roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  role_name VARCHAR(100) NOT NULL,
  role_code VARCHAR(50) NOT NULL UNIQUE,
  description VARCHAR(500),
  priority INT DEFAULT 0,

  -- 역할 범위
  role_scope ENUM('admin', 'user', 'both') DEFAULT 'both',

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  updated_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. 사용자-역할 매핑 테이블
CREATE TABLE IF NOT EXISTS user_roles (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  role_id BIGINT NOT NULL,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),

  UNIQUE KEY uk_user_role (user_id, role_id),
  FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE,
  INDEX idx_user (user_id),
  INDEX idx_role (role_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. 메뉴 권한 매핑 테이블
CREATE TABLE IF NOT EXISTS menu_permissions (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  menu_id BIGINT NOT NULL,

  -- 권한 대상 (하나만 값을 가짐)
  group_id BIGINT NULL,
  user_id VARCHAR(50) NULL,
  role_id BIGINT NULL,

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. 관련 사이트 테이블 (푸터용)
CREATE TABLE IF NOT EXISTS related_sites (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  menu_id BIGINT NOT NULL,

  site_name VARCHAR(100) NOT NULL,
  site_url VARCHAR(500) NOT NULL,
  site_icon VARCHAR(200),
  sort_order INT DEFAULT 0,
  is_new_window BOOLEAN DEFAULT TRUE,

  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  created_by VARCHAR(100),
  is_active BOOLEAN DEFAULT TRUE,
  is_deleted BOOLEAN DEFAULT FALSE,

  FOREIGN KEY (menu_id) REFERENCES menus(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- 기본 데이터 INSERT
-- =====================================================

-- 기본 그룹
INSERT INTO user_groups (group_name, group_code, priority, group_type, created_by) VALUES
('전체 회원', 'all_members', 0, 'system', 'system'),
('일반 회원', 'regular', 10, 'system', 'system'),
('VIP 회원', 'vip', 50, 'system', 'system'),
('프리미엄 회원', 'premium', 80, 'system', 'system')
ON DUPLICATE KEY UPDATE group_name = VALUES(group_name);

-- 기본 역할
INSERT INTO roles (role_name, role_code, priority, role_scope, created_by) VALUES
('슈퍼관리자', 'super_admin', 100, 'admin', 'system'),
('관리자', 'admin', 50, 'admin', 'system'),
('매니저', 'manager', 30, 'admin', 'system'),
('에디터', 'editor', 20, 'both', 'system'),
('뷰어', 'viewer', 10, 'both', 'system')
ON DUPLICATE KEY UPDATE role_name = VALUES(role_name);

-- =====================================================
-- USER 타입 기본 메뉴 데이터
-- =====================================================

-- 1차 메뉴 (depth: 0)
INSERT INTO menus (menu_type, menu_name, menu_code, icon, link_type, link_url, permission_type, sort_order, created_by) VALUES
('user', '마이페이지', 'mypage', 'mdi-account-circle', 'none', NULL, 'member', 1, 'system'),
('user', '주문/배송', 'orders', 'mdi-package-variant', 'none', NULL, 'member', 2, 'system'),
('user', '활동내역', 'activity', 'mdi-history', 'none', NULL, 'member', 3, 'system'),
('user', '고객지원', 'my_support', 'mdi-help-circle', 'none', NULL, 'member', 4, 'system')
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

-- 2차 메뉴 - 마이페이지 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '회원정보 수정', 'mypage_profile', 'url', '/mypage/profile', 1, 'member', 1, 'system'
FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '비밀번호 변경', 'mypage_password', 'url', '/mypage/password', 1, 'member', 2, 'system'
FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '회원등급/혜택', 'mypage_grade', 'url', '/mypage/grade', 1, 'member', 3, 'system'
FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '회원탈퇴', 'mypage_withdraw', 'url', '/mypage/withdraw', 1, 'member', 4, 'system'
FROM menus WHERE menu_code = 'mypage' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

-- 2차 메뉴 - 주문/배송 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '주문내역', 'orders_list', 'url', '/mypage/orders', 1, 'member', 1, 'system'
FROM menus WHERE menu_code = 'orders' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '배송조회', 'orders_delivery', 'url', '/mypage/delivery', 1, 'member', 2, 'system'
FROM menus WHERE menu_code = 'orders' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '취소/반품/교환', 'orders_cancel', 'url', '/mypage/cancel', 1, 'member', 3, 'system'
FROM menus WHERE menu_code = 'orders' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

-- 2차 메뉴 - 활동내역 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '찜목록', 'activity_wishlist', 'url', '/mypage/wishlist', 1, 'member', 1, 'system'
FROM menus WHERE menu_code = 'activity' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '최근 본 상품', 'activity_recent', 'url', '/mypage/recent', 1, 'member', 2, 'system'
FROM menus WHERE menu_code = 'activity' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '내가 쓴 글', 'activity_posts', 'url', '/mypage/posts', 1, 'member', 3, 'system'
FROM menus WHERE menu_code = 'activity' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '포인트/쿠폰', 'activity_point', 'url', '/mypage/point', 1, 'member', 4, 'system'
FROM menus WHERE menu_code = 'activity' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

-- 2차 메뉴 - 고객지원 하위
INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '1:1 문의내역', 'my_support_inquiry', 'url', '/mypage/inquiry', 1, 'member', 1, 'system'
FROM menus WHERE menu_code = 'my_support' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);

INSERT INTO menus (menu_type, parent_id, menu_name, menu_code, link_type, link_url, depth, permission_type, sort_order, created_by)
SELECT 'user', id, '상품 Q&A', 'my_support_qna', 'url', '/mypage/qna', 1, 'member', 2, 'system'
FROM menus WHERE menu_code = 'my_support' AND menu_type = 'user'
ON DUPLICATE KEY UPDATE menu_name = VALUES(menu_name);
