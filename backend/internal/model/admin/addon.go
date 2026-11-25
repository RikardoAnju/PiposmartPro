package admin

import "time"

type AddonTransactionAdminRes struct {
	ID              string     `gorm:"column:ha_id" json:"ha_id"`
	OutletID        string     `gorm:"column:ha_outlet" json:"ha_outlet"`
	OutletName      string     `gorm:"column:outlet_name" json:"outlet_name"`
	OwnerName       string     `gorm:"column:owner_name" json:"owner_name"`
	Total           float64    `gorm:"column:ha_total" json:"ha_total"`
	MetodeBayar     string     `gorm:"column:ha_metode_bayar" json:"ha_metode_bayar"`
	Status          string     `gorm:"column:ha_status" json:"ha_status"`
	Bukti           *string    `gorm:"column:ha_bukti" json:"ha_bukti"`
	BankName        string     `gorm:"column:bank_name" json:"bank_name"`
	ItemNames       string     `gorm:"column:ha_item_names" json:"item_names"`
	CreatedAt       time.Time  `gorm:"column:ha_created" json:"ha_created"`
	TanggalValidasi *time.Time `gorm:"column:ha_tanggal_validasi" json:"ha_tanggal_validasi"`
	Details         []AddonTransactionAdminDetail `gorm:"-" json:"details,omitempty"`
}

type AddonTransactionAdminDetail struct {
	ID          string     `gorm:"column:dha_id" json:"dha_id"`
	TransaksiID string     `gorm:"column:dha_transaksi" json:"dha_transaksi"`
	AddonID     string     `gorm:"column:dha_addons" json:"dha_addons"`
	ItemName    string     `gorm:"column:item_name" json:"item_name"`
	ItemDesc    string     `gorm:"column:item_desc" json:"item_desc"`
	Harga       float64    `gorm:"column:dha_harga" json:"dha_harga"`
	TargetID    string     `gorm:"column:dha_target_id" json:"dha_target_id"`
	Berakhir    *time.Time `gorm:"column:ha_berakhir" json:"ha_berakhir,omitempty"`
	FeatureStatus string   `gorm:"column:feature_status" json:"feature_status"`
}
