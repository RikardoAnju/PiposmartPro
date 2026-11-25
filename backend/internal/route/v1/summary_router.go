// internal/router/v1/summary_router.go
package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupSummaryRoutes(r *gin.RouterGroup, db *gorm.DB) {
	// Inisialisasi Service dan Controller khusus Summary
	summarySvc := service.NewSummaryService(db)
	summaryCtrl := controller.NewSummaryController(summarySvc)

	// Proteksi dengan JWT dan Cek Langganan sesuai pola AyoCuci
	// Route ini mengarah ke /api/v1/summary/aggregated yang dipanggil oleh Flutter
	summary := r.Group("/summary", middleware.JWTAuth())
	{
		summary.GET("/aggregated", summaryCtrl.GetAggregatedSummary)
	}
}