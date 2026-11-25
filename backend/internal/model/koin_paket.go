// internal/model/koin_package.go
package model

import "time"

type KoinPackage struct {
	ID          uint      `gorm:"primaryKey" json:"id"`
	JumlahKoin  int       `gorm:"column:pk_jumlah;not null" json:"jumlah_koin"`
	DiscountPct int       `gorm:"column:pk_discount;default:0" json:"discount_pct"`
	IsActive    bool      `gorm:"column:pk_status;default:true" json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

func (KoinPackage) TableName() string {
	return "ac_koin_packages"
}