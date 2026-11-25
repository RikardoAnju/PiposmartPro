package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterReportRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	koinSvc := service.NewKoinService(db)
	pegawaiSvc := service.NewPegawaiService(db)
	addonSvc := service.NewAddonService(db, koinSvc, pegawaiSvc)
	reportSvc := service.NewReportService(db)
	ctrl := controller.NewReportController(reportSvc)

	report := rg.Group("/report", middleware.JWTAuth())
	{
		// Screen 1: Semua Data Transaksi
		report.GET(
			"/transactions",
			middleware.AuthPermission("laporan", "read_transaction"),
			ctrl.GetTransactionReport,
		)

		// Bottom Sheet Ringkasan di Screen 1
		report.GET(
			"/transactions/summary",
			middleware.AuthPermission("laporan", "read_transaction"),
			ctrl.GetOperationalSummary,
		)

		// Screen 2: Transaksi Per Layanan
		report.GET(
			"/services",
			middleware.AuthPermission("laporan", "read_service_summary"),
			middleware.RequireAddon("REPORT_SERVICE_SUMMARY", addonSvc),
			ctrl.GetServiceReport,
		)
	}
}
