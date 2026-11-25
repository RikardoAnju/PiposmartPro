package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterFinanceRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	// 1. Inisialisasi Service & Dependency
	// Kita butuh AddonService untuk dikirim ke middleware pengecekan
	koinSvc := service.NewKoinService(db)
	pegawaiSvc := service.NewPegawaiService(db)
	addonSvc := service.NewAddonService(db, koinSvc, pegawaiSvc)

	financeSvc := service.NewFinanceService(db)
	ctrl := controller.NewFinanceController(financeSvc)
	depositReportCtrl := controller.NewDepositReportController(service.NewDepositReportService(db))

	// 2. Group route finance dengan proteksi JWT
	finance := rg.Group("/finance", middleware.JWTAuth())
	{
		// --- AKSES BASE (Gratis/Trial) ---

		// Dashboard & Analytics
		finance.GET(
			"/dashboard/summary",
			middleware.AuthAnyPermission(
				"laporan",
				"read_daily_summary",
				"read_omset",
				"read_pengeluaran",
				"read_pendapatan",
				"read_profit_loss",
				"read_transaction",
			),
			ctrl.GetDashboardSummary,
		)
		finance.GET(
			"/dashboard/chart",
			middleware.AuthPermission("laporan", "read_omset"),
			middleware.AuthPermission("laporan", "read_pengeluaran"),
			middleware.AuthPermission("laporan", "read_pendapatan"),
			middleware.AuthPermission("laporan", "read_profit_loss"),
			ctrl.GetDashboardChart,
		)

		// Laporan Omset (Nilai Nota)
		finance.GET(
			"/report-omset",
			middleware.AuthPermission("laporan", "read_omset"),
			ctrl.GetOmsetReport,
		)
		finance.GET(
			"/report-omset/detail",
			middleware.AuthPermission("laporan", "read_omset"),
			ctrl.GetOmsetDetail,
		)

		// Laporan Pendapatan (Uang Masuk)
		finance.GET(
			"/report-income",
			middleware.AuthPermission("laporan", "read_pendapatan"),
			ctrl.GetIncomeReport,
		)
		finance.GET(
			"/report-income/methods",
			middleware.AuthPermission("laporan", "read_pendapatan"),
			ctrl.GetIncomeMethods,
		)
		finance.GET(
			"/report-income/detail",
			middleware.AuthAnyPermission("laporan", "read_pendapatan", "read_profit_loss"),
			ctrl.GetIncomeDetail,
		)
		finance.GET(
			"/report-deposit",
			middleware.AuthPermission("laporan", "read_pendapatan"),
			depositReportCtrl.GetReport,
		)
		finance.GET(
			"/report-deposit/analytics",
			middleware.AuthPermission("laporan", "read_pendapatan"),
			depositReportCtrl.GetAnalytics,
		)

		// Laporan Pengeluaran (Analisa Biaya)
		finance.GET(
			"/report-expense",
			middleware.AuthPermission("laporan", "read_pengeluaran"),
			ctrl.GetExpenseAnalisa,
		)
		finance.GET(
			"/report-expense/category",
			middleware.AuthPermission("laporan", "read_pengeluaran"),
			ctrl.GetExpenseByCategory,
		)
		finance.GET(
			"/report-expense/detail",
			middleware.AuthPermission("laporan", "read_pengeluaran"),
			ctrl.GetExpenseDetail,
		)

		// --- AKSES PRO (Eceran - Membutuhkan Add-on) ---

		// 5. LAPORAN PIUTANG PELANGGAN
		finance.GET(
			"/report-piutang",
			middleware.AuthPermission("laporan", "read_debt"),
			middleware.RequireAddon("REPORT_DEBT", addonSvc),
			ctrl.GetPiutangReport,
		)

		// 6. LAPORAN LABA / RUGI (P&L Statement)
		finance.GET(
			"/report-profit-loss",
			middleware.AuthPermission("laporan", "read_profit_loss"),
			middleware.RequireAddon("REPORT_PROFIT_LOSS", addonSvc),
			ctrl.GetProfitLossReport,
		)

		// Detail Bottom Sheet untuk Laba/Rugi (Ikut proteksi Laba Rugi)
		finance.GET(
			"/report-profit-loss/detail-metode",
			middleware.AuthPermission("laporan", "read_profit_loss"),
			middleware.RequireAddon("REPORT_PROFIT_LOSS", addonSvc),
			ctrl.GetProfitLossDetailMetode,
		)

		finance.GET(
			"/report-profit-loss/detail-expense",
			middleware.AuthPermission("laporan", "read_profit_loss"),
			middleware.RequireAddon("REPORT_PROFIT_LOSS", addonSvc),
			ctrl.GetProfitLossDetailPengeluaran,
		)
	}
}
