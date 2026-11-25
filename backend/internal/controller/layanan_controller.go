package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type LayananController struct {
	svc *service.LayananService
}

func NewLayananController(s *service.LayananService) *LayananController {
	return &LayananController{svc: s}
}

func (ctrl *LayananController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string dari context
	actorID := c.MustGet("actor_id").(string)
	actorType, _ := c.Get("actor_type")

	var req struct {
		Name      string   `json:"name" binding:"required"`
		Processes []string `json:"processes"`
		Products  []struct {
			Name         string   `json:"name" binding:"required"`
			Price        float64  `json:"price"`
			Unit         string   `json:"unit"`
			MinimalOrder *float64 `json:"minimalOrder"`
			Duration     int      `json:"duration"`
			DurationUnit string   `json:"durationUnit"`
			IconPath     string   `json:"iconPath"`
			Prioritas    int      `json:"prioritas"`
		} `json:"products"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid: "+err.Error())
		return
	}

	layanan := model.Layanan{
		OutletID: outletID.(string),
		Nama:     req.Name,
		Proses:   strings.Join(req.Processes, ","),
	}

	for _, p := range req.Products {
		layanan.Products = append(layanan.Products, model.JenisProduk{
			Nama: p.Name, Harga: p.Price, Satuan: p.Unit,
			MinimalOrder: p.MinimalOrder,
			Durasi:       p.Duration, DurasiSatuan: p.DurationUnit, Icon: p.IconPath, Prioritas: p.Prioritas,
		})
	}

	if err := ctrl.svc.CreateLayanan(layanan, actorID, actorType.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("layanan:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Layanan berhasil ditambahkan", nil)
}

// GetPopular mengembalikan layanan tersering se-outlet untuk fitur "Tambah Cepat".
func (ctrl *LayananController) GetPopular(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	cacheKey := fmt.Sprintf("layanan:popular:%s", outletID.(string))
	var data []service.PopularService
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil layanan populer (Cached)", data)
		return
	}

	data, err := ctrl.svc.GetPopularProductIDs(outletID.(string), 12)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	database.SetCache(cacheKey, data, 1*time.Hour)
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil layanan populer", data)
}

func (ctrl *LayananController) GetByOutlet(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("layanan:list:%s", outletID.(string))
	var data []model.Layanan
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data layanan (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.GetLayananByOutlet(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 24*time.Hour)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data layanan", data)
}

func (ctrl *LayananController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType, _ := c.Get("actor_type")

	var req struct {
		Name      string   `json:"name" binding:"required"`
		Processes []string `json:"processes"`
		Products  []struct {
			ID           string   `json:"id"` // TAMBAHKAN INI agar ID produk lama terbawa
			Name         string   `json:"name" binding:"required"`
			Price        float64  `json:"price"`
			Unit         string   `json:"unit"`
			MinimalOrder *float64 `json:"minimalOrder"`
			Duration     int      `json:"duration"`
			DurationUnit string   `json:"durationUnit"`
			IconPath     string   `json:"iconPath"`
			Prioritas    int      `json:"prioritas"`
		} `json:"products"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	layanan := model.Layanan{
		ID: id, OutletID: outletID.(string), Nama: req.Name,
		Proses: strings.Join(req.Processes, ","),
	}

	for _, p := range req.Products {
		layanan.Products = append(layanan.Products, model.JenisProduk{
			ID:           p.ID, // PASTIKAN ID dipetakan di sini
			Nama:         p.Name,
			Harga:        p.Price,
			Satuan:       p.Unit,
			MinimalOrder: p.MinimalOrder,
			Durasi:       p.Duration,
			DurasiSatuan: p.DurationUnit,
			Icon:         p.IconPath,
			Prioritas:    p.Prioritas,
		})
	}

	if err := ctrl.svc.UpdateLayanan(layanan, actorID, actorType.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("layanan:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Layanan berhasil diperbarui", nil)
}

func (ctrl *LayananController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.DeleteLayanan(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("layanan:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Layanan berhasil dihapus", nil)
}
