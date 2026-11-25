package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type PengeluaranService struct {
	db *gorm.DB
}

func NewPengeluaranService(db *gorm.DB) *PengeluaranService {
	return &PengeluaranService{db: db}
}

func (s *PengeluaranService) DB() *gorm.DB {
	return s.db
}

// Create mencatat pengeluaran baru dan langsung mengembalikan data lengkap dengan nama penginput
func (s *PengeluaranService) Create(p model.Pengeluaran) (model.Pengeluaran, error) {
	// Validasi kategori pengeluaran secara cepat
	var catCount int64
	s.db.Table("ac_kategori_pengeluaran").
		Where("kp_id = ? AND kp_outlet = ?", p.KategoriID, p.OutletID).
		Count(&catCount)
	if catCount == 0 {
		return p, errors.New("kategori pengeluaran tidak valid")
	}

	p.ID = utils.GenPengeluaranID(s.db, p.OutletID)

	if err := s.db.Create(&p).Error; err != nil {
		return p, err
	}

	// FIX: Tambahkan COLLATE utf8mb4_unicode_ci pada CAST
	var result model.Pengeluaran
	err := s.db.Table("ac_pengeluaran AS pg").
		Select(`
            pg.*,
            kp.kp_kategori AS kategori_nama,
            COALESCE(u.usr_nama, p.pg_nama, 'System') AS user_update_nama
        `).
		Joins("LEFT JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").
		Joins("LEFT JOIN ac_user u ON pg.pg_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND pg.pg_userupdate_type = 'user'").
		Joins("LEFT JOIN ac_pegawai p ON pg.pg_userupdate = p.pg_id AND pg.pg_userupdate_type = 'pegawai'").
		Where("pg.pg_id = ?", p.ID).
		Scan(&result).Error

	// Invalidate Cache
	s.invalidateCache(p.OutletID)

	return result, err
}

// recomputePayrollExpenseTotal menghitung ulang nominal pengeluaran bersumber
// payroll dari data payroll TERKINI (base+bonus-deduction seluruh item yang
// dibayar bersamaan, clamp ke 0 sekali di akhir), alih-alih percaya kolom
// pg_total yang bisa jadi dibuat sebelum bug perhitungan gabungan payroll
// diperbaiki (lihat MarkBulkPaid di payroll_service.go). Dipakai di List &
// GetByID supaya angka lama yang sudah salah ikut otomatis "sembuh".
//
// Kalau hasil hitung ulang beda dari pg_total yang tersimpan, langsung
// ditulis balik ke DB (bukan cuma dikoreksi di response) — supaya laporan
// lain yang masih baca pg_total mentah lewat SUM() langsung (dashboard,
// finance summary, dll) ikut otomatis benar tanpa perlu migrasi data manual
// atau ditambal satu-satu di setiap query.
//
// Mengembalikan (0, false) kalau item payroll-nya tidak ditemukan (mis.
// sudah dihapus) — pemanggil harus tetap pakai pg_total apa adanya.
func (s *PengeluaranService) recomputePayrollExpenseTotal(pengeluaranID, outletID, itemID string, currentTotal float64) (float64, bool) {
	if itemID == "" {
		return 0, false
	}
	var anchor struct {
		PegawaiID string     `gorm:"column:pi_pegawai"`
		PeriodID  string     `gorm:"column:pi_period"`
		PaidAt    *time.Time `gorm:"column:pi_paid_at"`
	}
	if err := s.db.Table("ac_payroll_item").
		Select("pi_pegawai, pi_period, pi_paid_at").
		Where("pi_id = ? AND pi_outlet = ?", itemID, outletID).
		Take(&anchor).Error; err != nil || anchor.PaidAt == nil {
		return 0, false
	}
	var group []struct {
		BaseAmount      float64 `gorm:"column:pi_base_amount"`
		BonusAmount     float64 `gorm:"column:pi_bonus_amount"`
		DeductionAmount float64 `gorm:"column:pi_deduction_amount"`
	}
	if err := s.db.Table("ac_payroll_item").
		Select("pi_base_amount, pi_bonus_amount, pi_deduction_amount").
		Where("pi_outlet = ? AND pi_pegawai = ? AND pi_period = ? AND pi_status = 'paid' AND pi_paid_at = ?",
			outletID, anchor.PegawaiID, anchor.PeriodID, anchor.PaidAt).
		Scan(&group).Error; err != nil || len(group) == 0 {
		return 0, false
	}
	var total float64
	for _, it := range group {
		total += it.BaseAmount + it.BonusAmount - it.DeductionAmount
	}
	if total < 0 {
		total = 0
	}
	if total != currentTotal {
		// Best-effort: kalau gagal ditulis, response tetap pakai nilai yang
		// sudah dihitung ulang di atas, cuma belum "sembuh" permanen di DB.
		s.db.Model(&model.Pengeluaran{}).
			Where("pg_id = ?", pengeluaranID).
			Update("pg_total", total)
		// Dashboard/finance summary di-cache terpisah (lihat GetDashboardSummary
		// di summary_service.go) dan tidak otomatis tahu pg_total berubah lewat
		// jalur "self-heal" ini. Tanpa invalidate ini, Home tetap menampilkan
		// pengeluaran lama sampai cache 5 menitnya kedaluwarsa sendiri.
		s.invalidateCache(outletID)
	}
	return total, true
}

// List mengambil daftar pengeluaran dengan SQL Joins dan fix collation error
func (s *PengeluaranService) List(outletID, start, end string) ([]model.Pengeluaran, error) {
	var results []model.Pengeluaran

	// FIX: Tambahkan COLLATE utf8mb4_unicode_ci pada CAST as CHAR
	query := s.db.Table("ac_pengeluaran AS pg").
		Select(`
            pg.*,
            kp.kp_kategori AS kategori_nama,
            COALESCE(u.usr_nama, p.pg_nama, 'System') AS user_update_nama
        `).
		Joins("LEFT JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").
		Joins("LEFT JOIN ac_user u ON pg.pg_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND pg.pg_userupdate_type = 'user'").
		Joins("LEFT JOIN ac_pegawai p ON pg.pg_userupdate = p.pg_id AND pg.pg_userupdate_type = 'pegawai'").
		Where("pg.pg_outlet = ?", outletID)

	if start != "" && end != "" {
		query = query.Where("DATE(pg.pg_tanggal) BETWEEN ? AND ?", start, end)
	}

	err := query.Order("pg.pg_tanggal DESC").Scan(&results).Error
	if err != nil {
		return results, err
	}
	for i := range results {
		if strings.EqualFold(strings.TrimSpace(results[i].SourceType), "payroll") {
			if recomputed, ok := s.recomputePayrollExpenseTotal(results[i].ID, outletID, results[i].SourceID, results[i].Total); ok {
				results[i].Total = recomputed
			}
		}
	}
	return results, nil
}

// GetByID mengambil satu pengeluaran lengkap dan selalu membatasi data ke outlet aktif.
func (s *PengeluaranService) GetByID(id, outletID string) (model.Pengeluaran, error) {
	var result model.Pengeluaran
	err := s.db.Table("ac_pengeluaran AS pg").
		Select(`
            pg.*,
            kp.kp_kategori AS kategori_nama,
            COALESCE(u.usr_nama, p.pg_nama, 'System') AS user_update_nama
        `).
		Joins("LEFT JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").
		Joins("LEFT JOIN ac_user u ON pg.pg_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND pg.pg_userupdate_type = 'user'").
		Joins("LEFT JOIN ac_pegawai p ON pg.pg_userupdate = p.pg_id AND pg.pg_userupdate_type = 'pegawai'").
		Where("pg.pg_id = ? AND pg.pg_outlet = ?", id, outletID).
		Take(&result).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		return result, errors.New("data pengeluaran tidak ditemukan")
	}
	if err != nil {
		return result, err
	}
	if strings.EqualFold(strings.TrimSpace(result.SourceType), "payroll") {
		if recomputed, ok := s.recomputePayrollExpenseTotal(result.ID, outletID, result.SourceID, result.Total); ok {
			result.Total = recomputed
		}
	}
	return result, nil
}

// Update memperbarui data pengeluaran dan mengembalikan data lengkap untuk cache UI
func (s *PengeluaranService) Update(id string, p model.Pengeluaran) (model.Pengeluaran, error) {
	var existing model.Pengeluaran
	if err := s.db.Where("pg_id = ? AND pg_outlet = ?", id, p.OutletID).First(&existing).Error; err != nil {
		return p, errors.New("data pengeluaran tidak ditemukan")
	}

	updateData := map[string]interface{}{
		"pg_kategori":        p.KategoriID,
		"pg_total":           p.Total,
		"pg_keterangan":      p.Keterangan,
		"pg_tanggal":         p.Tanggal,
		"pg_userupdate":      p.UserUpdate,
		"pg_userupdate_type": p.UserUpdateType,
		"pg_bukti":           p.Bukti,
	}

	if err := s.db.Model(&existing).Updates(updateData).Error; err != nil {
		return p, err
	}

	var result model.Pengeluaran
	err := s.db.Table("ac_pengeluaran AS pg").
		Select(`
            pg.*,
            kp.kp_kategori AS kategori_nama,
            COALESCE(u.usr_nama, p.pg_nama, 'System') AS user_update_nama
        `).
		Joins("LEFT JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").
		Joins("LEFT JOIN ac_user u ON pg.pg_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND pg.pg_userupdate_type = 'user'").
		Joins("LEFT JOIN ac_pegawai p ON pg.pg_userupdate = p.pg_id AND pg.pg_userupdate_type = 'pegawai'").
		Where("pg.pg_id = ?", id).
		Scan(&result).Error

	// Invalidate Cache
	s.invalidateCache(p.OutletID)

	return result, err
}

// Delete menghapus data pengeluaran
func (s *PengeluaranService) Delete(id, outletID string) error {
	var p model.Pengeluaran
	if err := s.db.Where("pg_id = ? AND pg_outlet = ?", id, outletID).First(&p).Error; err != nil {
		return errors.New("data tidak ditemukan")
	}

	if err := s.db.Delete(&p).Error; err != nil {
		return err
	}

	// Invalidate Cache
	s.invalidateCache(outletID)
	return nil
}

func (s *PengeluaranService) invalidateCache(outletID string) {
	// 1. Hapus dashboard summary
	database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID))
	// 2. Hapus semua laporan finance terkait outlet ini (pattern matching)
	database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
}
