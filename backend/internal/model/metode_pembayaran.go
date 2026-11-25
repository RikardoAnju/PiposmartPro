package model

import "time"

type MetodePembayaran struct {
	ID        string `gorm:"column:mp_id;primaryKey;size:40"`
	OutletID  string `gorm:"column:mp_outlet;size:20"`
	Nama      string `gorm:"column:mp_nama_metode"`
	Deskripsi string `gorm:"column:mp_deskripsi"`
	Kategori  string `gorm:"column:mp_kategori"` // Cash | Transfer | E-Wallet
	// Jangan gunakan default tag di sini: GORM dapat menghilangkan nilai 0
	// saat insert, sehingga metode yang sengaja dibuat nonaktif menjadi aktif.
	Status int `gorm:"column:mp_status"`

	NamaPemilik     *string `gorm:"column:mp_nama_pemilik"`
	NomorAkun       *string `gorm:"column:mp_nomor_akun"`
	NamaBank        *string `gorm:"column:mp_nama_bank"`
	EwalletProvider *string `gorm:"column:mp_ewallet_provider"`
	NomorHP         *string `gorm:"column:mp_nomor_hp"`

	CreatedAt time.Time  `gorm:"column:mp_created;autoCreateTime"`
	UpdatedAt *time.Time `gorm:"column:mp_lastupdate;autoUpdateTime"`

	// DIUBAH: Dari uint menjadi string
	UserUpdate     string `gorm:"column:mp_userupdate;size:50"`
	UserUpdateType string `gorm:"column:mp_userupdate_type"`
}

func (MetodePembayaran) TableName() string {
	return "ac_metode_pembayaran"
}
