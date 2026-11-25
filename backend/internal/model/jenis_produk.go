package model

import (
	"time"

	"gorm.io/gorm"
)

type JenisProduk struct {
	ID           string     `gorm:"column:jp_id;primaryKey;size:40" json:"id"`
	LayananID    string     `gorm:"column:jp_layanan;size:30" json:"layanan_id"`
	Nama         string     `gorm:"column:jp_nama" json:"nama"`
	Harga        float64    `gorm:"column:jp_harga" json:"harga"`
	Satuan       string     `gorm:"column:jp_satuan" json:"satuan"` 
	MinimalOrder *float64   `gorm:"column:jp_minimal_order" json:"minimal_order,omitempty"`
	Durasi       int        `gorm:"column:jp_durasi" json:"durasi"`
	DurasiSatuan string     `gorm:"column:jp_durasi_satuan" json:"durasi_satuan"`
	Icon         string     `gorm:"column:jp_gambar" json:"icon"`
	UpdatedAt    *time.Time `gorm:"column:jp_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
	DeletedAt gorm.DeletedAt `gorm:"index" json:"-"`
	Prioritas      int        `gorm:"column:jp_prioritas;default:0" json:"prioritas"`

	UserUpdate     string   `gorm:"column:jp_userupdate;size:50" json:"user_update"`
	UserUpdateType string   `gorm:"column:jp_userupdate_type" json:"user_update_type"`
	Layanan        *Layanan `gorm:"foreignKey:LayananID;references:ID" json:"-"`
}

func (JenisProduk) TableName() string {
	return "ac_jenis_produk"
}
