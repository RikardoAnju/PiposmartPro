package controller

import (
	"net/http"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/gin-gonic/gin"
)

type AppSettingController struct {
	settingService service.AppSettingService
}

func NewAppSettingController(settingService service.AppSettingService) *AppSettingController {
	return &AppSettingController{settingService: settingService}
}

func (c *AppSettingController) GetSettings(ctx *gin.Context) {
	settings, err := c.settingService.GetSettings()
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}
	ctx.JSON(http.StatusOK, gin.H{
		"status": true,
		"message": "Success fetching app settings",
		"data":   settings,
	})
}
