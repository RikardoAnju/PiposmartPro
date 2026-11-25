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

type ItemController struct {
	svc *service.ItemService
}

func NewItemController(s *service.ItemService) *ItemController {
	return &ItemController{svc: s}
}

func (ctrl *ItemController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	
	// DIUBAH: Langsung ambil sebagai string dari context
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama string `json:"nama" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nama item wajib diisi")
		return
	}

	item := model.Item{
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Status:         1,
		UserUpdate:     actorID, // String ID Pegawai/Owner
		UserUpdateType: actorType,
	}

	data, err := ctrl.svc.Create(item)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("items:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Item berhasil ditambahkan", data)
}

func (ctrl *ItemController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("items:list:%s", outletID.(string))
	var data []model.Item
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar item (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil daftar item")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 24*time.Hour)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar item", data)
}

func (ctrl *ItemController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("items:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Item berhasil dihapus", nil)
}

func (ctrl *ItemController) Update(c *gin.Context) {
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

	err := ctrl.svc.Update(model.Item{
		ID:             id,
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Status:         req.Status,
		UserUpdate:     actorID, // ID Pegawai String tersimpan utuh
		UserUpdateType: actorType,
	})

	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("items:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Item berhasil diperbarui", nil)
}