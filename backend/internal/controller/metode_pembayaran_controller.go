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

type MetodePembayaranController struct {
	svc *service.MetodePembayaranService
}

func NewMetodePembayaranController(s *service.MetodePembayaranService) *MetodePembayaranController {
	return &MetodePembayaranController{svc: s}
}

func (ctrl *MetodePembayaranController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string dari context
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Name            string  `json:"name" binding:"required"`
		Description     string  `json:"description"`
		Category        string  `json:"category" binding:"required"`
		IsActive        bool    `json:"is_active"`
		BankName        *string `json:"bank_name"`
		AccountNumber   *string `json:"account_number"`
		AccountHolder   *string `json:"account_holder"`
		EwalletProvider *string `json:"ewallet_provider"`
		PhoneNumber     *string `json:"phone_number"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak lengkap: "+err.Error())
		return
	}

	status := 0
	if req.IsActive {
		status = 1
	}

	mp := model.MetodePembayaran{
		OutletID:        outletID.(string),
		Nama:            req.Name,
		Deskripsi:       req.Description,
		Kategori:        req.Category,
		Status:          status,
		NamaBank:        req.BankName,
		NomorAkun:       req.AccountNumber,
		NamaPemilik:     req.AccountHolder,
		EwalletProvider: req.EwalletProvider,
		NomorHP:         req.PhoneNumber,
		UserUpdate:      actorID, // String ID
		UserUpdateType:  actorType,
	}

	data, err := ctrl.svc.Create(mp)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("payment:list:v2:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Metode pembayaran berhasil ditambah", data)
}

func (ctrl *MetodePembayaranController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("payment:list:v2:%s", outletID.(string))
	var data []model.MetodePembayaran
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 24*time.Hour)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data", data)
}

func (ctrl *MetodePembayaranController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Name            string  `json:"name"`
		Description     string  `json:"description"`
		IsActive        bool    `json:"is_active"`
		BankName        *string `json:"bank_name"`
		AccountNumber   *string `json:"account_number"`
		AccountHolder   *string `json:"account_holder"`
		EwalletProvider *string `json:"ewallet_provider"`
		PhoneNumber     *string `json:"phone_number"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	if req.Name == "" {
		status := 0
		if req.IsActive {
			status = 1
		}
		if err := ctrl.svc.UpdateStatus(id, outletID.(string), status, actorID, actorType); err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
			return
		}
		database.InvalidateCache(fmt.Sprintf("payment:list:v2:%s", outletID.(string)))
		utils.JSONResponse(c, http.StatusOK, "Status metode pembayaran berhasil diperbarui", nil)
		return
	}

	status := 0
	if req.IsActive {
		status = 1
	}

	mp := model.MetodePembayaran{
		ID:              id,
		OutletID:        outletID.(string),
		Nama:            req.Name,
		Deskripsi:       req.Description,
		Status:          status,
		NamaBank:        req.BankName,
		NomorAkun:       req.AccountNumber,
		NamaPemilik:     req.AccountHolder,
		EwalletProvider: req.EwalletProvider,
		NomorHP:         req.PhoneNumber,
		UserUpdate:      actorID,
		UserUpdateType:  actorType,
	}

	if err := ctrl.svc.Update(mp); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("payment:list:v2:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Metode pembayaran berhasil diperbarui", nil)
}

func (ctrl *MetodePembayaranController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("payment:list:v2:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Metode pembayaran berhasil dihapus", nil)
}
