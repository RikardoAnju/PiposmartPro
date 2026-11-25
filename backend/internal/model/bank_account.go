package model

import "time"

type BankAccount struct {
	ID            uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	BankName      string    `gorm:"type:varchar(50);not null" json:"bank_name"`      // Contoh: BCA, Mandiri
	AccountName   string    `gorm:"type:varchar(100);not null" json:"account_name"` // Nama Pemilik Rekening
	AccountNumber string    `gorm:"type:varchar(50);not null" json:"account_number"` 
	IsActive      bool      `gorm:"default:true" json:"is_active"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

func (BankAccount) TableName() string {
	return "ac_bank_accounts"
}