package model

import "time"

type Voucher struct {
	ID             string     `gorm:"column:vc_id;primaryKey;size:60" json:"vc_id"`
	KodeVoucher    string     `gorm:"column:vc_voucher;unique;not null" json:"vc_voucher"`
	Jenis          string     `gorm:"column:vc_jenis" json:"vc_jenis"` // e.g., 'persen', 'nominal'
	NilaiPotongan  float64    `gorm:"column:vc_nilai_potongan" json:"vc_nilai_potongan"`
	Keterangan     string     `gorm:"column:vc_keterangan" json:"vc_keterangan"`
	TanggalMulai   time.Time  `gorm:"column:vc_tanggalmulai" json:"vc_tanggalmulai"`
	TanggalBerakhir time.Time `gorm:"column:vc_tanggalberakhir" json:"vc_tanggalberakhir"`
	JumlahVoucher  int        `gorm:"column:vc_jumlah_voucher" json:"vc_jumlah_voucher"`
	SisaVoucher    int        `gorm:"column:vc_sisa_voucher" json:"vc_sisa_voucher"`
	// MinTopup: minimal nominal top-up (Rupiah kotor sebelum potongan) agar
	// voucher boleh dipakai. 0 = tanpa minimal. Mencegah voucher diskon besar
	// dipakai pada top-up kecil.
	MinTopup       float64    `gorm:"column:vc_min_topup;default:0" json:"vc_min_topup"`
	Status         int        `gorm:"column:vc_status;default:1" json:"vc_status"`
	Target         string     `gorm:"column:vc_target;default:ALL" json:"vc_target"` // e.g., 'ALL', 'KOIN', 'ADDON'
	CreatedAt      time.Time  `gorm:"column:vc_created;autoCreateTime" json:"vc_created"`
	UpdatedAt      *time.Time `gorm:"column:vc_lastupdate;autoUpdateTime" json:"vc_lastupdate"`
	UserUpdate     string     `gorm:"column:vc_userupdate" json:"vc_userupdate"`
}

func (Voucher) TableName() string {
	return "ac_voucher"
}