package admin

type CustomerListResult struct {
	ID         string `json:"id" gorm:"column:pel_id"`
	Name       string `json:"name" gorm:"column:pel_nama"`
	NoHP       string `json:"nohp" gorm:"column:pel_nohp"`
	OutletName string `json:"outlet_name" gorm:"column:ot_nama"`
	OutletID   string `json:"outlet_id" gorm:"column:ot_id"`
	TotalTrans int    `json:"total_transaksi" gorm:"column:total_trans"`
	CreatedAt  string `json:"created_at" gorm:"column:pel_created"`
}