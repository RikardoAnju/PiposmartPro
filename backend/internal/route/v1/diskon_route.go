package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterDiskonRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewDiskonController(service.NewDiskonService(db))

	diskon := rg.Group("/discounts", middleware.JWTAuth())
	{

		diskon.GET("", ctrl.List)

		diskon.POST("", middleware.AuthPermission("diskon", "create"), ctrl.Create)
		diskon.PUT("/:id", middleware.AuthPermission("diskon", "update"), ctrl.Update)
		diskon.DELETE("/:id", middleware.AuthPermission("diskon", "delete"), ctrl.Delete)
	}
}
