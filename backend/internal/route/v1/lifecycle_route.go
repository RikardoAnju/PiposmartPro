package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupLifecycleRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewLifecycleEventController(service.NewLifecycleEventService(db))
	group := rg.Group("/lifecycle", middleware.JWTAuth())
	group.POST("/events", ctrl.Track)
}
