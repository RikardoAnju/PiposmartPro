package model

import (
	"encoding/json"
	"time"
)

// AdminRole adalah role yang bisa di-assign ke akun admin panel
type AdminRole struct {
	ID          string          `gorm:"column:ar_id;primaryKey;size:50;autoIncrement:false" json:"id"`
	Nama        string          `gorm:"column:ar_nama" json:"nama"`
	Permissions json.RawMessage `gorm:"column:ar_permissions" json:"permissions"`
	CreatedBy   string          `gorm:"column:ar_created_by;size:12" json:"created_by"`
	CreatedAt   time.Time       `gorm:"column:ar_created;autoCreateTime" json:"created_at"`
}

func (AdminRole) TableName() string { return "ac_admin_role" }
