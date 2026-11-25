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

type ParfumController struct {
	svc *service.ParfumService
}

func NewParfumController(s *service.ParfumService) *ParfumController {
	return &ParfumController{svc: s}
}

func (ctrl *ParfumController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string dari context
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama string `json:"nama" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nama parfum wajib diisi")
		return
	}

	parfum := model.Parfum{
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Status:         1,
		UserUpdate:     actorID, // String ID
		UserUpdateType: actorType,
	}

	data, err := ctrl.svc.Create(parfum)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("parfum:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Parfum berhasil ditambahkan", data)
}

func (ctrl *ParfumController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("parfum:list:%s", outletID.(string))
	var data []model.Parfum
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar parfum (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil daftar parfum")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 24*time.Hour)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar parfum", data)
}

func (ctrl *ParfumController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("parfum:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Parfum berhasil dihapus", nil)
}

func (ctrl *ParfumController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama   string `json:"nama" binding:"required"`
		Status int    `json:"status"` 
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	parfum := model.Parfum{
		ID:             id,
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Status:         req.Status,
		UserUpdate:     actorID, // ID Pegawai String tersimpan utuh
		UserUpdateType: actorType,
	}

	if err := ctrl.svc.Update(parfum); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("parfum:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Parfum berhasil diperbarui", nil)
}