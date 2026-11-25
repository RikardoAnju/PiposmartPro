package model

import "time"

type ContentBanner struct {
	ID          uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Category    string    `gorm:"type:varchar(20);not null;index" json:"category"`
	Title       string    `gorm:"type:varchar(160);not null" json:"title"`
	Summary     string    `gorm:"type:varchar(255)" json:"summary"`
	Body        string    `gorm:"type:text;not null" json:"body"`
	// VoucherCode: kode voucher opsional, khusus konten kategori PROMO. Kosong =
	// tidak menampilkan kartu salin kode di artikel.
	VoucherCode string    `gorm:"column:voucher_code;type:varchar(60)" json:"voucher_code"`
	ImageURL    string    `gorm:"column:image_url;type:varchar(255);not null" json:"image_url"`
	PublishedAt time.Time `json:"published_at"`
	IsActive    bool      `gorm:"default:true;index" json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (ContentBanner) TableName() string {
	return "ac_content_banners"
}
