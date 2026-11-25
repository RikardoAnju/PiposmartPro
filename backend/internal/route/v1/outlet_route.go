package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"log"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupOutletRoutes(r *gin.RouterGroup, db *gorm.DB) {
	// Inisialisasi dependensi seeder
	roleSvc := service.NewRoleService(db)
	parfumSvc := service.NewParfumService(db)
	layananSvc := service.NewLayananService(db)
	katExpSvc := service.NewKategoriPengeluaranService(db)
	paySvc := service.NewMetodePembayaranService(db)
	if err := paySvc.EnsureDefaultsForExistingOutlets(); err != nil {
		log.Printf("gagal memastikan metode pembayaran default: %v", err)
	}
	itemSvc := service.NewItemService(db)

	// Suntikkan ke OutletService
	svc := service.NewOutletService(db, roleSvc, parfumSvc, layananSvc, katExpSvc, paySvc, itemSvc)
	ctrl := controller.NewOutletController(svc)

	outlet := r.Group("/outlet", middleware.JWTAuth())
	{
		outlet.GET("/list", ctrl.List)
		outlet.POST("/create", ctrl.Create)
		outlet.POST("/switch", ctrl.Switch) // Endpoint Switch Outlet

		outlet.GET("/profile", ctrl.GetProfile)
		outlet.PUT("/profile", ctrl.UpdateProfile)
	}
}
