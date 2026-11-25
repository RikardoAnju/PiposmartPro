package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterRoleRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewRoleController(service.NewRoleService(db))

	role := rg.Group("/roles",
		middleware.JWTAuth(),
	)
	{
		role.GET("", ctrl.List)

		role.POST("", middleware.AuthPermission("pegawai", "create"), ctrl.Create)
		role.PUT("/:id", middleware.AuthPermission("pegawai", "update"), ctrl.Update)
		role.DELETE("/:id", middleware.AuthPermission("pegawai", "delete"), ctrl.Delete)
	}
}
