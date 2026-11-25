package model

import "time"

type Diskon struct {
	ID           string    `gorm:"column:dis_id;primaryKey;size:50" json:"id"`
	OutletID     string    `gorm:"column:dis_outlet;size:20" json:"outlet_id"`
	Nama         string    `gorm:"column:dis_nama" json:"nama"`
	Nilai        float64   `gorm:"column:dis_nilai_diskon" json:"nilai"`
	Tipe         string    `gorm:"column:dis_jenis" json:"tipe"`
	TanggalMulai time.Time `gorm:"column:dis_tanggal_mulai" json:"tanggal_mulai"`
	TanggalAkhir time.Time `gorm:"column:dis_tanggal_akhir" json:"tanggal_akhir"`
	// JadwalTipe: 'rentang_tanggal' (default) | 'hari_berulang'.
	JadwalTipe string `gorm:"column:dis_jadwal_tipe;size:20;default:'rentang_tanggal'" json:"jadwal_tipe"`
	// Hari: daftar hari aktif untuk 'hari_berulang', CSV weekday 1=Senin..7=Minggu (mis. "5" atau "6,7").
	Hari      string     `gorm:"column:dis_hari;size:20;default:''" json:"hari"`
	Status    int        `gorm:"column:dis_status;default:1" json:"status"`
	CreatedAt time.Time  `gorm:"column:dis_created;autoCreateTime" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:dis_lastupdate;autoUpdateTime" json:"updated_at"`

	// DIUBAH: Dari uint menjadi string
	UserUpdate     string `gorm:"column:dis_userupdate;size:50" json:"user_update"`
	UserUpdateType string `gorm:"column:dis_userupdate_type" json:"user_update_type"`
}

func (Diskon) TableName() string {
	return "ac_diskon"
}
