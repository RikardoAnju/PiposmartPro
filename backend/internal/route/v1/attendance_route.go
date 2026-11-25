package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func RegisterAttendanceRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	ctrl := controller.NewAttendanceController(service.NewAttendanceService(db))
	addonSvc := service.NewAddonService(db, service.NewKoinService(db), service.NewPegawaiService(db))
	group := rg.Group("/attendance", middleware.JWTAuth(), middleware.RequireAddon("ATTENDANCE", addonSvc))
	group.GET("/configuration", middleware.AuthPermission("pegawai", "read"), ctrl.GetConfiguration)
	group.PUT("/configuration", middleware.AuthPermission("pegawai", "update"), ctrl.SaveConfiguration)
	group.POST("/check-in", ctrl.CheckIn)
	group.POST("/check-out", ctrl.CheckOut)
	group.POST("/leave-requests", ctrl.RequestLeave)
	group.POST("/overtime-requests", ctrl.RequestOvertime)
	group.GET("/overtime-requests", ctrl.OvertimeRequests)
	group.PATCH("/overtime-requests/:id", middleware.AuthPermission("pegawai", "update"), ctrl.DecideOvertime)
	group.GET("/leave-requests", ctrl.LeaveRequests)
	group.PATCH("/leave-requests/:id", middleware.AuthPermission("pegawai", "update"), ctrl.UpdateLeaveStatus)
	group.GET("/records", ctrl.Records)
	group.GET("/holidays", ctrl.Holidays)
	group.POST("/holidays", ctrl.AddHoliday)
	group.DELETE("/holidays/:id", ctrl.DeleteHoliday)
}
