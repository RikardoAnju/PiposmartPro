package model

import "time"

type KategoriPengeluaran struct {
	ID         string     `gorm:"column:kp_id;primaryKey;size:50" json:"id"`
	OutletID   string     `gorm:"column:kp_outlet;size:20" json:"outlet_id"`
	Kategori   string     `gorm:"column:kp_kategori" json:"kategori"`
	Status     int        `gorm:"column:kp_status;default:1" json:"status"`
	CreatedAt  time.Time  `gorm:"column:kp_created;autoCreateTime" json:"created_at"`
	UpdatedAt  *time.Time `gorm:"column:kp_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
	
	// DIUBAH: Dari uint menjadi string
	UserUpdate string     `gorm:"column:kp_userupdate;size:50" json:"user_update"`
}

func (KategoriPengeluaran) TableName() string {
	return "ac_kategori_pengeluaran"
}