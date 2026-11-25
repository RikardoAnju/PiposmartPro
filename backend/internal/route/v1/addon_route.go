package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterAddonRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	// 1. Inisialisasi Dependensi
	koinSvc := service.NewKoinService(db)
	pegawaiSvc := service.NewPegawaiService(db)

	addonSvc := service.NewAddonService(db, koinSvc, pegawaiSvc)
	ctrl := controller.NewAddonController(addonSvc)

	// --- GROUP KHUSUS TENANT / OWNER (Mobile App) ---
	// Endpoint untuk belanja fitur, aktivasi outlet, dan cek status langganan
	addon := rg.Group("/addons", middleware.JWTAuth())
	{
		// Info & History
		addon.GET("/pending-orders", ctrl.GetPendingOrders)
		addon.GET("/history-all", ctrl.GetAllHistory)
		addon.GET("/history/:id", ctrl.GetDetail)
		addon.GET("/active", ctrl.GetActiveFitur)
		addon.GET("/katalog", ctrl.GetKatalog)

		// Flow Aktivasi PRO (Permanen)
		addon.POST("/activate-outlet", ctrl.ActivateOutlet)

		// Flow Pembelian Fitur (Add-on)
		addon.POST("/buy-koin", ctrl.PurchaseWithKoin) // Instant potong koin
		addon.POST("/request", ctrl.RequestActivation) // Order via Midtrans/Transfer

		// Voucher & Promo
		addon.GET("/validate-voucher", ctrl.ValidateVoucher)

		// Upload & Management
		addon.POST("/upload-bukti", ctrl.UploadBukti)
		addon.POST("/cancel-order", ctrl.CancelOrder) // User cancel (Status -> CANCELED)
	}

	// --- GROUP KHUSUS ADMIN PANEL ---
	// Digunakan admin internal untuk validasi pembayaran manual
	adminAddon := rg.Group("/admin/addons", middleware.JWTAuth(), middleware.AdminOnly())
	{
		// List semua transaksi untuk Admin
		adminAddon.GET("", ctrl.AdminListTransactions)
		adminAddon.GET("/:id", ctrl.AdminGetDetail)

		// Approve transaksi (Ubah PENDING/PENDING_VALIDATION -> SUCCESS)
		adminAddon.PATCH("/approve", ctrl.AdminApprove)

		// ✅ Admin Reject/Cancel (Status -> FAILED agar user bisa re-upload)
		// URL: /v1/admin/addons/cancel?id=HA-XXXXX
		adminAddon.PATCH("/cancel", ctrl.AdminCancel)
	}
}