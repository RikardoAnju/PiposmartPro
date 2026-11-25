package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupContentRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	svc := admin.NewAdminContentService(db)
	ctrl := controller.NewContentController(svc)
	rg.GET("/content", ctrl.List)
}

func SetupAdminContentRoutes(adminGroup *gin.RouterGroup, db *gorm.DB) {
	ctrl := adminCtrl.NewAdminContentController(admin.NewAdminContentService(db))
	content := adminGroup.Group("/content")
	content.Use(middleware.AdminPermission("content", "read"))
	{
		content.GET("", ctrl.GetAll)
		content.GET("/:id", ctrl.GetByID)
		content.POST("", middleware.AdminPermission("content", "create"), ctrl.Create)
		content.PUT("/:id", middleware.AdminPermission("content", "update"), ctrl.Update)
		content.PATCH("/:id/status", middleware.AdminPermission("content", "update"), ctrl.ToggleStatus)
		content.DELETE("/:id", middleware.AdminPermission("content", "delete"), ctrl.Delete)
	}
}
