package model

import (
	"database/sql/driver"
	"encoding/json"
	"time"

	"gorm.io/datatypes"
)

type ResetBackup struct {
	ID           string         `gorm:"column:rb_id;primaryKey;size:36" json:"id"`
	OutletID     string         `gorm:"column:rb_outlet;size:20;index" json:"outlet_id"`
	ResetType    string         `gorm:"column:rb_type;size:50" json:"reset_type"` // full(factory reset)|transactions_only|customers_only
	Reason       string         `gorm:"column:rb_reason;size:255" json:"reason"`  // trial_to_production|data_cleanup|customer_request|other
	ResetAt      time.Time      `gorm:"column:rb_reset_at;autoCreateTime" json:"reset_at"`
	BackupData   datatypes.JSON `gorm:"column:rb_backup_data;type:longtext" json:"backup_data"` // JSON snapshot for recovery
	DeletedStats DeletedStats   `gorm:"column:rb_stats;type:json" json:"deleted_stats"`

	// Audit Trail
	ActorID   string `gorm:"column:rb_actor_id;size:50" json:"actor_id"`
	ActorType string `gorm:"column:rb_actor_type;size:20" json:"actor_type"` // admin

	CreatedAt time.Time `gorm:"column:rb_created;autoCreateTime" json:"created_at"`
}

func (ResetBackup) TableName() string {
	return "ac_reset_backup"
}

type DeletedStats struct {
	Orders               int64 `json:"orders"`
	Customers            int64 `json:"customers"`
	Expenses             int64 `json:"expenses"`
	DetailTransaksi      int64 `json:"detail_transaksi"`
	DPTransaksi          int64 `json:"dp_transaksi"`
	ItemTransaksi        int64 `json:"item_transaksi"`
	LogTransaksi         int64 `json:"log_transaksi"`
	HistoryKoin          int64 `json:"history_koin"`
	TopupKoin            int64 `json:"topup_koin"`
	Diskon               int64 `json:"diskon"`
	HistoryDiskon        int64 `json:"history_diskon"`
	DPOutlet             int64 `json:"dp_outlet"`
	AddonTransaksi       int64 `json:"addon_transaksi"`
	AddonDetailTransaksi int64 `json:"addon_detail_transaksi"`
	AddonHistory         int64 `json:"addon_history"`
	Pegawai              int64 `json:"pegawai"`
	Roles                int64 `json:"roles"`
	Layanan              int64 `json:"layanan"`
	JenisProduk          int64 `json:"jenis_produk"`
	Parfums              int64 `json:"parfums"`
	Items                int64 `json:"items"`
	MetodePembayaran     int64 `json:"metode_pembayaran"`
	KategoriPengeluaran  int64 `json:"kategori_pengeluaran"`
	Notifications        int64 `json:"notifications"`
}

func (ds DeletedStats) Value() (driver.Value, error) {
	return json.Marshal(ds)
}

func (ds *DeletedStats) Scan(value interface{}) error {
	bytes, _ := value.([]byte)
	return json.Unmarshal(bytes, &ds)
}
