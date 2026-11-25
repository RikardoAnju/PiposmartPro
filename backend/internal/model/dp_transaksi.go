package model

import "time"

type DPTransaksi struct {
	ID                  string     `gorm:"column:dptr_id;primaryKey;size:70" json:"id"`
	TransaksiID         string     `gorm:"column:dptr_transaksi;size:60" json:"transaksi_id"`
	MetodePembayaranID  string     `gorm:"column:dptr_metode_pembayaran;size:40" json:"metode_pembayaran_id"`
	BuktiDP             *string    `gorm:"column:dptr_bukti_dp" json:"bukti_dp,omitempty"`
	TanggalDP           time.Time  `gorm:"column:dptr_tanggal_dp;index:idx_dp_trx_tanggal" json:"tanggal_dp"`
	JumlahDP            float64    `gorm:"column:dptr_jumlah_dp" json:"jumlah_dp"`
	JumlahSisa          float64    `gorm:"column:dptr_jumlah_sisa" json:"jumlah_sisa"`
	DepositUsageAmount  float64    `gorm:"-" json:"deposit_usage_amount,omitempty"`
	DepositBalanceAfter *float64   `gorm:"-" json:"deposit_balance_after,omitempty"`
	CreatedAt           time.Time  `gorm:"column:dptr_created;autoCreateTime" json:"created_at"`
	UpdatedAt           *time.Time `gorm:"column:dptr_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`

	// DIUBAH: Dari uint menjadi string
	UserUpdate string `gorm:"column:dptr_userupdate;size:50" json:"user_update"`

	MetodePembayaran *MetodePembayaran `gorm:"foreignKey:MetodePembayaranID;references:ID" json:"metode_pembayaran,omitempty"`
}

func (DPTransaksi) TableName() string {
	return "ac_dp_transaksi"
}
