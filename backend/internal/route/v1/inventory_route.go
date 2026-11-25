package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterInventoryRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewInventoryController(service.NewInventoryService(db))
	group := rg.Group("/inventory", middleware.JWTAuth())
	group.GET("", ctrl.Overview)
	group.GET("/items", ctrl.ListItems)
	group.POST("/items", ctrl.CreateItem)
	group.POST("/items/:id/stock", ctrl.AdjustStock)
	group.GET("/categories", ctrl.ListCategories)
	group.POST("/categories", ctrl.CreateCategory)
	group.PUT("/categories/:id", ctrl.UpdateCategory)
	group.DELETE("/categories/:id", ctrl.DeleteCategory)
	group.GET("/settings", ctrl.GetSetting)
	group.PUT("/settings", ctrl.SaveSetting)
}
