package v1

import (
	"github.com/RikardoAnju/PiposmartPro/internal/controller"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func SetupRoutes(r *gin.Engine, db *gorm.DB) {
	middleware.PegawaiSessionStateChecker = func(actorID string) (middleware.PegawaiSessionState, error) {
		var row struct {
			TokenVersion int        `gorm:"column:pg_token_version"`
			Status       int        `gorm:"column:pg_status"`
			DeletedAt    *time.Time `gorm:"column:pg_deleted_at"`
			Type         string     `gorm:"column:pg_type"`
			ActiveUntil  *time.Time `gorm:"column:pg_active_until"`
		}
		err := db.Table("ac_pegawai").
			Select("pg_token_version, pg_status, pg_deleted_at, pg_type, pg_active_until").
			Where("pg_id = ?", actorID).
			Take(&row).Error
		if err != nil {
			return middleware.PegawaiSessionState{}, err
		}
		status := row.Status
		if row.Type == "addon" && (row.ActiveUntil == nil || !row.ActiveUntil.After(time.Now())) {
			status = 0
		}
		return middleware.PegawaiSessionState{
			TokenVersion: row.TokenVersion,
			Status:       status,
			Deleted:      row.DeletedAt != nil,
		}, nil
	}

	// --- DISABLE TRAILING SLASH REDIRECT ---
	// Biar request /admin/topups dan /admin/topups/ dianggap sama dan gak kena 307
	r.RedirectTrailingSlash = false
	r.RedirectFixedPath = false

	r.Use(func(c *gin.Context) {
		origin := c.Request.Header.Get("Origin")
		if origin != "" {
			c.Writer.Header().Set("Access-Control-Allow-Origin", origin)
		}

		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE, PATCH")

		// --- BAGIAN KRUSIAL: Tambahkan semua header yang mungkin dikirim browser ---
		// Termasuk header SNAP/ASPI (X-TIMESTAMP, X-SIGNATURE, dll) agar Client
		// Simulator ASPI (berjalan di browser) lolos preflight ke endpoint notify.
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Accept, Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, Authorization-Customer, Token, origin, Cache-Control, X-Requested-With, X-TIMESTAMP, X-SIGNATURE, X-PARTNER-ID, X-EXTERNAL-ID, X-IP-ADDRESS, X-DEVICE-ID, CHANNEL-ID, X-CHANNEL-ID, X-CLIENT-KEY, X-LONGITUDE, X-LATITUDE")
		// Pantulkan header yang diminta browser saat preflight agar semua header
		// kustom (mis. varian penulisan dari simulator) otomatis diizinkan.
		if reqHeaders := c.Request.Header.Get("Access-Control-Request-Headers"); reqHeaders != "" {
			c.Writer.Header().Set("Access-Control-Allow-Headers", reqHeaders)
		}

		c.Writer.Header().Set("Access-Control-Expose-Headers", "Content-Length")

		// Handle PREFLIGHT (OPTIONS)
		if c.Request.Method == "OPTIONS" {
			// Gunakan AbortWithStatus(204) tapi pastikan Header di atas sudah ter-set
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Serve Static Files (Untuk bukti transfer, nota, dll)
	r.Static("/uploads", "./uploads")
	r.StaticFile("/account-deletion", "./web/html/account_deletion.html")
	r.StaticFile("/privacy-policy", "./web/html/privacy_policy.html")

	notaPublicCtrl := controller.NewNotaPublicController(
		service.NewTransaksiService(db, service.NewKoinService(db)),
		service.NewNotaService(db),
	)
	r.GET("/nota/:encodedId", notaPublicCtrl.ServeNotaPage)

	v1 := r.Group("/api/v1")
	{
		v1.GET("/ping", func(c *gin.Context) {
			c.JSON(200, gin.H{"message": "ping"})
		})
		koinSvc := service.NewKoinService(db)
		pegawaiSvc := service.NewPegawaiService(db)
		addonSvc := service.NewAddonService(db, koinSvc, pegawaiSvc)
		midSvc := service.NewMidtransService(koinSvc, addonSvc)
		midCtrl := controller.NewMidtransController(midSvc)
		v1.POST("/callback/midtrans", midCtrl.HandleNotification)
		nobuCtrl := controller.NewNobuController(service.NewNobuPaymentService(db))
		v1.POST("/callback/nobu/qris", nobuCtrl.Notify)
		// ASPI-standard callback path registered with Nobu. Keep the legacy path
		// above for backward compatibility with existing configuration.
		r.POST("/v1.0/qr/qr-mpm-notify/", nobuCtrl.Notify)
		r.POST("/v2.0/access-token/b2b/", nobuCtrl.AccessTokenB2B)
		v1.GET("/ws", controller.HandleWS)

		// --- REGISTER ALL MODULES ---
		SetupAuthRoutes(v1, db)
		RegisterLayananRoutes(v1, db)
		RegisterPelangganRoutes(v1, db)
		RegisterTransaksiRoutes(v1, db)
		RegisterItemRoutes(v1, db)
		RegisterInventoryRoutes(v1, db)
		RegisterParfumRoutes(v1, db)
		RegisterMetodePembayaranRoutes(v1, db)
		RegisterDiskonRoutes(v1, db)
		RegisterRoleRoutes(v1, db)
		RegisterPegawaiRoutes(v1, db)
		RegisterPayrollRoutes(v1, db)
		RegisterAttendanceRoutes(v1, db)
		RegisterPengeluaranRoutes(v1, db)
		SetupDashboardRoutes(v1, db)
		RegisterReportRoutes(v1, db)
		SetupOutletRoutes(v1, db)
		RegisterNotaRoutes(v1, db)
		RegisterStatusRoutes(v1, db)
		SetupSummaryRoutes(v1, db)
		KoinRoutes(v1, db)
		RegisterIapRoutes(v1, db)
		SetupAdminRoutes(v1, db)
		RegisterFinanceRoutes(v1, db)
		SetupNotifRoutes(v1, db)
		SetupLifecycleRoutes(v1, db)
		RegisterAddonRoutes(v1, db)
		RegisterCustomerReportRoutes(v1, db)
		SetupContentRoutes(v1, db)
		SetupTutorialRoutes(v1, db)
		SetupLegalDocumentRoutes(v1, db)
		SetupReferralRoutes(v1, db)
		SetupAppSettingRoutes(v1, db)
		SetupLeadOpsRoutes(v1, db)
		SetupFeatureRequestRoutes(v1, db)
	}
}
