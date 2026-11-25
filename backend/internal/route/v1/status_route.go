package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func 	RegisterStatusRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	// Inisialisasi Service & Controller khusus Monitoring/Status
	statusSvc := service.NewStatusService(db)
	ctrl := controller.NewStatusController(statusSvc)

	// Grouping dengan Middleware Stack (Sama dengan transaksi demi keamanan)
	status := rg.Group("/status",
		middleware.JWTAuth(),
	
	)
	{
		// Monitoring Antrian & Filter Tanggal
		status.GET("/queue", ctrl.GetQueue)
		status.GET("/counts", ctrl.GetQueueCounts)
		status.GET("/search", ctrl.Search)

		// OPTIMASI: 1 Hit API mendapatkan data awal semua tab
		status.GET("/aggregated", ctrl.GetAggregatedQueue)

		// Workflow Status (Satuan & Bulk)
		status.PATCH("/update", ctrl.UpdateStatusBulk) // Menggunakan endpoint bulk untuk efisiensi
	}
}