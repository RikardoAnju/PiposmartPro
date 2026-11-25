package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

type ItemService struct {
	db *gorm.DB
}

func NewItemService(db *gorm.DB) *ItemService {
	return &ItemService{db: db}
}

// Create menambahkan master item baru
func (s *ItemService) Create(item model.Item) (model.Item, error) {
	// 1. Validasi: Cek duplikasi nama item di outlet yang sama
	var count int64
	s.db.Model(&model.Item{}).Where("it_outlet = ? AND it_item = ? AND it_status = 1", item.OutletID, item.Nama).Count(&count)
	if count > 0 {
		return item, errors.New("nama item sudah terdaftar di outlet ini")
	}

	// 2. Generate ID: IT.{OUTLET_ID}.{SEQUENCE}
	item.ID = utils.GenItemID(s.db, item.OutletID)
	item.Status = 1

	err := s.db.Create(&item).Error
	return item, err
}

// CreateDefaultItems dipanggil otomatis saat registrasi outlet baru menggunakan transaksi utama
// DIUBAH: ownerID sekarang bertipe string agar sinkron dengan audit trail
func (s *ItemService) CreateDefaultItems(tx *gorm.DB, outletID string, ownerID string) error {
	defaults := []string{"Baju", "Celana", "Selimut", "Handuk", "Sprei"}

	for i, nama := range defaults {
		item := model.Item{
			ID:             fmt.Sprintf("IT.%s.%02d", outletID, i+1),
			OutletID:       outletID,
			Nama:           nama,
			Status:         1,
			UserUpdate:     ownerID, // Menyimpan ID Owner sebagai string
			UserUpdateType: "user",
		}

		if err := tx.Create(&item).Error; err != nil {
			return fmt.Errorf("gagal insert item default %s: %v", nama, err)
		}
	}
	
	return nil
}

// List mengambil semua item aktif di outlet tertentu
func (s *ItemService) List(outletID string) ([]model.Item, error) {
	var items []model.Item
	err := s.db.Where("it_outlet = ?", outletID).
		Order("it_item ASC").
		Find(&items).Error
	return items, err
}

// Update mengubah nama atau status item
func (s *ItemService) Update(item model.Item) error {
	var count int64
	s.db.Model(&model.Item{}).Where("it_id = ? AND it_outlet = ?", item.ID, item.OutletID).Count(&count)
	if count == 0 {
		return errors.New("data item tidak ditemukan")
	}

	return s.db.Model(&model.Item{}).
		Where("it_id = ? AND it_outlet = ?", item.ID, item.OutletID).
		Updates(map[string]interface{}{
			"it_item":            item.Nama,
			"it_status":          item.Status,
			"it_userupdate":      item.UserUpdate, // Sekarang menerima ID String Pegawai/Owner
			"it_userupdate_type": item.UserUpdateType,
		}).Error
}

// Delete menghapus item (Soft Delete)
func (s *ItemService) Delete(id string, outletID string) error {
	var trxCount int64
	s.db.Table("ac_item_transaksi").Where("itr_item = ?", id).Count(&trxCount)
	if trxCount > 0 {
		return errors.New("item tidak bisa dihapus karena sudah memiliki riwayat transaksi (gunakan non-aktifkan saja)")
	}

	var count int64
	s.db.Model(&model.Item{}).Where("it_id = ? AND it_outlet = ?", id, outletID).Count(&count)
	if count == 0 {
		return errors.New("data item tidak ditemukan")
	}

	return s.db.Model(&model.Item{}).Where("it_id = ? AND it_outlet = ?", id, outletID).Update("it_status", 0).Error
}