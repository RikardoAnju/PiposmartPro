package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/notifier"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type AdminReferralService interface {
	GetDashboard() (map[string]interface{}, error)
	ListPayouts(status string) ([]map[string]interface{}, error)
	ListRewards(status string) ([]map[string]interface{}, error)
	UpdatePayoutStatus(id, status string, adminNote *string) error
	GetConfig() (map[string]model.EconomyConfig, error)
	UpdateConfig(key, value string) error
}

type adminReferralService struct {
	db *gorm.DB
}

func NewAdminReferralService(db *gorm.DB) AdminReferralService {
	return &adminReferralService{db: db}
}

func (s *adminReferralService) GetDashboard() (map[string]interface{}, error) {
	var totalRewards, pendingPayouts, totalPayoutAmount int
	var totalReferrals int64
	var pendingCount int64

	s.db.Model(&model.ReferralReward{}).Select("COALESCE(SUM(rr_reward_amount), 0)").Scan(&totalRewards)
	s.db.Model(&model.ReferralReward{}).Where("rr_type = ?", "topup").Distinct("rr_referred_user").Count(&totalReferrals)
	s.db.Model(&model.ReferralPayoutRequest{}).
		Where("rp_status IN ?", []string{"pending", "approved", "process"}).
		Select("COALESCE(SUM(rp_amount), 0)").Scan(&pendingPayouts)
	s.db.Model(&model.ReferralPayoutRequest{}).
		Where("rp_status = ?", "pending").
		Count(&pendingCount)
	s.db.Model(&model.ReferralPayoutRequest{}).
		Where("rp_status IN ?", []string{"done", "paid"}).
		Select("COALESCE(SUM(rp_amount), 0)").Scan(&totalPayoutAmount)

	configs, err := s.GetConfig()
	if err != nil {
		return nil, err
	}
	payoutBudget := utils.StringToInt(configs["referral_payout_monthly_budget"].Value)
	payoutOwnerLimit := utils.StringToInt(configs["referral_payout_monthly_owner_limit"].Value)
	payoutMinAmount := utils.StringToInt(configs["referral_payout_min_amount"].Value)
	payoutMaxAmount := utils.StringToInt(configs["referral_payout_max_amount"].Value)
	payoutUsed := s.getMonthlyPayoutUsed(time.Now())
	payoutRemaining := payoutBudget - payoutUsed
	if payoutRemaining < 0 {
		payoutRemaining = 0
	}

	return map[string]interface{}{
		"first_topup_percent":          configs["referral_percent_first"].Value,
		"first_topup_percent_referred": configs["referral_percent_first_referred"].Value,
		"next_topup_percent":           configs["referral_percent_subsequent"].Value,
		"monthly_reward_limit":         configs["referral_reward_limit_monthly"].Value,
		"payout_monthly_budget":        payoutBudget,
		"payout_owner_monthly_limit":   payoutOwnerLimit,
		"payout_monthly_used":          payoutUsed,
		"payout_monthly_remaining":     payoutRemaining,
		"payout_min_amount":            payoutMinAmount,
		"payout_max_amount":            payoutMaxAmount,
		"total_referrals":              totalReferrals,
		"total_rewards":                totalRewards,
		"pending_payouts":              pendingPayouts,
		"pending_count":                pendingCount,
		"total_paid_out":               totalPayoutAmount,
	}, nil
}

func (s *adminReferralService) ListPayouts(status string) ([]map[string]interface{}, error) {
	query := s.db.Table("ac_referral_payout_requests rp").
		Select(`rp.rp_id, rp.rp_amount, rp.rp_status, rp.rp_bank_name, rp.rp_account_name, rp.rp_account_number,
			rp.rp_note, rp.rp_admin_note, rp.rp_created, rp.rp_processed_at, rp.rp_completed_at,
			u.usr_id, u.usr_nama, u.usr_email, u.usr_nohp,
			COUNT(DISTINCT rpi.rpi_id) AS bonus_count,
			GROUP_CONCAT(DISTINCT referred.usr_nama ORDER BY referred.usr_nama SEPARATOR ', ') AS referred_owner_names,
			GROUP_CONCAT(DISTINCT outlet.ot_nama ORDER BY outlet.ot_nama SEPARATOR ', ') AS referred_outlet_names`).
		Joins("JOIN ac_user u ON u.usr_id = rp.rp_user").
		Joins("LEFT JOIN ac_referral_payout_items rpi ON rpi.rpi_payout_id = rp.rp_id").
		Joins("LEFT JOIN ac_referral_rewards rr ON rr.rr_id = rpi.rpi_reward_id").
		Joins("LEFT JOIN ac_user referred ON referred.usr_id = rr.rr_referred_user").
		Joins("LEFT JOIN ac_outlet outlet ON outlet.ot_id = rr.rr_referred_outlet").
		Group("rp.rp_id, rp.rp_amount, rp.rp_status, rp.rp_bank_name, rp.rp_account_name, rp.rp_account_number, rp.rp_note, rp.rp_admin_note, rp.rp_created, rp.rp_processed_at, rp.rp_completed_at, u.usr_id, u.usr_nama, u.usr_email, u.usr_nohp").
		Order("rp.rp_created DESC")

	if status != "" && status != "all" {
		if status == "done" {
			status = "paid"
		}
		query = query.Where("rp.rp_status = ?", status)
	}

	var rows []map[string]interface{}
	if err := query.Scan(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

func (s *adminReferralService) ListRewards(status string) ([]map[string]interface{}, error) {
	query := s.db.Table("ac_referral_rewards rr").
		Select(`rr.rr_id, rr.rr_reward_amount, rr.rr_type, rr.rr_percent, rr.rr_reference_id, rr.rr_status, rr.rr_created,
				rr.rr_coin_amount, rr.rr_coin_status,
				referrer.usr_id AS referrer_id, referrer.usr_nama AS referrer_nama, referrer.usr_email AS referrer_email,
				referred.usr_id AS referred_id, referred.usr_nama AS referred_nama, referred.usr_email AS referred_email,
				rr.rr_referred_outlet, outlet.ot_nama AS referred_outlet_name,
				rpi.rpi_payout_id AS payout_id,
				rp.rp_status AS payout_status,
				COALESCE(tk.tk_jumlah, 0) AS topup_coin_amount,
				COALESCE(tk.tk_total, 0) AS topup_amount_rp`).
		Joins("JOIN ac_user referrer ON referrer.usr_id = rr.rr_referrer_user").
		Joins("JOIN ac_user referred ON referred.usr_id = rr.rr_referred_user").
		Joins("LEFT JOIN ac_outlet outlet ON outlet.ot_id = rr.rr_referred_outlet").
		Joins("LEFT JOIN ac_referral_payout_items rpi ON rpi.rpi_reward_id = rr.rr_id").
		Joins("LEFT JOIN ac_referral_payout_requests rp ON rp.rp_id = rpi.rpi_payout_id").
		Joins("LEFT JOIN ac_top_koin tk ON tk.id = rr.rr_reference_id AND rr.rr_type = 'topup'").
		Order("rr.rr_created DESC")

	if status != "" && status != "all" {
		query = query.Where("rr.rr_status = ?", status)
	}

	var rows []map[string]interface{}
	if err := query.Scan(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

func (s *adminReferralService) UpdatePayoutStatus(id, status string, adminNote *string) error {
	status = strings.TrimSpace(strings.ToLower(status))
	allowed := map[string]bool{
		"pending":  true,
		"approved": true,
		"process":  true,
		"done":     true,
		"paid":     true,
	}
	if !allowed[status] {
		return errors.New("status payout tidak valid")
	}
	if status == "done" {
		status = "paid"
	}

	return s.db.Transaction(func(tx *gorm.DB) error {
		var payout model.ReferralPayoutRequest
		if err := tx.Where("rp_id = ?", id).First(&payout).Error; err != nil {
			return errors.New("data payout tidak ditemukan")
		}
		if payout.Status == status {
			return nil
		}
		if !isForwardReferralPayoutStatus(payout.Status, status) {
			return errors.New("transisi status payout tidak valid")
		}
		if adminNote != nil && strings.TrimSpace(*adminNote) == "" {
			adminNote = nil
		}

		updates := map[string]interface{}{
			"rp_status":     status,
			"rp_admin_note": adminNote,
		}
		now := time.Now()
		if status == "process" && payout.ProcessedAt == nil {
			updates["rp_processed_at"] = &now
		}
		if status == "paid" {
			if payout.ProcessedAt == nil {
				updates["rp_processed_at"] = &now
			}
			updates["rp_completed_at"] = &now
		}

		if err := tx.Model(&payout).Updates(updates).Error; err != nil {
			return err
		}
		if status == "paid" {
			if err := tx.Exec(`
					UPDATE ac_referral_rewards rr
					JOIN ac_referral_payout_items rpi ON rpi.rpi_reward_id = rr.rr_id
					SET rr.rr_status = 'paid'
					WHERE rpi.rpi_payout_id = ?`, payout.ID).Error; err != nil {
				return err
			}
		}

		title, message := referralPayoutStatusCopy(status, payout.Amount)
		if title != "" {
			if notifErr := notifier.CreateUserNotification(
				tx,
				payout.UserID,
				"REFERRAL",
				title,
				message,
				map[string]interface{}{"payout_id": payout.ID, "status": status, "amount": payout.Amount},
			); notifErr != nil {
				fmt.Printf("Gagal membuat notifikasi status payout: %v\n", notifErr)
			}
		}
		return nil
	})
}

func referralPayoutStatusCopy(status string, amount int) (string, string) {
	amountText := formatAdminRupiah(amount)
	switch status {
	case "approved":
		return "Pencairan Referral Disetujui", fmt.Sprintf("Pengajuan pencairan saldo referral Rp %s sudah disetujui dan masuk antrean proses finance.", amountText)
	case "process":
		return "Pencairan Referral Diproses", fmt.Sprintf("Pencairan saldo referral Rp %s sedang diproses oleh finance ke rekening tujuan.", amountText)
	case "paid":
		return "Pencairan Referral Selesai", fmt.Sprintf("Pencairan saldo referral Rp %s sudah selesai. Silakan cek rekening tujuan kamu.", amountText)
	default:
		return "", ""
	}
}

func formatAdminRupiah(amount int) string {
	s := fmt.Sprintf("%d", amount)
	n := len(s)
	if n <= 3 {
		return s
	}
	rem := n % 3
	if rem == 0 {
		rem = 3
	}
	out := s[:rem]
	for i := rem; i < n; i += 3 {
		out += "." + s[i:i+3]
	}
	return out
}

func isForwardReferralPayoutStatus(current, next string) bool {
	order := map[string]int{
		"pending":  1,
		"approved": 2,
		"process":  3,
		"done":     4,
		"paid":     4,
	}
	return order[next] > order[current]
}

func (s *adminReferralService) GetConfig() (map[string]model.EconomyConfig, error) {
	keys := referralConfigDefinitions()
	result := make(map[string]model.EconomyConfig, len(keys))
	for _, cfg := range keys {
		current := cfg
		if err := s.db.Where(model.EconomyConfig{Key: cfg.Key}).Attrs(cfg).FirstOrCreate(&current).Error; err != nil {
			return nil, err
		}
		result[current.Key] = current
	}
	return result, nil
}

func (s *adminReferralService) UpdateConfig(key, value string) error {
	key = strings.TrimSpace(key)
	allowed := map[string]model.EconomyConfig{}
	for _, cfg := range referralConfigDefinitions() {
		allowed[cfg.Key] = cfg
	}

	cfg, ok := allowed[key]
	if !ok {
		return errors.New("konfigurasi referral tidak valid")
	}
	if utils.StringToInt(value) < 0 {
		return errors.New("nilai konfigurasi tidak valid")
	}

	if err := s.db.Where(model.EconomyConfig{Key: cfg.Key}).Attrs(cfg).FirstOrCreate(&cfg).Error; err != nil {
		return err
	}
	if err := s.db.Model(&cfg).Update("cfg_value", value).Error; err != nil {
		return err
	}
	database.InvalidateCache("economy:configs", "economy:config:"+key)
	return nil
}

func referralConfigDefinitions() []model.EconomyConfig {
	return []model.EconomyConfig{
		{Key: "referral_percent_first", Value: "15", Type: "percentage", Desc: "Persentase komisi dari top up pertama owner yang diajak"},
		{Key: "referral_percent_first_referred", Value: "0", Type: "percentage", Desc: "Persentase bonus koin untuk owner yang diajak saat top up pertama"},
		{Key: "referral_percent_subsequent", Value: "5", Type: "percentage", Desc: "Persentase komisi dari top up berikutnya owner yang diajak"},
		{Key: "referral_reward_limit_monthly", Value: "5", Type: "amount", Desc: "Batas maksimal top up per bulan dari owner yang sama yang mendapat komisi"},
		{Key: "referral_payout_monthly_budget", Value: "3000000", Type: "amount", Desc: "Kuota global maksimal pencairan saldo referral per bulan"},
		{Key: "referral_payout_monthly_owner_limit", Value: "200000", Type: "amount", Desc: "Batas maksimal pencairan referral per owner setiap bulan"},
		{Key: "referral_payout_min_amount", Value: "100000", Type: "amount", Desc: "Nominal minimum request payout saldo referral"},
		{Key: "referral_payout_max_amount", Value: "200000", Type: "amount", Desc: "Nominal maksimum request payout saldo referral per transaksi"},
	}
}

func adminReferralMonthRange(now time.Time) (time.Time, time.Time) {
	loc := now.Location()
	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, loc)
	return start, start.AddDate(0, 1, 0)
}

func (s *adminReferralService) getMonthlyPayoutUsed(now time.Time) int {
	start, end := adminReferralMonthRange(now)
	var used int
	s.db.Model(&model.ReferralPayoutRequest{}).
		Where("rp_status IN ? AND rp_created >= ? AND rp_created < ?", []string{"pending", "approved", "process", "done", "paid"}, start, end).
		Select("COALESCE(SUM(rp_amount), 0)").
		Scan(&used)
	return used
}
