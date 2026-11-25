package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"

	"gorm.io/gorm"
)

func nobuQRISEnabled() bool {
	return strings.EqualFold(strings.TrimSpace(config.GetEnv("NOBU_QRIS_ENABLED", "false")), "true")
}

func isNobuMethod(name string) bool {
	return strings.EqualFold(strings.TrimSpace(name), "QRIS Nobu")
}

type MetodePembayaranService struct {
	db *gorm.DB
}

func NewMetodePembayaranService(db *gorm.DB) *MetodePembayaranService {
	return &MetodePembayaranService{db: db}
}

func (s *MetodePembayaranService) Create(mp model.MetodePembayaran) (model.MetodePembayaran, error) {
	if isNobuMethod(mp.Nama) && !nobuQRISEnabled() {
		return mp, errors.New("QRIS Nobu belum tersedia")
	}
	// 1. Validasi: Cek duplikasi nama di outlet yang sama
	var count int64
	s.db.Model(&model.MetodePembayaran{}).Where("mp_outlet = ? AND mp_nama_metode = ?", mp.OutletID, mp.Nama).Count(&count)
	if count > 0 {
		return mp, errors.New("nama metode pembayaran sudah ada")
	}

	// 2. Generate ID (MP.{OUTLET_ID}.{SEQ})
	mp.ID = utils.GenMetodeBayarID(s.db, mp.OutletID)
	err := s.db.Create(&mp).Error
	return mp, err
}

// CreateDefaultMethods dipanggil otomatis saat registrasi outlet baru menggunakan transaksi utama
// DIUBAH: ownerID sekarang bertipe string
func (s *MetodePembayaranService) CreateDefaultMethods(tx *gorm.DB, outletID string, ownerID string) error {
	defaultMethod := model.MetodePembayaran{
		ID:             utils.GenMetodeBayarID(tx, outletID),
		OutletID:       outletID,
		Nama:           "Tunai / Cash",
		Kategori:       "Cash",
		Status:         1,
		UserUpdate:     ownerID, // Menyimpan ID Owner sebagai string
		UserUpdateType: "user",
	}

	if err := tx.Create(&defaultMethod).Error; err != nil {
		return fmt.Errorf("gagal insert metode pembayaran default: %v", err)
	}

	qrisOutletMethod := model.MetodePembayaran{
		ID:             utils.GenMetodeBayarID(tx, outletID),
		OutletID:       outletID,
		Nama:           "QRIS Outlet",
		Deskripsi:      "Pembayaran QRIS manual milik outlet",
		Kategori:       "QRIS",
		Status:         0,
		UserUpdate:     ownerID,
		UserUpdateType: "user",
	}
	if err := tx.Create(&qrisOutletMethod).Error; err != nil {
		return fmt.Errorf("gagal insert metode QRIS outlet: %v", err)
	}

	// QRIS Nobu di-seed nonaktif/opt-in. Owner harus mengaktifkannya setelah
	// konfigurasi integrasi siap.
	nobuMethod := model.MetodePembayaran{
		ID:             utils.GenMetodeBayarID(tx, outletID),
		OutletID:       outletID,
		Nama:           "QRIS Nobu",
		Deskripsi:      "Pembayaran QRIS otomatis via Nobu",
		Kategori:       "QRIS",
		Status:         0,
		UserUpdate:     "system",
		UserUpdateType: "system",
	}
	if err := tx.Create(&nobuMethod).Error; err != nil {
		return fmt.Errorf("gagal insert metode pembayaran QRIS Nobu: %v", err)
	}

	return nil
}

// EnsureDefaultsForExistingOutlets menambahkan slot metode default yang belum
// ada tanpa mengubah metode, status, atau ID yang sudah dipakai outlet lama.
func (s *MetodePembayaranService) EnsureDefaultsForExistingOutlets() error {
	var outlets []model.Outlet
	if err := s.db.Select("ot_id, ot_user").Find(&outlets).Error; err != nil {
		return err
	}
	return s.db.Transaction(func(tx *gorm.DB) error {
		for _, outlet := range outlets {
			ownerID := fmt.Sprintf("%d", outlet.UserID)
			var cashCount, qrisCount, nobuCount int64
			tx.Model(&model.MetodePembayaran{}).Where("mp_outlet = ? AND mp_nama_metode = ?", outlet.ID, "Tunai / Cash").Count(&cashCount)
			tx.Model(&model.MetodePembayaran{}).Where("mp_outlet = ? AND mp_kategori = ? AND mp_nama_metode <> ?", outlet.ID, "QRIS", "QRIS Nobu").Count(&qrisCount)
			tx.Model(&model.MetodePembayaran{}).Where("mp_outlet = ? AND mp_nama_metode = ?", outlet.ID, "QRIS Nobu").Count(&nobuCount)

			if cashCount == 0 {
				if err := tx.Create(&model.MetodePembayaran{ID: utils.GenMetodeBayarID(tx, outlet.ID), OutletID: outlet.ID, Nama: "Tunai / Cash", Kategori: "Cash", Status: 1, UserUpdate: ownerID, UserUpdateType: "system"}).Error; err != nil {
					return err
				}
			}
			if qrisCount == 0 {
				if err := tx.Create(&model.MetodePembayaran{ID: utils.GenMetodeBayarID(tx, outlet.ID), OutletID: outlet.ID, Nama: "QRIS Outlet", Deskripsi: "Pembayaran QRIS manual milik outlet", Kategori: "QRIS", Status: 0, UserUpdate: ownerID, UserUpdateType: "system"}).Error; err != nil {
					return err
				}
			}
			if nobuCount == 0 {
				if err := tx.Create(&model.MetodePembayaran{ID: utils.GenMetodeBayarID(tx, outlet.ID), OutletID: outlet.ID, Nama: "QRIS Nobu", Deskripsi: "Pembayaran QRIS otomatis via Nobu", Kategori: "QRIS", Status: 0, UserUpdate: "system", UserUpdateType: "system"}).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})
}

func (s *MetodePembayaranService) List(outletID string) ([]model.MetodePembayaran, error) {
	var results []model.MetodePembayaran
	query := s.db.Where("mp_outlet = ?", outletID)
	if !nobuQRISEnabled() {
		query = query.Where("LOWER(TRIM(mp_nama_metode)) <> ?", "qris nobu")
	}
	err := query.Order("mp_status DESC, mp_nama_metode ASC").Find(&results).Error
	return results, err
}

func (s *MetodePembayaranService) Update(mp model.MetodePembayaran) error {
	var existing model.MetodePembayaran
	if err := s.db.Where("mp_id = ? AND mp_outlet = ?", mp.ID, mp.OutletID).First(&existing).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("metode pembayaran tidak ditemukan")
		}
		return err
	}
	if isNobuMethod(existing.Nama) && mp.Status == 1 && !nobuQRISEnabled() {
		return errors.New("QRIS Nobu belum tersedia")
	}
	if isNobuMethod(mp.Nama) && !nobuQRISEnabled() {
		return errors.New("QRIS Nobu belum tersedia")
	}
	if existing.ID == "" {
		return errors.New("metode pembayaran tidak ditemukan")
	}

	return s.db.Model(&model.MetodePembayaran{}).
		Where("mp_id = ? AND mp_outlet = ?", mp.ID, mp.OutletID).
		Updates(map[string]interface{}{
			"mp_nama_metode":      mp.Nama,
			"mp_deskripsi":        mp.Deskripsi,
			"mp_status":           mp.Status,
			"mp_nama_pemilik":     mp.NamaPemilik,
			"mp_nomor_akun":       mp.NomorAkun,
			"mp_nama_bank":        mp.NamaBank,
			"mp_ewallet_provider": mp.EwalletProvider,
			"mp_nomor_hp":         mp.NomorHP,
			"mp_userupdate":       mp.UserUpdate, // Menerima ID String
			"mp_userupdate_type":  mp.UserUpdateType,
		}).Error
}

func (s *MetodePembayaranService) UpdateStatus(id string, outletID string, status int, actorID string, actorType string) error {
	var existing model.MetodePembayaran
	if err := s.db.Where("mp_id = ? AND mp_outlet = ?", id, outletID).First(&existing).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return errors.New("metode pembayaran tidak ditemukan")
		}
		return err
	}
	if status == 1 && isNobuMethod(existing.Nama) && !nobuQRISEnabled() {
		return errors.New("QRIS Nobu belum tersedia")
	}
	return s.db.Model(&model.MetodePembayaran{}).
		Where("mp_id = ? AND mp_outlet = ?", id, outletID).
		Updates(map[string]interface{}{
			"mp_status":          status,
			"mp_userupdate":      actorID,
			"mp_userupdate_type": actorType,
		}).Error
}

func (s *MetodePembayaranService) Delete(id string, outletID string) error {
	var trxCount int64
	s.db.Table("ac_dp_transaksi").Where("dptr_metode_pembayaran = ?", id).Count(&trxCount)
	if trxCount > 0 {
		return errors.New("metode tidak bisa dihapus karena memiliki riwayat transaksi (gunakan non-aktifkan saja)")
	}

	var count int64
	s.db.Model(&model.MetodePembayaran{}).Where("mp_id = ? AND mp_outlet = ?", id, outletID).Count(&count)
	if count == 0 {
		return errors.New("data tidak ditemukan")
	}

	return s.db.Where("mp_id = ? AND mp_outlet = ?", id, outletID).Delete(&model.MetodePembayaran{}).Error
}
