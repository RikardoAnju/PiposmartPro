package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterMetodePembayaranRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewMetodePembayaranController(service.NewMetodePembayaranService(db))
	
	// 1. JWTAuth: Memvalidasi identitas dan mengisi outlet_id ke context.
	// 2. CheckSubscription: Memastikan outlet masih dalam masa langganan aktif sebelum mengelola sistem pembayaran.
	mp := rg.Group("/payment-methods", middleware.JWTAuth())
	{
		// List metode pembayaran bisa diakses semua staf (untuk keperluan memilih metode bayar saat transaksi).
		mp.GET("", ctrl.List)

		// Create, Update, dan Delete diproteksi agar hanya Owner/staf berwenang yang bisa mengubah akun keuangan.
		mp.POST("", middleware.AuthPermission("pembayaran", "create"), ctrl.Create)
		mp.PUT("/:id", middleware.AuthPermission("pembayaran", "update"), ctrl.Update)
		mp.DELETE("/:id", middleware.AuthPermission("pembayaran", "delete"), ctrl.Delete)
	}
}