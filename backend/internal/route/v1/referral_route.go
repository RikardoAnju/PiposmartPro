package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	adminCtrl "github.com/RikardoAnju/PiposmartPro/internal/controller/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupReferralRoutes(rg *gin.RouterGroup, db *gorm.DB) {
	koinSvc := service.NewKoinService(db)
	referralCtrl := controller.NewReferralController(service.NewReferralService(db, koinSvc))

	referral := rg.Group("/referral")
	referral.Use(middleware.JWTAuth())
	{
		referral.Use(func(c *gin.Context) {
			actorType, _ := c.Get("actor_type")
			if actorType != "user" {
				c.JSON(403, gin.H{
					"status":  false,
					"message": "Fitur referral hanya untuk owner",
				})
				c.Abort()
				return
			}
			c.Next()
		})

		referral.GET("/recruited-owners", referralCtrl.GetRecruitedOwners)
		referral.GET("/summary", referralCtrl.GetSummary)
		referral.POST("/apply", referralCtrl.ApplyCode)
		referral.POST("/convert-to-koin", referralCtrl.ConvertToKoin)
	
		referral.POST("/payout-requests", referralCtrl.CreatePayoutRequest)
		referral.GET("/payout-accounts", referralCtrl.ListPayoutAccounts)
		referral.GET("/top-rank-owner", referralCtrl.GetTopReferralOwnerRanks)
		referral.POST("/payout-accounts", referralCtrl.CreatePayoutAccount)
		referral.PUT("/payout-accounts/:id", referralCtrl.UpdatePayoutAccount)
		referral.PATCH("/payout-accounts/:id/default", referralCtrl.SetDefaultPayoutAccount)
		referral.DELETE("/payout-accounts/:id", referralCtrl.DeletePayoutAccount)
	}
}

func SetupAdminReferralRoutes(adminGroup *gin.RouterGroup, db *gorm.DB) {
	ctrl := adminCtrl.NewAdminReferralController(adminSvc.NewAdminReferralService(db))
	referral := adminGroup.Group("/referrals")
	referral.Use(middleware.AdminPermission("referrals", "read"))
	{
		referral.GET("/dashboard", ctrl.GetDashboard)
		referral.GET("/config", ctrl.GetConfig)
		referral.PATCH("/config", middleware.AdminPermission("referrals", "update"), ctrl.UpdateConfig)
		referral.GET("/payouts", ctrl.ListPayouts)
		referral.PATCH("/payouts/:id/status", middleware.AdminPermission("referrals", "approve"), ctrl.UpdatePayoutStatus)
		referral.GET("/rewards", ctrl.ListRewards)
	}
}
