package admin

import (
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AdminAccountController struct {
	svc adminSvc.AdminAccountService
}

func NewAdminAccountController(svc adminSvc.AdminAccountService) *AdminAccountController {
	return &AdminAccountController{svc: svc}
}

// =====================================
// ADMIN ACCOUNTS
// =====================================

// GET /admin/accounts
func (ctrl *AdminAccountController) ListAdmins(c *gin.Context) {
	admins, err := ctrl.svc.ListAdmins()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data akun admin")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", admins)
}

// POST /admin/accounts
func (ctrl *AdminAccountController) CreateAdmin(c *gin.Context) {
	var req struct {
		Nama     string  `json:"nama" binding:"required"`
		Email    string  `json:"email" binding:"required,email"`
		Password string  `json:"password" binding:"required,min=6"`
		RoleID   *string `json:"role_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid: "+err.Error())
		return
	}

	admin, err := ctrl.svc.CreateAdmin(req.Nama, req.Email, req.Password, req.RoleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Akun admin berhasil dibuat", admin)
}

// PUT /admin/accounts/:id
func (ctrl *AdminAccountController) UpdateAdmin(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Nama     string  `json:"nama" binding:"required"`
		Email    string  `json:"email" binding:"required,email"`
		Password string  `json:"password"`
		RoleID   *string `json:"role_id"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid: "+err.Error())
		return
	}

	admin, err := ctrl.svc.UpdateAdmin(id, req.Nama, req.Email, req.Password, req.RoleID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Akun admin berhasil diperbarui", admin)
}

// DELETE /admin/accounts/:id
func (ctrl *AdminAccountController) DeleteAdmin(c *gin.Context) {
	id := c.Param("id")
	if err := ctrl.svc.DeleteAdmin(id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Akun admin berhasil dihapus", nil)
}

// PATCH /admin/accounts/:id/role
func (ctrl *AdminAccountController) AssignRole(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		RoleID *string `json:"role_id"` // null = hapus role
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	if err := ctrl.svc.AssignRole(id, req.RoleID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Role berhasil di-assign", nil)
}

// =====================================
// ADMIN ROLES
// =====================================

// GET /admin/admin-roles
func (ctrl *AdminAccountController) ListRoles(c *gin.Context) {
	roles, err := ctrl.svc.ListRoles()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data role")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", roles)
}

// POST /admin/admin-roles
func (ctrl *AdminAccountController) CreateRole(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)

	var req struct {
		Nama        string          `json:"nama" binding:"required"`
		Permissions json.RawMessage `json:"permissions" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid: "+err.Error())
		return
	}

	role, err := ctrl.svc.CreateRole(req.Nama, req.Permissions, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Role berhasil dibuat", role)
}

// PUT /admin/admin-roles/:id
func (ctrl *AdminAccountController) UpdateRole(c *gin.Context) {
	id := c.Param("id")

	var req struct {
		Nama        string          `json:"nama" binding:"required"`
		Permissions json.RawMessage `json:"permissions" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	if err := ctrl.svc.UpdateRole(id, req.Nama, req.Permissions); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Role berhasil diperbarui", nil)
}

// DELETE /admin/admin-roles/:id
func (ctrl *AdminAccountController) DeleteRole(c *gin.Context) {
	id := c.Param("id")
	if err := ctrl.svc.DeleteRole(id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Role berhasil dihapus", nil)
}
