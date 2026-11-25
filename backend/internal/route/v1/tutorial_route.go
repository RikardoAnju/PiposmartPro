package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupTutorialRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	svc := admin.NewAdminTutorialService(db)
	ctrl := controller.NewTutorialController(svc)
	rg.GET("/tutorials", ctrl.List)
}

func SetupAdminTutorialRoutes(adminGroup *gin.RouterGroup, db *gorm.DB) {
	ctrl := adminCtrl.NewAdminTutorialController(admin.NewAdminTutorialService(db))
	tutorials := adminGroup.Group("/tutorials")
	tutorials.Use(middleware.AdminPermission("tutorials", "read"))
	{
		tutorials.GET("", ctrl.GetAll)
		tutorials.GET("/:id", ctrl.GetByID)
		tutorials.POST("", middleware.AdminPermission("tutorials", "create"), ctrl.Create)
		tutorials.PUT("/:id", middleware.AdminPermission("tutorials", "update"), ctrl.Update)
		tutorials.PATCH("/:id/status", middleware.AdminPermission("tutorials", "update"), ctrl.ToggleStatus)
		tutorials.DELETE("/:id", middleware.AdminPermission("tutorials", "delete"), ctrl.Delete)
	}
}
