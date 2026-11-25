package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupAppSettingRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	svc := service.NewAppSettingService(db)
	ctrl := controller.NewAppSettingController(svc)
	rg.GET("/app-settings", ctrl.GetSettings)
}

func SetupAdminAppSettingRoutes(adminGroup *gin.RouterGroup, db *gorm.DB) {
	svc := service.NewAppSettingService(db)
	ctrl := adminCtrl.NewAdminAppSettingController(svc)
	settings := adminGroup.Group("/app-settings")
	settings.Use(middleware.AdminPermission("settings", "read"))
	{
		settings.GET("", ctrl.GetSettings)
		settings.PUT("", middleware.AdminPermission("settings", "update"), ctrl.UpdateSettings)
	}
}
