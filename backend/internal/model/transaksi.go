package model

import "time"

type Transaksi struct {
	ID               string     `gorm:"column:tr_id;primaryKey;size:60" json:"id"`
	OutletID         string     `gorm:"column:tr_outlet;size:20;index:idx_trx_perf,priority:1" json:"outlet_id"`
	StatusOrder      string     `gorm:"column:tr_status_order;default:'Antrian';index:idx_trx_perf,priority:2" json:"status_order"`
	CreatedAt        time.Time  `gorm:"column:tr_created;autoCreateTime;index:idx_trx_perf,priority:3" json:"created_at"`
	PelangganID      string     `gorm:"column:tr_pelanggan;size:60;index:idx_trx_pelanggan" json:"pelanggan_id"`
	ParfumID         *string    `gorm:"column:tr_parfum;size:40" json:"parfum_id,omitempty"`
	DiskonID         *string    `gorm:"column:tr_diskon;size:50" json:"diskon_id,omitempty"`
	TotalKotor       float64    `gorm:"column:tr_total_kotor" json:"total_kotor"`
	PotonganDiskon   float64    `gorm:"column:tr_potongan_diskon" json:"potongan_diskon"`
	RoundingAmount   float64    `gorm:"column:tr_rounding" json:"rounding_amount"` // BARU: Simpan selisih pembulatan
	Total            float64    `gorm:"column:tr_total" json:"total_akhir"`
	StatusPembayaran string     `gorm:"column:tr_status_pembayaran;default:'Belum Lunas';index" json:"status_pembayaran"`
	Catatan          *string    `gorm:"column:tr_catatan" json:"catatan,omitempty"`
	UpdatedAt        *time.Time `gorm:"column:tr_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
	UserUpdate       *string    `gorm:"column:tr_userupdate;size:50" json:"user_update,omitempty"`
	UserUpdateType   *string    `gorm:"column:tr_userupdate_type" json:"user_update_type,omitempty"`
	JemputAlamat     *string    `gorm:"column:tr_jemput_alamat" json:"jemput_alamat,omitempty"`
	JemputBiaya      *float64   `gorm:"column:tr_jemput_biaya" json:"jemput_biaya,omitempty"`
	AntarAlamat      *string    `gorm:"column:tr_antar_alamat" json:"antar_alamat,omitempty"`
	AntarBiaya       *float64   `gorm:"column:tr_antar_biaya" json:"antar_biaya,omitempty"`
	Estimate         *time.Time `gorm:"column:tr_estimate" json:"estimate_at"`
	KasirNama        string     `gorm:"column:tr_kasir_nama;size:100" json:"kasir_name,omitempty"`
	MetodePembayaran string     `gorm:"column:metode_pembayaran" json:"metode_pembayaran"` // Scan dari subquery
	DPAmount         float64    `gorm:"column:dp_amount;->" json:"dp_amount"`
	SisaBayar        float64    `gorm:"column:sisa_bayar;->" json:"sisa_bayar"`

	Pelanggan      Pelanggan         `gorm:"foreignKey:PelangganID;references:ID" json:"pelanggan,omitempty"`
	Outlet         *Outlet           `gorm:"foreignKey:OutletID;references:ID" json:"outlet,omitempty"`
	Parfum         *Parfum           `gorm:"foreignKey:ParfumID;references:ID" json:"parfum,omitempty"`
	Diskon         *Diskon           `gorm:"foreignKey:DiskonID;references:ID" json:"diskon,omitempty"`
	Details        []DetailTransaksi `gorm:"foreignKey:TransaksiID;references:ID" json:"details,omitempty"`
	PaymentHistory []DPTransaksi     `gorm:"foreignKey:TransaksiID;references:ID" json:"payment_history,omitempty"`
	Items          []ItemTransaksi   `gorm:"foreignKey:TransaksiID;references:ID" json:"items,omitempty"`
	Logs           []LogTransaksi    `gorm:"foreignKey:TransaksiID;references:ID" json:"logs,omitempty"`
}

func (Transaksi) TableName() string {
	return "ac_transaksi"
}
