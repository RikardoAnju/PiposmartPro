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

func (ctrl *NotifController) RecordEvent(c *gin.Context) {
	var req struct {
		MasterID   string `json:"master_id" binding:"required"`
		EventType  string `json:"event_type" binding:"required"`
		Target     string `json:"target"`
		Reason     string `json:"reason"`
		Platform   string `json:"platform"`
		AppVersion string `json:"app_version"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input event tidak valid")
		return
	}
	event := model.NotifEvent{
		MasterID: req.MasterID, OutletID: c.GetString("outlet_id"),
		ActorID: c.GetString("actor_id"), ActorType: c.GetString("actor_type"),
		EventType: req.EventType, Target: req.Target, Reason: req.Reason,
		Platform: req.Platform, AppVersion: req.AppVersion,
	}
	if err := ctrl.svc.RecordEvent(event); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Event notifikasi dicatat", nil)
}

type NotifController struct {
	svc *service.NotifService
}

func NewNotifController(s *service.NotifService) *NotifController {
	return &NotifController{svc: s}
}

func (ctrl *NotifController) GetMyNotifications(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("notif:list:%s:%s:%s", outletID.(string), c.GetString("actor_type"), c.GetString("actor_id"))
	var data interface{}
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil notifikasi (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.List(outletID.(string), c.GetString("actor_id"), c.GetString("actor_type"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat notifikasi")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 1*time.Minute)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil notifikasi", data)
}

func (ctrl *NotifController) ReadNotification(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	idParam := c.Param("id")

	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID tidak valid")
		return
	}

	if err := ctrl.svc.MarkAsRead(uint(id), outletID.(string), c.GetString("actor_id"), c.GetString("actor_type")); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("notif:list:%s", outletID.(string)), fmt.Sprintf("notif:unread:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Notifikasi telah dibaca", nil)
}

func (ctrl *NotifController) ReadSelected(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	var req struct {
		IDs []uint `json:"ids" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID tidak valid")
		return
	}

	if err := ctrl.svc.MarkManyAsRead(req.IDs, outletID.(string), c.GetString("actor_id"), c.GetString("actor_type")); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("notif:list:%s", outletID.(string)), fmt.Sprintf("notif:unread:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Notifikasi terpilih telah dibaca", nil)
}

func (ctrl *NotifController) ReadAll(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.MarkAllAsRead(outletID.(string), c.GetString("actor_id"), c.GetString("actor_type")); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menandai semua")
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("notif:list:%s", outletID.(string)), fmt.Sprintf("notif:unread:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Semua notifikasi telah dibaca", nil)
}

func (ctrl *NotifController) DeleteSelected(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	var req struct {
		IDs []uint `json:"ids" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID tidak valid")
		return
	}

	if err := ctrl.svc.DeleteMany(req.IDs, outletID.(string), c.GetString("actor_id"), c.GetString("actor_type")); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghapus notifikasi")
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("notif:list:%s", outletID.(string)), fmt.Sprintf("notif:unread:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Notifikasi terpilih telah dihapus", nil)
}

func (ctrl *NotifController) UnreadCount(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("notif:unread:%s:%s:%s", outletID.(string), c.GetString("actor_type"), c.GetString("actor_id"))
	var count int64
	if database.GetCache(cacheKey, &count) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil (Cached)", gin.H{"unread_count": count})
		return
	}

	// 2. Try DB
	count, err := ctrl.svc.GetUnreadCount(outletID.(string), c.GetString("actor_id"), c.GetString("actor_type"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghitung badge")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, count, 1*time.Minute)

	utils.JSONResponse(c, http.StatusOK, "Berhasil", gin.H{"unread_count": count})
}
