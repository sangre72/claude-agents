const mysql = require('mysql2');

// MySQL 연결 설정
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
      console.log('[Menu Admin MySQL] Successfully connected to the database.');
      mysqlAvailable = true;
    }
  });
} catch (err) {
  console.warn('[Menu Admin MySQL] Failed to create connection:', err.message);
}

/**
 * 입력값 검증
 */
const validateInput = (input, fieldName, maxLength = 100) => {
  if (typeof input !== 'string') {
    throw new Error(`${fieldName} must be a string`);
  }
  if (input.length === 0) {
    throw new Error(`${fieldName} is required`);
  }
  if (input.length > maxLength) {
    throw new Error(`${fieldName} exceeds maximum length of ${maxLength}`);
  }
  const dangerous = /<script|javascript:|onerror=|onclick=|--/i;
  if (dangerous.test(input)) {
    throw new Error(`${fieldName} contains invalid characters`);
  }
  return input.trim();
};

/**
 * 관리자 권한 확인
 * TODO: 프로덕션에서는 아래 주석을 해제하고 return true; 를 삭제하세요
 */
const checkAdminPermission = (session) => {
  // 개발 환경에서는 권한 체크 비활성화
  return true;

  // if (!session || !session.isLoggedIn || !session.isAdmin) {
  //   return false;
  // }
  // return true;
};

/**
 * 전체 메뉴 조회 (관리자용)
 * GET /api/admin/menus
 */
const getAllMenus = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const { type } = req.query;

    let query = `
      SELECT
        m.*,
        p.menu_name as parent_name
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
        console.error('[Menu Admin] Error fetching menus:', error);
        return res.status(500).json({
          success: false,
          error_code: 'QUERY_ERROR',
          message: '메뉴 조회 중 오류가 발생했습니다.'
        });
      }

      res.json({
        success: true,
        data: results
      });
    });
  } catch (error) {
    console.error('[Menu Admin] Error in getAllMenus:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '메뉴 조회 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 메뉴 상세 조회
 * GET /api/admin/menus/:id
 */
const getMenuById = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const { id } = req.params;

    const query = 'SELECT * FROM menus WHERE id = ? AND is_deleted = 0';

    connection.query(query, [parseInt(id)], (error, results) => {
      if (error) {
        console.error('[Menu Admin] Error fetching menu:', error);
        return res.status(500).json({
          success: false,
          error_code: 'QUERY_ERROR',
          message: '메뉴 조회 중 오류가 발생했습니다.'
        });
      }

      if (results.length === 0) {
        return res.status(404).json({
          success: false,
          error_code: 'MENU_NOT_FOUND',
          message: '메뉴를 찾을 수 없습니다.'
        });
      }

      res.json({
        success: true,
        data: results[0]
      });
    });
  } catch (error) {
    console.error('[Menu Admin] Error in getMenuById:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '메뉴 조회 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 메뉴 생성
 * POST /api/admin/menus
 */
const createMenu = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const {
      menu_type,
      parent_id,
      menu_name,
      menu_code,
      description,
      icon,
      link_type,
      link_url,
      permission_type,
      show_condition,
      sort_order
    } = req.body;

    let validMenuType, validMenuName, validMenuCode;
    try {
      validMenuType = validateInput(menu_type, 'menu_type', 50);
      validMenuName = validateInput(menu_name, 'menu_name', 100);
      validMenuCode = validateInput(menu_code, 'menu_code', 50);
    } catch (err) {
      return res.status(400).json({
        success: false,
        error_code: 'INVALID_INPUT',
        message: err.message
      });
    }

    const depth = parent_id ? 1 : 0;
    const createdBy = req.session.userId || 'admin';

    const query = `
      INSERT INTO menus (
        menu_type, parent_id, menu_name, menu_code, description, icon,
        link_type, link_url, permission_type, show_condition,
        depth, sort_order, created_by, updated_by
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `;

    connection.query(
      query,
      [
        validMenuType,
        parent_id || null,
        validMenuName,
        validMenuCode,
        description || null,
        icon || null,
        link_type || 'url',
        link_url || null,
        permission_type || 'member',
        show_condition || 'always',
        depth,
        sort_order || 0,
        createdBy,
        createdBy
      ],
      (error, result) => {
        if (error) {
          console.error('[Menu Admin] Error creating menu:', error);
          if (error.code === 'ER_DUP_ENTRY') {
            return res.status(400).json({
              success: false,
              error_code: 'DUPLICATE_MENU_CODE',
              message: '이미 존재하는 메뉴 코드입니다.'
            });
          }
          return res.status(500).json({
            success: false,
            error_code: 'CREATE_ERROR',
            message: '메뉴 생성 중 오류가 발생했습니다.'
          });
        }

        res.status(201).json({
          success: true,
          data: {
            id: result.insertId,
            message: '메뉴가 생성되었습니다.'
          }
        });
      }
    );
  } catch (error) {
    console.error('[Menu Admin] Error in createMenu:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '메뉴 생성 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 메뉴 수정
 * PUT /api/admin/menus/:id
 */
const updateMenu = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const { id } = req.params;
    const {
      menu_name,
      description,
      icon,
      link_type,
      link_url,
      permission_type,
      show_condition,
      is_visible,
      is_active
    } = req.body;

    let validMenuName;
    try {
      validMenuName = validateInput(menu_name, 'menu_name', 100);
    } catch (err) {
      return res.status(400).json({
        success: false,
        error_code: 'INVALID_INPUT',
        message: err.message
      });
    }

    const updatedBy = req.session.userId || 'admin';

    const query = `
      UPDATE menus
      SET
        menu_name = ?,
        description = ?,
        icon = ?,
        link_type = ?,
        link_url = ?,
        permission_type = ?,
        show_condition = ?,
        is_visible = ?,
        is_active = ?,
        updated_by = ?
      WHERE id = ? AND is_deleted = 0
    `;

    connection.query(
      query,
      [
        validMenuName,
        description || null,
        icon || null,
        link_type || 'url',
        link_url || null,
        permission_type || 'member',
        show_condition || 'always',
        is_visible !== undefined ? is_visible : true,
        is_active !== undefined ? is_active : true,
        updatedBy,
        parseInt(id)
      ],
      (error, result) => {
        if (error) {
          console.error('[Menu Admin] Error updating menu:', error);
          return res.status(500).json({
            success: false,
            error_code: 'UPDATE_ERROR',
            message: '메뉴 수정 중 오류가 발생했습니다.'
          });
        }

        if (result.affectedRows === 0) {
          return res.status(404).json({
            success: false,
            error_code: 'MENU_NOT_FOUND',
            message: '메뉴를 찾을 수 없습니다.'
          });
        }

        res.json({
          success: true,
          data: {
            message: '메뉴가 수정되었습니다.'
          }
        });
      }
    );
  } catch (error) {
    console.error('[Menu Admin] Error in updateMenu:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '메뉴 수정 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 메뉴 삭제 (Soft Delete)
 * DELETE /api/admin/menus/:id
 */
const deleteMenu = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const { id } = req.params;
    const updatedBy = req.session.userId || 'admin';

    const query = `
      UPDATE menus
      SET is_deleted = 1, updated_by = ?
      WHERE id = ?
    `;

    connection.query(query, [updatedBy, parseInt(id)], (error, result) => {
      if (error) {
        console.error('[Menu Admin] Error deleting menu:', error);
        return res.status(500).json({
          success: false,
          error_code: 'DELETE_ERROR',
          message: '메뉴 삭제 중 오류가 발생했습니다.'
        });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          error_code: 'MENU_NOT_FOUND',
          message: '메뉴를 찾을 수 없습니다.'
        });
      }

      res.json({
        success: true,
        data: {
          message: '메뉴가 삭제되었습니다.'
        }
      });
    });
  } catch (error) {
    console.error('[Menu Admin] Error in deleteMenu:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '메뉴 삭제 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 메뉴 순서 변경
 * PUT /api/admin/menus/reorder
 */
const reorderMenus = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const { orderedIds } = req.body;

    if (!Array.isArray(orderedIds) || orderedIds.length === 0) {
      return res.status(400).json({
        success: false,
        error_code: 'INVALID_INPUT',
        message: 'orderedIds must be a non-empty array'
      });
    }

    const updatedBy = req.session.userId || 'admin';

    connection.beginTransaction((transError) => {
      if (transError) {
        console.error('[Menu Admin] Transaction error:', transError);
        return res.status(500).json({
          success: false,
          error_code: 'TRANSACTION_ERROR',
          message: '순서 변경 중 오류가 발생했습니다.'
        });
      }

      let completed = 0;
      let hasError = false;

      orderedIds.forEach((id, index) => {
        const query = `
          UPDATE menus
          SET sort_order = ?, updated_by = ?
          WHERE id = ?
        `;

        connection.query(query, [index, updatedBy, parseInt(id)], (error) => {
          if (error && !hasError) {
            hasError = true;
            console.error('[Menu Admin] Error updating order:', error);
            return connection.rollback(() => {
              res.status(500).json({
                success: false,
                error_code: 'UPDATE_ERROR',
                message: '순서 변경 중 오류가 발생했습니다.'
              });
            });
          }

          completed++;

          if (completed === orderedIds.length && !hasError) {
            connection.commit((commitError) => {
              if (commitError) {
                console.error('[Menu Admin] Commit error:', commitError);
                return connection.rollback(() => {
                  res.status(500).json({
                    success: false,
                    error_code: 'COMMIT_ERROR',
                    message: '순서 변경 중 오류가 발생했습니다.'
                  });
                });
              }

              res.json({
                success: true,
                data: {
                  message: '메뉴 순서가 변경되었습니다.'
                }
              });
            });
          }
        });
      });
    });
  } catch (error) {
    console.error('[Menu Admin] Error in reorderMenus:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '순서 변경 중 오류가 발생했습니다.'
    });
  }
};

/**
 * 메뉴 이동 (부모 변경 + 순서 변경)
 * PUT /api/admin/menus/:id/move
 */
const moveMenu = async (req, res) => {
  try {
    if (!mysqlAvailable) {
      return res.status(503).json({
        success: false,
        error_code: 'DATABASE_UNAVAILABLE',
        message: 'Database service is not available'
      });
    }

    if (!checkAdminPermission(req.session)) {
      return res.status(403).json({
        success: false,
        error_code: 'ACCESS_DENIED',
        message: '관리자 권한이 필요합니다.'
      });
    }

    const { id } = req.params;
    const { parent_id, sort_order } = req.body;

    if (sort_order === undefined || sort_order < 0) {
      return res.status(400).json({
        success: false,
        error_code: 'INVALID_INPUT',
        message: 'sort_order is required and must be >= 0'
      });
    }

    const updatedBy = req.session.userId || 'admin';

    // 부모가 변경되면 depth 계산
    let newDepth = 0;
    if (parent_id) {
      const parentQuery = 'SELECT depth FROM menus WHERE id = ?';
      connection.query(parentQuery, [parseInt(parent_id)], (error, results) => {
        if (error) {
          console.error('[Menu Admin] Error fetching parent:', error);
          return res.status(500).json({
            success: false,
            error_code: 'QUERY_ERROR',
            message: '부모 메뉴 조회 중 오류가 발생했습니다.'
          });
        }

        if (results.length === 0) {
          return res.status(404).json({
            success: false,
            error_code: 'PARENT_NOT_FOUND',
            message: '부모 메뉴를 찾을 수 없습니다.'
          });
        }

        newDepth = results[0].depth + 1;
        updateMenuPosition(id, parent_id, newDepth, sort_order, updatedBy, res);
      });
    } else {
      updateMenuPosition(id, null, 0, sort_order, updatedBy, res);
    }
  } catch (error) {
    console.error('[Menu Admin] Error in moveMenu:', error);
    res.status(500).json({
      success: false,
      error_code: 'INTERNAL_ERROR',
      message: '메뉴 이동 중 오류가 발생했습니다.'
    });
  }
};

const updateMenuPosition = (id, parentId, depth, sortOrder, updatedBy, res) => {
  const query = `
    UPDATE menus
    SET parent_id = ?, depth = ?, sort_order = ?, updated_by = ?
    WHERE id = ? AND is_deleted = 0
  `;

  connection.query(
    query,
    [parentId, depth, sortOrder, updatedBy, parseInt(id)],
    (error, result) => {
      if (error) {
        console.error('[Menu Admin] Error moving menu:', error);
        return res.status(500).json({
          success: false,
          error_code: 'UPDATE_ERROR',
          message: '메뉴 이동 중 오류가 발생했습니다.'
        });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({
          success: false,
          error_code: 'MENU_NOT_FOUND',
          message: '메뉴를 찾을 수 없습니다.'
        });
      }

      res.json({
        success: true,
        data: {
          message: '메뉴가 이동되었습니다.'
        }
      });
    }
  );
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
