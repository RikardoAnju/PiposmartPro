package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"

	"gorm.io/gorm"
)

type KategoriPengeluaranService struct {
	db *gorm.DB
}

func NewKategoriPengeluaranService(db *gorm.DB) *KategoriPengeluaranService {
	return &KategoriPengeluaranService{db: db}
}

func (s *KategoriPengeluaranService) Create(kp model.KategoriPengeluaran) (model.KategoriPengeluaran, error) {
	kp.Kategori = strings.TrimSpace(kp.Kategori)
	if kp.Kategori == "" {
		return kp, errors.New("nama kategori wajib diisi")
	}

	// 1. Validasi Duplikasi Nama di Outlet yang sama
	var count int64
	s.db.Model(&model.KategoriPengeluaran{}).
		Where("kp_outlet = ? AND LOWER(kp_kategori) = LOWER(?) AND kp_status = 1", kp.OutletID, kp.Kategori).
		Count(&count)
	if count > 0 {
		return kp, errors.New("nama kategori ini sudah ada")
	}

	// 2. Generate ID (KP.OUTLETID.XXX)
	kp.ID = utils.GenKatPengeluaranID(s.db, kp.OutletID)
	kp.Status = 1

	err := s.db.Create(&kp).Error
	if err != nil && isDuplicateKategoriError(err) {
		return kp, errors.New("nama kategori ini sudah ada")
	}
	return kp, err
}

// CreateDefaultCategories dipanggil otomatis saat registrasi outlet baru menggunakan transaksi utama
// DIUBAH: ownerID sekarang bertipe string
func (s *KategoriPengeluaranService) CreateDefaultCategories(tx *gorm.DB, outletID string, ownerID string) error {
	defaults := []string{"Listrik & Air", "Sewa Tempat", "Gaji Pegawai", "Sabun & Pewangi", "Lain-lain"}

	for _, nama := range defaults {
		kp := model.KategoriPengeluaran{
			ID:         utils.GenKatPengeluaranID(tx, outletID),
			OutletID:   outletID,
			Kategori:   nama,
			Status:     1,
			UserUpdate: ownerID, // Menyimpan ID Owner sebagai string
		}

		if err := tx.Create(&kp).Error; err != nil {
			return fmt.Errorf("gagal insert kategori pengeluaran %s: %v", nama, err)
		}
	}

	return nil
}

func (s *KategoriPengeluaranService) List(outletID string) ([]model.KategoriPengeluaran, error) {
	var results []model.KategoriPengeluaran
	err := s.db.Where("kp_outlet = ? AND kp_status = 1", outletID).
		Order("kp_kategori ASC").
		Find(&results).Error
	return results, err
}

func (s *KategoriPengeluaranService) Update(id, outletID string, kp model.KategoriPengeluaran) error {
	kp.Kategori = strings.TrimSpace(kp.Kategori)
	if kp.Kategori == "" {
		return errors.New("nama kategori wajib diisi")
	}

	var count int64
	s.db.Model(&model.KategoriPengeluaran{}).Where("kp_id = ? AND kp_outlet = ?", id, outletID).Count(&count)
	if count == 0 {
		return errors.New("kategori tidak ditemukan")
	}

	var duplicateCount int64
	s.db.Model(&model.KategoriPengeluaran{}).
		Where("kp_id <> ? AND kp_outlet = ? AND LOWER(kp_kategori) = LOWER(?) AND kp_status = 1", id, outletID, kp.Kategori).
		Count(&duplicateCount)
	if duplicateCount > 0 {
		return errors.New("nama kategori ini sudah ada")
	}

	err := s.db.Model(&model.KategoriPengeluaran{}).
		Where("kp_id = ? AND kp_outlet = ?", id, outletID).
		Updates(map[string]interface{}{
			"kp_kategori":   kp.Kategori,
			"kp_userupdate": kp.UserUpdate, // Sekarang menerima ID String
		}).Error
	if err != nil && isDuplicateKategoriError(err) {
		return errors.New("nama kategori ini sudah ada")
	}
	return err
}

func isDuplicateKategoriError(err error) bool {
	if err == nil {
		return false
	}
	message := strings.ToLower(err.Error())
	return strings.Contains(message, "duplicate entry") || strings.Contains(message, "error 1062")
}

func (s *KategoriPengeluaranService) Delete(id, outletID string) error {
	var count int64
	s.db.Model(&model.Pengeluaran{}).Where("pg_kategori = ? AND pg_outlet = ?", id, outletID).Count(&count)
	if count > 0 {
		return fmt.Errorf("kategori tidak dapat dihapus karena telah digunakan dalam %d transaksi pengeluaran", count)
	}

	var kpCount int64
	s.db.Model(&model.KategoriPengeluaran{}).Where("kp_id = ? AND kp_outlet = ?", id, outletID).Count(&kpCount)
	if kpCount == 0 {
		return errors.New("kategori tidak ditemukan")
	}

	return s.db.Model(&model.KategoriPengeluaran{}).
		Where("kp_id = ? AND kp_outlet = ?", id, outletID).
		Update("kp_status", 0).Error
}
