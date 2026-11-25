package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterPegawaiRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewPegawaiController(service.NewPegawaiService(db))

	// 1. JWTAuth: Memvalidasi token dan mengambil outlet_id.
	// CheckSubscription dan RequireFeature dihapus agar akses tidak terikat status langganan/paket.
	pgw := rg.Group("/employees", middleware.JWTAuth())
	{
		pgw.GET("/me", ctrl.Me)
		// Tambah Pegawai: Cek izin spesifik role "create"
		pgw.POST("",
			middleware.AuthPermission("pegawai", "create"),
			ctrl.Create,
		)

		// Lihat Daftar Pegawai: Cek izin spesifik role "read"
		pgw.GET("",
			middleware.AuthPermission("pegawai", "read"),
			ctrl.List,
		)

		// Update Data Pegawai: Cek izin spesifik role "update"
		pgw.PUT("/:id",
			middleware.AuthPermission("pegawai", "update"),
			ctrl.Update,
		)

		// Hapus Pegawai: Cek izin spesifik role "delete"
		pgw.DELETE("/:id",
			middleware.AuthPermission("pegawai", "delete"),
			ctrl.Delete,
		)

		// Paksa logout pegawai: hanya bisa oleh role yang punya akses update
		pgw.POST("/:id/force-logout",
			middleware.AuthPermission("pegawai", "update"),
			ctrl.ForceLogout,
		)
	}
}
