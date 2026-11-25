package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/push"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"

	"cloud.google.com/go/auth/credentials/idtoken"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

type AuthController struct {
	authService *service.AuthService
	otpService  *service.OTPService
	db          *gorm.DB // Tambahkan ini agar bisa akses database langsung
}

func NewAuthController(s *service.AuthService, o *service.OTPService, db *gorm.DB) *AuthController {
	return &AuthController{
		authService: s,
		otpService:  o,
		db:          db, // Inject db ke controller
	}
}

// --- SEED ADMIN (Cuma buat sekali jalan kalau manual SQL gagal) ---
func (ctrl *AuthController) SeedAdmin(c *gin.Context) {
	password := "admin123"
	hashed, _ := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)

	admin := model.Admin{
		ID:       "ADM.000001",
		Nama:     "Super Admin",
		Email:    "admin@com",
		Password: string(hashed),
	}

	// Simpan ke DB langsung lewat controller (karena ini emergency seeder)
	if err := ctrl.db.Create(&admin).Error; err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal seed: "+err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Admin seeded successfully!", nil)
}

// --- REFRESH TOKEN ---
func (ctrl *AuthController) RefreshToken(c *gin.Context) {
	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")

	token, err := ctrl.authService.RefreshToken(actorID.(string), actorType.(string))
	if err != nil {
		log.Printf(
			"auth:refresh failed actor_type=%s actor_id=%s ip=%s err=%v",
			actorType.(string),
			actorID.(string),
			c.ClientIP(),
			err,
		)
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memperbarui sesi")
		return
	}

	log.Printf(
		"auth:refresh success actor_type=%s actor_id=%s ip=%s",
		actorType.(string),
		actorID.(string),
		c.ClientIP(),
	)

	utils.JSONResponse(c, http.StatusOK, "Sesi diperbarui", gin.H{"access_token": token})
}

// --- FORGOT PASSWORD FLOW ---
func (ctrl *AuthController) ForgotPasswordSendOTP(c *gin.Context) {
	var req struct {
		Phone   string `json:"phone" binding:"required"`
		Email   string `json:"email" binding:"required,email"`
		Channel string `json:"channel" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data pengiriman OTP tidak lengkap")
		return
	}

	email, err := ctrl.authService.ValidateForgotPasswordAccount(req.Email, req.Phone)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Akun tidak ditemukan atau data tidak cocok")
		return
	}

	if err := ctrl.otpService.GenerateAndSendOTPByChannel(req.Phone, email, req.Channel, "forgot_password"); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengirim OTP")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "OTP berhasil dikirim", gin.H{"channel": req.Channel})
}

func (ctrl *AuthController) ForgotPasswordLookupAccount(c *gin.Context) {
	var req struct {
		Method string `json:"method" binding:"required"`
		Value  string `json:"value" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Metode dan data pencarian diperlukan")
		return
	}

	account, err := ctrl.authService.FindForgotPasswordAccount(req.Method, req.Value)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Akun tidak ditemukan")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Akun ditemukan", account)
}

func (ctrl *AuthController) ForgotPasswordVerifyOTP(c *gin.Context) {
	var req struct {
		Email string `json:"email" binding:"required,email"`
		Phone string `json:"phone" binding:"required"`
		OTP   string `json:"otp" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	if !ctrl.otpService.VerifyOTP(req.Phone, req.OTP, true, "forgot_password") {
		utils.ErrorResponse(c, http.StatusUnauthorized, "OTP salah atau kedaluwarsa")
		return
	}

	email, err := ctrl.authService.ValidateForgotPasswordAccount(req.Email, req.Phone)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Email dan nomor HP tidak cocok")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "OTP valid", gin.H{"email": email})
}

func (ctrl *AuthController) ForgotPasswordReset(c *gin.Context) {
	var req struct {
		Email       string `json:"email" binding:"required,email"`
		Phone       string `json:"phone" binding:"required"`
		OTP         string `json:"otp" binding:"required"`
		NewPassword string `json:"new_password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	if !ctrl.otpService.VerifyOTP(req.Phone, req.OTP, false, "forgot_password") {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Sesi verifikasi habis, silakan coba lagi")
		return
	}

	if err := ctrl.authService.ResetPasswordByEmailAndPhone(req.Email, req.Phone, req.NewPassword); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Password berhasil direset", nil)
}

// --- DELETE ACCOUNT ---
func (ctrl *AuthController) DeleteAccount(c *gin.Context) {
	var req struct {
		Reason       string `json:"reason" binding:"required"`
		ReasonDetail string `json:"reason_detail" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Alasan dan detail penghapusan akun wajib diisi")
		return
	}

	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")

	if err := ctrl.authService.DeleteAccount(
		actorID.(string),
		actorType.(string),
		req.Reason,
		req.ReasonDetail,
	); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghapus akun")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Akun berhasil dihapus permanen", nil)
}

// --- LOGIN ---
func (ctrl *AuthController) Login(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Email atau password tidak valid")
		return
	}

	user, token, outletID, hasOutlet, actorType, permissions, err := ctrl.authService.Login(req.Email, req.Password)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, err.Error())
		return
	}

	resp := gin.H{
		"access_token": token,
		"actor_id":     utils.ExtractUserID(user),
		"actor_type":   actorType,
		"permissions":  permissions,
		"outlet_id":    outletID,
		"has_outlet":   hasOutlet,
		"user":         user,
	}

	if actorType == "user" {
		if u, ok := user.(model.User); ok {
			resp["last_outlet_id"] = u.LastOutletID
		}
	}

	utils.JSONResponse(c, http.StatusOK, "Login berhasil", resp)
}

// Impersonate: login sebagai user via email + secret (build internal only).
// Digate env IMPERSONATION_SECRET di server (kosong = nonaktif).
func (ctrl *AuthController) Impersonate(c *gin.Context) {
	var req struct {
		Email  string `json:"email" binding:"required,email"`
		Secret string `json:"secret" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Email atau secret tidak valid")
		return
	}

	user, token, outletID, hasOutlet, actorType, permissions, err := ctrl.authService.ImpersonateByEmail(req.Email, req.Secret)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Impersonation berhasil", gin.H{
		"access_token": token,
		"actor_id":     utils.ExtractUserID(user),
		"actor_type":   actorType,
		"permissions":  permissions,
		"outlet_id":    outletID,
		"has_outlet":   hasOutlet,
		"user":         user,
	})
}

// --- GOOGLE LOGIN ---
func (ctrl *AuthController) GoogleLogin(c *gin.Context) {
	var body struct {
		IDToken string `json:"idToken" binding:"required"`
	}

	if err := c.ShouldBindJSON(&body); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Token Google diperlukan")
		return
	}

	webClientID := config.GetEnv("GOOGLE_CLIENT_ID", "")
	payload, err := idtoken.Validate(context.Background(), body.IDToken, webClientID)

	if err != nil {
		fmt.Printf("❌ Google Auth Error: %v\n", err)
		utils.ErrorResponse(c, http.StatusUnauthorized, "Sesi Google tidak valid")
		return
	}

	email := payload.Claims["email"].(string)
	googleID := payload.Subject
	name := payload.Claims["name"].(string)

	user, token, outletID, hasOutlet, actorType, permissions, err := ctrl.authService.GoogleLogin(email, googleID, name)

	if err != nil {
		if err.Error() == "USER_NOT_FOUND" {
			registrationToken, tokenErr := utils.GenerateRegistrationTicket(
				"google_registration",
				email,
				googleID,
				"",
			)
			if tokenErr != nil {
				utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyiapkan pendaftaran Google")
				return
			}
			utils.JSONResponse(c, http.StatusOK, "User belum terdaftar", gin.H{
				"is_registered":      false,
				"email":              email,
				"name":               name,
				"google_id":          googleID,
				"registration_token": registrationToken,
			})
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memproses data")
		return
	}

	resp := gin.H{
		"access_token":  token,
		"actor_id":      utils.ExtractUserID(user),
		"actor_type":    actorType,
		"permissions":   permissions,
		"outlet_id":     outletID,
		"has_outlet":    hasOutlet,
		"is_registered": true,
		"user":          user,
	}

	if u, ok := user.(model.User); ok {
		resp["last_outlet_id"] = u.LastOutletID
	}

	utils.JSONResponse(c, http.StatusOK, "Google Login berhasil", resp)
}

func (ctrl *AuthController) AppleLogin(c *gin.Context) {
	var body struct {
		IDToken string `json:"idToken" binding:"required"`
		Email   string `json:"email"`
		Name    string `json:"name"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Token Apple diperlukan")
		return
	}

	claims, err := service.AppleIdentityClaims(body.IDToken)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Sesi Apple tidak valid")
		return
	}

	email, _ := claims["email"].(string)
	if email == "" {
		email = body.Email
	}
	sub, _ := claims["sub"].(string)
	name := body.Name

	user, token, outletID, hasOutlet, actorType, permissions, err := ctrl.authService.AppleLogin(email, sub, name)
	if err != nil {
		if err.Error() == "USER_NOT_FOUND" {
			registrationToken, tokenErr := utils.GenerateAppleRegistrationTicket(
				"apple_registration",
				email,
				sub,
				"",
			)
			if tokenErr != nil {
				utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyiapkan pendaftaran Apple")
				return
			}
			utils.JSONResponse(c, http.StatusOK, "User belum terdaftar", gin.H{
				"is_registered":      false,
				"email":              email,
				"name":               name,
				"apple_id":           sub,
				"registration_token": registrationToken,
			})
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memproses data")
		return
	}

	resp := gin.H{
		"access_token":  token,
		"actor_id":      utils.ExtractUserID(user),
		"actor_type":    actorType,
		"permissions":   permissions,
		"outlet_id":     outletID,
		"has_outlet":    hasOutlet,
		"is_registered": true,
		"user":          user,
	}
	if u, ok := user.(model.User); ok {
		resp["last_outlet_id"] = u.LastOutletID
	}
	utils.JSONResponse(c, http.StatusOK, "Apple Login berhasil", resp)
}

func (ctrl *AuthController) RegisterPushToken(c *gin.Context) {
	var req struct {
		Token      string `json:"token" binding:"required"`
		Platform   string `json:"platform"`
		AppVersion string `json:"app_version"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Token push tidak valid")
		return
	}

	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")
	outletID, _ := c.Get("outlet_id")
	outletIDText := fmt.Sprint(outletID)

	if err := push.RegisterToken(ctrl.db, push.RegisterTokenInput{
		Token:      req.Token,
		OutletID:   outletIDText,
		ActorID:    fmt.Sprint(actorID),
		ActorType:  fmt.Sprint(actorType),
		Platform:   req.Platform,
		AppVersion: req.AppVersion,
	}); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyimpan token push")
		return
	}

	summary, err := push.TokenStatusForOutlet(ctrl.db, outletIDText, req.Token)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memeriksa status token push")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Token push tersimpan", gin.H{
		"current_token_active": summary.CurrentTokenActive,
		"active_token_count":   summary.ActiveTokenCount,
	})
}

func (ctrl *AuthController) PushTokenStatus(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	token := strings.TrimSpace(c.Query("token"))

	summary, err := push.TokenStatusForOutlet(ctrl.db, fmt.Sprint(outletID), token)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memeriksa status token push")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Status token push berhasil diambil", gin.H{
		"current_token_active": summary.CurrentTokenActive,
		"active_token_count":   summary.ActiveTokenCount,
	})
}

func (ctrl *AuthController) UnregisterPushToken(c *gin.Context) {
	var req struct {
		Token string `json:"token" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Token push tidak valid")
		return
	}

	outletID, _ := c.Get("outlet_id")
	if err := push.DeactivateToken(ctrl.db, req.Token, fmt.Sprint(outletID)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menonaktifkan token push")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Token push dinonaktifkan", nil)
}

// --- CHANGE PASSWORD ---
func (ctrl *AuthController) ChangePassword(c *gin.Context) {
	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")
	if actorType != "user" {
		utils.ErrorResponse(c, http.StatusForbidden, "Aksi ini hanya untuk Owner")
		return
	}
	var req struct {
		OldPassword string `json:"old_password" binding:"required"`
		NewPassword string `json:"new_password" binding:"required,min=6"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}
	if err := ctrl.authService.ChangePassword(actorID.(string), req.OldPassword, req.NewPassword); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Password berhasil diperbarui", nil)
}

// --- GET ME ---
func (ctrl *AuthController) GetMe(c *gin.Context) {
	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")
	outletID, _ := c.Get("outlet_id")

	user, err := ctrl.authService.GetMe(actorID.(string), actorType.(string))
	if err != nil {
		log.Printf(
			"auth:me failed actor_type=%s actor_id=%s outlet_id=%v ip=%s err=%v",
			actorType.(string),
			actorID.(string),
			outletID,
			c.ClientIP(),
			err,
		)
		utils.ErrorResponse(c, http.StatusNotFound, "Data profil tidak ditemukan")
		return
	}

	log.Printf(
		"auth:me success actor_type=%s actor_id=%s outlet_id=%v ip=%s",
		actorType.(string),
		actorID.(string),
		outletID,
		c.ClientIP(),
	)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data profil", user)
}

// --- UPDATE PROFILE ---
func (ctrl *AuthController) UpdateProfile(c *gin.Context) {
	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")

	if actorType != "user" {
		utils.ErrorResponse(c, http.StatusForbidden, "Hanya Owner yang dapat mengubah profil")
		return
	}

	var req struct {
		Nama  string `json:"nama"`
		Email string `json:"email"`
		NoHP  string `json:"no_hp"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	updates := make(map[string]interface{})
	if req.Nama != "" {
		updates["usr_nama"] = req.Nama
	}
	if req.Email != "" {
		updates["usr_email"] = req.Email
	}
	if req.NoHP != "" {
		updates["usr_nohp"] = req.NoHP
	}

	if err := ctrl.authService.UpdateProfileOwner(actorID.(string), updates); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Profil berhasil diperbarui", nil)
}

// --- LOGIN ADMIN ---
func (ctrl *AuthController) LoginAdmin(c *gin.Context) {
	var req struct {
		Email    string `json:"email" binding:"required,email"`
		Password string `json:"password" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Email dan password diperlukan")
		return
	}

	admin, token, err := ctrl.authService.LoginAdmin(req.Email, req.Password)
	if err != nil {
		utils.ErrorResponse(c, http.StatusUnauthorized, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Login Admin berhasil", gin.H{
		"access_token": token,
		"actor_type":   "admin",
		"permissions":  gin.H{"all": []string{"*"}}, // Admin selalu punya akses penuh
		"user":         admin,
	})
}
