package model

import "time"

type Pelanggan struct {
	ID       string `gorm:"column:pl_id;primaryKey;size:50" json:"id"`
	OutletID string `gorm:"column:pl_outlet;size:20;index" json:"outlet_id"`
	Kode     string `gorm:"column:pl_kode" json:"kode"`
	
	// Index untuk mempercepat JOIN dan Search
	Nama     string `gorm:"column:pl_nama;index" json:"nama"`
	
	NoHP           string     `gorm:"column:pl_nohp" json:"no_hp"`
	Alamat         string     `gorm:"column:pl_alamat" json:"alamat"`
	JenisKelamin   string     `gorm:"column:pl_jenis_kelamin" json:"jenis_kelamin"`
	TanggalLahir   *time.Time `gorm:"column:pl_tanggal_lahir" json:"tanggal_lahir"`
	Status         int        `gorm:"column:pl_status;default:1" json:"status"`
	CreatedAt      time.Time  `gorm:"column:pl_created;autoCreateTime" json:"created_at"`
	UpdatedAt      *time.Time `gorm:"column:pl_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
	UserUpdate     string     `gorm:"column:pl_userupdate;size:50" json:"user_update"`
	UserUpdateType string     `gorm:"column:pl_userupdate_type" json:"user_update_type"`
}

func (Pelanggan) TableName() string {
	return "ac_pelanggan"
}