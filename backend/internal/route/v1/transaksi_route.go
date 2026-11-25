package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterTransaksiRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	// Inisialisasi Service & Controller khusus Transaksi
	trxSvc := service.NewTransaksiService(db, service.NewKoinService(db))
	notaSvc := service.NewNotaService(db)
	addonSvc := service.NewAddonService(db, service.NewKoinService(db), service.NewPegawaiService(db))
	ctrl := controller.NewTransaksiController(trxSvc, notaSvc)

	// Grouping dengan Middleware Stack
	trx := rg.Group("/transactions",
		middleware.JWTAuth(),
	)
	{
		// CRUD & Finance
		trx.POST("", ctrl.Create)
		trx.GET("", ctrl.GetAll)
		trx.GET("/performance", middleware.RequireAddon("KARYAWAN_PERFORMANCE", addonSvc), ctrl.GetAll)
		trx.GET("/detail", ctrl.GetByID)
		trx.POST("/payment", ctrl.ProcessPayment)
		trx.POST("/qris/nobu", controller.NewNobuController(service.NewNobuPaymentService(db)).GenerateQR)
		trx.GET("/qris/nobu", controller.NewNobuController(service.NewNobuPaymentService(db)).QRStatus)
		trx.PUT("/update", ctrl.Update)
		trx.PATCH("/status/update", ctrl.UpdateStatus)
		// Catatan:  bisa ditambahkan jika Service Update tersedia
	}
}
