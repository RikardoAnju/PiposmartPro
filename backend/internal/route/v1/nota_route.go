package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterNotaRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	svc := service.NewNotaService(db)
	ctrl := controller.NewNotaController(svc)
	koinSvc := service.NewKoinService(db)

	nota := rg.Group("/nota-setting", middleware.JWTAuth())
	{
		nota.GET("", ctrl.GetSetting)
		nota.PUT("", ctrl.UpdateSetting)
		nota.POST("/logo", ctrl.UploadLogo)
		nota.DELETE("/logo", ctrl.DeleteLogo)
	}

	// Public route — tanpa auth
	notaPublicCtrl := controller.NewNotaPublicController(
		service.NewTransaksiService(db, koinSvc),
		service.NewNotaService(db),
	)
	rg.GET("/nota/public/:encodedId", notaPublicCtrl.GetNotaJSON)
}
