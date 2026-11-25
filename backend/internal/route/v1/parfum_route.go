package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterParfumRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewParfumController(service.NewParfumService(db))
	
	// 1. JWTAuth: Memvalidasi token dan mengambil outlet_id.
	// 2. CheckSubscription: Memastikan masa aktif langganan dan mengambil package_id terbaru.
	parfum := rg.Group("/parfums", middleware.JWTAuth())
	{
		// List parfum dapat diakses oleh semua staff (untuk keperluan memilih parfum saat input transaksi).
		parfum.GET("", ctrl.List)

		// Create, Update, dan Delete diproteksi dengan AuthPermission.
		// Memastikan hanya Role dengan izin spesifik pada modul "parfum" yang bisa mengubah data.
		parfum.POST("", middleware.AuthPermission("parfum", "create"), ctrl.Create)
		parfum.PUT("/:id", middleware.AuthPermission("parfum", "update"), ctrl.Update)
		parfum.DELETE("/:id", middleware.AuthPermission("parfum", "delete"), ctrl.Delete)
	}
}