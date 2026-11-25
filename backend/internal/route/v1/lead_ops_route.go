package v1

import (
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupLeadOpsRoutes(adminGroup *gin.RouterGroup, db *gorm.DB) {
	leadOpsSvc := adminSvc.NewLeadOpsService(db)
	leadOpsCtrl := adminCtrl.NewLeadOpsController(leadOpsSvc)

	leadOps := adminGroup.Group("/lead-ops")
	leadOps.Use(middleware.AdminPermission("lead-ops", "read"))
	{
		leadOps.GET("/summary", leadOpsCtrl.GetSummary)
		leadOps.GET("/me/summary", leadOpsCtrl.GetMySummary)
		leadOps.GET("/me", leadOpsCtrl.GetMe)
		leadOps.GET("/me/leads", leadOpsCtrl.ListMyLeads)
		leadOps.GET("/admins", leadOpsCtrl.ListAdmins)
		leadOps.GET("/leads", leadOpsCtrl.ListLeads)
		leadOps.GET("/leads/:id", leadOpsCtrl.GetLeadDetail)
		leadOps.GET("/assignments", leadOpsCtrl.ListAssignments)
		leadOps.POST("/import", middleware.AdminPermission("lead-ops", "create"), leadOpsCtrl.ImportLeads)
		leadOps.POST("/leads/import", middleware.AdminPermission("lead-ops", "create"), leadOpsCtrl.ImportLeads)
		leadOps.POST("/leads/:id/assign", middleware.AdminPermission("lead-ops", "update"), leadOpsCtrl.AssignLead)
		leadOps.POST("/leads/:id/reassign", middleware.AdminPermission("lead-ops", "update"), leadOpsCtrl.ReassignLead)
		leadOps.POST("/leads/:id/release", middleware.AdminPermission("lead-ops", "update"), leadOpsCtrl.ReleaseLead)
		leadOps.POST("/leads/:id/followups", middleware.AdminPermission("lead-ops", "update"), leadOpsCtrl.AddFollowUp)
		leadOps.POST("/leads/:id/opportunity", middleware.AdminPermission("lead-ops", "update"), leadOpsCtrl.UpsertOpportunity)
		leadOps.POST("/seed-sample", middleware.AdminPermission("lead-ops", "create"), leadOpsCtrl.SeedSampleData)
	}
}
