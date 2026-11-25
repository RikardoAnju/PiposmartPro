package model

import "time"

// SalesLeadStatus menyimpan status tindak-lanjut sales untuk sebuah outlet
// pada halaman "Target Sales". Ini terpisah dari modul Lead Ops (yang berbasis
// import manual) — di sini status melekat langsung ke outlet dan dipakai untuk
// menandai progress kontak terhadap target yang di-skor otomatis.
//
// Nilai status yang dipakai UI: "baru", "dihubungi", "tertarik", "closing", "gagal".
type SalesLeadStatus struct {
	OutletID  string    `gorm:"column:sls_outlet;primaryKey;size:20" json:"outlet_id"`
	Status    string    `gorm:"column:sls_status;size:20;default:'baru';index" json:"status"`
	Note      string    `gorm:"column:sls_note;type:text" json:"note"`
	ByID      string    `gorm:"column:sls_by_id;size:12;index" json:"by_id"`
	ByName    string    `gorm:"column:sls_by_name;size:150" json:"by_name"`
	CreatedAt time.Time `gorm:"column:sls_created;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:sls_updated;autoUpdateTime" json:"updated_at"`
}

func (SalesLeadStatus) TableName() string {
	return "ac_sales_lead_status"
}
