package model

import "time"

type Layanan struct {
	ID             string        `gorm:"column:ly_id;primaryKey;size:30" json:"id"`
	OutletID       string        `gorm:"column:ly_outlet;size:20" json:"outlet_id"` 
	Nama           string        `gorm:"column:ly_nama" json:"nama"`
	Proses         string        `gorm:"column:ly_proses" json:"proses"`
	CreatedAt      time.Time     `gorm:"column:ly_created;autoCreateTime" json:"created_at"`
	UpdatedAt      *time.Time    `gorm:"column:ly_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
	
	// DIUBAH: Dari uint menjadi string
	UserUpdate     string        `gorm:"column:ly_userupdate;size:50" json:"user_update"`
	UserUpdateType string        `gorm:"column:ly_userupdate_type" json:"user_update_type"`
	
	Products       []JenisProduk `gorm:"foreignKey:LayananID;references:ID" json:"products,omitempty"`
}

func (Layanan) TableName() string {
	return "ac_layanan"
}