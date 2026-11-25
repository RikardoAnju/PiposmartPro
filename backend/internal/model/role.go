package model

import (
	"encoding/json" // Penting untuk json.RawMessage
	"time"
)

type Role struct {
	ID             string          `gorm:"column:rl_id;primaryKey;size:50;autoIncrement:false" json:"id"`
	OutletID       string          `gorm:"column:rl_outlet;size:20" json:"outlet_id"`
	Nama           string          `gorm:"column:rl_nama" json:"nama"`
	
	// DIUBAH: Menggunakan json.RawMessage agar response API rapi (JSON Object)
	// GORM tetap bisa menyimpan ini ke kolom TEXT/VARCHAR di database.
	Permission     json.RawMessage `gorm:"column:rl_permission" json:"permission"`
	
	CreatedAt      time.Time       `gorm:"column:rl_created;autoCreateTime" json:"created_at"`
	UpdatedAt      *time.Time      `gorm:"column:rl_lastupdate;autoUpdateTime" json:"updated_at"`
	
	// Identitas pengubah terakhir
	UserUpdate     string          `gorm:"column:rl_userupdate;size:50" json:"user_update"`
	UserUpdateType string          `gorm:"column:rl_userupdate_type" json:"user_update_type"`

	// Relasi Opsional
	Outlet         *Outlet         `gorm:"foreignKey:OutletID;references:ID" json:"outlet,omitempty"`
}

func (Role) TableName() string {
	return "ac_role"
}