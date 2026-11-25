package model

import "time"

type ItemTransaksi struct {
	ID          string     `gorm:"column:itr_id;primaryKey;size:70" json:"id"`
	TransaksiID string     `gorm:"column:itr_transaksi;size:60" json:"transaksi_id"`
	ItemID      string     `gorm:"column:itr_item;size:40" json:"item_id"`
	ItemName    string     `gorm:"column:nama_item;->" json:"nama_item,omitempty"`
	ServiceName string     `gorm:"column:itr_service_name;size:120" json:"service_name,omitempty"`
	Qty         int        `gorm:"column:itr_qty" json:"qty"`
	Keterangan  *string    `gorm:"column:itr_keterangan" json:"keterangan,omitempty"`
	CreatedAt   time.Time  `gorm:"column:itr_created;autoCreateTime" json:"created_at"`
	UpdatedAt   *time.Time `gorm:"column:itr_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`

	// DIUBAH: Dari uint menjadi string
	UserUpdate     string `gorm:"column:itr_userupdate;size:50" json:"user_update"`
	UserUpdateType string `gorm:"column:itr_userupdate_type" json:"user_update_type"`

	MasterItem *Item `gorm:"foreignKey:ItemID;references:ID" json:"master_item,omitempty"`
}

func (ItemTransaksi) TableName() string {
	return "ac_item_transaksi"
}
