package admin

type OwnerListResult struct {
	ID           uint   `json:"id" gorm:"column:ac_id"`
	Name         string `json:"name" gorm:"column:ac_nama"`
	Email        string `json:"email" gorm:"column:ac_email"`
	NoHP         string `json:"nohp" gorm:"column:ac_nohp"` // Tambahkan ini
	OwnerCode    string `json:"owner_code" gorm:"column:ac_owner_code"`
	TotalOutlets int    `json:"total_outlets" gorm:"column:total_outlets"`
	Status       int    `json:"status" gorm:"column:ac_status"`
	CreatedAt    string `json:"created_at" gorm:"column:ac_created"`
}
