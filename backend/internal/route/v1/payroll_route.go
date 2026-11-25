package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterPayrollRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewPayrollController(service.NewPayrollService(db))
	addonSvc := service.NewAddonService(db, service.NewKoinService(db), service.NewPegawaiService(db))

	payroll := rg.Group("/payroll", middleware.JWTAuth(), middleware.RequireAddon("PAYROLL", addonSvc))
	{
		payroll.GET("/pending-employees", middleware.AuthPermission("pegawai", "read"), ctrl.GetPendingEmployees)
		payroll.GET("/configs", middleware.AuthPermission("pegawai", "read"), ctrl.GetConfigs)
		payroll.POST("/configs/:pegawai_id", middleware.AuthPermission("pegawai", "update"), ctrl.SaveSalaryConfig)
		payroll.GET("/active", middleware.AuthPermission("pegawai", "read"), ctrl.GetActive)
		payroll.GET("/history", middleware.AuthPermission("pegawai", "read"), ctrl.GetHistory)
		payroll.GET("/items/:id", middleware.AuthPermission("pegawai", "read"), ctrl.GetItemDetail)
		payroll.PUT("/items/:id", middleware.AuthPermission("pegawai", "update"), ctrl.UpdateItemComponents)
		payroll.DELETE("/items/:id", middleware.AuthPermission("pegawai", "update"), ctrl.DeleteItem)
		payroll.POST("/items/:id/paid", middleware.AuthPermission("pegawai", "update"), ctrl.MarkPaid)
		payroll.POST("/items/bulk-paid", middleware.AuthPermission("pegawai", "update"), ctrl.MarkBulkPaid)
	}
}
