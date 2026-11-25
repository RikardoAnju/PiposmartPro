package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterPelangganRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewPelangganController(service.NewPelangganService(db))
	depositCtrl := controller.NewCustomerDepositController(service.NewCustomerDepositService(db))

	// 1. JWTAuth: Memvalidasi token dan mengambil outlet_id.
	// 2. CheckSubscription: Memastikan langganan aktif dan mengambil package_id terbaru.
	// 3. RequireFeature: Memastikan paket memiliki fitur 'PELANGGAN_DB' (ftr_id 3 dari seeder).
	pelanggan := rg.Group("/pelanggan",
		middleware.JWTAuth(),
	)
	{
		pelanggan.GET("", middleware.AuthPermission("pelanggan", "read"), ctrl.List)
		pelanggan.GET("/:id", middleware.AuthPermission("pelanggan", "read"), ctrl.GetByID)
		pelanggan.GET("/:id/deposit", middleware.AuthPermission("pelanggan", "read"), depositCtrl.GetBalance)
		pelanggan.GET("/:id/deposit/ledger", middleware.AuthPermission("pelanggan", "read"), depositCtrl.GetLedger)
		pelanggan.GET("/:id/deposit/ledger/:entryId", middleware.AuthPermission("pelanggan", "read"), depositCtrl.GetLedgerEntry)
		pelanggan.POST("/:id/deposit/topup", middleware.AuthPermission("pelanggan", "update"), depositCtrl.TopUp)
		pelanggan.POST("/:id/deposit/topup/:topupId/adjust", middleware.AuthPermission("pelanggan", "update"), depositCtrl.AdjustTopUp)
		pelanggan.GET("/:id/deposit/topup/:topupId/adjustment-state", middleware.AuthPermission("pelanggan", "read"), depositCtrl.GetAdjustmentState)
		pelanggan.POST("", middleware.AuthPermission("pelanggan", "create"), ctrl.Create)
		pelanggan.POST("/import", middleware.AuthPermission("pelanggan", "create"), ctrl.BulkImport)
		pelanggan.POST("/bulk-delete", middleware.AuthPermission("pelanggan", "delete"), ctrl.BulkDelete)

		// Fitur sensitif (Edit/Hapus) bisa diproteksi lebih lanjut dengan AuthPermission
		pelanggan.PUT("/:id", middleware.AuthPermission("pelanggan", "update"), ctrl.Update)
		pelanggan.DELETE("/:id", middleware.AuthPermission("pelanggan", "delete"), ctrl.Delete)
	}
}
