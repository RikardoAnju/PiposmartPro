package model

import "time"

type OutletHistoryNama struct {
	ID            uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	OutletID      string     `gorm:"column:ot_id;size:20;index;not null" json:"ot_id"`
	OldName       string     `gorm:"column:old_name;type:varchar(255);not null" json:"old_name"`
	NewName       string     `gorm:"column:new_name;type:varchar(255);not null" json:"new_name"`
	ChangedBy     *string    `gorm:"column:changed_by;size:50" json:"changed_by"`
	ChangedByType *string    `gorm:"column:changed_by_type;size:20" json:"changed_by_type"`
	CreatedAt     time.Time  `gorm:"column:created_at;autoCreateTime" json:"created_at"`
}

func (OutletHistoryNama) TableName() string {
	return "ac_outlet_history_nama"
}
