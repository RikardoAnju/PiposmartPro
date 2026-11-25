package model

import (
	"time"

	"gorm.io/datatypes"
)

type Pengeluaran struct {
	ID             string         `gorm:"column:pg_id;primaryKey;size:50" json:"id"`
	KategoriID     string         `gorm:"column:pg_kategori;size:50" json:"kategori_id"`
	OutletID       string         `gorm:"column:pg_outlet;size:20;index:idx_pg_outlet_tanggal,priority:1" json:"outlet_id"`
	Tanggal        time.Time      `gorm:"column:pg_tanggal;index:idx_pg_outlet_tanggal,priority:2" json:"tanggal"`
	DueDate        *time.Time     `gorm:"column:pg_due_date;index" json:"due_date,omitempty"`
	Total          float64        `gorm:"column:pg_total" json:"total"`
	Keterangan     string         `gorm:"column:pg_keterangan" json:"keterangan"`
	Bukti          datatypes.JSON `gorm:"column:pg_bukti" json:"bukti"`
	SourceType     string         `gorm:"column:pg_source_type;size:30;index" json:"source_type,omitempty"`
	SourceID       string         `gorm:"column:pg_source_id;size:50;index" json:"source_id,omitempty"`
	CreatedAt      time.Time      `gorm:"column:pg_created;autoCreateTime" json:"created_at"`
	UpdatedAt      *time.Time     `gorm:"column:pg_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
	UserUpdate     string         `gorm:"column:pg_userupdate;size:50" json:"user_update"`
	UserUpdateType string         `gorm:"column:pg_userupdate_type" json:"user_update_type"`

	// --- VIRTUAL FIELDS (Update Terbaru) ---
	// Tag gorm:"->" menandakan field ini read-only (hanya untuk pengambilan data via Join)
	KategoriNama   string `gorm:"->" json:"kategori_nama"`
	UserUpdateNama string `gorm:"->" json:"user_update_nama"`

	// Field ini tetap dipertahankan untuk kompatibilitas jika dibutuhkan Preload di tempat lain
	Kategori KategoriPengeluaran `gorm:"foreignKey:KategoriID;references:ID" json:"kategori_info,omitempty"`
}

func (Pengeluaran) TableName() string {
	return "ac_pengeluaran"
}
