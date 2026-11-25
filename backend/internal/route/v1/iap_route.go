package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterIapRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	koinSvc := service.NewKoinService(db)
	pegawaiSvc := service.NewPegawaiService(db)
	addonSvc := service.NewAddonService(db, koinSvc, pegawaiSvc)
	iapSvc := service.NewIapService(db, koinSvc, addonSvc)
	ctrl := controller.NewIapController(iapSvc)

	iap := rg.Group("/iap", middleware.JWTAuth())
	{
		ios := iap.Group("/ios")
		ios.GET("/products", ctrl.GetIosProducts)
		ios.POST("/verify-coin-topup", ctrl.VerifyIosCoinTopup)
		ios.POST("/verify-outlet-pro", ctrl.VerifyIosOutletPro)
	}
}
