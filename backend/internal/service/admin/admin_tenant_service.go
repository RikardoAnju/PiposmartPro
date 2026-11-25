package admin

import (
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"gorm.io/gorm"
)

type AdminTenantService struct {
	db *gorm.DB
}

func (s *AdminTenantService) GetNameHistory(outletID string) ([]model.OutletHistoryNama, error) {
	var histories []model.OutletHistoryNama
	err := s.db.Where("ot_id = ?", outletID).Order("created_at desc").Find(&histories).Error
	return histories, err
}

type regionRow struct {
	ID   string `json:"id"`
	Nama string `json:"nama"`
}

type regionCacheStore struct {
	mu        sync.RWMutex
	provinsi  map[string]string
	kota      map[string]string
	kecamatan map[string]string
}

var (
	regionCache = &regionCacheStore{
		provinsi:  map[string]string{},
		kota:      map[string]string{},
		kecamatan: map[string]string{},
	}
	numericRegionCode = regexp.MustCompile(`^[0-9.]+$`)
	regionHTTPClient  = &http.Client{Timeout: 8 * time.Second}
)

func NewAdminTenantService(db *gorm.DB) *AdminTenantService {
	return &AdminTenantService{db: db}
}

func (s *AdminTenantService) DeleteTenant(outletID string) error {
	var outlet model.Outlet
	if err := s.db.First(&outlet, "ot_id = ?", outletID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return fmt.Errorf("outlet tidak ditemukan")
		}
		return fmt.Errorf("gagal mengambil data outlet: %w", err)
	}

	var ownerOutletCount int64
	if err := s.db.Model(&model.Outlet{}).Where("ot_user = ?", outlet.UserID).Count(&ownerOutletCount).Error; err != nil {
		return fmt.Errorf("gagal menghitung outlet owner: %w", err)
	}
	if ownerOutletCount <= 1 {
		return fmt.Errorf("outlet terakhir milik owner tidak bisa dihapus. Hapus akun owner untuk menghapus seluruh outlet terkait")
	}

	if err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := deleteOutletTransactionTrees(tx, outletID); err != nil {
			return err
		}
		if err := deleteOutletOperationalData(tx, outletID); err != nil {
			return err
		}
		if err := tx.Where("ot_id = ?", outletID).Delete(&model.Outlet{}).Error; err != nil {
			return fmt.Errorf("gagal menghapus outlet: %w", err)
		}

		var nextOutletID *string
		var remainingOutlet model.Outlet
		err := tx.Where("ot_user = ?", outlet.UserID).Order("ot_created DESC").First(&remainingOutlet).Error
		if err == nil {
			nextOutletID = &remainingOutlet.ID
		} else if err != gorm.ErrRecordNotFound {
			return fmt.Errorf("gagal menentukan outlet terakhir owner: %w", err)
		}

		updates := map[string]interface{}{
			"usr_last_outlet": nextOutletID,
		}
		if err := tx.Model(&model.User{}).Where("usr_id = ?", outlet.UserID).Updates(updates).Error; err != nil {
			return fmt.Errorf("gagal memperbarui outlet terakhir owner: %w", err)
		}

		return nil
	}); err != nil {
		return err
	}

	if err := s.invalidateTenantDeleteCaches(outletID); err != nil {
		return err
	}

	return nil
}

// GetAllTenants mengambil semua outlet terdaftar dengan skema One-Time Activation
func (s *AdminTenantService) GetAllTenants(txStart, txEnd string) ([]map[string]interface{}, error) {
	cacheKey := fmt.Sprintf("admin:tenants:list:v5:%s:%s", txStart, txEnd)
	var tenants []map[string]interface{}
	if database.GetCache(cacheKey, &tenants) {
		return tenants, nil
	}

	query := `
        SELECT
            o.ot_id, o.ot_nama, o.ot_koin, o.ot_status, o.ot_created, o.ot_max_pegawai_base,
            o.ot_nohp, o.ot_alamat, o.ot_kecamatan, o.ot_kota, o.ot_provinsi,
            o.ot_tipe_lokasi_usaha,
            o.ot_user as owner_id,
            u.usr_nama as owner_name, u.usr_email as owner_email, u.usr_nohp as owner_nohp,
            u.usr_referral_code as owner_code, u.usr_lead_source as owner_lead_source,
            CASE
                WHEN o.ot_activated_at IS NOT NULL THEN 'PRO'
                WHEN o.ot_trial_at > NOW() THEN 'TRIAL'
                ELSE 'EXPIRED'
            END as subscription_status,
            COALESCE(o.ot_activated_at, o.ot_trial_at) as expiry_date,
            -- AGREGASI DAILY
            (SELECT COUNT(*) FROM ac_transaksi WHERE tr_outlet = o.ot_id AND DATE(tr_created) = CURDATE()) as daily_tx_count,
            (SELECT COALESCE(SUM(tr_total), 0) FROM ac_transaksi WHERE tr_outlet = o.ot_id AND DATE(tr_created) = CURDATE()) as daily_tx_amount,
            -- AGREGASI TOTAL
            (SELECT COUNT(*) FROM ac_transaksi WHERE tr_outlet = o.ot_id) as total_tx_count,
            (SELECT COALESCE(SUM(tr_total), 0) FROM ac_transaksi WHERE tr_outlet = o.ot_id) as total_tx_amount,
            -- KEAKTIFAN NASABAH: transaksi terakhir + jendela 7/30 hari
            tx.last_tx_at,
            COALESCE(tx.tx_count_7d, 0) as tx_count_7d,
            COALESCE(tx.tx_count_30d, 0) as tx_count_30d,
            -- ADD-ON AKTIF: outlet punya minimal 1 add-on yang belum kedaluwarsa
            CASE WHEN aa.ha_outlet IS NOT NULL THEN 1 ELSE 0 END as addon_active,
            COALESCE(aa.addon_names, '') as addon_active_names,
            -- Jumlah top up SUKSES (berbayar) sepanjang waktu. Apple IAP
            -- tercatat langsung di ledger koin, bukan di ac_top_koin.
            ((SELECT COUNT(*) FROM ac_top_koin
                WHERE tk_outlet = o.ot_id AND LOWER(COALESCE(tk_status, '')) IN ('success','completed','accepted'))
             +
             (SELECT COUNT(*) FROM ac_history_koin h
                WHERE h.hk_outlet = o.ot_id
                  AND h.hk_jenis_transaksi = 'masuk'
                  AND (LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%apple iap%'
                       OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%app store%'
                       OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%ios iap%'))) as topup_count
        FROM ac_outlet o
        JOIN ac_user u ON o.ot_user = u.usr_id
        LEFT JOIN (
            SELECT
                tr_outlet,
                COUNT(*) as total_tx_count,
                COALESCE(SUM(tr_total), 0) as total_tx_amount,
                MAX(tr_created) as last_tx_at,
                SUM(CASE WHEN tr_created >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) as tx_count_7d,
                SUM(CASE WHEN tr_created >= NOW() - INTERVAL 30 DAY THEN 1 ELSE 0 END) as tx_count_30d,
                SUM(
                    CASE
                        WHEN tr_created >= CURDATE()
                         AND tr_created < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
                        THEN 1
                        ELSE 0
                    END
                ) as daily_tx_count,
                COALESCE(SUM(
                    CASE
                        WHEN tr_created >= CURDATE()
                         AND tr_created < DATE_ADD(CURDATE(), INTERVAL 1 DAY)
                        THEN tr_total
                        ELSE 0
                    END
                ), 0) as daily_tx_amount
            FROM ac_transaksi
            GROUP BY tr_outlet
        ) tx ON tx.tr_outlet = o.ot_id
        LEFT JOIN (
            SELECT
                h.ha_outlet,
                GROUP_CONCAT(DISTINCT COALESCE(a.ad_addons, h.ha_addons) SEPARATOR ', ') as addon_names
            FROM ac_history_addons h
            LEFT JOIN ac_addons a ON a.ad_id = h.ha_addons
            WHERE h.ha_berakhir > NOW()
            GROUP BY h.ha_outlet
        ) aa ON aa.ha_outlet = o.ot_id
        WHERE ((? = '' AND ? = '') OR EXISTS (
            SELECT 1 FROM ac_transaksi period_tx
            WHERE period_tx.tr_outlet = o.ot_id
              AND (? = '' OR period_tx.tr_created >= CONCAT(?, ' 00:00:00'))
              AND (? = '' OR period_tx.tr_created < DATE_ADD(CONCAT(?, ' 00:00:00'), INTERVAL 1 DAY))
        ))
        ORDER BY o.ot_created DESC`

	if err := s.db.Raw(query, txStart, txEnd, txStart, txStart, txEnd, txEnd).Scan(&tenants).Error; err != nil {
		return tenants, err
	}

	resolveTenantRegions(tenants)
	database.SetCache(cacheKey, tenants, 30*time.Second)
	return tenants, nil
}

func deleteOutletTransactionTrees(tx *gorm.DB, outletID string) error {
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

func deleteOutletOperationalData(tx *gorm.DB, outletID string) error {
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
		return fmt.Errorf("gagal menghapus notifikasi: %w", err)
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
		return fmt.Errorf("gagal menghapus role: %w", err)
	}

	return nil
}

func (s *AdminTenantService) invalidateTenantDeleteCaches(outletID string) error {
	keys := []string{
		"admin:tenants:list:v2",
		fmt.Sprintf("outlet:profile:%s", outletID),
		fmt.Sprintf("summary:dashboard:%s", outletID),
		fmt.Sprintf("pelanggan:list:v2:%s", outletID),
		fmt.Sprintf("items:list:%s", outletID),
		fmt.Sprintf("layanan:list:%s", outletID),
		fmt.Sprintf("parfum:list:%s", outletID),
		fmt.Sprintf("payment:list:v2:%s", outletID),
		fmt.Sprintf("diskon:list:%s", outletID),
		fmt.Sprintf("notif:list:%s", outletID),
		fmt.Sprintf("notif:unread:%s", outletID),
	}
	database.InvalidateCache(keys...)
	database.ClearCacheByPattern("admin:tenants:list:v4:*")
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
	return nil
}

func cleanRegionCode(value interface{}) string {
	code := strings.TrimSpace(toRegionString(value))
	return code
}

func normalizeRegionCode(value interface{}) string {
	return strings.ReplaceAll(cleanRegionCode(value), ".", "")
}

func isRegionCode(value interface{}) bool {
	code := cleanRegionCode(value)
	return code != "" && numericRegionCode.MatchString(code)
}

func toRegionString(value interface{}) string {
	switch v := value.(type) {
	case nil:
		return ""
	case string:
		return v
	case []byte:
		return string(v)
	default:
		return fmt.Sprint(v)
	}
}

func resolveTenantRegions(tenants []map[string]interface{}) {
	provinceCodes := map[string]bool{}
	cityCodes := map[string]bool{}
	districtCodes := map[string]bool{}

	for _, tenant := range tenants {
		if isRegionCode(tenant["ot_provinsi"]) {
			provinceCodes[normalizeRegionCode(tenant["ot_provinsi"])] = true
		}
		if isRegionCode(tenant["ot_kota"]) {
			cityCodes[normalizeRegionCode(tenant["ot_kota"])] = true
		}
		if isRegionCode(tenant["ot_kecamatan"]) {
			districtCodes[normalizeRegionCode(tenant["ot_kecamatan"])] = true
		}
	}

	ensureProvinceNames()
	for provinceCode := range provinceCodes {
		ensureCityNames(provinceCode)
	}
	for cityCode := range cityCodes {
		ensureDistrictNames(cityCode)
	}

	for _, tenant := range tenants {
		if isRegionCode(tenant["ot_provinsi"]) {
			code := normalizeRegionCode(tenant["ot_provinsi"])
			if name := regionCache.lookupProvince(code); name != "" {
				tenant["ot_provinsi"] = name
			}
		}
		if isRegionCode(tenant["ot_kota"]) {
			code := normalizeRegionCode(tenant["ot_kota"])
			if name := regionCache.lookupCity(code); name != "" {
				tenant["ot_kota"] = name
			}
		}
		if isRegionCode(tenant["ot_kecamatan"]) {
			code := normalizeRegionCode(tenant["ot_kecamatan"])
			if name := regionCache.lookupDistrict(code); name != "" {
				tenant["ot_kecamatan"] = name
			}
		}
	}
}

func fetchRegionRows(path string) ([]regionRow, error) {
	res, err := regionHTTPClient.Get("https://ibnux.github.io/data-indonesia/" + path)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		return nil, nil
	}

	var rows []regionRow
	if err := json.NewDecoder(res.Body).Decode(&rows); err != nil {
		return nil, err
	}
	return rows, nil
}

func ensureProvinceNames() {
	regionCache.mu.RLock()
	loaded := len(regionCache.provinsi) > 0
	regionCache.mu.RUnlock()
	if loaded {
		return
	}

	rows, err := fetchRegionRows("provinsi.json")
	if err != nil {
		return
	}

	regionCache.mu.Lock()
	defer regionCache.mu.Unlock()
	for _, row := range rows {
		regionCache.provinsi[row.ID] = row.Nama
	}
}

func ensureCityNames(provinceCode string) {
	regionCache.mu.RLock()
	hasAny := false
	for cityCode := range regionCache.kota {
		if strings.HasPrefix(cityCode, provinceCode) {
			hasAny = true
			break
		}
	}
	regionCache.mu.RUnlock()
	if hasAny {
		return
	}

	rows, err := fetchRegionRows("kabupaten/" + provinceCode + ".json")
	if err != nil {
		return
	}

	regionCache.mu.Lock()
	defer regionCache.mu.Unlock()
	for _, row := range rows {
		regionCache.kota[row.ID] = row.Nama
	}
}

func ensureDistrictNames(cityCode string) {
	regionCache.mu.RLock()
	hasAny := false
	for districtCode := range regionCache.kecamatan {
		if strings.HasPrefix(districtCode, cityCode) {
			hasAny = true
			break
		}
	}
	regionCache.mu.RUnlock()
	if hasAny {
		return
	}

	rows, err := fetchRegionRows("kecamatan/" + cityCode + ".json")
	if err != nil {
		return
	}

	regionCache.mu.Lock()
	defer regionCache.mu.Unlock()
	for _, row := range rows {
		regionCache.kecamatan[row.ID] = row.Nama
	}
}

func (c *regionCacheStore) lookupProvince(code string) string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.provinsi[code]
}

func (c *regionCacheStore) lookupCity(code string) string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.kota[code]
}

func (c *regionCacheStore) lookupDistrict(code string) string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.kecamatan[code]
}

// GetTenantDetail mengambil detail lengkap outlet beserta seluruh riwayat finansial & operasional
func (s *AdminTenantService) GetTenantDetail(id string) (map[string]interface{}, error) {
	var profile map[string]interface{}
	var koinHistory []map[string]interface{}
	var topupHistory []map[string]interface{}
	var addonHistory []map[string]interface{}
	var trxHistory []map[string]interface{}
	var staffAccounts []map[string]interface{}
	var staffRoles []map[string]interface{}

	queryProfile := `
        SELECT 
            o.*, 
            o.ot_user as owner_id,
            u.usr_nama as owner_name, 
            u.usr_email as owner_email,
            u.usr_lead_source as owner_lead_source,
            CASE 
                WHEN o.ot_activated_at IS NOT NULL THEN 'PRO'
                WHEN o.ot_trial_at > NOW() THEN 'TRIAL'
                ELSE 'EXPIRED'
            END as subscription_status,
            COALESCE(o.ot_activated_at, o.ot_trial_at) as expiry_date
        FROM ac_outlet o
        JOIN ac_user u ON o.ot_user = u.usr_id
        WHERE o.ot_id = ? 
        LIMIT 1`

	if err := s.db.Raw(queryProfile, id).Scan(&profile).Error; err != nil {
		return nil, err
	}
	if profile == nil {
		return nil, gorm.ErrRecordNotFound
	}

	// Fetch Histories
	s.db.Raw("SELECT hk_id, hk_jenis_transaksi, hk_jumlah, hk_keterangan, hk_created FROM ac_history_koin WHERE hk_outlet = ? ORDER BY hk_created DESC LIMIT 20", id).Scan(&koinHistory)
	queryTopup := `
		SELECT tk_id, tk_jumlah, tk_total, tk_metode_bayar, tk_status, tk_created, tk_bukti, tk_lastupdate, tk_tanggal_validasi, tk_staf_validasi, keterangan 
		FROM (
			SELECT id as tk_id, tk_jumlah, tk_total, tk_metode_bayar, tk_status, tk_created, tk_bukti, tk_lastupdate, tk_tanggal_validasi, tk_staf_validasi, '' as keterangan
			FROM ac_top_koin 
			WHERE tk_outlet = ?

			UNION ALL

			SELECT h.hk_id as tk_id, h.hk_jumlah as tk_jumlah,
				CASE
					WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%apple iap%'
					  OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%app store%'
					  OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%ios iap%'
					THEN ROUND(
						h.hk_jumlah * COALESCE(CAST(cfg.cfg_value AS DECIMAL(18,2)), 200)
						* (100 - COALESCE(pkg.pk_discount, 0)) / 100,
						0
					)
					ELSE 0
				END as tk_total,
				CASE
					WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%apple iap%'
					  OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%app store%'
					  OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%ios iap%'
					THEN 'iap_topup'
					ELSE 'bonus'
				END as tk_metode_bayar,
				'success' as tk_status, h.hk_created as tk_created, '' as tk_bukti,
				h.hk_created as tk_lastupdate, h.hk_created as tk_tanggal_validasi,
				'SYSTEM' as tk_staf_validasi, h.hk_keterangan as keterangan
			FROM ac_history_koin h
			LEFT JOIN (
				SELECT pk_jumlah, MAX(pk_discount) AS pk_discount
				FROM ac_koin_packages WHERE pk_status = 1 GROUP BY pk_jumlah
			) pkg ON pkg.pk_jumlah = h.hk_jumlah
			LEFT JOIN ac_config_economy cfg ON cfg.cfg_key = 'price_per_coin'
			WHERE h.hk_outlet = ? AND h.hk_jenis_transaksi = 'masuk' AND h.hk_keterangan NOT LIKE '%TK-%' AND h.hk_keterangan NOT LIKE 'Tambahan % Koin dari AyoCuci%'
		) t
		ORDER BY tk_created DESC`
	s.db.Raw(queryTopup, id, id).Scan(&topupHistory)

	queryAddon := `
		SELECT 
			t.ha_id,
			COALESCE(d.dha_harga, t.ha_total) AS ha_total,
			t.ha_metode_bayar,
			t.ha_status,
			COALESCE(a.ad_addons, CASE WHEN d.dha_addons = 'OUTLET_ACTIVATION' THEN 'Aktivasi Lisensi PRO' ELSE t.ha_item_names END) AS ha_item_names,
			t.ha_created,
			t.ha_bukti,
			h.ha_berakhir,
			CASE 
				WHEN t.ha_status != 'SUCCESS' THEN 'INACTIVE'
				WHEN d.dha_addons = 'OUTLET_ACTIVATION' OR t.ha_item_names LIKE '%Aktivasi%' THEN 'ACTIVE'
				WHEN h.ha_berakhir > NOW() THEN 'ACTIVE'
				ELSE 'EXPIRED'
			END AS feature_status
		FROM ac_transaksi_addons t
		LEFT JOIN ac_detail_transaksi_addons d ON d.dha_transaksi = t.ha_id
		LEFT JOIN ac_addons a ON d.dha_addons = a.ad_id
		LEFT JOIN ac_history_addons h ON h.ha_outlet = t.ha_outlet AND h.ha_addons = d.dha_addons AND h.ha_target_id = d.dha_target_id
		WHERE t.ha_outlet = ?
		ORDER BY t.ha_created DESC
		LIMIT 30`
	s.db.Raw(queryAddon, id).Scan(&addonHistory)

	// Fetch Latest Laundry Transactions
	s.db.Raw(`
		SELECT
			t.tr_id as id,
			p.pl_nama as cust,
			t.tr_total as total,
			t.tr_status_order as status,
			t.tr_created as date,
			t.tr_userupdate as actor_id,
			t.tr_userupdate_type as actor_type,
			t.tr_kasir_nama as kasir_name
		FROM ac_transaksi t
		LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
		WHERE t.tr_outlet = ?
		ORDER BY t.tr_created DESC
		LIMIT 10
	`, id).Scan(&trxHistory)

	s.db.Raw(`
		SELECT
			pg.pg_id AS id,
			pg.pg_nama AS nama,
			pg.pg_email AS email,
			pg.pg_nohp AS nohp,
			pg.pg_status AS status,
			pg.pg_type AS type,
			pg.pg_active_until AS active_until,
			pg.pg_created AS created_at,
			rl.rl_id AS role_id,
			rl.rl_nama AS role_name,
			(
				SELECT COUNT(*)
				FROM ac_transaksi t
				WHERE t.tr_outlet = pg.pg_outlet
				  AND t.tr_userupdate = pg.pg_id
				  AND t.tr_userupdate_type = 'pegawai'
			) AS tx_count,
			(
				SELECT COALESCE(SUM(t.tr_total), 0)
				FROM ac_transaksi t
				WHERE t.tr_outlet = pg.pg_outlet
				  AND t.tr_userupdate = pg.pg_id
				  AND t.tr_userupdate_type = 'pegawai'
			) AS tx_revenue,
			(
				SELECT MAX(t.tr_created)
				FROM ac_transaksi t
				WHERE t.tr_outlet = pg.pg_outlet
				  AND t.tr_userupdate = pg.pg_id
				  AND t.tr_userupdate_type = 'pegawai'
			) AS last_transaction_at
		FROM ac_pegawai pg
		LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role
		WHERE pg.pg_outlet = ?
		ORDER BY pg.pg_created DESC
	`, id).Scan(&staffAccounts)

	s.db.Raw(`
		SELECT
			rl_id AS id,
			rl_nama AS nama
		FROM ac_role
		WHERE rl_outlet = ?
		ORDER BY rl_nama ASC
	`, id).Scan(&staffRoles)

	// Fetch Metrics
	var todayOrders, totalOrders int64
	var todayRevenue, totalRevenue float64
	var activeStaff int64

	s.db.Table("ac_transaksi").Where("tr_outlet = ? AND DATE(tr_created) = CURDATE()", id).Count(&todayOrders)
	s.db.Table("ac_transaksi").Where("tr_outlet = ? AND DATE(tr_created) = CURDATE()", id).Select("COALESCE(SUM(tr_total), 0)").Scan(&todayRevenue)

	s.db.Table("ac_transaksi").Where("tr_outlet = ?", id).Count(&totalOrders)
	s.db.Table("ac_transaksi").Where("tr_outlet = ?", id).Select("COALESCE(SUM(tr_total), 0)").Scan(&totalRevenue)

	s.db.Table("ac_pegawai").Where("pg_outlet = ? AND pg_status = 1", id).Count(&activeStaff)

	metrics := map[string]interface{}{
		"today_orders":  todayOrders,
		"today_revenue": todayRevenue,
		"total_orders":  totalOrders,
		"total_revenue": totalRevenue,
		"active_staff":  activeStaff,
	}

	return map[string]interface{}{
		"profile":        profile,
		"koin_history":   koinHistory,
		"topup_history":  topupHistory,
		"addon_history":  addonHistory,
		"trx_history":    trxHistory,
		"staff_accounts": staffAccounts,
		"staff_roles":    staffRoles,
		"metrics":        metrics,
	}, nil
}

// UpdateTenantStatus mengubah status operasional outlet (1: Aktif, 0: Suspend/Reject)
func (s *AdminTenantService) UpdateTenantStatus(id string, status int) error {
	return s.db.Table("ac_outlet").Where("ot_id = ?", id).Update("ot_status", status).Error
}
