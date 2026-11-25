package model

import "time"

type Admin struct {
	ID        string     `gorm:"column:adm_id;primaryKey;size:12" json:"adm_id"` // ADM.000001
	Nama      string     `gorm:"column:adm_nama" json:"adm_nama"`
	Email     string     `gorm:"column:adm_email;unique" json:"adm_email"`
	Password  string     `gorm:"column:adm_password" json:"-"`
	RoleID    *string    `gorm:"column:adm_role;size:50" json:"adm_role"`
	IsMaster  bool       `gorm:"column:adm_is_master;default:false" json:"adm_is_master"`
	CreatedAt time.Time  `gorm:"column:adm_created;autoCreateTime" json:"adm_created"`

	// Relasi (opsional, preload saat dibutuhkan)
	Role *AdminRole `gorm:"foreignKey:RoleID;references:ID" json:"role,omitempty"`
}

func (Admin) TableName() string { return "ac_admin" }