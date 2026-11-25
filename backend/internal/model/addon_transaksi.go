package model

import "time"

// Addon: Master data katalog fitur (e.g., 'Extra Staff', 'REPORT_DEBT')
type Addon struct {
	ID         string    `gorm:"column:ad_id;primaryKey;size:50" json:"ad_id"`
	Nama       string    `gorm:"column:ad_addons" json:"ad_nama"`
	Link       string    `gorm:"column:ad_link" json:"ad_link"`
	Harga      float64   `gorm:"column:ad_harga" json:"ad_harga"`
	Keterangan string    `gorm:"column:ad_keterangan" json:"ad_keterangan"`
	Status     int       `gorm:"column:ad_status;default:1" json:"ad_status"`
	CreatedAt  time.Time `gorm:"column:ad_created;autoCreateTime" json:"ad_created"`
}

func (Addon) TableName() string { return "ac_addons" }

// TransaksiAddon: Header transaksi pembelian fitur (Invoice)
type TransaksiAddon struct {
	ID              string     `gorm:"column:ha_id;primaryKey;size:50" json:"ha_id"`
	OutletID        string     `gorm:"column:ha_outlet;size:50;index" json:"ha_outlet"`
	Total           float64    `gorm:"column:ha_total" json:"ha_total"`
	MetodeBayar     string     `gorm:"column:ha_metode_bayar" json:"ha_metode_bayar"`
	Status          string     `gorm:"column:ha_status" json:"ha_status"`
	Bukti           *string    `gorm:"column:ha_bukti" json:"ha_bukti"`
	BankID          *uint      `gorm:"column:ha_bank_id" json:"bank_id"`
	SnapURL         *string    `gorm:"column:ha_snap_url" json:"ha_snap_url"`
	StafValidasi    *string    `gorm:"column:ha_staf_validasi" json:"ha_staf_validasi"`
	TanggalValidasi *time.Time `gorm:"column:ha_tanggal_validasi" json:"ha_tanggal_validasi"`
	CreatedAt       time.Time  `gorm:"column:ha_created;autoCreateTime" json:"ha_created"`
	UpdatedAt       *time.Time `gorm:"column:ha_lastupdate;autoUpdateTime" json:"ha_lastupdate"`

	// ✅ SEKARANG JADI KOLOM FISIK
	ItemNames string `gorm:"column:ha_item_names" json:"item_names"` 

	// ✅ VOUCHER & PROMO
	KodeVoucher     *string    `gorm:"column:ha_kode_voucher" json:"kode_voucher"`
	Potongan        float64    `gorm:"column:ha_potongan" json:"potongan"`

	Details []DetailTransaksiAddon `gorm:"foreignKey:TransaksiID;references:ID" json:"details"`
}

func (TransaksiAddon) TableName() string { return "ac_transaksi_addons" }

// DetailTransaksiAddon: Item-item yang dibeli dalam satu invoice
type DetailTransaksiAddon struct {
	ID          string  `gorm:"column:dha_id;primaryKey;size:50" json:"dha_id"`
	TransaksiID string  `gorm:"column:dha_transaksi;size:50;index" json:"dha_transaksi"`
	AddonID     string  `gorm:"column:dha_addons;size:50" json:"dha_addons"`
	Harga       float64 `gorm:"column:dha_harga" json:"dha_harga"`
	TargetID    string  `gorm:"column:dha_target_id;size:50" json:"target_id"`

	Addon *Addon `gorm:"foreignKey:AddonID;references:ID" json:"addon,omitempty"`
}

func (DetailTransaksiAddon) TableName() string { return "ac_detail_transaksi_addons" }

// HistoryAddon: Data aktifasi fitur global
type HistoryAddon struct {
	ID        string    `gorm:"column:ha_id;primaryKey;size:50" json:"ha_id"`
	AddonID   string    `gorm:"column:ha_addons;size:50" json:"ha_addons"`
	OutletID  string    `gorm:"column:ha_outlet;size:50;index" json:"ha_outlet"`
	Mulai     time.Time `gorm:"column:ha_mulai" json:"ha_mulai"`
	Berakhir  time.Time `gorm:"column:ha_berakhir" json:"ha_berakhir"`
	TargetID  string    `gorm:"column:ha_target_id;size:50" json:"target_id"`
	CreatedAt time.Time `gorm:"column:ha_created;autoCreateTime" json:"ha_created"`

	Addon *Addon `gorm:"foreignKey:AddonID;references:ID" json:"addon,omitempty"`
}

func (HistoryAddon) TableName() string { return "ac_history_addons" }