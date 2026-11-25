package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

type RegisterService struct {
	db          *gorm.DB
	roleSvc     *RoleService
	parfumSvc   *ParfumService
	layananSvc  *LayananService
	katExpSvc   *KategoriPengeluaranService
	paySvc      *MetodePembayaranService
	itemSvc     *ItemService
	koinSvc     *KoinService
	referralSvc *ReferralService
	emailSvc    *EmailService
}

func NewRegisterService(
	db *gorm.DB,
	r *RoleService,
	p *ParfumService,
	l *LayananService,
	k *KategoriPengeluaranService,
	pay *MetodePembayaranService,
	i *ItemService,
	koin *KoinService,
	referral *ReferralService,
) *RegisterService {
	return &RegisterService{
		db:          db,
		roleSvc:     r,
		parfumSvc:   p,
		layananSvc:  l,
		katExpSvc:   k,
		paySvc:      pay,
		itemSvc:     i,
		koinSvc:     koin,
		referralSvc: referral,
		emailSvc:    NewEmailService(),
	}
}

type RegisterResult struct {
	User      model.User
	Outlet    model.Outlet
	BaseBonus int
}

func (s *RegisterService) FinalRegister(userData model.User, outletData model.Outlet, refCode string) (*RegisterResult, error) {
	result := &RegisterResult{}

	err := s.db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		var referrer *model.User

		// 1. VALIDASI & SIMPAN REFERRAL (hanya simpan ReferredBy, tidak ada reward saat daftar)
		if refCode != "" {
			var foundReferrer model.User
			if err := tx.Where("usr_referral_code = ?", strings.ToUpper(refCode)).First(&foundReferrer).Error; err != nil {
				if errors.Is(err, gorm.ErrRecordNotFound) {
					return fmt.Errorf("kode referral '%s' tidak valid", refCode)
				}
				return fmt.Errorf("error validasi referral: %v", err)
			}
			userData.ReferredBy = &foundReferrer.ID
			referrer = &foundReferrer
		}

		userData.ReferralCode = strings.ToUpper(utils.GenerateReferralCode(6))

		// 2. SIMPAN USER (OWNER)
		if err := tx.Create(&userData).Error; err != nil {
			return fmt.Errorf("gagal simpan user: %v", err)
		}

		// 3. HITUNG BONUS KOIN DARI CONFIG (flat, tidak ada tambahan bonus referral)
		var cfgBase model.EconomyConfig
		tx.Where("cfg_key = ?", "bonus_koin_new_user").First(&cfgBase)
		baseBonus := utils.StringToInt(cfgBase.Value)
		if baseBonus == 0 {
			baseBonus = 20
		}

		// 4. SETUP OUTLET (Trial & Limitasi Dasar)
		outletData.UserID = userData.ID
		outletData.ID = utils.GenOutletID(tx, userData.ID)
		outletData.Koin = baseBonus
		outletData.IsMetodePembayaran = 1
		outletData.IsFiturDiskon = 1
		outletData.TrialExpiresAt = now.AddDate(0, 0, 31)
		outletData.MaxPegawaiBase = 2
		outletData.ActivatedAt = nil

		if err := tx.Create(&outletData).Error; err != nil {
			return fmt.Errorf("gagal simpan outlet: %v", err)
		}

		// 5. SIMPAN RIWAYAT KOIN UNTUK USER BARU
		ownerIDStr := strconv.FormatUint(uint64(userData.ID), 10)
		ketKoin := fmt.Sprintf("Bonus pendaftaran outlet baru (+%d)", baseBonus)

		if err := s.koinSvc.AddHistoryKoin(tx, outletData.ID, "masuk", baseBonus, ketKoin, ownerIDStr); err != nil {
			return fmt.Errorf("gagal mencatat riwayat koin: %v", err)
		}

		// 6. NOTIFIKASI SELAMAT DATANG USER BARU
		welcomeNotifID := utils.GenNotifID()
		welcomeTitle := utils.CleanNotificationText("Akun AyoCuci Siap Digunakan", "Notifikasi AyoCuci")
		welcomeMessage := utils.CleanNotificationText(
			fmt.Sprintf("Akun laundry kamu sudah aktif. Kamu mendapat %d koin bonus dan trial 30 hari. Mulai atur layanan, pelanggan, dan transaksi dari satu aplikasi.", baseBonus),
			"Akun laundry kamu sudah aktif. Mulai kelola operasional laundry dari AyoCuci.",
		)
		tx.Exec(`INSERT INTO ac_notif_master (nm_id, nm_kategori, nm_judul, nm_pesan, nm_userupdate, nm_created) 
			VALUES (?, 'SISTEM', ?, ?, 'SYSTEM', NOW())`,
			welcomeNotifID,
			welcomeTitle,
			welcomeMessage,
		)
		tx.Exec(`INSERT INTO ac_notif_receiver (nr_nm_id, nr_outlet, nr_status) VALUES (?, ?, 0)`, welcomeNotifID, outletData.ID)

		if referrer != nil {
			if err := s.referralSvc.NotifyReferralCodeUsed(tx, referrer.ID, userData.Nama); err != nil {
				fmt.Printf("Gagal membuat notifikasi referral digunakan: %v\n", err)
			}
		}

		// 7. SEEDER DATA DEFAULT
		if err := s.roleSvc.CreateDefaultRoles(tx, outletData.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat role default: %v", err)
		}
		if err := s.parfumSvc.CreateDefaultParfums(tx, outletData.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat parfum default: %v", err)
		}
		if err := s.layananSvc.CreateDefaultLayanans(tx, outletData.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat layanan default: %v", err)
		}
		if err := s.katExpSvc.CreateDefaultCategories(tx, outletData.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat kategori pengeluaran default: %v", err)
		}
		if err := s.paySvc.CreateDefaultMethods(tx, outletData.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat metode pembayaran default: %v", err)
		}
		if err := s.itemSvc.CreateDefaultItems(tx, outletData.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat item default: %v", err)
		}

		result.User = userData
		result.Outlet = outletData
		result.BaseBonus = baseBonus

		return nil
	})

	if err != nil {
		return nil, err
	}

	return result, nil
}

func (s *RegisterService) SendWelcomeEmail(result *RegisterResult) error {
	if result == nil {
		return nil
	}

	email := strings.TrimSpace(result.User.Email)
	if email == "" {
		return nil
	}

	var existing model.EmailDispatchLog
	err := s.db.
		Where("edl_category = ? AND edl_user_id = ? AND edl_status = ?", "welcome_account", result.User.ID, "sent").
		Order("edl_id DESC").
		First(&existing).Error
	if err == nil {
		return nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return err
	}

	sendResult, sendErr := s.emailSvc.SendWelcomeEmail(
		email,
		result.User.Nama,
		result.Outlet.Nama,
		result.BaseBonus,
	)

	logStatus := "sent"
	provider := "resend"
	var providerID *string
	var message *string
	now := time.Now()
	sentAt := &now

	if sendResult != nil {
		provider = sendResult.Provider
		if id := strings.TrimSpace(sendResult.ID); id != "" {
			providerID = &id
		}
		if reason := strings.TrimSpace(sendResult.Reason); reason != "" {
			message = &reason
		}
	}

	if sendErr != nil {
		logStatus = "failed"
		sentAt = nil
		msg := sendErr.Error()
		message = &msg
	}

	outletID := result.Outlet.ID
	entry := model.EmailDispatchLog{
		Category:     "welcome_account",
		Email:        email,
		UserID:       &result.User.ID,
		OutletID:     &outletID,
		DispatchDate: time.Now().Format("2006-01-02"),
		Status:       logStatus,
		Subject:      "Selamat Datang di AyoCuci",
		Provider:     provider,
		ProviderID:   providerID,
		Message:      message,
		SentAt:       sentAt,
	}
	if createErr := s.db.Create(&entry).Error; createErr != nil {
		return createErr
	}

	return sendErr
}

func (s *RegisterService) CheckReferralCode(code string) (model.User, error) {
	var referrer model.User
	err := s.db.Where("usr_referral_code = ?", strings.ToUpper(code)).First(&referrer).Error
	if err != nil {
		return referrer, errors.New("kode referral tidak ditemukan")
	}
	return referrer, nil
}

func candidatePhoneDigits(phone string) []string {
	normalized := NormalizePhoneForOTP(phone)
	candidates := []string{normalized}

	if strings.HasPrefix(normalized, "62") && len(normalized) > 2 {
		local := "0" + normalized[2:]
		bare := normalized[2:]
		candidates = append(candidates, local, bare)
	}

	seen := make(map[string]struct{}, len(candidates))
	deduped := make([]string, 0, len(candidates))
	for _, candidate := range candidates {
		candidate = strings.TrimSpace(candidate)
		if candidate == "" {
			continue
		}
		if _, exists := seen[candidate]; exists {
			continue
		}
		seen[candidate] = struct{}{}
		deduped = append(deduped, candidate)
	}

	return deduped
}

func (s *RegisterService) IsPhoneRegistered(phone string) bool {
	var count int64
	candidates := candidatePhoneDigits(phone)
	if len(candidates) == 0 {
		return false
	}

	s.db.Model(&model.User{}).
		Where("REGEXP_REPLACE(COALESCE(usr_nohp, ''), '[^0-9]', '') IN ?", candidates).
		Count(&count)
	return count > 0
}

func (s *RegisterService) IsEmailRegistered(email string) bool {
	var count int64
	s.db.Model(&model.User{}).Where("usr_email = ?", email).Count(&count)
	return count > 0
}
