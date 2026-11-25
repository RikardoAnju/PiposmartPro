package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupFeatureRequestRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewFeatureRequestController(service.NewFeatureRequestService(db))
	group := rg.Group("/feature-requests")
	group.Use(middleware.JWTAuth())
	group.GET("", ctrl.List)
	group.GET("/:id", ctrl.Get)
	group.POST("", ctrl.Create)
	group.PUT("/:id", ctrl.Update)
	group.POST("/:id/vote", ctrl.ToggleVote)
	group.POST("/:id/attachments", ctrl.UploadAttachment)
	group.DELETE("/:id/attachments/:attachmentId", ctrl.DeleteAttachment)
}
