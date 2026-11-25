package admin

import "time"

type TopupKoinAdminRes struct {
	ID                 string     `gorm:"column:tk_id" json:"tk_id"`
	OutletID           string     `gorm:"column:tk_outlet" json:"tk_outlet"`
	OutletName         string     `gorm:"column:outlet_name" json:"outlet_name"`
	OwnerName          string     `gorm:"column:owner_name" json:"owner_name"`
	Jumlah             int        `gorm:"column:tk_jumlah" json:"tk_jumlah"`
	MetodeBayar        string     `gorm:"column:tk_metode_bayar" json:"tk_metode_bayar"`
	NominalDasar       float64    `gorm:"column:tk_nominal_dasar" json:"tk_nominal_dasar"`
	KodeUnik           int        `gorm:"column:tk_kode_unik" json:"tk_kode_unik"`
	Total              float64    `gorm:"column:tk_total" json:"tk_total"`
	ExpiredAt          time.Time  `gorm:"column:tk_expired_at" json:"tk_expired_at"`
	Bukti              *string    `gorm:"column:tk_bukti" json:"tk_bukti"`
	BankName           *string    `gorm:"column:bank_name" json:"bank_name"`
	Status             string     `gorm:"column:tk_status" json:"tk_status"`
	CreatedAt          time.Time  `gorm:"column:tk_created" json:"tk_created"`
	LastUpdate         *time.Time `gorm:"column:tk_lastupdate" json:"tk_lastupdate"`
	TanggalUploadBukti *time.Time `gorm:"column:tk_tanggal_upload_bukti" json:"tk_tanggal_upload_bukti"`
	TanggalValidasi    *time.Time `gorm:"column:tk_tanggal_validasi" json:"tk_tanggal_validasi"`
	StafValidasi       *string    `gorm:"column:tk_staf_validasi" json:"tk_staf_validasi"`
}

type PemasukanKoinAdminRes struct {
	ID                 string     `json:"tk_id"`
	OutletID           string     `json:"tk_outlet"`
	OutletName         string     `json:"outlet_name"`
	OwnerName          string     `json:"owner_name"`
	Jumlah             int        `json:"tk_jumlah"`
	MetodeBayar        string     `json:"tk_metode_bayar"`
	SourceType         string     `json:"source_type"`
	NominalDasar       float64    `json:"tk_nominal_dasar"`
	KodeUnik           int        `json:"tk_kode_unik"`
	Total              float64    `json:"tk_total"`
	ExpiredAt          time.Time  `json:"tk_expired_at"`
	Bukti              *string    `json:"tk_bukti"`
	BankName           *string    `json:"bank_name"`
	Status             string     `json:"tk_status"`
	CreatedAt          time.Time  `json:"tk_created"`
	LastUpdate         *time.Time `json:"tk_lastupdate"`
	TanggalUploadBukti *time.Time `json:"tk_tanggal_upload_bukti"`
	TanggalValidasi    *time.Time `json:"tk_tanggal_validasi"`
	StafValidasi       *string    `json:"tk_staf_validasi"`
	Keterangan         string     `json:"keterangan"`
	BonusType          string     `json:"bonus_type"`
	// Urutan dan tipe ini dihitung terhadap waktu transaksi, bukan dari total
	// terkini, sehingga transaksi lama tidak berubah saat ada top up baru.
	TopupSequence     int    `json:"topup_sequence"`
	CustomerTopupType string `json:"customer_topup_type"`
}

type CoinLedgerAdminRes struct {
	ID             string    `gorm:"column:hk_id" json:"hk_id"`
	OutletID       string    `gorm:"column:hk_outlet" json:"hk_outlet"`
	OutletName     string    `gorm:"column:outlet_name" json:"outlet_name"`
	OwnerName      string    `gorm:"column:owner_name" json:"owner_name"`
	JenisTransaksi string    `gorm:"column:hk_jenis_transaksi" json:"hk_jenis_transaksi"`
	Jumlah         int       `gorm:"column:hk_jumlah" json:"hk_jumlah"`
	Keterangan     string    `gorm:"column:hk_keterangan" json:"hk_keterangan"`
	Status         int       `gorm:"column:hk_status" json:"hk_status"`
	CreatedAt      time.Time `gorm:"column:hk_created" json:"hk_created"`
	SourceType     string    `gorm:"column:source_type" json:"source_type"`
}
