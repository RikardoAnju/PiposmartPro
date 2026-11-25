package model

import "time"

type HistoryKoin struct {
	ID             string     `gorm:"column:hk_id;primaryKey;size:60" json:"hk_id"`
	OutletID       string     `gorm:"column:hk_outlet;not null" json:"hk_outlet"`
	JenisTransaksi string     `gorm:"column:hk_jenis_transaksi" json:"hk_jenis_transaksi"` // 'masuk' atau 'keluar'
	Jumlah         int        `gorm:"column:hk_jumlah" json:"hk_jumlah"`                   // <--- TAMBAHKAN INI
	Keterangan     string     `gorm:"column:hk_keterangan" json:"hk_keterangan"`
	Status         int        `gorm:"column:hk_status" json:"hk_status"`
	CreatedAt      time.Time  `gorm:"column:hk_created;autoCreateTime" json:"hk_created"`
	UpdatedAt      *time.Time `gorm:"column:hk_lastupdate;autoUpdateTime" json:"hk_lastupdate"`
	UserUpdate     string     `gorm:"column:hk_userupdate" json:"hk_userupdate"`
}

func (HistoryKoin) TableName() string {
	return "ac_history_koin"
}