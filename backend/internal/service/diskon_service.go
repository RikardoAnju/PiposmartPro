package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

type DiskonService struct {
	db *gorm.DB
}

func NewDiskonService(db *gorm.DB) *DiskonService {
	return &DiskonService{db: db}
}

func validateDiskon(dis model.Diskon) error {
	if dis.TanggalAkhir.Before(dis.TanggalMulai) {
		return errors.New("tanggal akhir tidak boleh sebelum tanggal mulai")
	}
	if dis.TanggalAkhir.After(dis.TanggalMulai.AddDate(0, 0, 90)) {
		return errors.New("masa berlaku diskon maksimal 90 hari")
	}

	if dis.Nilai <= 0 {
		return errors.New("nilai diskon harus lebih besar dari 0")
	}

	if dis.Tipe == "persen" && dis.Nilai > 100 {
		return errors.New("persentase diskon maksimal 100%")
	}

	return nil
}

func (s *DiskonService) Create(dis model.Diskon) (model.Diskon, error) {
	if err := validateDiskon(dis); err != nil {
		return dis, err
	}

	// 2. Generate ID (DIS.OUTLETID.MM.XXX)
	dis.ID = utils.GenDiskonID(s.db, dis.OutletID)

	// Create akan menyimpan UserUpdate (String) dan UserUpdateType secara otomatis
	err := s.db.Create(&dis).Error
	return dis, err
}

func (s *DiskonService) List(outletID string) ([]model.Diskon, error) {
	var results []model.Diskon
	// Mengurutkan berdasarkan status aktif dan tanggal buat terbaru
	err := s.db.Where("dis_outlet = ?", outletID).
		Order("dis_status DESC, dis_created DESC").
		Find(&results).Error

	if err != nil {
		return nil, fmt.Errorf("gagal mengambil daftar diskon: %v", err)
	}

	return results, nil
}

func (s *DiskonService) Update(dis model.Diskon) error {
	// 1. Validasi keberadaan data
	var count int64
	s.db.Model(&model.Diskon{}).Where("dis_id = ? AND dis_outlet = ?", dis.ID, dis.OutletID).Count(&count)
	if count == 0 {
		return errors.New("data diskon tidak ditemukan")
	}

	if err := validateDiskon(dis); err != nil {
		return err
	}

	// Updates map memastikan data audit String tersimpan dengan benar
	return s.db.Model(&model.Diskon{}).
		Where("dis_id = ? AND dis_outlet = ?", dis.ID, dis.OutletID).
		Updates(map[string]interface{}{
			"dis_nama":            dis.Nama,
			"dis_nilai_diskon":    dis.Nilai,
			"dis_jenis":           dis.Tipe,
			"dis_jadwal_tipe":     dis.JadwalTipe,
			"dis_hari":            dis.Hari,
			"dis_tanggal_mulai":   dis.TanggalMulai,
			"dis_tanggal_akhir":   dis.TanggalAkhir,
			"dis_status":          dis.Status,
			"dis_userupdate":      dis.UserUpdate, // Sekarang menerima String (ID Pegawai/Owner)
			"dis_userupdate_type": dis.UserUpdateType,
		}).Error
}

func (s *DiskonService) Delete(id string, outletID string) error {
	// 1. Cek apakah diskon sudah digunakan di tabel transaksi untuk menjaga integritas data
	var count int64
	s.db.Table("ac_transaksi").Where("tr_diskon = ?", id).Count(&count)

	if count > 0 {
		return fmt.Errorf("diskon sudah digunakan dalam %d transaksi. Silakan nonaktifkan statusnya saja", count)
	}

	// 2. Cek keberadaan data sebelum hapus
	var exists int64
	s.db.Model(&model.Diskon{}).Where("dis_id = ? AND dis_outlet = ?", id, outletID).Count(&exists)
	if exists == 0 {
		return errors.New("data diskon tidak ditemukan")
	}

	return s.db.Where("dis_id = ? AND dis_outlet = ?", id, outletID).Delete(&model.Diskon{}).Error
}
