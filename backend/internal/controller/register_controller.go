package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type RegisterController struct {
	regService *service.RegisterService
	otpService *service.OTPService
}

var (
	allowedBusinessLocations = []string{"Ruko", "Rumah", "Kios"}
	allowedBusinessCapitals  = []string{"Rp20 juta - Rp50 juta", "Rp50 juta - Rp80 juta", "Di atas Rp100 juta"}
	allowedEmployeeCounts    = []string{"1 orang", "2 orang", "Lebih dari 3 orang"}
	allowedMachineCounts     = []string{"2 unit", "4 unit", "6 unit", "Lebih dari 6 unit"}
)

func isOneOf(value string, allowed []string) bool {
	for _, item := range allowed {
		if value == item {
			return true
		}
	}
	return false
}

func validateOutletBusinessProfile(tipeLokasi, modal, karyawan, mesin string) string {
	switch {
	case !isOneOf(tipeLokasi, allowedBusinessLocations):
		return "Pilih tempat usaha yang valid"
	case !isOneOf(modal, allowedBusinessCapitals):
		return "Pilih kisaran modal usaha yang valid"
	case !isOneOf(karyawan, allowedEmployeeCounts):
		return "Pilih jumlah karyawan yang valid"
	case !isOneOf(mesin, allowedMachineCounts):
		return "Pilih jumlah mesin dan pengering yang valid"
	default:
		return ""
	}
}

func NewRegisterController(s *service.RegisterService, o *service.OTPService) *RegisterController {
	return &RegisterController{
		regService: s,
		otpService: o,
	}
}

func (ctrl *RegisterController) CheckPhone(c *gin.Context) {
	var req struct {
		Phone string `json:"usr_nohp" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nomor HP diperlukan")
		return
	}

	if ctrl.regService.IsPhoneRegistered(req.Phone) {
		utils.ErrorResponse(c, http.StatusConflict, "Nomor HP sudah terdaftar")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Nomor HP tersedia", nil)
}

func (ctrl *RegisterController) SendOTP(c *gin.Context) {
	var req struct {
		Phone string `json:"usr_nohp" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nomor HP diperlukan")
		return
	}

	if ctrl.regService.IsPhoneRegistered(req.Phone) {
		utils.ErrorResponse(c, http.StatusConflict, "Nomor HP sudah terdaftar")
		return
	}

	validation, err := ctrl.otpService.ValidateWhatsAppNumber(req.Phone, "register")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nomor WhatsApp belum aktif atau tidak valid")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Nomor WhatsApp aktif dan siap dipakai", gin.H{
		"verification_token": validation.VerificationToken,
		"normalized_phone":   validation.Phone,
	})
}

func (ctrl *RegisterController) VerifyOTP(c *gin.Context) {
	var req struct {
		Phone string `json:"usr_nohp" binding:"required"`
		Code  string `json:"otp_code"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak lengkap")
		return
	}

	if ctrl.regService.IsPhoneRegistered(req.Phone) {
		utils.ErrorResponse(c, http.StatusConflict, "Nomor HP sudah terdaftar")
		return
	}

	validation, err := ctrl.otpService.ValidateWhatsAppNumber(req.Phone, "register")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nomor WhatsApp belum aktif atau tidak valid")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Nomor WhatsApp tervalidasi", gin.H{
		"verification_token": validation.VerificationToken,
		"normalized_phone":   validation.Phone,
	})
}

// internal/controller/register_controller.go

func (ctrl *RegisterController) ValidateReferral(c *gin.Context) {
	code := c.Query("code")
	if code == "" {
		// Balikin suksess tapi data kosong kalau user gak input apa-apa
		utils.JSONResponse(c, http.StatusOK, "Kode kosong", nil)
		return
	}

	// Panggil service, jangan panggil GetDB() langsung di sini
	referrer, err := ctrl.regService.CheckReferralCode(code)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Kode referral tidak valid")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Kode referral valid", gin.H{
		"referrer_name": referrer.Nama,
	})
}

func (ctrl *RegisterController) ValidateAccount(c *gin.Context) {
	var user model.User
	if err := c.ShouldBindJSON(&user); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format data akun tidak valid")
		return
	}
	if ctrl.regService.IsEmailRegistered(user.Email) {
		utils.ErrorResponse(c, http.StatusConflict, "Email sudah terdaftar")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Data akun valid", nil)
}

func (ctrl *RegisterController) ValidateOutlet(c *gin.Context) {
	var outlet model.Outlet
	if err := c.ShouldBindJSON(&outlet); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format data outlet tidak valid")
		return
	}
	if outlet.Nama == "" || outlet.Alamat == nil || *outlet.Alamat == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nama outlet dan alamat wajib diisi")
		return
	}
	if outlet.TipeLokasiUsaha == nil || outlet.ModalUsaha == nil || outlet.JumlahKaryawan == nil || outlet.JumlahMesin == nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Profil usaha outlet wajib dilengkapi")
		return
	}
	if message := validateOutletBusinessProfile(*outlet.TipeLokasiUsaha, *outlet.ModalUsaha, *outlet.JumlahKaryawan, *outlet.JumlahMesin); message != "" {
		utils.ErrorResponse(c, http.StatusBadRequest, message)
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Data outlet valid", nil)
}

func (ctrl *RegisterController) FinalRegister(c *gin.Context) {
	var req struct {
		Username        string  `json:"username" binding:"required"`
		Email           string  `json:"email" binding:"required,email"`
		NomorHP         string  `json:"nomor_hp" binding:"required"`
		Password        string  `json:"password"`
		ConfirmPassword string  `json:"confirmPassword"`
		LeadSource      string  `json:"lead_source"`
		GoogleID        *string `json:"google_id"`
		GoogleToken     string  `json:"google_registration_token"`
		AppleID         *string `json:"apple_id"`
		AppleToken      string  `json:"apple_registration_token"`
		PhoneToken      string  `json:"phone_verification_token"`
		OTPToken        string  `json:"otp_verification_token"`
		ReferralCode    string  `json:"referral_code"`
		Outlet          struct {
			NamaOutlet      string `json:"nama_outlet" binding:"required"`
			NomorHP         string `json:"nomor_hp"`
			Provinsi        string `json:"provinsi"`
			Kota            string `json:"kota"`
			Kecamatan       string `json:"kecamatan"`
			Alamat          string `json:"alamat"`
			TipeLokasiUsaha string `json:"tipe_lokasi_usaha" binding:"required"`
			ModalUsaha      string `json:"modal_usaha" binding:"required"`
			JumlahKaryawan  string `json:"jumlah_karyawan" binding:"required"`
			JumlahMesin     string `json:"jumlah_mesin" binding:"required"`
			TanggalBerjalan string `json:"tanggal_berjalan"`
		} `json:"outlet"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data pendaftaran tidak lengkap")
		return
	}

	normalizedPhone := service.NormalizePhoneForOTP(req.NomorHP)
	if len(normalizedPhone) < 10 || len(normalizedPhone) > 15 || !strings.HasPrefix(normalizedPhone, "62") {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nomor HP tidak valid")
		return
	}
	req.NomorHP = normalizedPhone

	phoneVerificationToken := strings.TrimSpace(req.PhoneToken)
	if phoneVerificationToken == "" {
		phoneVerificationToken = strings.TrimSpace(req.OTPToken)
	}

	phoneVerified := false
	if phoneVerificationToken != "" {
		phoneClaims, err := utils.ValidateRegistrationTicket(phoneVerificationToken, "phone_registration")
		if err == nil && phoneClaims.Phone == normalizedPhone {
			phoneVerified = true
		}
	}
	if !phoneVerified {
		validation, err := ctrl.otpService.ValidateWhatsAppNumber(normalizedPhone, "register")
		if err != nil || validation == nil || validation.Phone != normalizedPhone {
			utils.ErrorResponse(c, http.StatusUnauthorized, "Nomor WhatsApp owner belum aktif atau tidak valid")
			return
		}
	}

	isGoogleRegistration := strings.TrimSpace(req.GoogleToken) != ""
	isAppleRegistration := strings.TrimSpace(req.AppleToken) != ""
	if isGoogleRegistration {
		claims, err := utils.ValidateRegistrationTicket(req.GoogleToken, "google_registration")
		if err != nil {
			utils.ErrorResponse(c, http.StatusUnauthorized, "Sesi pendaftaran Google tidak valid atau kedaluwarsa")
			return
		}
		if !strings.EqualFold(strings.TrimSpace(req.Email), claims.Email) {
			utils.ErrorResponse(c, http.StatusUnauthorized, "Email tidak sesuai dengan akun Google")
			return
		}
		req.Email = claims.Email
		req.GoogleID = &claims.GoogleID
		req.AppleID = nil
	} else {
		req.GoogleID = nil
	}

	if isAppleRegistration {
		claims, err := utils.ValidateRegistrationTicket(req.AppleToken, "apple_registration")
		if err != nil {
			utils.ErrorResponse(c, http.StatusUnauthorized, "Token registrasi Apple tidak valid")
			return
		}
		req.Email = claims.Email
		req.AppleID = &claims.AppleID
		req.GoogleID = nil
	}

	if ctrl.regService.IsPhoneRegistered(req.NomorHP) {
		utils.ErrorResponse(c, http.StatusConflict, "Nomor HP sudah terdaftar")
		return
	}
	if ctrl.regService.IsEmailRegistered(req.Email) {
		utils.ErrorResponse(c, http.StatusConflict, "Email sudah terdaftar")
		return
	}

	if !isGoogleRegistration {
		if req.Password == "" || req.Password != req.ConfirmPassword {
			utils.ErrorResponse(c, http.StatusBadRequest, "Password tidak valid atau konfirmasi tidak cocok")
			return
		}
	}
	if message := validateOutletBusinessProfile(
		req.Outlet.TipeLokasiUsaha,
		req.Outlet.ModalUsaha,
		req.Outlet.JumlahKaryawan,
		req.Outlet.JumlahMesin,
	); message != "" {
		utils.ErrorResponse(c, http.StatusBadRequest, message)
		return
	}

	user := model.User{
		Nama:     req.Username,
		Email:    req.Email,
		NoHP:     &req.NomorHP,
		GoogleID: req.GoogleID,
		AppleID:  req.AppleID,
		LeadSource: func() *string {
			leadSource := strings.TrimSpace(req.LeadSource)
			if leadSource == "" {
				return nil
			}
			return &leadSource
		}(),
	}

	finalPassword := req.Password
	if isGoogleRegistration && finalPassword == "" {
		finalPassword = utils.GenerateRandomString(16)
	}
	hashed, _ := utils.HashPassword(finalPassword)
	user.Password = &hashed

	outlet := model.Outlet{
		Nama:            req.Outlet.NamaOutlet,
		NoHP:            &req.Outlet.NomorHP,
		Provinsi:        &req.Outlet.Provinsi,
		Kota:            &req.Outlet.Kota,
		Kecamatan:       &req.Outlet.Kecamatan,
		Alamat:          &req.Outlet.Alamat,
		TipeLokasiUsaha: &req.Outlet.TipeLokasiUsaha,
		ModalUsaha:      &req.Outlet.ModalUsaha,
		JumlahKaryawan:  &req.Outlet.JumlahKaryawan,
		JumlahMesin:     &req.Outlet.JumlahMesin,
		TanggalBerjalan: func() *string {
			if req.Outlet.TanggalBerjalan == "" {
				return nil
			}
			s := req.Outlet.TanggalBerjalan
			return &s
		}(),
	}

	result, err := ctrl.regService.FinalRegister(user, outlet, req.ReferralCode)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyelesaikan pendaftaran: "+err.Error())
		return
	}

	if mailErr := ctrl.regService.SendWelcomeEmail(result); mailErr != nil {
		// Jangan gagal registrasi hanya karena email welcome gagal.
		// Log dicatat di backend agar bisa ditelusuri dari server.
		println("⚠️ welcome email gagal:", mailErr.Error())
	}

	utils.JSONResponse(c, http.StatusCreated, "Pendaftaran berhasil. Silakan login.", nil)
}
