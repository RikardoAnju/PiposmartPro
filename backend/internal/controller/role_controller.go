package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json" // Diperlukan untuk json.RawMessage
	"net/http"

	"github.com/gin-gonic/gin"
)

type RoleController struct {
	svc *service.RoleService
}

func NewRoleController(s *service.RoleService) *RoleController {
	return &RoleController{svc: s}
}

func (ctrl *RoleController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama       string          `json:"nama" binding:"required"`
		// DIUBAH: Menggunakan json.RawMessage agar bisa menerima Object JSON langsung
		Permission json.RawMessage `json:"permission" binding:"required"` 
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak lengkap atau format JSON permission salah")
		return
	}

	role := model.Role{
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Permission:     req.Permission,
		UserUpdate:     actorID, 
		UserUpdateType: actorType,
	}

	data, err := ctrl.svc.Create(role)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Role berhasil dibuat", data)
}

func (ctrl *RoleController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data role")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data role", data)
}

func (ctrl *RoleController) Update(c *gin.Context) {
	id := c.Param("id") 
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama       string          `json:"nama" binding:"required"`
		// DIUBAH: Menggunakan json.RawMessage
		Permission json.RawMessage `json:"permission" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	role := model.Role{
		ID:             id,
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Permission:     req.Permission,
		UserUpdate:     actorID,
		UserUpdateType: actorType,
	}

	if err := ctrl.svc.Update(role); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Role berhasil diperbarui", nil)
}

func (ctrl *RoleController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Role berhasil dihapus", nil)
}