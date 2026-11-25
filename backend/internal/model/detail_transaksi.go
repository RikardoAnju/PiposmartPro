package model

import "time"

type DetailTransaksi struct {
	ID             string       `gorm:"column:dtr_id;primaryKey;size:80" json:"id"`
	TransaksiID    string       `gorm:"column:dtr_transaksi;size:60;index:idx_dtr_trx" json:"transaksi_id"`
	ProductID      string       `gorm:"column:dtr_layanan;size:40" json:"product_id"`
	NamaLayanan    string       `gorm:"column:dtr_nama_layanan" json:"nama_layanan"`
	Harga          float64      `gorm:"column:dtr_harga" json:"harga"`
	Qty            float64      `gorm:"column:dtr_qty" json:"qty"`
	Satuan         string       `gorm:"column:dtr_satuan" json:"satuan"`
	Subtotal       float64      `gorm:"column:dtr_subtotal" json:"subtotal"`
	CategoryName   string       `gorm:"column:category_name;->" json:"category_name,omitempty"`
	NamaKategori   string       `gorm:"column:nama_kategori;->" json:"nama_kategori,omitempty"`
	IconPath       string       `gorm:"column:icon_path;->" json:"icon_path,omitempty"`
	DtrIcon        string       `gorm:"column:dtr_icon;->" json:"dtr_icon,omitempty"`
	ReadyAt        *time.Time   `gorm:"column:dtr_ready_at;index" json:"ready_at"`
	CreatedAt      time.Time    `gorm:"column:dtr_created;autoCreateTime" json:"created_at"`
	UserUpdate     string       `gorm:"column:dtr_userupdate;size:50" json:"user_update"`
	UserUpdateType string       `gorm:"column:dtr_userupdate_type" json:"user_update_type"`
	Product        *JenisProduk `gorm:"foreignKey:ProductID;references:ID" json:"product_metadata,omitempty"`
}

func (DetailTransaksi) TableName() string {
	return "ac_detail_transaksi"
}
