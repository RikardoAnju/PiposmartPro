package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AdminUserController struct {
	svc admin.AdminUserService
}

func NewAdminUserController(svc admin.AdminUserService) *AdminUserController {
	return &AdminUserController{svc}
}

func (ctrl *AdminUserController) ListOwners(c *gin.Context) {
	users, err := ctrl.svc.GetAllOwners()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  false,
			"message": "Gagal mengambil data user: " + err.Error(),
		})
		return
	}

	page, limit := parsePagination(c, 25)
	total := len(users)
	start := (page - 1) * limit
	if start > total {
		start = total
	}
	end := start + limit
	if end > total {
		end = total
	}

	if c.Query("paginated") != "1" {
		c.JSON(http.StatusOK, gin.H{
			"status": true,
			"data":   users,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": true,
		"data": gin.H{
			"items": users[start:end],
			"pagination": gin.H{
				"page":  page,
				"limit": limit,
				"total": total,
			},
		},
	})
}

func (ctrl *AdminUserController) GetOwnerDetail(c *gin.Context) {
	id := c.Param("id")
	ownerDetail, err := ctrl.svc.GetOwnerDetail(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  false,
			"message": "Gagal mengambil detail owner: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": true,
		"data":   ownerDetail,
	})
}

func (ctrl *AdminUserController) UpdateOwnerProfile(c *gin.Context) {
	id := c.Param("id")

	var req struct {
		Name     string `json:"name"`
		Email    string `json:"email"`
		NoHP     string `json:"nohp"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  false,
			"message": "Data tidak valid",
		})
		return
	}

	updates := map[string]interface{}{}
	if req.Name != "" {
		updates["usr_nama"] = req.Name
	}
	if req.Email != "" {
		updates["usr_email"] = req.Email
	}
	if req.NoHP != "" {
		updates["usr_nohp"] = req.NoHP
	}
	if req.Password != "" {
		updates["usr_password"] = req.Password
	}

	if err := ctrl.svc.UpdateOwnerProfile(id, updates); err != nil {
		status := http.StatusInternalServerError
		message := "Gagal memperbarui profil owner"
		if err == gorm.ErrDuplicatedKey {
			status = http.StatusConflict
			message = "Email sudah dipakai user lain"
		}
		c.JSON(status, gin.H{
			"status":  false,
			"message": message,
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  true,
		"message": "Profil owner berhasil diperbarui",
	})
}

func (ctrl *AdminUserController) DeleteOwner(c *gin.Context) {
	id := c.Param("id")

	var req struct {
		Reason       string `json:"reason"`
		ReasonDetail string `json:"reason_detail"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"status":  false,
			"message": "Data tidak valid",
		})
		return
	}

	if req.Reason == "" {
		req.Reason = "deleted_by_admin"
	}

	if err := ctrl.svc.DeleteOwner(id, req.Reason, req.ReasonDetail); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"status":  false,
			"message": "Gagal menghapus owner: " + err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  true,
		"message": "Owner dan seluruh data terkait berhasil dihapus",
	})
}
