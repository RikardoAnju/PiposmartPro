package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	adminService "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

func (ctrl *AdminNotifController) ListTemplates(c *gin.Context) {
	rows, err := ctrl.svc.ListTemplates(c.Query("active_only") == "true")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": rows})
}

func (ctrl *AdminNotifController) LifecycleOverview(c *gin.Context) {
	data, err := ctrl.svc.GetLifecycleOverview()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": data})
}

func (ctrl *AdminNotifController) UpdateLifecycleRule(c *gin.Context) {
	var rule model.LifecycleAutomationRule
	if err := c.ShouldBindJSON(&rule); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Konfigurasi rule tidak valid"})
		return
	}
	saved, err := ctrl.svc.UpdateLifecycleRule(c.Param("key"), rule, c.GetString("admin_email"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": saved})
}

func (ctrl *AdminNotifController) CreateTemplate(c *gin.Context) {
	var template model.NotifTemplate
	if c.ShouldBindJSON(&template) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Input template tidak valid"})
		return
	}
	template.CreatedBy = c.GetString("admin_email")
	template.UpdatedBy = template.CreatedBy
	saved, err := ctrl.svc.CreateTemplate(template)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"status": true, "data": saved})
}

func (ctrl *AdminNotifController) UpdateTemplate(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "ID template tidak valid"})
		return
	}
	var template model.NotifTemplate
	if c.ShouldBindJSON(&template) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Input template tidak valid"})
		return
	}
	template.UpdatedBy = c.GetString("admin_email")
	saved, err := ctrl.svc.UpdateTemplate(uint(id), template)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": saved})
}

func (ctrl *AdminNotifController) DeleteTemplate(c *gin.Context) {
	id, err := strconv.ParseUint(c.Param("id"), 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "ID template tidak valid"})
		return
	}
	if err := ctrl.svc.DeleteTemplate(uint(id)); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "message": "Template dihapus"})
}

type AdminNotifController struct {
	svc adminService.AdminNotifService
}

func NewAdminNotificationController(svc adminService.AdminNotifService) *AdminNotifController {
	return &AdminNotifController{svc}
}

func (ctrl *AdminNotifController) SendBroadcast(c *gin.Context) {
	var req struct {
		Judul          string   `json:"judul" binding:"required"`
		Pesan          string   `json:"pesan" binding:"required"`
		Kategori       string   `json:"kategori" binding:"required"`
		Outlets        []string `json:"outlets" binding:"required"`
		Target         string   `json:"target"`
		EntityID       string   `json:"entity_id"`
		ParentID       string   `json:"parent_id"`
		FallbackTarget string   `json:"fallback_target"`
		CTALabel       string   `json:"cta_label"`
	}

	var imageURL *string
	if strings.HasPrefix(c.GetHeader("Content-Type"), "multipart/form-data") {
		req.Judul = c.PostForm("judul")
		req.Pesan = c.PostForm("pesan")
		req.Kategori = c.PostForm("kategori")
		req.Outlets = c.PostFormArray("outlets")
		req.Target = c.PostForm("target")
		req.EntityID = c.PostForm("entity_id")
		req.ParentID = c.PostForm("parent_id")
		req.FallbackTarget = c.PostForm("fallback_target")
		req.CTALabel = c.PostForm("cta_label")

		file, err := c.FormFile("image")
		if err == nil && file != nil {
			contentType := file.Header.Get("Content-Type")
			if !strings.HasPrefix(contentType, "image/") {
				c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "File harus berupa gambar"})
				return
			}
			if file.Size > 5<<20 {
				c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Ukuran gambar maksimal 5MB"})
				return
			}

			path, err := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
				SubFolder: "notifications",
				Prefix:    "notif",
				MaxWidth:  1280,
				Quality:   78,
			})
			if err != nil {
				c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
				return
			}
			imageURL = &path
		}
	} else if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Input tidak valid"})
		return
	}

	if req.Judul == "" || req.Pesan == "" || req.Kategori == "" || len(req.Outlets) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Input tidak valid"})
		return
	}

	adminEmail, _ := c.Get("admin_email")
	if adminEmail == nil {
		adminEmail = "system_admin"
	}

	err := ctrl.svc.Broadcast(
		req.Judul,
		req.Pesan,
		req.Kategori,
		req.Outlets,
		imageURL,
		adminService.BroadcastNavigation{
			Target: req.Target, EntityID: req.EntityID, ParentID: req.ParentID,
			FallbackTarget: req.FallbackTarget, CTALabel: req.CTALabel,
		},
		adminEmail.(string),
	)
	if err != nil {
		if errors.Is(err, adminService.ErrBroadcastTargetNotFound) ||
			errors.Is(err, adminService.ErrInvalidNotificationTarget) ||
			errors.Is(err, adminService.ErrInvalidNotificationEntity) {
			c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": true, "message": "Broadcast berhasil dipublikasikan"})
}

func (ctrl *AdminNotifController) GetLogs(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "25"))
	logs, err := ctrl.svc.GetHistory(adminService.NotificationHistoryFilter{
		Page: page, Limit: limit, Search: c.Query("search"), Category: c.Query("category"),
		OutletID: c.Query("outlet_id"), Date: c.Query("date"), Source: c.Query("source"),
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"status": true,
		"data":   logs,
	})
}

func (ctrl *AdminNotifController) GetOutletOptions(c *gin.Context) {
	rows, err := ctrl.svc.GetNotificationOutletOptions()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": rows})
}

func (ctrl *AdminNotifController) GetDetail(c *gin.Context) {
	id := c.Param("id")
	res, err := ctrl.svc.GetDetailReceivers(id)
	if err != nil {
		c.JSON(500, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(200, gin.H{"status": true, "data": res})
}

func (ctrl *AdminNotifController) GetEntityOptions(c *gin.Context) {
	rows, err := ctrl.svc.GetEntityOptions(c.Query("target"), c.Query("outlet_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": rows})
}

func (ctrl *AdminNotifController) GetPushTokens(c *gin.Context) {
	id := c.Param("id")
	res, err := ctrl.svc.GetDetailPushTokens(id)
	if err != nil {
		c.JSON(500, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(200, gin.H{"status": true, "data": res})
}

func (ctrl *AdminNotifController) DeactivatePushToken(c *gin.Context) {
	var req struct {
		OutletID string `json:"outlet_id" binding:"required"`
		Token    string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "Input tidak valid"})
		return
	}

	if err := ctrl.svc.DeactivatePushToken(req.OutletID, req.Token); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": true, "message": "Token push dinonaktifkan"})
}

func (ctrl *AdminNotifController) DeleteBroadcast(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, gin.H{"status": false, "message": "ID tidak valid"})
		return
	}

	err := ctrl.svc.DeleteBroadcast(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": true, "message": "Broadcast berhasil dihapus"})
}
