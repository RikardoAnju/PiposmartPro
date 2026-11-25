package model

import "time"

type LegalDocument struct {
	ID             uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Type           string    `gorm:"type:varchar(30);not null;uniqueIndex" json:"type"`
	Title          string    `gorm:"type:varchar(160);not null" json:"title"`
	EffectiveLabel string    `gorm:"column:effective_label;type:varchar(120)" json:"effective_label"`
	Body           string    `gorm:"type:longtext;not null" json:"body"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

func (LegalDocument) TableName() string {
	return "ac_legal_documents"
}
