package model

import "time"

type Outlet struct {
	ID              string   `gorm:"column:ot_id;primaryKey;size:20" json:"ot_id"`
	UserID          uint     `gorm:"column:ot_user;not null" json:"ot_user"`
	Nama            string   `gorm:"column:ot_nama" json:"ot_nama"`
	NoHP            *string  `gorm:"column:ot_nohp" json:"ot_nohp"`
	Provinsi        *string  `gorm:"column:ot_provinsi" json:"ot_provinsi"`
	Kota            *string  `gorm:"column:ot_kota" json:"ot_kota"`
	Kecamatan       *string  `gorm:"column:ot_kecamatan" json:"ot_kecamatan"`
	Alamat          *string  `gorm:"column:ot_alamat" json:"ot_alamat"`
	Latitude        *float64 `gorm:"column:ot_latitude" json:"ot_latitude"`
	Longitude       *float64 `gorm:"column:ot_longitude" json:"ot_longitude"`
	LocationRadius  int      `gorm:"column:ot_location_radius_meters;not null;default:5" json:"ot_location_radius_meters"`
	Gambar          *string  `gorm:"column:ot_gambar" json:"ot_gambar"`
	TipeLokasiUsaha *string  `gorm:"column:ot_tipe_lokasi_usaha;size:30" json:"ot_tipe_lokasi_usaha"`
	ModalUsaha      *string  `gorm:"column:ot_modal_usaha;size:50" json:"ot_modal_usaha"`
	JumlahKaryawan  *string  `gorm:"column:ot_jumlah_karyawan;size:30" json:"ot_jumlah_karyawan"`
	JumlahMesin     *string  `gorm:"column:ot_jumlah_mesin;size:30" json:"ot_jumlah_mesin"`
	TanggalBerjalan *string  `gorm:"column:ot_tanggal_berjalan" json:"ot_tanggal_berjalan"`
	Koin            int      `gorm:"column:ot_koin;default:0" json:"ot_koin"`
	Timezone        string   `gorm:"column:ot_timezone;size:20;default:'WIB'" json:"ot_timezone"` // WIB, WITA, WIT
	Status          int      `gorm:"column:ot_status;default:1" json:"ot_status"`

	// --- SISTEM AKTIVASI & TRIAL ---
	ActivatedAt    *time.Time `gorm:"column:ot_activated_at" json:"ot_activated_at"` // Null = Belum Aktivasi One-time
	TrialExpiresAt time.Time  `gorm:"column:ot_trial_at" json:"ot_trial_at"`         // Regis + 30 Hari

	// --- KONTROL LIMITASI DASAR ---
	// Default 2. Pegawai ke-3 dst akan dicek status addon-nya di masing-masing record pegawai
	MaxPegawaiBase int `gorm:"column:ot_max_pegawai_base;default:2" json:"max_pegawai_base"`

	// Konfigurasi Fitur Internal
	SkipProses         int `gorm:"column:ot_skip_proses;default:0" json:"ot_skip_proses"`
	IsMetodePembayaran int `gorm:"column:ot_metode_pembayaran;default:1" json:"ot_metode_pembayaran"`
	IsFiturDiskon      int `gorm:"column:ot_fitur_diskon;default:1" json:"ot_fitur_diskon"`

	CreatedAt time.Time  `gorm:"column:ot_created;autoCreateTime" json:"ot_created"`
	UpdatedAt *time.Time `gorm:"column:ot_lastupdate;autoUpdateTime" json:"updated_at"`

	// Audit Trail
	UserUpdate     *string `gorm:"column:ot_userupdate;size:50" json:"ot_userupdate"`
	UserUpdateType *string `gorm:"column:ot_userupdate_type" json:"ot_userupdate_type"`

	// Relasi
	Roles          []Role             `gorm:"foreignKey:OutletID;references:ID" json:"roles,omitempty"`
	Pegawai        []Pegawai          `gorm:"foreignKey:OutletID;references:ID" json:"pegawai,omitempty"`
	Layanan        []Layanan          `gorm:"foreignKey:OutletID;references:ID" json:"layanan,omitempty"`
	Items          []Item             `gorm:"foreignKey:OutletID;references:ID" json:"items,omitempty"`
	Parfums        []Parfum           `gorm:"foreignKey:OutletID;references:ID" json:"parfums,omitempty"`
	Discounts      []Diskon           `gorm:"foreignKey:OutletID;references:ID" json:"discounts,omitempty"`
	PaymentMethods []MetodePembayaran `gorm:"foreignKey:OutletID;references:ID" json:"payment_methods,omitempty"`
	Customers      []Pelanggan        `gorm:"foreignKey:OutletID;references:ID" json:"customers,omitempty"`
	TopupKoin      []TopupKoin        `gorm:"foreignKey:OutletID;references:ID" json:"topup_koin,omitempty"`
	HistoryKoin    []HistoryKoin      `gorm:"foreignKey:OutletID;references:ID" json:"history_koin,omitempty"`
	Notifications  []NotifReceiver    `gorm:"foreignKey:OutletID;references:ID" json:"notifications,omitempty"`
}

func (Outlet) TableName() string {
	return "ac_outlet"
}

func (o Outlet) GetLocation() *time.Location {
	switch o.Timezone {
	case "WITA":
		return time.FixedZone("WITA", 8*3600)
	case "WIT":
		return time.FixedZone("WIT", 9*3600)
	default:
		return time.FixedZone("WIB", 7*3600)
	}
}
