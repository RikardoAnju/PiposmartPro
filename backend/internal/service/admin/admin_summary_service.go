package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"fmt"
	"time"

	"gorm.io/gorm"
)

type AdminSummaryService struct {
	db *gorm.DB
}

func NewAdminSummaryService(db *gorm.DB) *AdminSummaryService {
	return &AdminSummaryService{db: db}
}

func (s *AdminSummaryService) GetPlatformOverview() (map[string]interface{}, error) {
	cacheKey := "admin:summary:platform:v2"
	var cached map[string]interface{}
	if database.GetCache(cacheKey, &cached) {
		return cached, nil
	}

	var res struct {
		TotalOutlets       int64 `gorm:"column:total_outlets"`
		ActiveOutlets      int64 `gorm:"column:active_outlets"`
		InactiveOutlets    int64 `gorm:"column:inactive_outlets"`
		TrialOutlets       int64 `gorm:"column:trial_outlets"`
		ProOutlets         int64 `gorm:"column:pro_outlets"`
		ExpiredOutlets     int64 `gorm:"column:expired_outlets"`
		TotalKoinIdle      int64 `gorm:"column:total_koin_idle"`
		TotalKoinPurchased int64 `gorm:"column:total_koin_purchased"`
		TotalKoinUsed      int64 `gorm:"column:total_koin_used"`
		KoinUsedToday      int64 `gorm:"column:koin_used_today"`
		NewUsersToday      int64 `gorm:"column:new_users_today"`
		TransactionsToday  int64 `gorm:"column:transactions_today"`
		// Status keaktifan nasabah (outlet) berbasis transaksi terakhir
		NasabahAktif7d        int64 `gorm:"column:nasabah_aktif_7d"`
		NasabahAktif30d       int64 `gorm:"column:nasabah_aktif_30d"`
		NasabahPasif          int64 `gorm:"column:nasabah_pasif"`
		NasabahDorman         int64 `gorm:"column:nasabah_dorman"`
		NasabahBelumTransaksi int64 `gorm:"column:nasabah_belum_transaksi"`
		OutletsAddonActive    int64 `gorm:"column:outlets_addon_active"`
	}

	coinPerTransaction := 1
	var coinCfg model.EconomyConfig
	if err := s.db.Where("cfg_key = ?", "coin_per_transaction").First(&coinCfg).Error; err == nil {
		switch coinCfg.Value {
		case "0":
			coinPerTransaction = 0
		case "1":
			coinPerTransaction = 1
		default:
			var parsed int
			if _, scanErr := fmt.Sscanf(coinCfg.Value, "%d", &parsed); scanErr == nil && parsed >= 0 {
				coinPerTransaction = parsed
			}
		}
	}

	query := `
		SELECT 
			outlet.total_outlets,
			outlet.active_outlets,
			outlet.inactive_outlets,
			outlet.trial_outlets,
			outlet.pro_outlets,
			outlet.expired_outlets,
			outlet.total_koin_idle,
			COALESCE(topup.total_koin_purchased, 0) as total_koin_purchased,
			COALESCE(coin_usage.total_koin_used, 0) as total_koin_used,
			COALESCE(coin_usage.koin_used_today, 0) as koin_used_today,
			COALESCE(users.new_users_today, 0) as new_users_today,
			COALESCE(trx.transactions_today, 0) as transactions_today,
			COALESCE(keaktifan.nasabah_aktif_7d, 0) as nasabah_aktif_7d,
			COALESCE(keaktifan.nasabah_aktif_30d, 0) as nasabah_aktif_30d,
			COALESCE(keaktifan.nasabah_pasif, 0) as nasabah_pasif,
			COALESCE(keaktifan.nasabah_dorman, 0) as nasabah_dorman,
			COALESCE(keaktifan.nasabah_belum_transaksi, 0) as nasabah_belum_transaksi,
			COALESCE(addon_active.outlets_addon_active, 0) as outlets_addon_active
		FROM (
			SELECT 
				COUNT(*) as total_outlets,
				SUM(CASE 
					WHEN ot_status = 1 AND (ot_activated_at IS NOT NULL OR ot_trial_at > NOW()) THEN 1
					ELSE 0
				END) as active_outlets,
				SUM(CASE 
					WHEN ot_status = 1 AND (ot_activated_at IS NOT NULL OR ot_trial_at > NOW()) THEN 0
					ELSE 1
				END) as inactive_outlets,
				SUM(CASE WHEN ot_status = 1 AND ot_activated_at IS NULL AND ot_trial_at > NOW() THEN 1 ELSE 0 END) as trial_outlets,
				SUM(CASE WHEN ot_status = 1 AND ot_activated_at IS NOT NULL THEN 1 ELSE 0 END) as pro_outlets,
				SUM(CASE WHEN ot_activated_at IS NULL AND ot_trial_at <= NOW() THEN 1 ELSE 0 END) as expired_outlets,
				COALESCE(SUM(CASE
					WHEN ot_status = 1 AND (ot_activated_at IS NOT NULL OR ot_trial_at > NOW()) THEN ot_koin
					ELSE 0
				END), 0) as total_koin_idle
			FROM ac_outlet
		) outlet
		CROSS JOIN (
			SELECT COUNT(*) as new_users_today
			FROM ac_user
			WHERE usr_created >= CURDATE()
			  AND usr_created < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
		) users
		CROSS JOIN (
			SELECT COUNT(*) as transactions_today
			FROM ac_transaksi
			WHERE tr_created >= CURDATE()
			  AND tr_created < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
		) trx
		CROSS JOIN (
			SELECT COALESCE(SUM(tk_jumlah), 0) as total_koin_purchased
			FROM ac_top_koin
			WHERE LOWER(COALESCE(tk_status, '')) IN ('success', 'completed', 'accepted')
			  AND LOWER(COALESCE(tk_metode_bayar, '')) <> 'bonus'
		) topup
		CROSS JOIN (
			SELECT
				CAST(
					(COALESCE(laundry.total_laundry_orders, 0) * ?) +
					COALESCE(addon.total_addon_koin_used, 0)
				AS SIGNED) as total_koin_used,
				CAST(
					(COALESCE(laundry.today_laundry_orders, 0) * ?) +
					COALESCE(addon.today_addon_koin_used, 0)
				AS SIGNED) as koin_used_today
			FROM (
				SELECT
					COUNT(*) as total_laundry_orders,
					SUM(CASE
						WHEN tr_created >= CURDATE()
						 AND tr_created < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
						THEN 1
						ELSE 0
					END) as today_laundry_orders
				FROM ac_transaksi
			) laundry
			CROSS JOIN (
				SELECT
					COALESCE(SUM(CASE
						WHEN UPPER(COALESCE(ha_metode_bayar, '')) = 'KOIN'
						 AND UPPER(COALESCE(ha_status, '')) = 'SUCCESS'
						THEN ha_total
						ELSE 0
					END), 0) as total_addon_koin_used,
					COALESCE(SUM(CASE
						WHEN UPPER(COALESCE(ha_metode_bayar, '')) = 'KOIN'
						 AND UPPER(COALESCE(ha_status, '')) = 'SUCCESS'
						 AND ha_created >= CURDATE()
						 AND ha_created < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
						THEN ha_total
						ELSE 0
					END), 0) as today_addon_koin_used
				FROM ac_transaksi_addons
			) addon
		) coin_usage
		CROSS JOIN (
			SELECT
				SUM(CASE WHEN last_tx >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) as nasabah_aktif_7d,
				SUM(CASE WHEN last_tx < NOW() - INTERVAL 7 DAY AND last_tx >= NOW() - INTERVAL 30 DAY THEN 1 ELSE 0 END) as nasabah_aktif_30d,
				SUM(CASE WHEN last_tx < NOW() - INTERVAL 30 DAY AND last_tx >= NOW() - INTERVAL 60 DAY THEN 1 ELSE 0 END) as nasabah_pasif,
				SUM(CASE WHEN last_tx < NOW() - INTERVAL 60 DAY THEN 1 ELSE 0 END) as nasabah_dorman,
				SUM(CASE WHEN last_tx IS NULL THEN 1 ELSE 0 END) as nasabah_belum_transaksi
			FROM (
				SELECT o.ot_id, tx.last_tx as last_tx
				FROM ac_outlet o
				LEFT JOIN (
					SELECT tr_outlet, MAX(tr_created) as last_tx
					FROM ac_transaksi GROUP BY tr_outlet
				) tx ON tx.tr_outlet = o.ot_id
			) outlet_last_tx
		) keaktifan
		CROSS JOIN (
			SELECT COUNT(DISTINCT ha_outlet) as outlets_addon_active
			FROM ac_history_addons
			WHERE ha_berakhir > NOW()
		) addon_active`

	err := s.db.Raw(query, coinPerTransaction, coinPerTransaction).Scan(&res).Error
	if err != nil {
		return nil, err
	}

	finalRes := map[string]interface{}{
		"total_outlets":        res.TotalOutlets,
		"total_koin":           res.TotalKoinIdle,
		"total_koin_idle":      res.TotalKoinIdle,
		"total_koin_purchased": res.TotalKoinPurchased,
		"total_koin_used":      res.TotalKoinUsed,
		"koin_used_today":      res.KoinUsedToday,
		"new_users_today":      res.NewUsersToday,
		"transactions_today":   res.TransactionsToday,
		"active_tenant":        res.ActiveOutlets,
		"active_outlets":       res.ActiveOutlets,
		"inactive_outlets":     res.InactiveOutlets,
		"trial_outlets":        res.TrialOutlets,
		"pro_outlets":          res.ProOutlets,
		"expired_outlets":      res.ExpiredOutlets,
		// Status keaktifan nasabah (outlet)
		"nasabah_aktif_7d":        res.NasabahAktif7d,
		"nasabah_aktif_30d":       res.NasabahAktif30d,
		"nasabah_pasif":           res.NasabahPasif,
		"nasabah_dorman":          res.NasabahDorman,
		"nasabah_belum_transaksi": res.NasabahBelumTransaksi,
		"outlets_addon_active":    res.OutletsAddonActive,
	}

	database.SetCache(cacheKey, finalRes, 20*time.Second)
	return finalRes, nil
}

func (s *AdminSummaryService) GetGlobalActivity() ([]map[string]interface{}, error) {
	var logs []map[string]interface{}

	query := `
        SELECT 
            t.tr_id, 
            t.tr_total, 
            t.tr_status_order, 
            t.tr_created,
            o.ot_nama as outlet_name,
            p.pl_nama as customer_name
        FROM ac_transaksi t
        JOIN ac_outlet o ON t.tr_outlet = o.ot_id
        LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
        ORDER BY t.tr_created DESC
        LIMIT 20`

	err := s.db.Raw(query).Scan(&logs).Error
	return logs, err
}
