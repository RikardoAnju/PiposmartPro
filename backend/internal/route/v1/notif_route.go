package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupNotifRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	svc := service.NewNotifService(db)
	ctrl := controller.NewNotifController(svc)

	// Gunakan group tanpa slash otomatis jika ingin bersih
	notif := rg.Group("/notifications")
	notif.Use(middleware.JWTAuth())
	{
		// UBAH "/" MENJADI ""
		notif.GET("", ctrl.GetMyNotifications) // Ini akan jadi /api/v1/notifications

		notif.GET("/unread-count", ctrl.UnreadCount)
		notif.PATCH("/read/:id", ctrl.ReadNotification)
		notif.PATCH("/read-selected", ctrl.ReadSelected)
		notif.PATCH("/read-all", ctrl.ReadAll)
		notif.PATCH("/delete-selected", ctrl.DeleteSelected)
		notif.POST("/events", ctrl.RecordEvent)
	}
}
