package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupAuthRoutes(r *gin.RouterGroup, db *gorm.DB) {
	// 1. Inisialisasi Service Pendukung
	roleSvc := service.NewRoleService(db)
	parfumSvc := service.NewParfumService(db)
	layananSvc := service.NewLayananService(db)
	katExpSvc := service.NewKategoriPengeluaranService(db)
	paySvc := service.NewMetodePembayaranService(db)
	itemSvc := service.NewItemService(db)

	locSvc := service.NewLocationService()
	koinSvc := service.NewKoinService(db) // Untuk akses bonus referral
	referralSvc := service.NewReferralService(db, koinSvc)

	// OTP Service digunakan bersama oleh Register dan Auth (Forgot Password)
	otpSvc := service.NewOTPService(db)

	// 2. Inisialisasi RegisterService
	regService := service.NewRegisterService(
		db,
		roleSvc,
		parfumSvc,
		layananSvc,
		katExpSvc,
		paySvc,
		itemSvc,
		koinSvc,
		referralSvc,
	)

	// 3. Inisialisasi Controller
	// Pastikan NewAuthController menerima 'db' (gorm.DB) sesuai update controller terakhir
	regCtrl := controller.NewRegisterController(regService, otpSvc)
	authCtrl := controller.NewAuthController(service.NewAuthService(db), otpSvc, db)
	locCtrl := controller.NewLocationController(locSvc)

	auth := r.Group("/auth")
	{
		// --- EMERGENCY SEEDER (Public - Jalankan sekali saja) ---
		// Tembak POST /api/v1/auth/seed-admin untuk mengisi data admin@com
		auth.POST("/seed-admin", authCtrl.SeedAdmin)

		location := r.Group("/location")
		{
			location.GET("/provinces", locCtrl.GetProvinces)
			location.GET("/cities", locCtrl.GetCities)
			location.GET("/districts", locCtrl.GetDistricts)
		}

		// --- Alur Registrasi (Public) ---
		register := auth.Group("/register")
		{
			register.POST("/check-phone", regCtrl.CheckPhone)
			register.POST("/send-otp", regCtrl.SendOTP)
			register.POST("/verify-otp", regCtrl.VerifyOTP)
			register.POST("/validate-account", regCtrl.ValidateAccount)
			register.POST("/validate-referral", regCtrl.ValidateReferral)
			register.POST("/validate-outlet", regCtrl.ValidateOutlet)
			register.POST("/final", regCtrl.FinalRegister)
		}

		// --- Alur Lupa Password (Public) ---
		forgot := auth.Group("/forgot-password")
		{
			forgot.POST("/lookup-account", authCtrl.ForgotPasswordLookupAccount)
			forgot.POST("/send-otp", authCtrl.ForgotPasswordSendOTP)     // Hit 1: Cek nomor & Kirim OTP
			forgot.POST("/verify-otp", authCtrl.ForgotPasswordVerifyOTP) // Hit 2: Verifikasi OTP
			forgot.POST("/reset", authCtrl.ForgotPasswordReset)          // Hit 3: Update Password
		}

		// --- Login Dasar (Public) ---
		auth.POST("/login", authCtrl.Login)
		// Impersonation (build internal, digate env IMPERSONATION_SECRET di server).
		auth.POST("/impersonate", authCtrl.Impersonate)
		auth.POST("/google", authCtrl.GoogleLogin)
		auth.POST("/apple", authCtrl.AppleLogin)

		// --- Login Admin (Public) ---
		auth.POST("/admin/login", authCtrl.LoginAdmin)

		// --- Grup Rute Terproteksi (Hanya JWT) ---
		protected := auth.Group("/")
		protected.Use(middleware.JWTAuth())
		{
			protected.GET("/me", authCtrl.GetMe)
			protected.POST("/refresh-token", authCtrl.RefreshToken)
			protected.POST("/push-token", authCtrl.RegisterPushToken)
			protected.GET("/push-token/status", authCtrl.PushTokenStatus)
			protected.POST("/push-token/unregister", authCtrl.UnregisterPushToken)

			// Keamanan Akun
			protected.PUT("/change-password", authCtrl.ChangePassword)
			protected.PUT("/profile", authCtrl.UpdateProfile)
			protected.DELETE("/delete-account", authCtrl.DeleteAccount)
		}
	}
}
