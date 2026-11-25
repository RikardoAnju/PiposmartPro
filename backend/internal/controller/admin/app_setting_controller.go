package admin

import (
	"net/http"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/gin-gonic/gin"
)

type AdminAppSettingController struct {
	settingService service.AppSettingService
}

func NewAdminAppSettingController(settingService service.AppSettingService) *AdminAppSettingController {
	return &AdminAppSettingController{settingService: settingService}
}

func (c *AdminAppSettingController) GetSettings(ctx *gin.Context) {
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

func (c *AdminAppSettingController) UpdateSettings(ctx *gin.Context) {
	var req model.AppSetting
	if err := ctx.ShouldBindJSON(&req); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"status": false, "message": err.Error()})
		return
	}

	settings, err := c.settingService.UpdateSettings(&req)
	if err != nil {
		ctx.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}

	ctx.JSON(http.StatusOK, gin.H{
		"status": true,
		"message": "Success updating app settings",
		"data":   settings,
	})
}
