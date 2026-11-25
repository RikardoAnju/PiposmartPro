package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type StatusController struct {
	svc *service.StatusService
}

func NewStatusController(s *service.StatusService) *StatusController {
	return &StatusController{svc: s}
}

func (ctrl *StatusController) GetQueue(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	status := c.DefaultQuery("status", "Antrian")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	startDate := c.Query("start")
	endDate := c.Query("end")
	sort := c.Query("order")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("status:list:%s:%s:%d:%s:%s:%s", outletID.(string), status, page, startDate, endDate, sort)
	var cachedRes interface{}
	if database.GetCache(cacheKey, &cachedRes) {
		utils.JSONResponse(c, http.StatusOK, "Success (Cached)", cachedRes)
		return
	}

	// 2. Try DB
	res, err := ctrl.svc.GetQueueByStatusPaged(outletID.(string), status, page, limit, startDate, endDate, sort)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat data")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, res, 5*time.Minute)

	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *StatusController) GetQueueCounts(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	startDate := c.Query("start")
	endDate := c.Query("end")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("status:counts:%s:%s:%s", outletID.(string), startDate, endDate)
	var cachedCounts interface{}
	if database.GetCache(cacheKey, &cachedCounts) {
		utils.JSONResponse(c, http.StatusOK, "Success (Cached)", cachedCounts)
		return
	}

	// 2. Try DB
	counts, err := ctrl.svc.GetQueueCount(outletID.(string), startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghitung")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, counts, 5*time.Minute)

	utils.JSONResponse(c, http.StatusOK, "Success", counts)
}

func (ctrl *StatusController) GetAggregatedQueue(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	startDate := c.Query("start")
	endDate := c.Query("end")
	sort := c.Query("order")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("status:aggregated:%s:%s:%s:%s", outletID.(string), startDate, endDate, sort)
	var cachedRes interface{}
	if database.GetCache(cacheKey, &cachedRes) {
		utils.JSONResponse(c, http.StatusOK, "Success (Cached)", cachedRes)
		return
	}

	// 2. Try DB
	res, err := ctrl.svc.GetFullQueueAggregated(outletID.(string), startDate, endDate, sort)
	if err != nil {
		utils.ErrorResponse(c, 500, "Gagal memuat data agregat")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, res, 5*time.Minute)

	utils.JSONResponse(c, 200, "Success", res)
}

func (ctrl *StatusController) UpdateStatusBulk(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		IDs    []string `json:"ids" binding:"required"`
		Status string   `json:"status" binding:"required"`
		Alasan string   `json:"alasan"` // ← opsional, diisi saat Batal
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, 400, "Data tidak valid")
		return
	}

	if err := ctrl.svc.UpdateStatusBulk(req.IDs, outletID.(string), req.Status, actorID, actorType, req.Alasan); err != nil {
		utils.ErrorResponse(c, 500, err.Error())
		return
	}

	// Invalidate Cache (Hapus data agregat & dashboard agar terhitung ulang)
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:summary:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:chart:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:profit_loss:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:expense:analisa:%s:*", outletID.(string)))

	database.InvalidateCache(
		fmt.Sprintf("summary:dashboard:%s", outletID.(string)),
	)
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID.(string)))

	utils.JSONResponse(c, 200, "Status pesanan berhasil diperbarui", nil)
}

func (ctrl *StatusController) Search(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	q := c.Query("q")

	if q == "" {
		utils.JSONResponse(c, 200, "Success", []model.QueueDTO{})
		return
	}

	res, err := ctrl.svc.SearchQueue(outletID.(string), q)
	if err != nil {
		utils.ErrorResponse(c, 500, "Gagal mencari")
		return
	}
	utils.JSONResponse(c, 200, "Success", res)
}
