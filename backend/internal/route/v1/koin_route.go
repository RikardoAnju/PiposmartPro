package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func KoinRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	kSvc := service.NewKoinService(db)
	eSvc := adminSvc.NewAdminEconomyService(db)
	bSvc := adminSvc.NewAdminBankService(db)
	pgwSvc := service.NewPegawaiService(db)
	addonSvc := service.NewAddonService(db, kSvc, pgwSvc)

	koinCtrl := controller.NewKoinController(kSvc, eSvc, addonSvc)
	bankCtrl := adminCtrl.NewAdminBankController(bSvc)

	koin := rg.Group("/koin")
	{
		// Public Webhook Midtrans
	

		koin.Use(middleware.JWTAuth())
		{
			// 🚀 Paket & Konfigurasi (Dinamis untuk UI Topup)
			koin.GET("/packages", koinCtrl.GetPackages) // <--- Tambah ini untuk List Paket Koin
			koin.GET("/economy-config", koinCtrl.GetEconomyConfig)
			koin.GET("/bank-accounts", bankCtrl.GetAll)
			koin.GET("/check-voucher", koinCtrl.CheckVoucher)

			// History & Monitoring
			koin.GET("/history", koinCtrl.GetHistory)
			koin.GET("/active-topups", koinCtrl.GetActiveTopups)
			koin.GET("/all-topups", koinCtrl.GetAllTopups)

			// Transaksi & Recovery
			koin.POST("/request-topup", koinCtrl.RequestTopup)
			koin.POST("/upload-bukti", koinCtrl.UploadBuktiTransfer)
			koin.POST("/cancel-topup", koinCtrl.CancelTopup)
			koin.GET("/regenerate-snap/:id", koinCtrl.RegenerateSnapURL)
		}
	}
}