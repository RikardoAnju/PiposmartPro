package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterCustomerReportRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	// Inisialisasi Service & Controller
	koinSvc := service.NewKoinService(db)
	pegawaiSvc := service.NewPegawaiService(db)
	addonSvc := service.NewAddonService(db, koinSvc, pegawaiSvc)
	customerReportSvc := service.NewCustomerReportService(db)
	ctrl := controller.NewCustomerReportController(customerReportSvc)

	// Group route khusus laporan pelanggan dengan proteksi JWT
	report := rg.Group("/report-customer", middleware.JWTAuth())
	{
		// 1. Ringkasan Pelanggan (Directory + Search)
		// Digunakan untuk screen daftar pelanggan utama
		report.GET(
			"/summary",
			middleware.AuthPermission("laporan", "read_customer"),
			ctrl.GetCustomerSummary,
		)

		// 2. Analitik Pertumbuhan (Tab Pertumbuhan)
		// Balikin data Total, Gender Breakdown, dan Tabel Harian
		report.GET(
			"/growth",
			middleware.AuthPermission("laporan", "read_customer"),
			middleware.RequireAddon("REPORT_CUSTOMER_GROWTH", addonSvc),
			ctrl.GetCustomerGrowth,
		)

		// 3. Top Pelanggan (Tab Top Pelanggan)
		// Balikin data Podium (Rank 1-3) dan Others (Rank 4++)
		report.GET(
			"/top",
			middleware.AuthPermission("laporan", "read_customer"),
			ctrl.GetTopCustomers,
		)
	}
}
