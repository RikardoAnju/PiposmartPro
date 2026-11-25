package model

import "time"

type NotaSetting struct {
	ID       string `gorm:"column:cn_id;primaryKey;size:50" json:"cn_id"`
	OutletID string `gorm:"column:cn_outlet;size:20;not null" json:"cn_outlet"`

	// Profil Nota (Header)
	NamaOutlet string  `gorm:"column:cn_nama_outlet" json:"cn_nama_outlet"`
	Alamat     string  `gorm:"column:cn_alamat" json:"cn_alamat"`
	Kontak     string  `gorm:"column:cn_kontak" json:"cn_kontak"`
	LogoURL    *string `gorm:"column:cn_logo" json:"cn_logo"`

	// Teks Nota (Footer)
	FooterNota     string `gorm:"column:cn_footer_nota" json:"cn_footer_nota"`
	FooterWhatsapp string `gorm:"column:cn_footer_whatsapp" json:"cn_footer_whatsapp"`

	// Settings Toggle (ON/OFF)
	ShowLogo       bool `gorm:"column:cn_sett_logo;default:true" json:"cn_sett_logo"`
	ShowQRCode     bool `gorm:"column:cn_sett_qr;default:true" json:"cn_sett_qr"`
	ShowNamaKasir  bool `gorm:"column:cn_sett_kasir;default:true" json:"cn_sett_kasir"`
	ShowKeterangan bool `gorm:"column:cn_sett_keterangan;default:true" json:"cn_sett_keterangan"`
	ShowFooterNota bool `gorm:"column:cn_sett_nota;default:true" json:"cn_sett_nota"`
	ShowFooterWA   bool `gorm:"column:cn_sett_whatsapp;default:true" json:"cn_sett_whatsapp"`
	ShowRounding   bool `gorm:"column:cn_sett_rounding;default:true" json:"cn_sett_rounding"`
	ShowDuration   bool `gorm:"column:cn_sett_durasi;default:true" json:"cn_sett_durasi"`

	// Konfigurasi Fisik
	PrinterSize int `gorm:"column:cn_ukuran;default:58" json:"cn_ukuran"`

	// Audit Trail (Konsisten dengan model Outlet)
	UpdatedAt      time.Time `gorm:"column:cn_lastupdate;autoUpdateTime" json:"cn_lastupdate"`
	UserUpdate     string    `gorm:"column:cn_userupdate;size:50" json:"cn_userupdate"`
	UserUpdateType string    `gorm:"column:cn_userupdate_type" json:"cn_userupdate_type"`
}

func (NotaSetting) TableName() string {
	return "ac_config_nota"
}

type NotaSettingUpdateRequest struct {
	NamaOutlet     *string `json:"cn_nama_outlet"`
	Alamat         *string `json:"cn_alamat"`
	Kontak         *string `json:"cn_kontak"`
	FooterNota     *string `json:"cn_footer_nota"`
	FooterWhatsapp *string `json:"cn_footer_whatsapp"`
	ShowLogo       *bool   `json:"cn_sett_logo"`
	ShowQRCode     *bool   `json:"cn_sett_qr"`
	ShowNamaKasir  *bool   `json:"cn_sett_kasir"`
	ShowKeterangan *bool   `json:"cn_sett_keterangan"`
	ShowFooterNota *bool   `json:"cn_sett_nota"`
	ShowFooterWA   *bool   `json:"cn_sett_whatsapp"`
	ShowRounding   *bool   `json:"cn_sett_rounding"`
	ShowDuration   *bool   `json:"cn_sett_durasi"`
	PrinterSize    *int    `json:"cn_ukuran"`
}

func (r NotaSettingUpdateRequest) ApplyTo(setting *NotaSetting) {
	if r.NamaOutlet != nil {
		setting.NamaOutlet = *r.NamaOutlet
	}
	if r.Alamat != nil {
		setting.Alamat = *r.Alamat
	}
	if r.Kontak != nil {
		setting.Kontak = *r.Kontak
	}
	if r.FooterNota != nil {
		setting.FooterNota = *r.FooterNota
	}
	if r.FooterWhatsapp != nil {
		setting.FooterWhatsapp = *r.FooterWhatsapp
	}
	if r.ShowLogo != nil {
		setting.ShowLogo = *r.ShowLogo
	}
	if r.ShowQRCode != nil {
		setting.ShowQRCode = *r.ShowQRCode
	}
	if r.ShowNamaKasir != nil {
		setting.ShowNamaKasir = *r.ShowNamaKasir
	}
	if r.ShowKeterangan != nil {
		setting.ShowKeterangan = *r.ShowKeterangan
	}
	if r.ShowFooterNota != nil {
		setting.ShowFooterNota = *r.ShowFooterNota
	}
	if r.ShowFooterWA != nil {
		setting.ShowFooterWA = *r.ShowFooterWA
	}
	if r.ShowRounding != nil {
		setting.ShowRounding = *r.ShowRounding
	}
	if r.ShowDuration != nil {
		setting.ShowDuration = *r.ShowDuration
	}
	if r.PrinterSize != nil {
		setting.PrinterSize = *r.PrinterSize
	}
}
