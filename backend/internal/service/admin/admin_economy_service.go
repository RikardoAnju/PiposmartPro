package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

func defaultEconomyConfigs() []model.EconomyConfig {
	return []model.EconomyConfig{
		{Key: "price_per_coin", Value: "200", Type: "amount", Desc: "Harga beli per 1 koin dalam Rupiah"},
		{Key: "coin_per_transaction", Value: "1", Type: "amount", Desc: "Koin yang dipotong tiap bikin nota laundry"},
		{Key: "activation_fee", Value: "1500000", Type: "amount", Desc: "Biaya aktivasi PRO permanen outlet"},
		{Key: "activation_discount_pct", Value: "75", Type: "percentage", Desc: "Diskon aktivasi PRO (dalam persen)"},
		{Key: "activation_mode", Value: "paid", Type: "text", Desc: "Mode aktivasi outlet: free atau paid"},
		{Key: "bonus_koin_new_user", Value: "20", Type: "amount", Desc: "Bonus koin awal pendaftaran outlet baru"},
		{Key: "referral_percent_first", Value: "15", Type: "percentage", Desc: "Persentase reward dari Top Up pertama owner yang diajak"},
		{Key: "referral_percent_first_referred", Value: "0", Type: "percentage", Desc: "Persentase bonus koin untuk owner yang diajak saat top up pertama"},
		{Key: "referral_percent_subsequent", Value: "5", Type: "percentage", Desc: "Persentase reward dari Top Up selanjutnya owner yang diajak"},
		{Key: "referral_reward_limit_monthly", Value: "5", Type: "amount", Desc: "Batas maksimal top up per bulan dari owner yang sama yang mendapat komisi"},
		{Key: "referral_payout_monthly_budget", Value: "3000000", Type: "amount", Desc: "Kuota global maksimal pencairan saldo referral per bulan"},
		{Key: "referral_payout_monthly_owner_limit", Value: "200000", Type: "amount", Desc: "Batas maksimal pencairan referral per owner setiap bulan"},
		{Key: "referral_payout_min_amount", Value: "100000", Type: "amount", Desc: "Nominal minimum request payout saldo referral"},
		{Key: "referral_payout_max_amount", Value: "200000", Type: "amount", Desc: "Nominal maksimum request payout saldo referral per transaksi"},
	}
}

func deprecatedEconomyConfigKeys() []string {
	return []string{
		"referral_bonus_new_user",
		"referral_bonus_inviter",
		"referral_cash_reward_owner",
		"referral_percent_topup",
	}
}

func defaultKoinPackages() []model.KoinPackage {
	return []model.KoinPackage{
		{JumlahKoin: 100, DiscountPct: 0, IsActive: true},
		{JumlahKoin: 500, DiscountPct: 5, IsActive: true},
		{JumlahKoin: 1000, DiscountPct: 10, IsActive: true},
		{JumlahKoin: 2500, DiscountPct: 15, IsActive: true},
	}
}

type AdminEconomyService interface {
	// Config Methods
	GetConfigs() ([]model.EconomyConfig, error)
	UpdateConfig(key, value string) error
	GetConfigValue(key string) string
	SeedEconomyConfig() error // Ini sekarang ngerjain Config + Paket Koin + Addons

	// Package Methods
	GetKoinPackages() ([]model.KoinPackage, error)
	CreatePackage(jumlah int, discount int) (model.KoinPackage, error)
	DeletePackage(id uint) error
	UpdatePackage(id uint, jumlah int, discount int) error

	// Addon Catalog Methods
	GetAddons() ([]model.Addon, error)
	CreateAddon(ad model.Addon) error
	UpdateAddon(id string, ad model.Addon) error
	DeleteAddon(id string) error
}

type adminEconomyService struct {
	db *gorm.DB
}

func NewAdminEconomyService(db *gorm.DB) AdminEconomyService {
	return &adminEconomyService{db}
}

// --- SEEDER IMPLEMENTATION ---

func (s *adminEconomyService) SeedEconomyConfig() error {
	if err := s.db.Where("cfg_key IN ?", deprecatedEconomyConfigKeys()).Delete(&model.EconomyConfig{}).Error; err != nil {
		return fmt.Errorf("failed removing deprecated economy configs: %w", err)
	}

	for _, cfg := range defaultEconomyConfigs() {
		if err := s.db.
			Where(model.EconomyConfig{Key: cfg.Key}).
			Attrs(model.EconomyConfig{
				Value: cfg.Value,
				Type:  cfg.Type,
				Desc:  cfg.Desc,
			}).
			FirstOrCreate(&cfg).Error; err != nil {
			return fmt.Errorf("failed seeding economy config %s: %w", cfg.Key, err)
		}
	}

	// 2. Seed Addon Catalog
	addons := []model.Addon{
		{
			ID:         "AD-001",
			Nama:       "Extra Slot Pegawai",
			Link:       "EXTRA_STAFF",
			Harga:      10,
			Keterangan: "Masa aktif 30 hari untuk 1 pegawai",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-002",
			Nama:       "Laporan Laba Rugi",
			Link:       "REPORT_PROFIT_LOSS",
			Harga:      35,
			Keterangan: "Akses laporan laba rugi.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-003",
			Nama:       "Laporan Piutang",
			Link:       "REPORT_DEBT",
			Harga:      35,
			Keterangan: "Akses laporan piutang pelanggan.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-004",
			Nama:       "Ringkasan Per Layanan",
			Link:       "REPORT_SERVICE_SUMMARY",
			Harga:      30,
			Keterangan: "Akses ringkasan transaksi per layanan.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-005",
			Nama:       "Analisa Pertumbuhan Pelanggan",
			Link:       "REPORT_CUSTOMER_GROWTH",
			Harga:      30,
			Keterangan: "Akses analisa pertumbuhan pelanggan.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-006",
			Nama:       "Absensi Karyawan",
			Link:       "ATTENDANCE",
			Harga:      30,
			Keterangan: "Akses pencatatan, pengaturan, dan riwayat absensi karyawan.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-007",
			Nama:       "Payroll Karyawan",
			Link:       "PAYROLL",
			Harga:      35,
			Keterangan: "Akses pengaturan gaji, perhitungan, dan pembayaran payroll karyawan.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
		{
			ID:         "AD-008",
			Nama:       "Karyawan Performance",
			Link:       "KARYAWAN_PERFORMANCE",
			Harga:      25,
			Keterangan: "Akses performa dan analisis data karyawan secara mendalam.",
			Status:     1,
			CreatedAt:  time.Now(),
		},
	}

	for _, ad := range addons {
		// Pake FirstOrCreate biar datanya gak numpuk/error duplicate saat restart server
		if err := s.db.Where(model.Addon{ID: ad.ID}).FirstOrCreate(&ad).Error; err != nil {
			return fmt.Errorf("failed seeding addon %s: %w", ad.ID, err)
		}
	}

	database.InvalidateCache("economy:configs")
	fmt.Println("✅ Economy Config & Addon Catalog Seeded Successfully!")
	return nil
}

// --- OTHER METHODS ---

func (s *adminEconomyService) GetConfigs() ([]model.EconomyConfig, error) {
	cacheKey := "economy:configs"
	var configs []model.EconomyConfig

	if database.GetCache(cacheKey, &configs) {
		return configs, nil
	}

	if err := s.SeedEconomyConfig(); err != nil {
		return nil, err
	}

	err := s.db.Where("cfg_key NOT IN ?", deprecatedEconomyConfigKeys()).
		Order("cfg_key asc").
		Find(&configs).Error
	if err == nil {
		database.SetCache(cacheKey, configs, 1*time.Hour)
	}

	return configs, err
}

func (s *adminEconomyService) UpdateConfig(key, value string) error {
	for _, deprecatedKey := range deprecatedEconomyConfigKeys() {
		if key == deprecatedKey {
			return fmt.Errorf("config %s sudah tidak dipakai", key)
		}
	}

	if key == "activation_mode" {
		switch strings.ToLower(strings.TrimSpace(value)) {
		case "free", "paid":
			value = strings.ToLower(strings.TrimSpace(value))
		default:
			return fmt.Errorf("config activation_mode hanya mendukung value free atau paid")
		}
	}

	err := s.db.Model(&model.EconomyConfig{}).Where("cfg_key = ?", key).Update("cfg_value", value).Error
	if err == nil {
		database.InvalidateCache("economy:configs", "economy:config:"+key)
	}
	return err
}

func (s *adminEconomyService) GetConfigValue(key string) string {
	cacheKey := "economy:config:" + key
	var val string

	if database.GetCache(cacheKey, &val) {
		return val
	}

	var config model.EconomyConfig
	s.db.Where("cfg_key = ?", key).First(&config)

	if config.Value != "" {
		database.SetCache(cacheKey, config.Value, 1*time.Hour)
	}

	return config.Value
}

func (s *adminEconomyService) GetKoinPackages() ([]model.KoinPackage, error) {
	cacheKey := "economy:packages"
	var packages []model.KoinPackage

	if database.GetCache(cacheKey, &packages) {
		return packages, nil
	}

	if err := s.SeedEconomyConfig(); err != nil {
		return nil, err
	}

	err := s.db.Order("pk_jumlah asc").Find(&packages).Error
	if err == nil {
		database.SetCache(cacheKey, packages, 1*time.Hour)
	}
	return packages, err
}

func (s *adminEconomyService) CreatePackage(jumlah int, discount int) (model.KoinPackage, error) {
	pkg := model.KoinPackage{JumlahKoin: jumlah, DiscountPct: discount, IsActive: true}
	err := s.db.Create(&pkg).Error
	if err == nil {
		database.InvalidateCache("economy:packages")
	}
	return pkg, err
}

func (s *adminEconomyService) DeletePackage(id uint) error {
	err := s.db.Delete(&model.KoinPackage{}, id).Error
	if err == nil {
		database.InvalidateCache("economy:packages")
	}
	return err
}

func (s *adminEconomyService) UpdatePackage(id uint, jumlah int, discount int) error {
	err := s.db.Model(&model.KoinPackage{}).Where("id = ?", id).Updates(map[string]interface{}{
		"pk_jumlah":   jumlah,
		"pk_discount": discount,
	}).Error
	if err == nil {
		database.InvalidateCache("economy:packages")
	}
	return err
}

func (s *adminEconomyService) GetAddons() ([]model.Addon, error) {
	var addons []model.Addon
	err := s.db.Order("ad_id asc").Find(&addons).Error
	return addons, err
}

func (s *adminEconomyService) CreateAddon(ad model.Addon) error {
	ad.CreatedAt = time.Now()
	return s.db.Create(&ad).Error
}

func (s *adminEconomyService) UpdateAddon(id string, ad model.Addon) error {
	return s.db.Model(&model.Addon{}).Where("ad_id = ?", id).Updates(ad).Error
}

func (s *adminEconomyService) DeleteAddon(id string) error {
	return s.db.Where("ad_id = ?", id).Delete(&model.Addon{}).Error
}
