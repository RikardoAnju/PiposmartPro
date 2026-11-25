package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupAdminRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	// 1. Initialize Services
	summarySvc := adminSvc.NewAdminSummaryService(db)
	tenantSvc := adminSvc.NewAdminTenantService(db)
	economySvc := adminSvc.NewAdminEconomyService(db)
	userSvc := adminSvc.NewAdminUserService(db)
	customerSvc := adminSvc.NewAdminCustomerService(db)
	notifSvc := adminSvc.NewAdminNotificationService(db)
	otpLogSvc := adminSvc.NewAdminOTPLogService(db)
	vSvc := adminSvc.NewAdminVoucherService(db)
	bankSvc := adminSvc.NewAdminBankService(db)
	kSvc := service.NewKoinService(db)
	roleSvc := service.NewRoleService(db)
	parfumSvc := service.NewParfumService(db)
	layananSvc := service.NewLayananService(db)
	katExpSvc := service.NewKategoriPengeluaranService(db)
	paySvc := service.NewMetodePembayaranService(db)
	itemSvc := service.NewItemService(db)
	pgwSvc := service.NewPegawaiService(db)
	addonSvc := service.NewAddonService(db, kSvc, pgwSvc)
	acctSvc := adminSvc.NewAdminAccountService(db)
	analyticsSvc := adminSvc.NewAdminAnalyticsService(db)
	salesTargetSvc := adminSvc.NewAdminSalesTargetService(db)
	trxAdminSvc := adminSvc.NewAdminTransactionService(db)
	resetDataSvc := adminSvc.NewResetDataService(db, roleSvc, parfumSvc, layananSvc, katExpSvc, paySvc, itemSvc, kSvc)
	accountDeletionSvc := adminSvc.NewAdminAccountDeletionService(db)
	featureRequestSvc := service.NewFeatureRequestService(db)

	// 2. Initialize Controllers
	summaryCtrl := adminCtrl.NewAdminSummaryController(summarySvc)
	tenantCtrl := adminCtrl.NewAdminTenantController(tenantSvc)
	economyCtrl := adminCtrl.NewAdminEconomyController(economySvc, db) // DB diinject untuk Seeding
	userCtrl := adminCtrl.NewAdminUserController(userSvc)
	customerCtrl := adminCtrl.NewAdminCustomerController(customerSvc)
	notifCtrl := adminCtrl.NewAdminNotificationController(notifSvc)
	otpLogCtrl := adminCtrl.NewOTPLogController(otpLogSvc)
	vCtrl := adminCtrl.NewAdminVoucherController(vSvc)
	bankCtrl := adminCtrl.NewAdminBankController(bankSvc)
	koinCtrl := controller.NewKoinController(kSvc, economySvc, addonSvc)
	addonCtrl := controller.NewAddonController(addonSvc)
	acctCtrl := adminCtrl.NewAdminAccountController(acctSvc)
	analyticsCtrl := adminCtrl.NewAdminAnalyticsController(analyticsSvc)
	salesTargetCtrl := adminCtrl.NewAdminSalesTargetController(salesTargetSvc)
	trxAdminCtrl := adminCtrl.NewAdminTransactionController(trxAdminSvc)
	resetDataCtrl := adminCtrl.NewResetDataController(resetDataSvc)
	accountDeletionCtrl := adminCtrl.NewAccountDeletionController(accountDeletionSvc)
	staffAccountCtrl := adminCtrl.NewAdminStaffAccountController(pgwSvc)
	nobuFinanceCtrl := adminCtrl.NewNobuFinanceController(db)
	featureRequestCtrl := adminCtrl.NewAdminFeatureRequestController(featureRequestSvc)

	// AI Analyst (Gemini + tool run_sql read-only). Bila env belum siap,
	// controller mengembalikan 503 dengan pesan jelas (tidak crash boot).
	aiAnalystSvc, aiAnalystErr := service.NewAIAnalystService()
	aiAnalystCtrl := controller.NewAIAnalystController(aiAnalystSvc, aiAnalystErr)

	// --- PRIVATE ENDPOINT (Admin Panel) ---
	adminGroup := rg.Group("/admin")

	// Middleware Proteksi Dasar: wajib admin account
	adminGroup.Use(middleware.JWTAuth(), func(c *gin.Context) {
		actorType, _ := c.Get("actor_type")
		if actorType != "admin" {
			c.JSON(http.StatusForbidden, gin.H{
				"status":  false,
				"message": "Forbidden: Admin access required",
			})
			c.Abort()
			return
		}
		c.Next()
	})

	{
		// 0. AI Analyst (chat data). Gated: butuh izin baca dashboard.
		adminGroup.POST("/ai-analyst/ask", middleware.AdminPermission("dashboard", "read"), aiAnalystCtrl.Ask)
		adminGroup.POST("/ai-analyst/ask-stream", middleware.AdminPermission("dashboard", "read"), aiAnalystCtrl.AskStream)

		// 1. Dashboard & Global Overview
		adminGroup.GET("/summary", middleware.AdminPermission("dashboard", "read"), summaryCtrl.GetDashboard)
		adminGroup.GET("/feature-requests", middleware.AdminPermission("dashboard", "read"), featureRequestCtrl.List)
		adminGroup.PATCH("/feature-requests/:id/status", middleware.AdminPermission("dashboard", "read"), featureRequestCtrl.UpdateStatus)

		// 1.1. Target Sales (peluang closing) — auto-scored dari aktivitas live
		adminGroup.GET("/sales-targets", middleware.AdminPermission("dashboard", "read"), salesTargetCtrl.List)
		adminGroup.PATCH("/sales-targets/:id/contact", middleware.AdminPermission("dashboard", "read"), salesTargetCtrl.SetContact)

		// 2. Management Tenants (Outlets)
		adminGroup.GET("/tenants", middleware.AdminPermission("tenants", "read"), tenantCtrl.ListTenants)
		adminGroup.GET("/tenants/:id", middleware.AdminPermission("tenants", "read"), tenantCtrl.GetDetail)
		adminGroup.GET("/tenants/:id/name-history", middleware.AdminPermission("tenants", "read"), tenantCtrl.GetNameHistory)
		adminGroup.PATCH("/tenants/:id/status", middleware.AdminPermission("tenants", "suspend"), tenantCtrl.UpdateStatus)
		adminGroup.DELETE("/tenants/:id", middleware.AdminPermission("tenants", "delete"), tenantCtrl.DeleteTenant)
		adminGroup.POST("/tenants/:id/staff-accounts", middleware.AdminPermission("staff-accounts", "create"), staffAccountCtrl.Create)
		adminGroup.PUT("/tenants/:id/staff-accounts/:staff_id", middleware.AdminPermission("staff-accounts", "update"), staffAccountCtrl.Update)
		adminGroup.DELETE("/tenants/:id/staff-accounts/:staff_id", middleware.AdminPermission("staff-accounts", "delete"), staffAccountCtrl.Delete)
		adminGroup.POST("/tenants/:id/inject-koin", middleware.AdminPermission("topups", "confirm"), koinCtrl.AdminInjectCoin)

		// 2.1. Outlet Data Management & Reset
		adminGroup.POST("/tenants/:id/data/reset", middleware.AdminPermission("tenants", "reset_data"), resetDataCtrl.ResetOutletData)
		adminGroup.GET("/tenants/:id/data/reset-history", middleware.AdminPermission("tenants", "read"), resetDataCtrl.GetResetHistory)
		adminGroup.GET("/tenants/:id/data/reset-history/:reset_id", middleware.AdminPermission("tenants", "read"), resetDataCtrl.GetResetDetail)
		adminGroup.GET("/account-deletions", middleware.AdminPermission("account-deletions", "read"), accountDeletionCtrl.List)

		// 3. Management Users (Owners)
		adminGroup.GET("/users", middleware.AdminPermission("users", "read"), userCtrl.ListOwners)
		adminGroup.GET("/users/:id", middleware.AdminPermission("users", "read"), userCtrl.GetOwnerDetail)
		adminGroup.PATCH("/users/:id", middleware.AdminPermission("users", "update"), userCtrl.UpdateOwnerProfile)
		adminGroup.DELETE("/users/:id", middleware.AdminPermission("users", "delete"), userCtrl.DeleteOwner)

		// 4. Management Customers (Lintas Platform)
		adminGroup.GET("/customers", middleware.AdminPermission("customers", "read"), customerCtrl.ListCustomers)

		// 4.1. Transactions History
		adminGroup.GET("/transactions", middleware.AdminPermission("dashboard", "read"), trxAdminCtrl.ListTransactions)
		adminGroup.GET("/nobu/payments", middleware.AdminPermission("dashboard", "read"), nobuFinanceCtrl.Payments)
		adminGroup.GET("/nobu/payables", middleware.AdminPermission("finance", "read"), nobuFinanceCtrl.Payables)
		adminGroup.GET("/nobu/audits", middleware.AdminPermission("finance", "read"), nobuFinanceCtrl.Audits)
		adminGroup.GET("/nobu/reconciliation", middleware.AdminPermission("finance", "read"), nobuFinanceCtrl.Reconcile)
		adminGroup.GET("/nobu/settlements", middleware.AdminPermission("finance", "read"), nobuFinanceCtrl.Settlements)
		adminGroup.POST("/nobu/settlements", middleware.AdminPermission("finance", "update"), nobuFinanceCtrl.CreateSettlement)
		adminGroup.PATCH("/nobu/settlements/:id", middleware.AdminPermission("finance", "update"), nobuFinanceCtrl.UpdateSettlement)

		// 5. Economy & Subscriptions Management
		economy := adminGroup.Group("/economy")
		economy.Use(middleware.AdminPermission("economy", "read"))
		{
			// Configs & Fees
			economy.GET("/configs", economyCtrl.GetAllConfigs)
			economy.PATCH("/configs", middleware.AdminPermission("economy", "update"), economyCtrl.UpdateConfig)

			// Seeder: Inisialisasi biaya aktivasi & bonus
			economy.POST("/seed", middleware.AdminPermission("economy", "create"), economyCtrl.SeedConfigs)

			// Koin Packages
			economy.GET("/packages", middleware.AdminPermission("packages", "read"), economyCtrl.GetPackages)
			economy.POST("/packages", middleware.AdminPermission("packages", "create"), economyCtrl.CreatePackage)
			economy.PUT("/packages/:id", middleware.AdminPermission("packages", "update"), economyCtrl.UpdatePackage)
			economy.DELETE("/packages/:id", middleware.AdminPermission("packages", "delete"), economyCtrl.DeletePackage)

			// Addon Catalog
			economy.GET("/addons", middleware.AdminPermission("packages", "read"), economyCtrl.GetAddons)
			economy.POST("/addons", middleware.AdminPermission("packages", "create"), economyCtrl.CreateAddon)
			economy.PATCH("/addons/:id", middleware.AdminPermission("packages", "update"), economyCtrl.UpdateAddon)
			economy.DELETE("/addons/:id", middleware.AdminPermission("packages", "delete"), economyCtrl.DeleteAddon)
		}

		// 6. Management Vouchers
		vouchers := adminGroup.Group("/vouchers")
		vouchers.Use(middleware.AdminPermission("vouchers", "read"))
		{
			vouchers.GET("", vCtrl.List)
			vouchers.POST("", middleware.AdminPermission("vouchers", "create"), vCtrl.Create)
			vouchers.PATCH("/:id/status", middleware.AdminPermission("vouchers", "activate"), vCtrl.ToggleStatus)
			vouchers.PUT("/:id", middleware.AdminPermission("vouchers", "update"), vCtrl.Update)
			vouchers.DELETE("/:id", middleware.AdminPermission("vouchers", "delete"), vCtrl.Delete)
		}

		// 7. Management Bank Accounts (Rekening Pusat)
		banks := adminGroup.Group("/banks")
		banks.Use(middleware.AdminPermission("economy", "read"))
		{
			banks.GET("", bankCtrl.GetAll)
			banks.POST("", middleware.AdminPermission("economy", "create"), bankCtrl.Create)
			banks.PUT("/:id", middleware.AdminPermission("economy", "update"), bankCtrl.Update)
			banks.PATCH("/:id/status", middleware.AdminPermission("economy", "update"), bankCtrl.ToggleStatus)
			banks.DELETE("/:id", middleware.AdminPermission("economy", "delete"), bankCtrl.Delete)
		}

		// 8. Management Topups & Billing (Topup Koin)
		topups := adminGroup.Group("/topup-koin")
		topups.Use(middleware.AdminPermission("topups", "read"))
		{
			topups.GET("/incoming", koinCtrl.AdminListAllPemasukan)
			topups.GET("/ledger", koinCtrl.AdminCoinLedger)
			topups.GET("", koinCtrl.AdminListTopups)
			topups.GET("/:id", koinCtrl.AdminGetTopupDetail)
			topups.PATCH("/confirm", middleware.AdminPermission("topups", "confirm"), koinCtrl.AdminConfirmTopup)
			topups.PATCH("/cancel-midtrans", middleware.AdminPermission("topups", "cancel"), koinCtrl.AdminCancelMidtrans)
		}

		// 10. Management Addons & Activation Billing
		addons := adminGroup.Group("/topup-addon")
		addons.Use(middleware.AdminPermission("subscriptions", "read"))
		{
			addons.GET("", addonCtrl.AdminListTransactions)
			addons.GET("/:id", addonCtrl.AdminGetDetail)
			addons.PATCH("/confirm", middleware.AdminPermission("topups", "confirm"), addonCtrl.AdminApprove)
			addons.PATCH("/cancel", middleware.AdminPermission("topups", "cancel"), addonCtrl.AdminCancel)
		}

		// 9. Notifications & Broadcast Logs
		adminGroup.POST("/notifications/broadcast", middleware.AdminPermission("notifications", "broadcast"), notifCtrl.SendBroadcast)
		adminGroup.GET("/notifications/templates", middleware.AdminPermission("notifications", "read"), notifCtrl.ListTemplates)
		adminGroup.GET("/notifications/lifecycle", middleware.AdminPermission("notifications", "read"), notifCtrl.LifecycleOverview)
		adminGroup.PUT("/notifications/lifecycle/rules/:key", middleware.AdminPermission("notifications", "update"), notifCtrl.UpdateLifecycleRule)
		adminGroup.POST("/notifications/templates", middleware.AdminPermission("notifications", "broadcast"), notifCtrl.CreateTemplate)
		adminGroup.PUT("/notifications/templates/:id", middleware.AdminPermission("notifications", "broadcast"), notifCtrl.UpdateTemplate)
		adminGroup.DELETE("/notifications/templates/:id", middleware.AdminPermission("notifications", "delete"), notifCtrl.DeleteTemplate)
		adminGroup.GET("/notifications/entity-options", middleware.AdminPermission("notifications", "read"), notifCtrl.GetEntityOptions)
		adminGroup.GET("/notifications/outlet-options", middleware.AdminPermission("notifications", "read"), notifCtrl.GetOutletOptions)
		adminGroup.GET("/notifications/logs", middleware.AdminPermission("notifications", "read"), notifCtrl.GetLogs)
		adminGroup.GET("/notifications/logs/:id", middleware.AdminPermission("notifications", "read"), notifCtrl.GetDetail)
		adminGroup.GET("/notifications/logs/:id/push-tokens", middleware.AdminPermission("notifications", "read"), notifCtrl.GetPushTokens)
		adminGroup.PATCH("/notifications/push-tokens/deactivate", middleware.AdminPermission("notifications", "delete"), notifCtrl.DeactivatePushToken)
		adminGroup.DELETE("/notifications/logs/:id", middleware.AdminPermission("notifications", "delete"), notifCtrl.DeleteBroadcast)

		adminGroup.GET("/otp-logs", middleware.AdminPermission("notifications", "read"), otpLogCtrl.List)

		SetupAdminContentRoutes(adminGroup, db)
		SetupAdminTutorialRoutes(adminGroup, db)
		SetupAdminLegalDocumentRoutes(adminGroup, db)
		SetupAdminReferralRoutes(adminGroup, db)
		SetupAdminAppSettingRoutes(adminGroup, db)
		SetupLeadOpsRoutes(adminGroup, db)

		// 11. Admin Account & Role Management (Master Admin Only)
		accounts := adminGroup.Group("/accounts")
		accounts.Use(middleware.MasterAdminOnly())
		{
			accounts.GET("", acctCtrl.ListAdmins)
			accounts.POST("", acctCtrl.CreateAdmin)
			accounts.PUT("/:id", acctCtrl.UpdateAdmin)
			accounts.DELETE("/:id", acctCtrl.DeleteAdmin)
			accounts.PATCH("/:id/role", acctCtrl.AssignRole)
		}

		adminRoles := adminGroup.Group("/admin-roles")
		adminRoles.Use(middleware.MasterAdminOnly())
		{
			adminRoles.GET("", acctCtrl.ListRoles)
			adminRoles.POST("", acctCtrl.CreateRole)
			adminRoles.PUT("/:id", acctCtrl.UpdateRole)
			adminRoles.DELETE("/:id", acctCtrl.DeleteRole)
		}

		// 12. Analytics & Laporan
		analytics := adminGroup.Group("/analytics")
		analytics.Use(middleware.AdminPermission("analytics", "read"))
		{
			analytics.GET("/revenue", analyticsCtrl.GetRevenue)
			analytics.GET("/growth", analyticsCtrl.GetGrowth)
			analytics.GET("/geography", analyticsCtrl.GetGeography)
			analytics.GET("/activity", analyticsCtrl.GetActivity)
			analytics.GET("/referral", analyticsCtrl.GetReferral)
			analytics.GET("/referral-topup-details", analyticsCtrl.GetReferralTopupDetails)
			analytics.GET("/inactive-owners", analyticsCtrl.GetInactiveOwners)
		}
	}
}
