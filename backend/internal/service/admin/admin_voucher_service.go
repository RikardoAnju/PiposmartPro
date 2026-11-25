package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"time"

	"gorm.io/gorm"
)

type AdminVoucherService interface {
	CreateVoucher(v model.Voucher) error
	GetVouchers() ([]model.Voucher, error)
	DeleteVoucher(id string) error
	UpdateVoucherStatus(id string, status int) error
	UpdateVoucher(id string, v model.Voucher) error
}

type adminVoucherService struct {
	db *gorm.DB
}

func NewAdminVoucherService(db *gorm.DB) AdminVoucherService {
	return &adminVoucherService{db}
}

func (s *adminVoucherService) CreateVoucher(v model.Voucher) error {
	if v.JumlahVoucher <= 0 {
		return errors.New("jumlah voucher harus lebih dari 0")
	}
	v.ID = utils.GenVoucherID(s.db) // Buat utilitas untuk generate ID
	v.SisaVoucher = v.JumlahVoucher // Awalnya sisa sama dengan jumlah
	v.CreatedAt = time.Now()
	return s.db.Create(&v).Error
}

func (s *adminVoucherService) GetVouchers() ([]model.Voucher, error) {
	var vouchers []model.Voucher
	err := s.db.Order("vc_created DESC").Find(&vouchers).Error
	return vouchers, err
}

func (s *adminVoucherService) DeleteVoucher(id string) error {
	return s.db.Where("vc_id = ?", id).Delete(&model.Voucher{}).Error
}

func (s *adminVoucherService) UpdateVoucherStatus(id string, status int) error {
	return s.db.Model(&model.Voucher{}).Where("vc_id = ?", id).Update("vc_status", status).Error
}

func (s *adminVoucherService) UpdateVoucher(id string, v model.Voucher) error {
	if v.JumlahVoucher <= 0 {
		return errors.New("jumlah voucher harus lebih dari 0")
	}

	var existing model.Voucher
	if err := s.db.Where("vc_id = ?", id).First(&existing).Error; err != nil {
		return err
	}

	used := existing.JumlahVoucher - existing.SisaVoucher
	if used < 0 {
		used = 0
	}
	newSisa := v.JumlahVoucher - used
	if newSisa < 0 {
		newSisa = 0
	}

	// Only allow updating certain fields
	updates := map[string]interface{}{
		"vc_voucher":         v.KodeVoucher,
		"vc_jenis":           v.Jenis,
		"vc_nilai_potongan":  v.NilaiPotongan,
		"vc_keterangan":      v.Keterangan,
		"vc_tanggalmulai":    v.TanggalMulai,
		"vc_tanggalberakhir": v.TanggalBerakhir,
		"vc_jumlah_voucher":  v.JumlahVoucher,
		"vc_sisa_voucher":    newSisa,
		"vc_target":          v.Target,
		"vc_min_topup":       v.MinTopup,
		"vc_userupdate":      v.UserUpdate,
	}
	return s.db.Model(&model.Voucher{}).Where("vc_id = ?", id).Updates(updates).Error
}
