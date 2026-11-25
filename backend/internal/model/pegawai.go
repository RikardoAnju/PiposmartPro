package model

import "time"

type Pegawai struct {
	ID              string     `gorm:"column:pg_id;primaryKey;size:30" json:"id"`
	OutletID        string     `gorm:"column:pg_outlet;size:20;index" json:"outlet_id"`
	RoleID          string     `gorm:"column:pg_role;size:50;not null" json:"role_id"`
	Nama            string     `gorm:"column:pg_nama" json:"nama"`
	Email           string     `gorm:"column:pg_email;unique" json:"email"`
	NoHP            string     `gorm:"column:pg_nohp" json:"nohp"`
	TanggalLahir    *time.Time `gorm:"column:pg_tanggal_lahir" json:"tanggal_lahir"`
	Password        *string    `gorm:"column:pg_password" json:"-"`
	Status          int        `gorm:"column:pg_status;default:1" json:"status"` // 1: Aktif, 0: Non-aktif
	TokenVersion    int        `gorm:"column:pg_token_version;default:0" json:"token_version"`
	DeletedAt       *time.Time `gorm:"column:pg_deleted_at;index" json:"deleted_at,omitempty"`
	AllOutletAccess bool       `gorm:"column:pg_all_outlet_access;default:false" json:"all_outlet_access"`
	LastOutletID    *string    `gorm:"column:pg_last_outlet;size:20" json:"last_outlet_id,omitempty"`

	// --- KONTROL ADDON INDEPENDEN (NEW) ---
	// Type: 'base' (untuk 2 pegawai gratis pertama), 'addon' (untuk pegawai berbayar)
	Type string `gorm:"column:pg_type;size:20;default:'base'" json:"type"`
	// ActiveUntil: Masa aktif pegawai. Jika Type='addon', tgl ini yang menentukan status login.
	// Jika Type='base', field ini bisa null (aktif selamanya).
	ActiveUntil *time.Time `gorm:"column:pg_active_until" json:"active_until"`

	CreatedAt time.Time  `gorm:"column:pg_created;autoCreateTime" json:"created_at"`
	UpdatedAt *time.Time `gorm:"column:pg_lastupdate;autoUpdateTime" json:"updated_at"`

	Role   *Role   `gorm:"foreignKey:RoleID;references:ID" json:"role,omitempty"`
	Outlet *Outlet `gorm:"foreignKey:OutletID;references:ID" json:"outlet,omitempty"`
}

func (Pegawai) TableName() string {
	return "ac_pegawai"
}
