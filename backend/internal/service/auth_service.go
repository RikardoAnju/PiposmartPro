package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"bytes"
	"crypto/rsa"
	"crypto/subtle"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"gorm.io/gorm"
)

type accountDeletionSnapshot struct {
	ActorStatus        *int     `json:"actor_status,omitempty"`
	ActorCreatedAt     *string  `json:"actor_created_at,omitempty"`
	LeadSource         *string  `json:"lead_source,omitempty"`
	ReferralCode       *string  `json:"referral_code,omitempty"`
	RoleID             *string  `json:"role_id,omitempty"`
	RoleName           *string  `json:"role_name,omitempty"`
	OutletID           *string  `json:"outlet_id,omitempty"`
	OutletName         *string  `json:"outlet_name,omitempty"`
	OutletCount        int      `json:"outlet_count,omitempty"`
	OutletIDs          []string `json:"outlet_ids,omitempty"`
	OutletNames        []string `json:"outlet_names,omitempty"`
	PegawaiCount       int64    `json:"pegawai_count,omitempty"`
	TotalKoin          int64    `json:"total_koin,omitempty"`
	AccountType        *string  `json:"account_type,omitempty"`
	ActiveUntil        *string  `json:"active_until,omitempty"`
	IsMasterAdmin      *bool    `json:"is_master_admin,omitempty"`
	AffectedOutletData bool     `json:"affected_outlet_data,omitempty"`
}

type accountDeletionRecord struct {
	ActorName  string
	ActorEmail string
	ActorPhone string
	Snapshot   string
}

func optionalString(value string) *string {
	value = strings.TrimSpace(value)
	if value == "" {
		return nil
	}
	return &value
}

func formatTimePointer(value *time.Time) *string {
	if value == nil || value.IsZero() {
		return nil
	}
	formatted := value.Format(time.RFC3339)
	return &formatted
}

func deleteAccountOutletCommerceData(tx *gorm.DB, outletID string) error {
	if err := tx.Exec(`
		DELETE dt FROM ac_detail_transaksi dt
		JOIN ac_transaksi t ON t.tr_id = dt.dtr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("gagal menghapus detail transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE it FROM ac_item_transaksi it
		JOIN ac_transaksi t ON t.tr_id = it.itr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("gagal menghapus item transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE dp FROM ac_dp_transaksi dp
		JOIN ac_transaksi t ON t.tr_id = dp.dptr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("gagal menghapus dp transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE lt FROM ac_log_transaksi lt
		JOIN ac_transaksi t ON t.tr_id = lt.lr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("gagal menghapus log transaksi: %w", err)
	}

	if err := tx.Where("tr_outlet = ?", outletID).Delete(&model.Transaksi{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE dt FROM ac_detail_transaksi_addons dt
		JOIN ac_transaksi_addons t ON t.ha_id = dt.dha_transaksi
		WHERE t.ha_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("gagal menghapus detail transaksi addon: %w", err)
	}

	if err := tx.Where("ha_outlet = ?", outletID).Delete(&model.TransaksiAddon{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus transaksi addon: %w", err)
	}

	if err := tx.Where("ha_outlet = ?", outletID).Delete(&model.HistoryAddon{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus histori addon: %w", err)
	}

	return nil
}

func deleteAccountOutletOperationalData(tx *gorm.DB, outletID string) error {
	if err := tx.Where("pl_outlet = ?", outletID).Delete(&model.Pelanggan{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus pelanggan: %w", err)
	}
	if err := tx.Where("pg_outlet = ?", outletID).Delete(&model.Pengeluaran{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus pengeluaran: %w", err)
	}
	if err := tx.Where("hk_outlet = ?", outletID).Delete(&model.HistoryKoin{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus histori koin: %w", err)
	}
	if err := tx.Where("tk_outlet = ?", outletID).Delete(&model.TopupKoin{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus top up koin: %w", err)
	}
	if err := tx.Where("dis_outlet = ?", outletID).Delete(&model.Diskon{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus diskon: %w", err)
	}
	if err := tx.Where("nr_outlet = ?", outletID).Delete(&model.NotifReceiver{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus notifikasi outlet: %w", err)
	}
	if err := tx.Where("pt_outlet = ?", outletID).Delete(&model.PushToken{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus push token outlet: %w", err)
	}
	if err := tx.Where("pg_outlet = ?", outletID).Delete(&model.Pegawai{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus pegawai: %w", err)
	}
	if err := tx.Unscoped().Where("jp_layanan IN (SELECT ly_id FROM ac_layanan WHERE ly_outlet = ?)", outletID).Delete(&model.JenisProduk{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus jenis produk: %w", err)
	}
	if err := tx.Where("ly_outlet = ?", outletID).Delete(&model.Layanan{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus layanan: %w", err)
	}
	if err := tx.Where("it_outlet = ?", outletID).Delete(&model.Item{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus item: %w", err)
	}
	if err := tx.Where("pf_outlet = ?", outletID).Delete(&model.Parfum{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus parfum: %w", err)
	}
	if err := tx.Where("mp_outlet = ?", outletID).Delete(&model.MetodePembayaran{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus metode pembayaran: %w", err)
	}
	if err := tx.Where("kp_outlet = ?", outletID).Delete(&model.KategoriPengeluaran{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus kategori pengeluaran: %w", err)
	}
	if err := tx.Where("rl_outlet = ?", outletID).Delete(&model.Role{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus role outlet: %w", err)
	}
	return nil
}

func deleteUserReferralData(tx *gorm.DB, userID uint) error {
	if err := tx.Exec(`
		DELETE rpi FROM ac_referral_payout_items rpi
		JOIN ac_referral_rewards rr ON rr.rr_id = rpi.rpi_reward_id
		WHERE rr.rr_referrer_user = ? OR rr.rr_referred_user = ?`, userID, userID).Error; err != nil {
		return fmt.Errorf("gagal menghapus item payout referral: %w", err)
	}
	if err := tx.Exec(`
		DELETE rpi FROM ac_referral_payout_items rpi
		JOIN ac_referral_payout_requests rp ON rp.rp_id = rpi.rpi_payout_id
		WHERE rp.rp_user = ?`, userID).Error; err != nil {
		return fmt.Errorf("gagal menghapus item payout request referral: %w", err)
	}
	if err := tx.Where("rr_referrer_user = ? OR rr_referred_user = ?", userID, userID).Delete(&model.ReferralReward{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus reward referral: %w", err)
	}
	if err := tx.Where("rwh_user = ?", userID).Delete(&model.ReferralWalletHistory{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus wallet history referral: %w", err)
	}
	if err := tx.Where("rp_user = ?", userID).Delete(&model.ReferralPayoutRequest{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus payout referral: %w", err)
	}
	if err := tx.Where("rpa_user = ?", userID).Delete(&model.ReferralPayoutAccount{}).Error; err != nil {
		return fmt.Errorf("gagal menghapus rekening payout referral: %w", err)
	}
	return nil
}

func (s *AuthService) buildAccountDeletionRecord(tx *gorm.DB, actorID string, actorType string) (*accountDeletionRecord, error) {
	switch actorType {
	case "user":
		var user model.User
		if err := tx.Where("usr_id = ?", actorID).First(&user).Error; err != nil {
			return nil, err
		}

		var outlets []model.Outlet
		if err := tx.Where("ot_user = ?", user.ID).Find(&outlets).Error; err != nil {
			return nil, err
		}

		outletIDs := make([]string, 0, len(outlets))
		outletNames := make([]string, 0, len(outlets))
		var totalKoin int64
		for _, outlet := range outlets {
			outletIDs = append(outletIDs, outlet.ID)
			outletNames = append(outletNames, outlet.Nama)
			totalKoin += int64(outlet.Koin)
		}

		var pegawaiCount int64
		if len(outletIDs) > 0 {
			if err := tx.Model(&model.Pegawai{}).Where("pg_outlet IN ?", outletIDs).Count(&pegawaiCount).Error; err != nil {
				return nil, err
			}
		}

		status := user.Status
		createdAt := user.CreatedAt.Format(time.RFC3339)
		snapshotBytes, err := json.Marshal(accountDeletionSnapshot{
			ActorStatus:        &status,
			ActorCreatedAt:     &createdAt,
			LeadSource:         user.LeadSource,
			ReferralCode:       optionalString(user.ReferralCode),
			OutletCount:        len(outlets),
			OutletIDs:          outletIDs,
			OutletNames:        outletNames,
			PegawaiCount:       pegawaiCount,
			TotalKoin:          totalKoin,
			AffectedOutletData: len(outlets) > 0,
		})
		if err != nil {
			return nil, err
		}

		record := &accountDeletionRecord{
			ActorName:  user.Nama,
			ActorEmail: user.Email,
			Snapshot:   string(snapshotBytes),
		}
		if user.NoHP != nil {
			record.ActorPhone = *user.NoHP
		}
		return record, nil

	case "pegawai":
		var pegawai model.Pegawai
		if err := tx.Preload("Role").Preload("Outlet").Where("pg_id = ?", actorID).First(&pegawai).Error; err != nil {
			return nil, err
		}

		status := pegawai.Status
		createdAt := pegawai.CreatedAt.Format(time.RFC3339)
		accountType := pegawai.Type
		var roleID *string
		if pegawai.RoleID != "" {
			roleID = &pegawai.RoleID
		}
		var roleName *string
		if pegawai.Role != nil && strings.TrimSpace(pegawai.Role.Nama) != "" {
			roleName = &pegawai.Role.Nama
		}
		var outletName *string
		if pegawai.Outlet != nil && strings.TrimSpace(pegawai.Outlet.Nama) != "" {
			outletName = &pegawai.Outlet.Nama
		}

		snapshotBytes, err := json.Marshal(accountDeletionSnapshot{
			ActorStatus:    &status,
			ActorCreatedAt: &createdAt,
			RoleID:         roleID,
			RoleName:       roleName,
			OutletID:       optionalString(pegawai.OutletID),
			OutletName:     outletName,
			AccountType:    &accountType,
			ActiveUntil:    formatTimePointer(pegawai.ActiveUntil),
		})
		if err != nil {
			return nil, err
		}

		return &accountDeletionRecord{
			ActorName:  pegawai.Nama,
			ActorEmail: pegawai.Email,
			ActorPhone: pegawai.NoHP,
			Snapshot:   string(snapshotBytes),
		}, nil

	case "admin":
		var admin model.Admin
		if err := tx.Preload("Role").Where("adm_id = ?", actorID).First(&admin).Error; err != nil {
			return nil, err
		}

		createdAt := admin.CreatedAt.Format(time.RFC3339)
		var roleID *string
		if admin.RoleID != nil && strings.TrimSpace(*admin.RoleID) != "" {
			roleID = admin.RoleID
		}
		var roleName *string
		if admin.Role != nil && strings.TrimSpace(admin.Role.Nama) != "" {
			roleName = &admin.Role.Nama
		}
		isMaster := admin.IsMaster
		snapshotBytes, err := json.Marshal(accountDeletionSnapshot{
			ActorCreatedAt: &createdAt,
			RoleID:         roleID,
			RoleName:       roleName,
			IsMasterAdmin:  &isMaster,
		})
		if err != nil {
			return nil, err
		}

		return &accountDeletionRecord{
			ActorName:  admin.Nama,
			ActorEmail: admin.Email,
			Snapshot:   string(snapshotBytes),
		}, nil
	}

	return &accountDeletionRecord{}, nil
}

type AuthService struct {
	db *gorm.DB
}

type ForgotPasswordAccount struct {
	AccountType  string `json:"account_type"`
	Name         string `json:"name"`
	Email        string `json:"email"`
	Phone        string `json:"phone"`
	MaskedEmail  string `json:"masked_email"`
	MaskedPhone  string `json:"masked_phone"`
	CanSendEmail bool   `json:"can_send_email"`
	CanSendWA    bool   `json:"can_send_whatsapp"`
}

var (
	appleJWKSOnce sync.Once
	appleJWKS     map[string]*rsa.PublicKey
	appleJWKSErr  error
)

func NewAuthService(db *gorm.DB) *AuthService {
	return &AuthService{db: db}
}

func maskEmail(email string) string {
	email = strings.TrimSpace(strings.ToLower(email))
	parts := strings.Split(email, "@")
	if len(parts) != 2 {
		return email
	}
	local := parts[0]
	domain := parts[1]
	if len(local) <= 2 {
		return local[:1] + "***@" + domain
	}
	return local[:3] + "*****@" + domain
}

func maskPhone(phone string) string {
	phone = NormalizePhoneForOTP(phone)
	if len(phone) <= 6 {
		return phone
	}
	return phone[:4] + "****" + phone[len(phone)-3:]
}

// Login menangani autentikasi Owner dan Pegawai dengan deteksi outlet terakhir
func (s *AuthService) Login(email, password string) (interface{}, string, string, bool, string, interface{}, error) {
	var user model.User
	var pegawai model.Pegawai
	var outletID string
	var hasOutlet bool
	var roleName string

	// 1. CARI SEBAGAI OWNER (AC_USER)
	err := s.db.Where("usr_email = ?", email).First(&user).Error
	if err == nil {
		if !utils.CheckPasswordHash(password, *user.Password) {
			return nil, "", "", false, "", nil, errors.New("password salah")
		}

		roleName = "Owner"

		if user.LastOutletID != nil {
			outletID = *user.LastOutletID
		}

		var totalOutlets int64
		s.db.Model(&model.Outlet{}).Where("ot_user = ?", user.ID).Count(&totalOutlets)

		var targetOutlet model.Outlet
		query := s.db.Where("ot_user = ? AND ot_status = 1", user.ID)
		if user.LastOutletID != nil {
			query = query.Order(gorm.Expr("CASE WHEN ot_id = ? THEN 0 ELSE 1 END", *user.LastOutletID))
		}

		if errOutlet := query.First(&targetOutlet).Error; errOutlet == nil {
			hasOutlet = true
			outletID = targetOutlet.ID
			if user.LastOutletID == nil || *user.LastOutletID != targetOutlet.ID {
				s.db.Model(&user).Update("usr_last_outlet", targetOutlet.ID)
			}
		} else {
			// Jika user punya outlet, tapi semuanya dinonaktifkan
			if totalOutlets > 0 {
				return nil, "", "", false, "", nil, errors.New("semua outlet Anda sedang dinonaktifkan, silakan hubungi admin")
			}
			// Jika belum punya outlet sama sekali
			if user.LastOutletID != nil {
				outletID = *user.LastOutletID
			}
		}

		permissions := map[string]interface{}{"all": []string{"*"}}

		userData := map[string]interface{}{
			"id":             user.ID,
			"nama":           user.Nama,
			"email":          user.Email,
			"nohp":           user.NoHP,
			"role_name":      roleName,
			"last_outlet_id": outletID,
		}

		claims := middleware.Claims{
			ActorID:     strconv.Itoa(int(user.ID)),
			ActorType:   "user",
			OutletID:    outletID,
			Permissions: `{"all": ["*"]}`,
		}

		token, errGen := utils.GenerateToken(claims)
		return userData, token, outletID, hasOutlet, "user", permissions, errGen
	}

	// 2. CARI SEBAGAI PEGAWAI (AC_PEGAWAI)
	err = s.db.Where("pg_email = ? AND pg_deleted_at IS NULL", email).First(&pegawai).Error
	if err == nil {
		if !utils.CheckPasswordHash(password, *pegawai.Password) {
			return nil, "", "", false, "", nil, errors.New("password salah")
		}
		if pegawai.Status != 1 {
			return nil, "", "", false, "", nil, errors.New("akun pegawai belum aktif. Hubungi pemilik outlet")
		}
		if pegawai.Type == "addon" && (pegawai.ActiveUntil == nil || !pegawai.ActiveUntil.After(time.Now())) {
			_ = s.db.Model(&model.Pegawai{}).
				Where("pg_id = ?", pegawai.ID).
				Updates(map[string]interface{}{
					"pg_status":        0,
					"pg_token_version": gorm.Expr("pg_token_version + 1"),
				}).Error
			return nil, "", "", false, "", nil, errors.New("add-on pegawai belum aktif atau masa aktifnya telah habis")
		}

		outletID = pegawai.OutletID
		if pegawai.AllOutletAccess && pegawai.LastOutletID != nil && *pegawai.LastOutletID != "" {
			var allowedCount int64
			errAccess := s.db.Table("ac_outlet target").
				Joins("JOIN ac_outlet primary_outlet ON primary_outlet.ot_id = ?", pegawai.OutletID).
				Where("target.ot_id = ? AND target.ot_user = primary_outlet.ot_user AND target.ot_status = 1", *pegawai.LastOutletID).
				Count(&allowedCount).Error
			if errAccess == nil && allowedCount > 0 {
				outletID = *pegawai.LastOutletID
			}
		}

		var targetOutlet model.Outlet
		if errOutlet := s.db.Where("ot_id = ?", outletID).First(&targetOutlet).Error; errOutlet != nil {
			return nil, "", "", false, "", nil, errors.New("outlet tidak ditemukan")
		}
		if targetOutlet.Status != 1 {
			return nil, "", "", false, "", nil, errors.New("outlet sedang dinonaktifkan")
		}

		var role model.Role
		if errRole := s.db.Where("rl_id = ?", pegawai.RoleID).First(&role).Error; errRole == nil {
			roleName = role.Nama
		} else {
			roleName = "Pegawai"
		}

		hasOutlet = true

		pegawaiData := map[string]interface{}{
			"id":                pegawai.ID,
			"outlet_id":         outletID,
			"primary_outlet_id": pegawai.OutletID,
			"role_id":           pegawai.RoleID,
			"role_name":         roleName,
			"nama":              pegawai.Nama,
			"email":             pegawai.Email,
			"nohp":              pegawai.NoHP,
			"status":            pegawai.Status,
			"all_outlet_access": pegawai.AllOutletAccess,
			"last_outlet_id":    pegawai.LastOutletID,
		}

		claims := middleware.Claims{
			ActorID:      pegawai.ID,
			ActorType:    "pegawai",
			OutletID:     outletID,
			RoleID:       pegawai.RoleID,
			Permissions:  string(role.Permission),
			TokenVersion: pegawai.TokenVersion,
		}

		token, errGen := utils.GenerateToken(claims)
		return pegawaiData, token, outletID, hasOutlet, "pegawai", role.Permission, errGen
	}

	return nil, "", "", false, "", nil, errors.New("akun tidak ditemukan atau tidak aktif")
}

// ImpersonateByEmail: login sebagai OWNER tanpa password, khusus build internal
// (lihat POV user untuk support/debug). DIGATE ketat oleh env IMPERSONATION_SECRET:
// jika kosong (mis. di prod yang tak mengaktifkannya), fitur nonaktif total.
// Setiap pemakaian dicatat ke log.
func (s *AuthService) ImpersonateByEmail(email, secret string) (interface{}, string, string, bool, string, interface{}, error) {
	expected := strings.TrimSpace(config.GetEnv("IMPERSONATION_SECRET", ""))
	if expected == "" {
		return nil, "", "", false, "", nil, errors.New("fitur impersonation tidak aktif")
	}
	if subtle.ConstantTimeCompare([]byte(strings.TrimSpace(secret)), []byte(expected)) != 1 {
		return nil, "", "", false, "", nil, errors.New("secret impersonation salah")
	}

	var user model.User
	if err := s.db.Where("usr_email = ?", strings.TrimSpace(email)).First(&user).Error; err != nil {
		return nil, "", "", false, "", nil, errors.New("akun user tidak ditemukan")
	}

	var outletID string
	var hasOutlet bool
	if user.LastOutletID != nil {
		outletID = *user.LastOutletID
	}
	var targetOutlet model.Outlet
	query := s.db.Where("ot_user = ?", user.ID)
	if user.LastOutletID != nil {
		query = query.Order(gorm.Expr("CASE WHEN ot_id = ? THEN 0 ELSE 1 END", *user.LastOutletID))
	}
	if errOutlet := query.First(&targetOutlet).Error; errOutlet == nil {
		hasOutlet = true
		if outletID == "" {
			outletID = targetOutlet.ID
		}
	}

	permissions := map[string]interface{}{"all": []string{"*"}}
	userData := map[string]interface{}{
		"id":             user.ID,
		"nama":           user.Nama,
		"email":          user.Email,
		"nohp":           user.NoHP,
		"role_name":      "Owner",
		"last_outlet_id": outletID,
	}
	claims := middleware.Claims{
		ActorID:     strconv.Itoa(int(user.ID)),
		ActorType:   "user",
		OutletID:    outletID,
		Permissions: `{"all": ["*"]}`,
	}
	token, errGen := utils.GenerateToken(claims)
	log.Printf("[IMPERSONATION] login sebagai user email=%s actor_id=%d outlet=%s", email, user.ID, outletID)
	return userData, token, outletID, hasOutlet, "user", permissions, errGen
}

// GoogleLogin menangani login via Google
func (s *AuthService) GoogleLogin(email, googleID, name string) (interface{}, string, string, bool, string, interface{}, error) {
	var user model.User
	var outletID string
	var hasOutlet bool
	roleName := "Owner"

	err := s.db.Where("usr_email = ?", email).First(&user).Error
	if err != nil {
		return nil, "", "", false, "", nil, errors.New("USER_NOT_FOUND")
	}

	if user.LastOutletID != nil {
		outletID = *user.LastOutletID
	}

	if user.GoogleID == nil || *user.GoogleID == "" {
		s.db.Model(&user).Update("usr_google_id", googleID)
	}

	var targetOutlet model.Outlet
	query := s.db.Where("ot_user = ?", user.ID)
	if user.LastOutletID != nil {
		query = query.Order(gorm.Expr("CASE WHEN ot_id = ? THEN 0 ELSE 1 END", *user.LastOutletID))
	}

	if errTrx := query.First(&targetOutlet).Error; errTrx == nil {
		hasOutlet = true
		if outletID == "" {
			outletID = targetOutlet.ID
		}
		if user.LastOutletID == nil {
			s.db.Model(&user).Update("usr_last_outlet", outletID)
		}
	}

	permissions := map[string]interface{}{"all": []string{"*"}}

	userData := map[string]interface{}{
		"id":             user.ID,
		"nama":           user.Nama,
		"email":          user.Email,
		"role_name":      roleName,
		"last_outlet_id": outletID,
	}

	claims := middleware.Claims{
		ActorID:     strconv.Itoa(int(user.ID)),
		ActorType:   "user",
		OutletID:    outletID,
		Permissions: `{"all": ["*"]}`,
	}

	token, _ := utils.GenerateToken(claims)
	return userData, token, outletID, hasOutlet, "user", permissions, nil
}

func (s *AuthService) AppleLogin(email, appleID, name string) (interface{}, string, string, bool, string, interface{}, error) {
	var user model.User
	var outletID string
	var hasOutlet bool
	roleName := "Owner"

	if err := s.db.Where("usr_apple_id = ?", appleID).First(&user).Error; err != nil {
		return nil, "", "", false, "", nil, errors.New("USER_NOT_FOUND")
	}

	if user.AppleID == nil || *user.AppleID == "" {
		s.db.Model(&user).Update("usr_apple_id", appleID)
	}

	if email != "" && !strings.EqualFold(user.Email, email) {
		s.db.Model(&user).Update("usr_email", email)
	}

	if user.LastOutletID != nil {
		outletID = *user.LastOutletID
	}

	var targetOutlet model.Outlet
	query := s.db.Where("ot_user = ?", user.ID)
	if user.LastOutletID != nil {
		query = query.Order(gorm.Expr("CASE WHEN ot_id = ? THEN 0 ELSE 1 END", *user.LastOutletID))
	}

	if errTrx := query.First(&targetOutlet).Error; errTrx == nil {
		hasOutlet = true
		if outletID == "" {
			outletID = targetOutlet.ID
		}
		if user.LastOutletID == nil {
			s.db.Model(&user).Update("usr_last_outlet", outletID)
		}
	}

	permissions := map[string]interface{}{"all": []string{"*"}}
	userData := map[string]interface{}{
		"id":             user.ID,
		"nama":           user.Nama,
		"email":          user.Email,
		"role_name":      roleName,
		"last_outlet_id": outletID,
	}

	claims := middleware.Claims{
		ActorID:     strconv.Itoa(int(user.ID)),
		ActorType:   "user",
		OutletID:    outletID,
		Permissions: `{"all": ["*"]}`,
	}

	token, _ := utils.GenerateToken(claims)
	return userData, token, outletID, hasOutlet, "user", permissions, nil
}

// RefreshToken memperbarui sesi
func (s *AuthService) RefreshToken(actorID string, actorType string) (string, error) {
	var outletID string
	var permissions string
	var roleID string
	var tokenVersion int

	switch actorType {
	case "user":
		var user model.User
		if err := s.db.First(&user, actorID).Error; err != nil {
			return "", err
		}

		if user.LastOutletID != nil {
			outletID = *user.LastOutletID
		} else {
			var firstOutlet model.Outlet
			if err := s.db.Where("ot_user = ?", user.ID).First(&firstOutlet).Error; err == nil {
				outletID = firstOutlet.ID
			}
		}
		permissions = `{"all": ["*"]}`
	case "pegawai":
		var pegawai model.Pegawai
		if err := s.db.Preload("Role").First(&pegawai, "pg_id = ?", actorID).Error; err != nil {
			return "", err
		}
		outletID = pegawai.OutletID
		if pegawai.AllOutletAccess && pegawai.LastOutletID != nil && *pegawai.LastOutletID != "" {
			var allowedCount int64
			err := s.db.Table("ac_outlet target").
				Joins("JOIN ac_outlet primary_outlet ON primary_outlet.ot_id = ?", pegawai.OutletID).
				Where("target.ot_id = ? AND target.ot_user = primary_outlet.ot_user AND target.ot_status = 1", *pegawai.LastOutletID).
				Count(&allowedCount).Error
			if err == nil && allowedCount > 0 {
				outletID = *pegawai.LastOutletID
			}
		}
		roleID = pegawai.RoleID
		permissions = string(pegawai.Role.Permission)
		tokenVersion = pegawai.TokenVersion
	case "admin":
		permissions = `{"all": ["*"]}`
	}

	claims := middleware.Claims{
		ActorID:      actorID,
		ActorType:    actorType,
		OutletID:     outletID,
		RoleID:       roleID,
		Permissions:  permissions,
		TokenVersion: tokenVersion,
	}

	return utils.GenerateToken(claims)
}

func (s *AuthService) GetEmailByPhone(phone string) (string, error) {
	var email string
	err := s.db.Table("ac_user").Select("usr_email").Where("usr_nohp = ?", phone).Scan(&email).Error
	if err == nil && email != "" {
		return email, nil
	}
	err = s.db.Table("ac_pegawai").Select("pg_email").Where("pg_nohp = ?", phone).Scan(&email).Error
	if err != nil || email == "" {
		return "", errors.New("email tidak ditemukan")
	}
	return email, nil
}

func (s *AuthService) FindForgotPasswordAccount(method, value string) (*ForgotPasswordAccount, error) {
	method = strings.TrimSpace(strings.ToLower(method))
	value = strings.TrimSpace(value)

	type userRow struct {
		Name  string
		Email string
		Phone string
	}

	var row userRow
	switch method {
	case "phone":
		phone := NormalizePhoneForOTP(value)
		err := s.db.Table("ac_user").
			Select("usr_nama as name, usr_email as email, usr_nohp as phone").
			Where("usr_nohp = ? AND usr_status = 1", phone).
			Scan(&row).Error
		if err == nil && strings.TrimSpace(row.Email) != "" {
			return &ForgotPasswordAccount{
				AccountType:  "user",
				Name:         row.Name,
				Email:        row.Email,
				Phone:        NormalizePhoneForOTP(row.Phone),
				MaskedEmail:  maskEmail(row.Email),
				MaskedPhone:  maskPhone(row.Phone),
				CanSendEmail: strings.TrimSpace(row.Email) != "",
				CanSendWA:    strings.TrimSpace(row.Phone) != "",
			}, nil
		}

		row = userRow{}
		err = s.db.Table("ac_pegawai").
			Select("pg_nama as name, pg_email as email, pg_nohp as phone").
			Where("pg_nohp = ? AND pg_status = 1", phone).
			Scan(&row).Error
		if err == nil && (strings.TrimSpace(row.Email) != "" || strings.TrimSpace(row.Phone) != "") {
			return &ForgotPasswordAccount{
				AccountType:  "pegawai",
				Name:         row.Name,
				Email:        row.Email,
				Phone:        NormalizePhoneForOTP(row.Phone),
				MaskedEmail:  maskEmail(row.Email),
				MaskedPhone:  maskPhone(row.Phone),
				CanSendEmail: strings.TrimSpace(row.Email) != "",
				CanSendWA:    strings.TrimSpace(row.Phone) != "",
			}, nil
		}
	case "email":
		err := s.db.Table("ac_user").
			Select("usr_nama as name, usr_email as email, usr_nohp as phone").
			Where("LOWER(usr_email) = LOWER(?) AND usr_status = 1", value).
			Scan(&row).Error
		if err == nil && strings.TrimSpace(row.Email) != "" {
			return &ForgotPasswordAccount{
				AccountType:  "user",
				Name:         row.Name,
				Email:        row.Email,
				Phone:        NormalizePhoneForOTP(row.Phone),
				MaskedEmail:  maskEmail(row.Email),
				MaskedPhone:  maskPhone(row.Phone),
				CanSendEmail: strings.TrimSpace(row.Email) != "",
				CanSendWA:    strings.TrimSpace(row.Phone) != "",
			}, nil
		}

		row = userRow{}
		err = s.db.Table("ac_pegawai").
			Select("pg_nama as name, pg_email as email, pg_nohp as phone").
			Where("LOWER(pg_email) = LOWER(?) AND pg_status = 1", value).
			Scan(&row).Error
		if err == nil && (strings.TrimSpace(row.Email) != "" || strings.TrimSpace(row.Phone) != "") {
			return &ForgotPasswordAccount{
				AccountType:  "pegawai",
				Name:         row.Name,
				Email:        row.Email,
				Phone:        NormalizePhoneForOTP(row.Phone),
				MaskedEmail:  maskEmail(row.Email),
				MaskedPhone:  maskPhone(row.Phone),
				CanSendEmail: strings.TrimSpace(row.Email) != "",
				CanSendWA:    strings.TrimSpace(row.Phone) != "",
			}, nil
		}
	}

	return nil, errors.New("akun tidak ditemukan")
}

func (s *AuthService) ValidateForgotPasswordAccount(email, phone string) (string, error) {
	var matchedEmail string
	phoneVariants := phoneLookupVariants(phone)

	err := s.db.Table("ac_user").
		Select("usr_email").
		Where("LOWER(usr_email) = LOWER(?) AND usr_nohp IN ?", email, phoneVariants).
		Scan(&matchedEmail).Error
	if err == nil && matchedEmail != "" {
		return matchedEmail, nil
	}

	err = s.db.Table("ac_pegawai").
		Select("pg_email").
		Where("LOWER(pg_email) = LOWER(?) AND pg_nohp IN ?", email, phoneVariants).
		Scan(&matchedEmail).Error
	if err == nil && matchedEmail != "" {
		return matchedEmail, nil
	}

	return "", errors.New("email dan nomor HP tidak cocok")
}

// phoneLookupVariants accepts the canonical OTP format (62...) and the
// legacy database format (08...), including a plus-prefixed international form.
func phoneLookupVariants(phone string) []string {
	canonical := NormalizePhoneForOTP(phone)
	variants := []string{canonical}
	if strings.HasPrefix(canonical, "62") && len(canonical) > 2 {
		variants = append(variants, "0"+canonical[2:], "+"+canonical)
	}
	return variants
}

func (s *AuthService) CheckPhoneExists(phone string) bool {
	var count int64
	s.db.Model(&model.User{}).Where("usr_nohp = ?", phone).Count(&count)
	if count > 0 {
		return true
	}
	s.db.Model(&model.Pegawai{}).Where("pg_nohp = ?", phone).Count(&count)
	return count > 0
}

func (s *AuthService) ResetPassword(phone, newPassword string) error {
	hashed, _ := utils.HashPassword(newPassword)

	res := s.db.Model(&model.User{}).Where("usr_nohp = ?", phone).Update("usr_password", hashed)
	if res.RowsAffected > 0 {
		return nil
	}

	res = s.db.Model(&model.Pegawai{}).Where("pg_nohp = ?", phone).Update("pg_password", hashed)
	if res.RowsAffected > 0 {
		return nil
	}

	return errors.New("gagal mengupdate password, akun tidak ditemukan")
}

func (s *AuthService) ResetPasswordByEmailAndPhone(email, phone, newPassword string) error {
	hashed, _ := utils.HashPassword(newPassword)

	res := s.db.Model(&model.User{}).
		Where("LOWER(usr_email) = LOWER(?) AND usr_nohp = ?", email, phone).
		Update("usr_password", hashed)
	if res.RowsAffected > 0 {
		return nil
	}

	res = s.db.Model(&model.Pegawai{}).
		Where("LOWER(pg_email) = LOWER(?) AND pg_nohp = ?", email, phone).
		Update("pg_password", hashed)
	if res.RowsAffected > 0 {
		return nil
	}

	return errors.New("gagal mengupdate password, akun tidak ditemukan")
}

func (s *AuthService) ChangePassword(userID string, oldPass, newPass string) error {
	var user model.User
	if err := s.db.Where("usr_id = ?", userID).First(&user).Error; err != nil {
		return errors.New("user tidak ditemukan")
	}

	if !utils.CheckPasswordHash(oldPass, *user.Password) {
		return errors.New("kata sandi lama yang Anda masukkan salah")
	}

	if oldPass == newPass {
		return errors.New("kata sandi baru tidak boleh sama dengan kata sandi lama")
	}

	hashed, _ := utils.HashPassword(newPass)
	return s.db.Model(&user).Update("usr_password", hashed).Error
}

func (s *AuthService) GetMe(actorID string, actorType string) (interface{}, error) {
	if actorType == "user" {
		var user model.User
		err := s.db.Where("usr_id = ?", actorID).First(&user).Error
		return user, err
	}
	var pegawai model.Pegawai
	err := s.db.Preload("Role").Where("pg_id = ?", actorID).First(&pegawai).Error
	return pegawai, err
}

func (s *AuthService) UpdateProfileOwner(userID string, updates map[string]interface{}) error {
	if rawPassword, ok := updates["usr_password"].(string); ok && rawPassword != "" {
		hashed, err := utils.HashPassword(rawPassword)
		if err != nil {
			return err
		}
		updates["usr_password"] = hashed
	} else {
		delete(updates, "usr_password")
	}
	return s.db.Model(&model.User{}).Where("usr_id = ?", userID).Updates(updates).Error
}

func (s *AuthService) DeleteAccount(actorID string, actorType string, reason string, reasonDetail string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		record, err := s.buildAccountDeletionRecord(tx, actorID, actorType)
		if err != nil {
			return err
		}

		if err := tx.Create(&model.AccountDeletion{
			ActorID:      actorID,
			ActorType:    actorType,
			ActorName:    record.ActorName,
			ActorEmail:   record.ActorEmail,
			ActorPhone:   record.ActorPhone,
			Reason:       reason,
			ReasonDetail: reasonDetail,
			Snapshot:     record.Snapshot,
		}).Error; err != nil {
			return err
		}

		if actorType == "user" {
			var outlets []model.Outlet
			if err := tx.Where("ot_user = ?", actorID).Find(&outlets).Error; err != nil {
				return err
			}
			for _, ot := range outlets {
				if err := deleteAccountOutletCommerceData(tx, ot.ID); err != nil {
					return err
				}
				if err := deleteAccountOutletOperationalData(tx, ot.ID); err != nil {
					return err
				}
			}

			var ownerUser model.User
			if err := tx.Where("usr_id = ?", actorID).First(&ownerUser).Error; err != nil {
				return err
			}
			if err := deleteUserReferralData(tx, ownerUser.ID); err != nil {
				return err
			}
			if err := tx.Where("pt_actor_id = ? AND pt_actor_type = ?", actorID, actorType).Delete(&model.PushToken{}).Error; err != nil {
				return err
			}
			if err := tx.Where("ot_user = ?", actorID).Delete(&model.Outlet{}).Error; err != nil {
				return err
			}
			return tx.Delete(&model.User{}, actorID).Error
		}
		if actorType == "admin" {
			return tx.Delete(&model.Admin{}, "adm_id = ?", actorID).Error
		}
		return tx.Delete(&model.Pegawai{}, "pg_id = ?", actorID).Error
	})
}

func AppleIdentityClaims(tokenString string) (map[string]any, error) {
	key, err := applePublicKeyFromToken(tokenString)
	if err != nil {
		return nil, err
	}

	claims := jwt.MapClaims{}
	parsed, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (any, error) {
		if token.Method.Alg() != jwt.SigningMethodRS256.Alg() {
			return nil, fmt.Errorf("unexpected signing method: %s", token.Method.Alg())
		}
		return key, nil
	})
	if err != nil || !parsed.Valid {
		if err == nil {
			err = errors.New("apple identity token tidak valid")
		}
		return nil, err
	}
	return claims, nil
}

func applePublicKeyFromToken(tokenString string) (*rsa.PublicKey, error) {
	header := struct {
		Kid string `json:"kid"`
		Alg string `json:"alg"`
	}{}
	parts := strings.Split(tokenString, ".")
	if len(parts) < 2 {
		return nil, errors.New("apple token tidak valid")
	}
	headerBytes, err := base64.RawURLEncoding.DecodeString(parts[0])
	if err != nil {
		return nil, err
	}
	if err := json.NewDecoder(bytes.NewReader(headerBytes)).Decode(&header); err != nil {
		return nil, err
	}

	appleJWKSOnce.Do(func() {
		appleJWKS, appleJWKSErr = fetchAppleJWKS()
	})
	if appleJWKSErr != nil {
		return nil, appleJWKSErr
	}

	key, ok := appleJWKS[header.Kid]
	if !ok {
		// Jika tidak ketemu (mungkin ada rotasi key dari Apple), fetch ulang
		newKeys, err := fetchAppleJWKS()
		if err == nil {
			appleJWKS = newKeys
			key, ok = appleJWKS[header.Kid]
		}
		if !ok {
			return nil, errors.New("apple public key tidak ditemukan")
		}
	}
	return key, nil
}

func fetchAppleJWKS() (map[string]*rsa.PublicKey, error) {
	resp, err := http.Get("https://appleid.apple.com/auth/keys")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch apple jwks: %s", resp.Status)
	}

	var payload struct {
		Keys []struct {
			Kid string `json:"kid"`
			Kty string `json:"kty"`
			Alg string `json:"alg"`
			Use string `json:"use"`
			N   string `json:"n"`
			E   string `json:"e"`
		} `json:"keys"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return nil, err
	}

	keys := make(map[string]*rsa.PublicKey)
	for _, item := range payload.Keys {
		if item.Kid == "" || item.N == "" || item.E == "" {
			continue
		}
		nBytes, err := base64.RawURLEncoding.DecodeString(item.N)
		if err != nil {
			continue
		}
		eBytes, err := base64.RawURLEncoding.DecodeString(item.E)
		if err != nil {
			continue
		}
		pub := &rsa.PublicKey{
			N: new(big.Int).SetBytes(nBytes),
			E: int(big.NewInt(0).SetBytes(eBytes).Int64()),
		}
		keys[item.Kid] = pub
	}
	return keys, nil
}

func (s *AuthService) LoginAdmin(email, password string) (model.Admin, string, error) {
	var admin model.Admin
	err := s.db.Preload("Role").Where("adm_email = ?", email).First(&admin).Error
	if err != nil {
		return admin, "", errors.New("akun admin tidak ditemukan")
	}

	if !utils.CheckPasswordHash(password, admin.Password) {
		return admin, "", errors.New("password salah")
	}

	// Tentukan permissions: master admin atau admin tanpa role = akses penuh
	permissions := `{"all": ["*"]}`
	if !admin.IsMaster && admin.Role != nil && len(admin.Role.Permissions) > 0 {
		permissions = string(admin.Role.Permissions)
	}

	claims := middleware.Claims{
		ActorID:     admin.ID,
		ActorType:   "admin",
		Permissions: permissions,
	}

	token, errGen := utils.GenerateToken(claims)
	return admin, token, errGen
}
