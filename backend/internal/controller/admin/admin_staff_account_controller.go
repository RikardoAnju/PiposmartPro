package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type AdminStaffAccountController struct {
	svc *service.PegawaiService
}

func NewAdminStaffAccountController(s *service.PegawaiService) *AdminStaffAccountController {
	return &AdminStaffAccountController{svc: s}
}

func (ctrl *AdminStaffAccountController) Create(c *gin.Context) {
	outletID := c.Param("id")

	var req struct {
		Nama         string `json:"nama" binding:"required"`
		Email        string `json:"email" binding:"required,email"`
		Password     string `json:"password" binding:"required,min=6"`
		RoleID       string `json:"role_id" binding:"required"`
		NoHP         string `json:"nohp"`
		TanggalLahir string `json:"tanggal_lahir"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format data tidak valid: "+err.Error())
		return
	}

	pegawai := model.Pegawai{
		OutletID: outletID,
		RoleID:   req.RoleID,
		Nama:     req.Nama,
		Email:    req.Email,
		Password: &req.Password,
		NoHP:     req.NoHP,
		Status:   1,
	}

	if req.TanggalLahir != "" {
		if parsed, err := time.Parse("2006-01-02", req.TanggalLahir); err == nil {
			pegawai.TanggalLahir = &parsed
		}
	}

	actorID, _ := c.Get("actor_id")
	data, err := ctrl.svc.Create(pegawai, fmt.Sprint(actorID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Akun karyawan berhasil dibuat", data)
}

func (ctrl *AdminStaffAccountController) Update(c *gin.Context) {
	id := c.Param("staff_id")
	outletID := c.Param("id")

	var req struct {
		Nama         *string `json:"nama"`
		RoleID       *string `json:"role_id"`
		Email        *string `json:"email"`
		NoHP         *string `json:"nohp"`
		TanggalLahir *string `json:"tanggal_lahir"`
		Password     *string `json:"password"`
		Status       *int    `json:"status"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	updates := make(map[string]interface{})
	if req.Nama != nil {
		updates["pg_nama"] = *req.Nama
	}
	if req.RoleID != nil {
		updates["pg_role"] = *req.RoleID
	}
	if req.Email != nil {
		updates["pg_email"] = *req.Email
	}
	if req.NoHP != nil {
		updates["pg_nohp"] = *req.NoHP
	}
	if req.TanggalLahir != nil {
		if *req.TanggalLahir == "" {
			updates["pg_tanggal_lahir"] = nil
		} else if parsed, err := time.Parse("2006-01-02", *req.TanggalLahir); err == nil {
			updates["pg_tanggal_lahir"] = parsed
		}
	}
	if req.Status != nil {
		updates["pg_status"] = *req.Status
	}

	var rawPassword string
	if req.Password != nil && *req.Password != "" {
		rawPassword = *req.Password
	}

	actorID, _ := c.Get("actor_id")
	if err := ctrl.svc.UpdatePartial(id, outletID, updates, rawPassword, fmt.Sprint(actorID)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Akun karyawan berhasil diperbarui", nil)
}

func (ctrl *AdminStaffAccountController) Delete(c *gin.Context) {
	id := c.Param("staff_id")
	outletID := c.Param("id")

	if err := ctrl.svc.Delete(id, outletID, ""); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Akun karyawan berhasil dihapus", nil)
}
