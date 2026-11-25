package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AdminEconomyController struct {
	svc admin.AdminEconomyService
	db  *gorm.DB // Tambahkan DB untuk keperluan seeding
}

func NewAdminEconomyController(svc admin.AdminEconomyService, db *gorm.DB) *AdminEconomyController {
	return &AdminEconomyController{svc, db}
}

// --- CONFIG HANDLERS ---

func (ctrl *AdminEconomyController) GetAllConfigs(c *gin.Context) {
	configs, err := ctrl.svc.GetConfigs()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil config")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", configs)
}

func (ctrl *AdminEconomyController) UpdateConfig(c *gin.Context) {
	var req struct {
		Key   string `json:"key" binding:"required"`
		Value string `json:"value" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input tidak valid")
		return
	}

	if err := ctrl.svc.UpdateConfig(req.Key, req.Value); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal update config")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Config updated successfully", nil)
}

// --- SEEDER HANDLER ---

func (ctrl *AdminEconomyController) SeedConfigs(c *gin.Context) {
	if err := ctrl.svc.SeedEconomyConfig(); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal seeding: "+err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Economy configs seeded successfully", nil)
}

// --- PACKAGE HANDLERS ---

func (ctrl *AdminEconomyController) GetPackages(c *gin.Context) {
	res, err := ctrl.svc.GetKoinPackages()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data paket")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminEconomyController) CreatePackage(c *gin.Context) {
	var req struct {
		JumlahKoin  int `json:"jumlah_koin" binding:"required"`
		DiscountPct int `json:"discount_pct"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input tidak valid")
		return
	}

	res, err := ctrl.svc.CreatePackage(req.JumlahKoin, req.DiscountPct)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyimpan paket")
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Paket berhasil dibuat", res)
}

func (ctrl *AdminEconomyController) DeletePackage(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID tidak valid")
		return
	}

	if err := ctrl.svc.DeletePackage(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghapus paket")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Paket berhasil dihapus", nil)
}

func (ctrl *AdminEconomyController) UpdatePackage(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID tidak valid")
		return
	}

	var req struct {
		JumlahKoin  int `json:"jumlah_koin" binding:"required"`
		DiscountPct int `json:"discount_pct"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input tidak valid")
		return
	}

	if err := ctrl.svc.UpdatePackage(uint(id), req.JumlahKoin, req.DiscountPct); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengupdate paket")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Paket berhasil diupdate", nil)
}

// --- ADDON CATALOG HANDLERS ---

func (ctrl *AdminEconomyController) GetAddons(c *gin.Context) {
	res, err := ctrl.svc.GetAddons()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data addon")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminEconomyController) CreateAddon(c *gin.Context) {
	var req model.Addon
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input tidak valid")
		return
	}

	if err := ctrl.svc.CreateAddon(req); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyimpan addon")
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Addon berhasil dibuat", nil)
}

func (ctrl *AdminEconomyController) UpdateAddon(c *gin.Context) {
	id := c.Param("id")
	var req model.Addon
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input tidak valid")
		return
	}

	if err := ctrl.svc.UpdateAddon(id, req); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal update addon")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Addon updated successfully", nil)
}

func (ctrl *AdminEconomyController) DeleteAddon(c *gin.Context) {
	id := c.Param("id")
	if err := ctrl.svc.DeleteAddon(id); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghapus addon")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Addon berhasil dihapus", nil)
}
