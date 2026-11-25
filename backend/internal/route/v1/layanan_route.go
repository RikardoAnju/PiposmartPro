package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterLayananRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewLayananController(service.NewLayananService(db))
	
	// 1. JWTAuth: Memvalidasi token dan mengambil outlet_id.
	// CheckSubscription dihapus agar akses tidak terikat status langganan.
	layanan := rg.Group("/layanan", middleware.JWTAuth())
	{
		// List layanan dapat dilihat oleh semua staff yang login.
		layanan.GET("", ctrl.GetByOutlet)

		// Layanan tersering se-outlet (fitur "Tambah Cepat" di app).
		layanan.GET("/popular", ctrl.GetPopular)

		// Create, Update, dan Delete tetap diproteksi dengan AuthPermission (RBAC).
		layanan.POST("", middleware.AuthPermission("layanan", "create"), ctrl.Create)
		layanan.PUT("/:id", middleware.AuthPermission("layanan", "update"), ctrl.Update)
		layanan.DELETE("/:id", middleware.AuthPermission("layanan", "delete"), ctrl.Delete)
	}
}