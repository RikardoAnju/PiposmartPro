package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupDashboardRoutes(r *gin.RouterGroup, db *gorm.DB) {
	summarySvc := service.NewSummaryService(db)
	summaryCtrl := controller.NewSummaryController(summarySvc)

	dash := r.Group("/dashboard", middleware.JWTAuth())
	{
		dash.GET(
			"/summary",
			middleware.AuthAnyPermission(
				"laporan",
				"read_home_summary",
				"read_pendapatan",
				"read_omset",
				"read_pengeluaran",
				"read_transaction",
			),
			summaryCtrl.GetHomeSummary,
		)
	}
}
