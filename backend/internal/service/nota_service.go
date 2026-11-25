package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"

	"gorm.io/gorm"
)

type NotaService struct {
	db *gorm.DB
}

func NewNotaService(db *gorm.DB) *NotaService {
	return &NotaService{db: db}
}

func (s *NotaService) GetSetting(outletID string) (model.NotaSetting, error) {
	var setting model.NotaSetting

	err := s.db.First(&setting, "cn_outlet = ?", outletID).Error

	// ✅ Bug 1 fix: pisahkan ErrRecordNotFound dari error lain
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return setting, fmt.Errorf("gagal mengambil setting nota: %w", err)
	}

	if errors.Is(err, gorm.ErrRecordNotFound) {
		var outlet model.Outlet
		if err := s.db.First(&outlet, "ot_id = ?", outletID).Error; err != nil {
			return setting, fmt.Errorf("data outlet tidak ditemukan")
		}

		setting = model.NotaSetting{
			ID:             utils.GenNotaSettingID(outletID),
			OutletID:       outletID,
			NamaOutlet:     outlet.Nama,
			Alamat:         utils.StringValue(outlet.Alamat),
			Kontak:         utils.StringValue(outlet.NoHP),
			FooterNota:     "Harap membawa bon ini ketika mengambil pakaian",
			FooterWhatsapp: "-",
			PrinterSize:    58,
			ShowLogo:       true,
			ShowQRCode:     true,
			ShowNamaKasir:  true,
			ShowKeterangan: true,
			ShowFooterNota: true,
			ShowFooterWA:   true,
			ShowRounding:   true,
			ShowDuration:   true,
			UserUpdate:     "SYSTEM",
			UserUpdateType: "system",
		}

		// ✅ Bug 3 fix: pakai FirstOrCreate / tangani duplicate key dengan graceful retry
		createErr := s.db.Create(&setting).Error
		if createErr != nil {
			// Kemungkinan race condition: record sudah dibuat oleh request lain
			// Coba fetch ulang sekali
			retryErr := s.db.First(&setting, "cn_outlet = ?", outletID).Error
			if retryErr != nil {
				return setting, fmt.Errorf("gagal inisialisasi setting nota: %w", createErr)
			}
		}
	}

	return setting, nil
}

func (s *NotaService) UpdateSetting(input model.NotaSetting) error {
	// ✅ Bug 2 fix: cek RowsAffected, return error kalau 0 row terupdate
	updates := map[string]interface{}{
		"cn_nama_outlet":     input.NamaOutlet,
		"cn_alamat":          input.Alamat,
		"cn_kontak":          input.Kontak,
		"cn_footer_nota":     input.FooterNota,
		"cn_footer_whatsapp": input.FooterWhatsapp,
		"cn_sett_logo":       input.ShowLogo,
		"cn_sett_qr":         input.ShowQRCode,
		"cn_sett_kasir":      input.ShowNamaKasir,
		"cn_sett_keterangan": input.ShowKeterangan,
		"cn_sett_nota":       input.ShowFooterNota,
		"cn_sett_whatsapp":   input.ShowFooterWA,
		"cn_sett_rounding":   input.ShowRounding,
		"cn_sett_durasi":     input.ShowDuration,
		"cn_ukuran":          input.PrinterSize,
		"cn_userupdate":      input.UserUpdate,
		"cn_userupdate_type": input.UserUpdateType,
	}
	if input.LogoURL != nil {
		updates["cn_logo"] = input.LogoURL
	}

	result := s.db.Model(&model.NotaSetting{}).
		Where("cn_outlet = ?", input.OutletID).
		Updates(updates)

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return fmt.Errorf("setting nota untuk outlet %s tidak ditemukan", input.OutletID)
	}

	return nil
}

func (s *NotaService) UpdateLogo(outletID, logoURL, actorID, actorType string) error {
	result := s.db.Model(&model.NotaSetting{}).
		Where("cn_outlet = ?", outletID).
		Updates(map[string]interface{}{
			"cn_logo":            logoURL,
			"cn_userupdate":      actorID,
			"cn_userupdate_type": actorType,
		})

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return fmt.Errorf("setting nota untuk outlet %s tidak ditemukan", outletID)
	}

	return nil
}

func (s *NotaService) DeleteLogo(outletID, actorID, actorType string) error {
	result := s.db.Model(&model.NotaSetting{}).
		Where("cn_outlet = ?", outletID).
		Updates(map[string]interface{}{
			"cn_logo":            nil,
			"cn_userupdate":      actorID,
			"cn_userupdate_type": actorType,
		})

	if result.Error != nil {
		return result.Error
	}

	if result.RowsAffected == 0 {
		return fmt.Errorf("setting nota untuk outlet %s tidak ditemukan", outletID)
	}

	return nil
}
