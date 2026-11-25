package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupLegalDocumentRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	svc := adminSvc.NewAdminLegalDocumentService(db)
	ctrl := controller.NewLegalDocumentController(svc)
	rg.GET("/legal-documents/:type", ctrl.GetByType)
}

func SetupAdminLegalDocumentRoutes(adminGroup *gin.RouterGroup, db *gorm.DB) {
	ctrl := adminCtrl.NewAdminLegalDocumentController(
		adminSvc.NewAdminLegalDocumentService(db),
	)
	legal := adminGroup.Group("/legal-documents")
	legal.Use(middleware.AdminPermission("legal", "read"))
	{
		legal.GET("", ctrl.GetAll)
		legal.GET("/:type", ctrl.GetByType)
		legal.PUT("/:type", middleware.AdminPermission("legal", "update"), ctrl.Upsert)
	}
}
