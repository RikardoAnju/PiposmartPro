package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterItemRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewItemController(service.NewItemService(db))

	itm := rg.Group("/items", middleware.JWTAuth())
	{
		itm.GET("", ctrl.List)


		itm.POST("", middleware.AuthPermission("item", "create"), ctrl.Create)
		itm.PUT("/:id", middleware.AuthPermission("item", "update"), ctrl.Update)
		itm.DELETE("/:id", middleware.AuthPermission("item", "delete"), ctrl.Delete)
	}
}