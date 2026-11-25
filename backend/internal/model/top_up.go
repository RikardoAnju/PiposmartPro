package model

import "time"

type TopupKoin struct {
	ID           string    `gorm:"primaryKey;type:varchar(50)" json:"tk_id"`
	OutletID     string    `gorm:"type:varchar(50);column:tk_outlet" json:"tk_outlet"`
	Jumlah       int       `gorm:"column:tk_jumlah" json:"tk_jumlah"`
	MetodeBayar  string    `gorm:"type:varchar(50);column:tk_metode_bayar" json:"tk_metode_bayar"`
	KodeVoucher  *string   `gorm:"type:varchar(50);column:tk_kode_voucher" json:"tk_kode_voucher"`
	Potongan     float64   `gorm:"column:tk_potongan" json:"tk_potongan"`
	NominalDasar float64   `gorm:"column:tk_nominal_dasar" json:"tk_nominal_dasar"`
	KodeUnik     int       `gorm:"column:tk_kode_unik" json:"tk_kode_unik"`
	Total        float64   `gorm:"column:tk_total" json:"tk_total"`
	ExpiredAt    time.Time `gorm:"column:tk_expired_at" json:"tk_expired_at"`

	// INI YANG KURANG: Field untuk menyimpan link Midtrans
	SnapURL string `gorm:"type:text;column:tk_snap_url" json:"tk_snap_url"`

	BuktiTransfer      *string    `gorm:"type:varchar(255);column:tk_bukti" json:"tk_bukti"`
	TanggalUploadBukti *time.Time `gorm:"column:tk_tanggal_upload_bukti" json:"tk_tanggal_upload_bukti"`
	BankID             *uint      `gorm:"column:tk_bank_id" json:"tk_bank_id"`
	StafValidasi       *string    `gorm:"type:varchar(50);column:tk_staf_validasi" json:"tk_staf_validasi"`
	TanggalValidasi    *time.Time `gorm:"column:tk_tanggal_validasi" json:"tk_tanggal_validasi"`

	// Catatan internal admin (mis. alasan inject koin). Hanya untuk admin —
	// TIDAK boleh ditampilkan ke owner/aplikasi kasir.
	InternalNote *string `gorm:"type:varchar(255);column:tk_internal_note" json:"tk_internal_note,omitempty"`

	Status     string    `gorm:"type:varchar(20);column:tk_status" json:"tk_status"`
	CreatedAt  time.Time `gorm:"column:tk_created" json:"tk_created"`
	UpdatedAt  time.Time `gorm:"column:tk_lastupdate" json:"tk_lastupdate"`
	UserUpdate string    `gorm:"type:varchar(50);column:tk_userupdate" json:"tk_userupdate"`
}

func (TopupKoin) TableName() string {
	return "ac_top_koin"
}
