package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type PelangganController struct {
	svc *service.PelangganService
}

func NewPelangganController(s *service.PelangganService) *PelangganController {
	return &PelangganController{svc: s}
}

func (ctrl *PelangganController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: actorID diambil sebagai string langsung dari context
	actorID := c.MustGet("actor_id").(string)
	actorType, _ := c.Get("actor_type")

	var req struct {
		Nama         string `json:"nama" binding:"required"`
		NoHP         string `json:"no_hp"`
		Alamat       string `json:"alamat"`
		JenisKelamin string `json:"jenis_kelamin"`
		TanggalLahir string `json:"tanggal_lahir"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid: "+err.Error())
		return
	}

	pelanggan := model.Pelanggan{
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		NoHP:           req.NoHP,
		Alamat:         req.Alamat,
		JenisKelamin:   req.JenisKelamin,
		UserUpdate:     actorID, // String ID Pegawai/Owner
		UserUpdateType: actorType.(string),
	}

	if req.TanggalLahir != "" {
		t, err := time.Parse("2006-01-02", req.TanggalLahir)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal lahir salah (Gunakan YYYY-MM-DD)")
			return
		}
		pelanggan.TanggalLahir = &t
	}

	data, err := ctrl.svc.Create(pelanggan)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Pelanggan berhasil didaftarkan", data)
}

func (ctrl *PelangganController) List(c *gin.Context) {
	outletID, exists := c.Get("outlet_id")
	if !exists {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Sesi tidak valid")
		return
	}

	// 1. Try Cache
	cacheKey := fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string))
	var data []service.PelangganListItem
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar pelanggan (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 30*time.Minute)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar pelanggan", data)
}

func (ctrl *PelangganController) BulkImport(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType, _ := c.Get("actor_type")

	var req struct {
		Items []struct {
			Nama         string `json:"nama"`
			NoHP         string `json:"no_hp"`
			Alamat       string `json:"alamat"`
			JenisKelamin string `json:"jenis_kelamin"`
		} `json:"items" binding:"required,min=1,max=200"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload import pelanggan tidak valid: "+err.Error())
		return
	}

	items := make([]service.BulkImportCustomerInput, 0, len(req.Items))
	for _, item := range req.Items {
		items = append(items, service.BulkImportCustomerInput{
			Nama:         item.Nama,
			NoHP:         item.NoHP,
			Alamat:       item.Alamat,
			JenisKelamin: item.JenisKelamin,
		})
	}

	data, err := ctrl.svc.BulkImport(outletID.(string), actorID, actorType.(string), items)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string)))
	if data.SuccessCount > 0 || data.SkippedCount > 0 {
		database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
		database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	}

	utils.JSONResponse(c, http.StatusCreated, "Import pelanggan selesai", data)
}

func (ctrl *PelangganController) BulkDelete(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	var req struct {
		IDs []string `json:"ids" binding:"required,min=1,max=200"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload hapus pelanggan tidak valid: "+err.Error())
		return
	}

	data, err := ctrl.svc.BulkDelete(outletID.(string), req.IDs)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string)))
	if data.SuccessCount > 0 {
		database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
		database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	}

	utils.JSONResponse(c, http.StatusOK, "Hapus pelanggan massal selesai", data)
}

func (ctrl *PelangganController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: actorID diambil sebagai string
	actorID := c.MustGet("actor_id").(string)
	actorType, _ := c.Get("actor_type")

	var req struct {
		Nama         string `json:"nama" binding:"required"`
		NoHP         string `json:"no_hp"`
		Alamat       string `json:"alamat"`
		JenisKelamin string `json:"jenis_kelamin"`
		TanggalLahir string `json:"tanggal_lahir"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	pelanggan := model.Pelanggan{
		ID:             id,
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		NoHP:           req.NoHP,
		Alamat:         req.Alamat,
		JenisKelamin:   req.JenisKelamin,
		UserUpdate:     actorID, // ID String tersimpan utuh
		UserUpdateType: actorType.(string),
	}

	if req.TanggalLahir != "" {
		t, err := time.Parse("2006-01-02", req.TanggalLahir)
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal lahir salah")
			return
		}
		pelanggan.TanggalLahir = &t
	}

	if err := ctrl.svc.Update(pelanggan); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string)), fmt.Sprintf("pelanggan:detail:%s", id))

	// Nama pelanggan mungkin berubah, bersihkan cache status yang menampilkan nama
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Data pelanggan berhasil diperbarui", nil)
}

func (ctrl *PelangganController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string)), fmt.Sprintf("pelanggan:detail:%s", id))

	// Bersihkan cache status yang mungkin mengandung data pelanggan ini
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Pelanggan berhasil dihapus", nil)
}

func (ctrl *PelangganController) GetByID(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("pelanggan:detail:%s", id)
	var data model.Pelanggan
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.GetByID(id, outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Pelanggan tidak ditemukan")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 30*time.Minute)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data", data)
}
