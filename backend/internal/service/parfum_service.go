package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

type ParfumService struct {
	db *gorm.DB
}

func NewParfumService(db *gorm.DB) *ParfumService {
	return &ParfumService{db: db}
}

// Create menambahkan parfum baru ke outlet
func (s *ParfumService) Create(parfum model.Parfum) (model.Parfum, error) {
	// 1. Validasi: Cek apakah nama parfum sudah ada di outlet ini
	var count int64
	s.db.Model(&model.Parfum{}).Where("pf_outlet = ? AND pf_nama = ?", parfum.OutletID, parfum.Nama).Count(&count)
	if count > 0 {
		return parfum, errors.New("nama parfum sudah terdaftar di outlet ini")
	}

	// 2. Generate ID otomatis menggunakan generator pusat
	parfum.ID = utils.GenParfumID(s.db, parfum.OutletID)
	parfum.Status = 1 // Set default aktif

	err := s.db.Create(&parfum).Error
	return parfum, err
}

// CreateDefaultParfums dipanggil otomatis saat registrasi outlet baru menggunakan transaksi utama
// DIUBAH: ownerID sekarang bertipe string
func (s *ParfumService) CreateDefaultParfums(tx *gorm.DB, outletID string, ownerID string) error {
	defaults := []string{"Ocean Fresh", "Sakura", "Lavender", "Lily", "Tanpa Parfum"}

	for _, nama := range defaults {
		parfum := model.Parfum{
			ID:             utils.GenParfumID(tx, outletID),
			OutletID:       outletID,
			Nama:           nama,
			Status:         1,
			UserUpdate:     ownerID, // Menyimpan ID Owner sebagai string
			UserUpdateType: "user",
		}

		if err := tx.Create(&parfum).Error; err != nil {
			return fmt.Errorf("gagal insert parfum %s: %v", nama, err)
		}
	}
	
	return nil
}

// List mengambil semua parfum aktif di outlet
func (s *ParfumService) List(outletID string) ([]model.Parfum, error) {
	var parfums []model.Parfum
	err := s.db.Where("pf_outlet = ?", outletID).
		Order("pf_nama ASC").
		Find(&parfums).Error
	return parfums, err
}

// Update mengubah data parfum (nama atau status)
func (s *ParfumService) Update(parfum model.Parfum) error {
	var count int64
	s.db.Model(&model.Parfum{}).Where("pf_id = ? AND pf_outlet = ?", parfum.ID, parfum.OutletID).Count(&count)
	if count == 0 {
		return errors.New("data parfum tidak ditemukan")
	}

	var dupCount int64
	s.db.Model(&model.Parfum{}).Where("pf_outlet = ? AND pf_nama = ? AND pf_id != ?", parfum.OutletID, parfum.Nama, parfum.ID).Count(&dupCount)
	if dupCount > 0 {
		return errors.New("nama parfum ini sudah digunakan")
	}

	return s.db.Model(&model.Parfum{}).
		Where("pf_id = ? AND pf_outlet = ?", parfum.ID, parfum.OutletID).
		Updates(map[string]interface{}{
			"pf_nama":            parfum.Nama,
			"pf_status":          parfum.Status,
			"pf_userupdate":      parfum.UserUpdate, // Sekarang menerima ID String
			"pf_userupdate_type": parfum.UserUpdateType,
		}).Error
}

// Delete menghapus parfum
func (s *ParfumService) Delete(id string, outletID string) error {
	var trxCount int64
	s.db.Table("ac_transaksi").Where("tr_parfum = ? AND tr_status_order NOT IN ?", id, []string{"Selesai", "Sudah Diambil"}).Count(&trxCount)
	if trxCount > 0 {
		return errors.New("parfum tidak bisa dihapus karena masih digunakan dalam transaksi berjalan")
	}

	var count int64
	s.db.Model(&model.Parfum{}).Where("pf_id = ? AND pf_outlet = ?", id, outletID).Count(&count)
	if count == 0 {
		return errors.New("data parfum tidak ditemukan")
	}

	return s.db.Where("pf_id = ? AND pf_outlet = ?", id, outletID).Delete(&model.Parfum{}).Error
}