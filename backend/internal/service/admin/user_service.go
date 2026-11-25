package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/model/admin"
	coreService "github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"time"

	"gorm.io/gorm"
)

type AdminUserService interface {
	GetAllOwners() ([]admin.OwnerListResult, error)
	GetOwnerDetail(id string) (map[string]interface{}, error)
	UpdateOwnerProfile(id string, updates map[string]interface{}) error
	DeleteOwner(id string, reason string, reasonDetail string) error
}

type adminUserService struct {
	db *gorm.DB
}

func NewAdminUserService(db *gorm.DB) AdminUserService {
	return &adminUserService{db}
}

func (s *adminUserService) GetAllOwners() ([]admin.OwnerListResult, error) {
	cacheKey := "admin:users:list:v1"
	var results []admin.OwnerListResult
	if database.GetCache(cacheKey, &results) {
		return results, nil
	}

	// Sesuaikan dengan kolom: usr_id, usr_nama, usr_email, usr_status, usr_created
	// Dan join ke ot_user di tabel ac_outlet
	query := `
		SELECT 
			u.usr_id as ac_id, 
			u.usr_nama as ac_nama, 
			u.usr_email as ac_email, 
			u.usr_nohp as ac_nohp,
			u.usr_referral_code as ac_owner_code,
			u.usr_status as ac_status, 
			u.usr_created as ac_created,
			COUNT(o.ot_id) as total_outlets
		FROM ac_user u
		LEFT JOIN ac_outlet o ON u.usr_id = o.ot_user
		GROUP BY u.usr_id, u.usr_nama, u.usr_email, u.usr_nohp, u.usr_referral_code, u.usr_status, u.usr_created
		ORDER BY u.usr_created DESC
	`

	err := s.db.Raw(query).Scan(&results).Error
	if err == nil {
		database.SetCache(cacheKey, results, 30*time.Second)
	}
	return results, err
}

func (s *adminUserService) GetOwnerDetail(id string) (map[string]interface{}, error) {
	var profile struct {
		ID           uint    `json:"id" gorm:"column:usr_id"`
		Name         string  `json:"name" gorm:"column:usr_nama"`
		Email        string  `json:"email" gorm:"column:usr_email"`
		NoHP         string  `json:"nohp" gorm:"column:usr_nohp"`
		Status       int     `json:"status" gorm:"column:usr_status"`
		ReferralCode string  `json:"referral_code" gorm:"column:usr_referral_code"`
		LeadSource   *string `json:"lead_source" gorm:"column:usr_lead_source"`
		CreatedAt    string  `json:"created_at" gorm:"column:usr_created"`
		ReferredBy   *uint   `json:"referred_by_id" gorm:"column:usr_referred_by"`
		InviterName  string  `json:"inviter_name" gorm:"column:inviter_name"`
	}

	// 1. Basic Profile & Inviter
	err := s.db.Raw(`
		SELECT u.*, i.usr_nama as inviter_name
		FROM ac_user u
		LEFT JOIN ac_user i ON u.usr_referred_by = i.usr_id
		WHERE u.usr_id = ?`, id).Scan(&profile).Error
	if err != nil {
		return nil, err
	}

	// 2. Financial Metrics (Aggregated across all outlets)
	var stats struct {
		TotalSpendTopup  int `json:"total_spend_topup"`
		TotalSpendAddon  int `json:"total_spend_addon"`
		ReferralEarnings int `json:"referral_earnings"`
		ReferralBalance  int `json:"referral_balance"`
		TotalCustomers   int `json:"total_customers"`
	}

	// Sum Topups & Addons for all outlets owned by this user
	s.db.Raw(`
		SELECT 
			COALESCE(SUM(tk.tk_total), 0) as total_spend_topup
		FROM ac_top_koin tk
		JOIN ac_outlet o ON tk.tk_outlet = o.ot_id
		WHERE o.ot_user = ? AND tk.tk_status = 'success'`, id).Scan(&stats.TotalSpendTopup)

	s.db.Raw(`
		SELECT 
			COALESCE(SUM(ha.ha_total), 0) as total_spend_addon
		FROM ac_transaksi_addons ha
		JOIN ac_outlet o ON ha.ha_outlet = o.ot_id
		WHERE o.ot_user = ? AND ha.ha_status = 'SUCCESS'`, id).Scan(&stats.TotalSpendAddon)

	// Referral Earnings & Balance
	s.db.Raw(`SELECT COALESCE(SUM(rr_reward_amount), 0) FROM ac_referral_rewards WHERE rr_referrer_user = ?`, id).Scan(&stats.ReferralEarnings)
	s.db.Raw(`SELECT COALESCE(rwh_balance_after, 0) FROM ac_referral_wallet_history WHERE rwh_user = ? ORDER BY rwh_created DESC LIMIT 1`, id).Scan(&stats.ReferralBalance)

	// Total unique customers across all outlets
	s.db.Raw(`
		SELECT COUNT(DISTINCT pl_id) 
		FROM ac_pelanggan 
		WHERE pl_outlet IN (SELECT ot_id FROM ac_outlet WHERE ot_user = ?)`, id).Scan(&stats.TotalCustomers)

	// 3. Recruits List
	recruits := []struct {
		ID        uint   `json:"id" gorm:"column:usr_id"`
		Name      string `json:"name" gorm:"column:usr_nama"`
		CreatedAt string `json:"created_at" gorm:"column:usr_created"`
		Status    int    `json:"status" gorm:"column:usr_status"`
	}{}
	s.db.Raw(`SELECT usr_id, usr_nama, usr_created, usr_status FROM ac_user WHERE usr_referred_by = ?`, id).Scan(&recruits)

	// 4. Outlets Portfolio with Stats
	outlets := []struct {
		ID           string  `json:"id" gorm:"column:ot_id"`
		Name         string  `json:"name" gorm:"column:ot_nama"`
		Koin         int     `json:"koin" gorm:"column:ot_koin"`
		Status       int     `json:"status" gorm:"column:ot_status"`
		TotalTrx     int     `json:"total_trx"`
		TotalRevenue float64 `json:"total_revenue"`
	}{}

	s.db.Raw(`
		SELECT 
			o.ot_id, o.ot_nama, o.ot_koin, o.ot_status,
			COUNT(t.tr_id) as total_trx,
			COALESCE(SUM(t.tr_total), 0) as total_revenue
		FROM ac_outlet o
		LEFT JOIN ac_transaksi t ON o.ot_id = t.tr_outlet
		WHERE o.ot_user = ?
		GROUP BY o.ot_id, o.ot_nama, o.ot_koin, o.ot_status`, id).Scan(&outlets)

	// 5. Referral Payout History
	payouts := []model.ReferralPayoutRequest{}
	s.db.Where("rp_user = ?", id).Order("rp_created DESC").Find(&payouts)

	// 6. Global Koin History (Recent 15 across all outlets)
	type KoinHistoryWithOutlet struct {
		model.HistoryKoin
		OutletNama string `json:"outlet_nama"`
	}
	globalKoin := []KoinHistoryWithOutlet{}
	s.db.Raw(`
		SELECT hk.*, o.ot_nama as outlet_nama
		FROM ac_history_koin hk
		JOIN ac_outlet o ON hk.hk_outlet = o.ot_id
		WHERE o.ot_user = ?
		ORDER BY hk.hk_created DESC
		LIMIT 15`, id).Scan(&globalKoin)

	// 7. Referral Reward History (komisi masuk per user)
	type ReferralRewardRow struct {
		ID             uint   `json:"rr_id"             gorm:"column:rr_id"`
		RewardAmount   int    `json:"rr_reward_amount"  gorm:"column:rr_reward_amount"`
		Type           string `json:"rr_type"           gorm:"column:rr_type"`
		ReferenceID    string `json:"rr_reference_id"   gorm:"column:rr_reference_id"`
		Status         string `json:"rr_status"         gorm:"column:rr_status"`
		CreatedAt      string `json:"rr_created"        gorm:"column:rr_created"`
		ReferredOutlet string `json:"rr_referred_outlet" gorm:"column:rr_referred_outlet"`
		ReferredNama   string `json:"referred_nama"     gorm:"column:referred_nama"`
		ReferredEmail  string `json:"referred_email"    gorm:"column:referred_email"`
	}
	referralRewards := []ReferralRewardRow{}
	s.db.Raw(`
		SELECT rr.rr_id, rr.rr_reward_amount, rr.rr_type, rr.rr_reference_id, rr.rr_status,
			rr.rr_created, rr.rr_referred_outlet,
			u.usr_nama AS referred_nama, u.usr_email AS referred_email
		FROM ac_referral_rewards rr
		JOIN ac_user u ON u.usr_id = rr.rr_referred_user
		WHERE rr.rr_referrer_user = ?
		ORDER BY rr.rr_created DESC`, id).Scan(&referralRewards)

	return map[string]interface{}{
		"profile":          profile,
		"stats":            stats,
		"recruits":         recruits,
		"outlets":          outlets,
		"payouts":          payouts,
		"koin_ledger":      globalKoin,
		"referral_rewards": referralRewards,
	}, nil
}

func (s *adminUserService) UpdateOwnerProfile(id string, updates map[string]interface{}) error {
	if email, ok := updates["usr_email"].(string); ok && email != "" {
		var count int64
		if err := s.db.Model(&model.User{}).
			Where("LOWER(usr_email) = LOWER(?) AND usr_id <> ?", email, id).
			Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return gorm.ErrDuplicatedKey
		}
	}

	if rawPassword, ok := updates["usr_password"].(string); ok && rawPassword != "" {
		hashed, err := utils.HashPassword(rawPassword)
		if err != nil {
			return err
		}
		updates["usr_password"] = hashed
	} else {
		delete(updates, "usr_password")
	}

	if len(updates) == 0 {
		return nil
	}

	if err := s.db.Model(&model.User{}).Where("usr_id = ?", id).Updates(updates).Error; err != nil {
		return err
	}
	database.InvalidateCache("admin:users:list:v1")
	return nil
}

func (s *adminUserService) DeleteOwner(id string, reason string, reasonDetail string) error {
	authSvc := coreService.NewAuthService(s.db)
	if err := authSvc.DeleteAccount(id, "user", reason, reasonDetail); err != nil {
		return err
	}
	database.InvalidateCache("admin:users:list:v1", fmt.Sprintf("admin:owner:detail:%s:v1", id))
	return nil
}
