package model

import "time"

type User struct {
	ID         uint    `gorm:"column:usr_id;primaryKey;autoIncrement" json:"usr_id"`
	Nama       string  `gorm:"column:usr_nama;not null" json:"usr_nama"`
	Email      string  `gorm:"column:usr_email;unique;not null" json:"usr_email"`
	Password   *string `json:"-" gorm:"column:usr_password"`
	NoHP       *string `gorm:"column:usr_nohp" json:"usr_nohp"`
	GoogleID   *string `gorm:"column:usr_google_id" json:"usr_google_id"`
	AppleID    *string `gorm:"column:usr_apple_id" json:"usr_apple_id"`
	LeadSource *string `gorm:"column:usr_lead_source;size:100" json:"usr_lead_source"`

	// Field untuk Fitur Ingat Outlet Terakhir
	LastOutletID *string `gorm:"column:usr_last_outlet;size:20" json:"usr_last_outlet"`

	ReferralCode string     `gorm:"column:usr_referral_code;unique" json:"usr_referral_code"` // Kode milik user ini
	ReferredBy   *uint      `gorm:"column:usr_referred_by" json:"usr_referred_by"`            // ID user pengajak
	Status       int        `gorm:"column:usr_status;default:1" json:"usr_status"`
	CreatedAt    time.Time  `gorm:"column:usr_created;autoCreateTime" json:"usr_created"`
	UpdatedAt    *time.Time `gorm:"column:usr_lastupdate;autoUpdateTime" json:"usr_lastupdate"`

	// Relasi ke Outlet
	Outlets []Outlet `gorm:"foreignKey:UserID;references:ID" json:"outlets,omitempty"`
}

func (User) TableName() string {
	return "ac_user"
}
