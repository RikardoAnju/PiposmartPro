package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterPengeluaranRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	kpSvc := service.NewKategoriPengeluaranService(db)
	kpCtrl := controller.NewKategoriPengeluaranController(kpSvc)

	pgSvc := service.NewPengeluaranService(db)
	pgCtrl := controller.NewPengeluaranController(pgSvc)

	// 1. JWTAuth: Memvalidasi sesi user.
	// 2. CheckSubscription: Memastikan langganan aktif.
	// 3. RequireFeature: Memastikan paket memiliki fitur 'EXPENSE_TRACK'.
	exp := rg.Group("/expenses",
		middleware.JWTAuth(),
	)
	{
		// --- Kategori Pengeluaran ---
		cat := exp.Group("/categories")
		{
			cat.GET("", middleware.AuthAnyPermission("pengeluaran", "read", "create"), kpCtrl.List)

			// Manajemen kategori biasanya hanya untuk Manager/Owner
			cat.POST("", middleware.AuthPermission("pengeluaran", "create"), kpCtrl.Create)
			cat.PUT("/:id", middleware.AuthPermission("pengeluaran", "update"), kpCtrl.Update)
			cat.DELETE("/:id", middleware.AuthPermission("pengeluaran", "delete"), kpCtrl.Delete)
		}

		// --- Transaksi Pengeluaran ---
		exp.GET("", middleware.AuthPermission("pengeluaran", "read"), pgCtrl.List)
		exp.GET("/:id", middleware.AuthPermission("pengeluaran", "read"), pgCtrl.Detail)

		// Gunakan AuthPermission untuk membatasi siapa yang boleh mencatat pengeluaran uang outlet
		exp.POST("", middleware.AuthPermission("pengeluaran", "create"), pgCtrl.Create)
		exp.PUT("/:id", middleware.AuthPermission("pengeluaran", "update"), pgCtrl.Update)
		exp.DELETE("/:id", middleware.AuthPermission("pengeluaran", "delete"), pgCtrl.Delete)
	}
}
