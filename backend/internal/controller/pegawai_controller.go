package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type PegawaiController struct {
	svc *service.PegawaiService
}

func NewPegawaiController(s *service.PegawaiService) *PegawaiController {
	return &PegawaiController{svc: s}
}

func (ctrl *PegawaiController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	var req struct {
		Nama            string `json:"nama" binding:"required"`
		Email           string `json:"email" binding:"required,email"`
		Password        string `json:"password" binding:"required,min=6"`
		RoleID          string `json:"role_id" binding:"required"`
		NoHP            string `json:"nohp"`
		TanggalLahir    string `json:"tanggal_lahir"`
		AllOutletAccess bool   `json:"all_outlet_access"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format data tidak valid: "+err.Error())
		return
	}
	if req.AllOutletAccess && c.GetString("actor_type") != "user" {
		utils.ErrorResponse(c, http.StatusForbidden, "Hanya owner yang dapat memberi akses semua outlet")
		return
	}

	pegawai := model.Pegawai{
		OutletID:        outletID.(string),
		RoleID:          req.RoleID,
		Nama:            req.Nama,
		Email:           req.Email,
		Password:        &req.Password,
		NoHP:            req.NoHP,
		Status:          1,
		AllOutletAccess: req.AllOutletAccess,
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

	utils.JSONResponse(c, http.StatusCreated, "Pegawai berhasil didaftarkan", data)
}

func (ctrl *PegawaiController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar pegawai", data)
}

func (ctrl *PegawaiController) Me(c *gin.Context) {
	actorID := c.GetString("actor_id")
	if c.GetString("actor_type") == "user" || actorID == "" {
		utils.ErrorResponse(c, http.StatusForbidden, "Profil karyawan tidak tersedia")
		return
	}
	data, err := ctrl.svc.GetByID(actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Data karyawan tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil profil karyawan", data)
}

func (ctrl *PegawaiController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	// Menggunakan pointer agar bisa mendeteksi field mana yang ada di JSON payload
	var req struct {
		Nama            *string `json:"nama"`
		RoleID          *string `json:"role_id"`
		Email           *string `json:"email"`
		NoHP            *string `json:"nohp"`
		TanggalLahir    *string `json:"tanggal_lahir"`
		Password        *string `json:"password"`
		Status          *int    `json:"status"`
		AllOutletAccess *bool   `json:"all_outlet_access"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}
	if req.AllOutletAccess != nil && c.GetString("actor_type") != "user" {
		utils.ErrorResponse(c, http.StatusForbidden, "Hanya owner yang dapat mengubah akses semua outlet")
		return
	}

	// Masukkan data ke map untuk dikirim ke service
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
	if req.AllOutletAccess != nil {
		updates["pg_all_outlet_access"] = *req.AllOutletAccess
	}

	// Khusus password, kita kirim raw string dulu untuk di-hash di service
	var rawPassword string
	if req.Password != nil && *req.Password != "" {
		rawPassword = *req.Password
	}

	actorID, _ := c.Get("actor_id")
	if err := ctrl.svc.UpdatePartial(id, outletID.(string), updates, rawPassword, fmt.Sprint(actorID)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	if req.Status != nil && *req.Status == 0 {
		utils.AppHub.BroadcastToOutlet(outletID.(string), gin.H{
			"type": "FORCE_LOGOUT",
			"payload": gin.H{
				"employee_id": id,
				"reason":      "Akun Anda telah dinonaktifkan oleh pemilik outlet.",
			},
		})
	}

	utils.JSONResponse(c, http.StatusOK, "Data pegawai berhasil diperbarui", nil)
}

func (ctrl *PegawaiController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	// DIUBAH: actorID diambil sebagai string agar sinkron
	actorID, _ := c.Get("actor_id")

	if err := ctrl.svc.Delete(id, outletID.(string), actorID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.AppHub.BroadcastToOutlet(outletID.(string), gin.H{
		"type": "FORCE_LOGOUT",
		"payload": gin.H{
			"employee_id": id,
			"reason":      "Akun pegawai Anda telah dihapus oleh pemilik outlet.",
		},
	})

	utils.JSONResponse(c, http.StatusOK, "Pegawai berhasil dihapus", nil)
}

func (ctrl *PegawaiController) ForceLogout(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.ForceLogout(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Beri tahu perangkat aktif di outlet. Client hanya mengeksekusi logout
	// ketika employee_id cocok dengan sesi lokalnya; perangkat lain mengabaikan.
	utils.AppHub.BroadcastToOutlet(outletID.(string), gin.H{
		"type": "FORCE_LOGOUT",
		"payload": gin.H{
			"employee_id": id,
			"reason":      "Sesi Anda telah diakhiri oleh owner.",
		},
	})

	utils.JSONResponse(c, http.StatusOK, "Sesi pegawai berhasil diakhiri", nil)
}
