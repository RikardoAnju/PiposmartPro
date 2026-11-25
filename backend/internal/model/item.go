package model

import "time"

type Item struct {
	ID        string     `gorm:"column:it_id;primaryKey;size:40" json:"id"`
	OutletID  string     `gorm:"column:it_outlet;size:20" json:"outlet_id"`
	Nama      string     `gorm:"column:it_item;not null" json:"nama"`
	Status    int        `gorm:"column:it_status;default:1" json:"status"`
	CreatedAt time.Time  `gorm:"column:it_created;autoCreateTime" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:it_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`

	// DIUBAH: Dari uint menjadi string
	UserUpdate     string `gorm:"column:it_userupdate;size:50" json:"user_update,omitempty"`
	UserUpdateType string `gorm:"column:it_userupdate_type" json:"user_update_type,omitempty"`
}

func (Item) TableName() string {
	return "ac_item"
}
