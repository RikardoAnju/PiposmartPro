package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/thirdparty/fonnte"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"math/rand"
	"strings"
	"sync"
	"time"

	"gorm.io/gorm"
)

type otpEntry struct {
	Code      string
	ExpiresAt time.Time
}

// Simpan OTP sementara (di produksi sebaiknya pakai Redis)
var (
	otpStorage = make(map[string]otpEntry)
	otpMu      sync.RWMutex
)

type OTPService struct {
	db       *gorm.DB
	emailSvc *EmailService
}

type PhoneValidationResult struct {
	Phone             string
	VerificationToken string
	Provider          string
	Reason            string
}

func NewOTPService(db *gorm.DB) *OTPService {
	return &OTPService{
		db:       db,
		emailSvc: NewEmailService(),
	}
}

func generateOTPCode() string {
	rng := rand.New(rand.NewSource(time.Now().UnixNano()))
	return fmt.Sprintf("%04d", rng.Intn(10000))
}

func normalizeFlow(flow string) string {
	flow = strings.TrimSpace(strings.ToLower(flow))
	flow = strings.ReplaceAll(flow, " ", "_")
	if flow == "" {
		return "unknown"
	}
	return flow
}

func NormalizePhoneForOTP(phone string) string {
	digits := strings.Map(func(r rune) rune {
		if r >= '0' && r <= '9' {
			return r
		}
		return -1
	}, phone)

	switch {
	case strings.HasPrefix(digits, "62"):
		return digits
	case strings.HasPrefix(digits, "0"):
		return "62" + digits[1:]
	case strings.HasPrefix(digits, "8"):
		return "62" + digits
	default:
		return digits
	}
}

func (s *OTPService) storeOTP(phone, code string) {
	otpMu.Lock()
	defer otpMu.Unlock()
	otpStorage[phone] = otpEntry{
		Code:      code,
		ExpiresAt: time.Now().Add(5 * time.Minute),
	}
}

func (s *OTPService) logEvent(phone string, email *string, flow, event, message string, otpCode *string) {
	s.logEventWithProvider(phone, email, flow, event, "fonnte", message, otpCode)
}

// providerOutageSignatures are substrings seen in Fonnte's own error text when
// the *provider's* linked WhatsApp sending device has a problem — as opposed
// to the target phone number genuinely being invalid/unregistered. These
// failures affect every request regardless of which number is being checked,
// so they're logged under a distinct event to make them easy to spot/filter
// in the admin OTP log rather than getting lost among ordinary rejections.
var providerOutageSignatures = []string{
	"device disconnected",
	"device not found",
	"device is not connected",
	"device tidak terhubung",
	"device belum terhubung",
	"device offline",
	"temporarily unavailable",
	"service unavailable",
	"bad gateway",
	"gateway timeout",
	"unauthorized",
}

func isProviderOutageMessage(message string) bool {
	lower := strings.ToLower(message)
	for _, signature := range providerOutageSignatures {
		if strings.Contains(lower, signature) {
			return true
		}
	}
	return false
}

func (s *OTPService) logEventWithProvider(phone string, email *string, flow, event, provider, message string, otpCode *string) {
	if s.db == nil {
		return
	}

	resolvedEvent := strings.TrimSpace(strings.ToLower(event))
	if strings.HasSuffix(resolvedEvent, "_failed") && isProviderOutageMessage(message) {
		resolvedEvent = "provider_disconnected"
	}

	entry := model.OTPRequestLog{
		Phone:    phone,
		Email:    email,
		Flow:     normalizeFlow(flow),
		Event:    resolvedEvent,
		Provider: strings.TrimSpace(provider),
		OTPCode:  otpCode,
		Message:  message,
	}

	if err := s.db.Create(&entry).Error; err != nil {
		fmt.Printf("⚠️ OTP log failed: %v\n", err)
	}
}

func (s *OTPService) getOTP(phone string) (otpEntry, bool) {
	otpMu.RLock()
	defer otpMu.RUnlock()

	entry, ok := otpStorage[phone]
	return entry, ok
}

func (s *OTPService) deleteOTP(phone string) {
	otpMu.Lock()
	defer otpMu.Unlock()
	delete(otpStorage, phone)
}

func (s *OTPService) ValidateWhatsAppNumber(phone, flow string) (*PhoneValidationResult, error) {
	normalizedPhone := NormalizePhoneForOTP(phone)
	result, err := fonnte.ValidateWhatsApp(normalizedPhone)
	if err != nil {
		provider := "fonnte"
		failureSummary := err.Error()
		if result != nil {
			provider = result.Provider
			failureSummary = result.Summary()
		}

		// Registrasi tidak boleh ikut lumpuh ketika device/provider Fonnte sedang
		// unavailable. Hanya outage provider yang dibuat fail-open; respons valid
		// bahwa nomor memang tidak terdaftar tetap ditolak di bawah.
		if isProviderOutageMessage(failureSummary + " " + err.Error()) {
			verificationToken, tokenErr := utils.GenerateRegistrationTicket(
				"phone_registration",
				"",
				"",
				normalizedPhone,
			)
			if tokenErr != nil {
				s.logEventWithProvider(normalizedPhone, nil, flow, "validate_failed", provider, "gagal membuat verification token saat provider unavailable", nil)
				return nil, tokenErr
			}

			s.logEventWithProvider(normalizedPhone, nil, flow, "validation_bypassed", provider, failureSummary, nil)
			return &PhoneValidationResult{
				Phone:             normalizedPhone,
				VerificationToken: verificationToken,
				Provider:          provider,
				Reason:            "provider_unavailable",
			}, nil
		}

		if result != nil {
			s.logEventWithProvider(normalizedPhone, nil, flow, "validate_failed", provider, failureSummary, nil)
			if result.Reason != "" {
				return nil, errors.New(result.Reason)
			}
		} else {
			s.logEvent(normalizedPhone, nil, flow, "validate_failed", err.Error(), nil)
		}
		return nil, err
	}

	verificationToken, tokenErr := utils.GenerateRegistrationTicket(
		"phone_registration",
		"",
		"",
		normalizedPhone,
	)
	if tokenErr != nil {
		s.logEventWithProvider(normalizedPhone, nil, flow, "validate_failed", result.Provider, "gagal membuat verification token", nil)
		return nil, tokenErr
	}

	s.logEventWithProvider(normalizedPhone, nil, flow, "validated", result.Provider, result.Summary(), nil)
	return &PhoneValidationResult{
		Phone:             normalizedPhone,
		VerificationToken: verificationToken,
		Provider:          result.Provider,
		Reason:            result.Reason,
	}, nil
}

// / Generate dan kirim OTP dengan pesan standar
func (s *OTPService) GenerateAndSendOTP(phone string, flow string) error {
	normalizedPhone := NormalizePhoneForOTP(phone)
	code := generateOTPCode()
	message := fmt.Sprintf("Kode OTP AyoCuci Anda adalah: %s. Berlaku selama 5 menit.", code)

	result, err := fonnte.SendWhatsApp(normalizedPhone, message)
	if err != nil {
		if result != nil {
			s.logEventWithProvider(normalizedPhone, nil, flow, "send_failed", result.Provider, result.Summary(), nil)
		} else {
			s.logEvent(normalizedPhone, nil, flow, "send_failed", err.Error(), nil)
		}
		return err
	}

	s.storeOTP(normalizedPhone, code)
	s.logEventWithProvider(normalizedPhone, nil, flow, "sent", result.Provider, result.Summary(), &code)
	return nil
}

// / Generate dan kirim OTP beserta info email (UX Friendly)
func (s *OTPService) GenerateAndSendOTPWithEmail(phone string, email string, flow string) error {
	normalizedPhone := NormalizePhoneForOTP(phone)
	trimmedEmail := strings.TrimSpace(email)
	code := generateOTPCode()
	message := fmt.Sprintf(
		"Kode OTP AyoCuci Anda: %s.\nDigunakan untuk reset password akun: %s.\nBerlaku selama 5 menit.",
		code,
		trimmedEmail,
	)

	var delivered bool
	var failureReasons []string

	emailResult, emailErr := s.emailSvc.SendForgotPasswordOTP(trimmedEmail, code)
	if emailErr != nil {
		if emailResult != nil {
			s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", emailResult.Provider, emailResult.Summary(), nil)
			failureReasons = append(failureReasons, emailResult.Summary())
		} else {
			s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", "resend", emailErr.Error(), nil)
			failureReasons = append(failureReasons, emailErr.Error())
		}
	} else {
		delivered = true
		s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "sent", emailResult.Provider, emailResult.Summary(), &code)
	}

	result, err := fonnte.SendWhatsApp(normalizedPhone, message)
	if err != nil {
		if result != nil {
			s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", result.Provider, result.Summary(), nil)
			failureReasons = append(failureReasons, result.Summary())
		} else {
			s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", "fonnte", err.Error(), nil)
			failureReasons = append(failureReasons, err.Error())
		}
	} else {
		delivered = true
		s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "sent", result.Provider, result.Summary(), &code)
	}

	if !delivered {
		if len(failureReasons) == 0 {
			return errors.New("gagal mengirim OTP")
		}
		return fmt.Errorf("gagal mengirim OTP: %s", strings.Join(failureReasons, " || "))
	}

	s.storeOTP(normalizedPhone, code)
	return nil
}

func (s *OTPService) GenerateAndSendOTPByChannel(phone string, email string, channel string, flow string) error {
	normalizedPhone := NormalizePhoneForOTP(phone)
	trimmedEmail := strings.TrimSpace(email)
	channel = strings.TrimSpace(strings.ToLower(channel))
	code := generateOTPCode()

	switch channel {
	case "email":
		emailResult, emailErr := s.emailSvc.SendForgotPasswordOTP(trimmedEmail, code)
		if emailErr != nil {
			if emailResult != nil {
				s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", emailResult.Provider, emailResult.Summary(), nil)
			} else {
				s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", "resend", emailErr.Error(), nil)
			}
			return emailErr
		}
		s.storeOTP(normalizedPhone, code)
		s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "sent", emailResult.Provider, emailResult.Summary(), &code)
		return nil
	case "whatsapp":
		message := fmt.Sprintf(
			"Kode OTP AyoCuci Anda: %s.\nDigunakan untuk reset password akun: %s.\nBerlaku selama 5 menit.",
			code,
			trimmedEmail,
		)
		result, err := fonnte.SendWhatsApp(normalizedPhone, message)
		if err != nil {
			if result != nil {
				s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", result.Provider, result.Summary(), nil)
			} else {
				s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "send_failed", "fonnte", err.Error(), nil)
			}
			return err
		}
		s.storeOTP(normalizedPhone, code)
		s.logEventWithProvider(normalizedPhone, &trimmedEmail, flow, "sent", result.Provider, result.Summary(), &code)
		return nil
	default:
		return errors.New("kanal OTP tidak valid")
	}
}

// / VerifyOTP yang mendukung alur multi-step
// / persist: jika true, OTP tidak akan dihapus dari storage (digunakan untuk step verifikasi tengah)
func (s *OTPService) VerifyOTP(phone, code string, persist bool, flow string) bool {
	normalizedPhone := NormalizePhoneForOTP(phone)
	saved, exists := s.getOTP(normalizedPhone)
	if !exists {
		s.logEvent(normalizedPhone, nil, flow, "verify_failed", "OTP tidak ditemukan", nil)
		return false
	}

	if time.Now().After(saved.ExpiresAt) {
		s.deleteOTP(normalizedPhone)
		s.logEvent(normalizedPhone, nil, flow, "verify_failed", "OTP kedaluwarsa", nil)
		return false
	}

	if saved.Code != code {
		s.logEvent(normalizedPhone, nil, flow, "verify_failed", "Kode OTP salah", nil)
		return false
	}

	// Hapus hanya jika TIDAK persist (tahap akhir/reset final)
	if !persist {
		s.deleteOTP(normalizedPhone)
	}

	s.logEvent(normalizedPhone, nil, flow, "verify_success", "OTP terverifikasi", nil)
	return true
}
