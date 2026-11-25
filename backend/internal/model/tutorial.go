package model

import "time"

type Tutorial struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	Type      string    `gorm:"type:varchar(20);not null;index" json:"type"`
	Category  string    `gorm:"type:varchar(40);not null;index" json:"category"`
	Title     string    `gorm:"type:varchar(180);not null" json:"title"`
	Summary   string    `gorm:"type:varchar(255)" json:"summary"`
	Body      string    `gorm:"type:text" json:"body"`
	VideoURL  string    `gorm:"column:video_url;type:varchar(255)" json:"video_url"`
	YoutubeID string    `gorm:"column:youtube_id;type:varchar(40)" json:"youtube_id"`
	PdfURL    string    `gorm:"column:pdf_url;type:varchar(255)" json:"pdf_url"`
	Duration  string    `gorm:"type:varchar(32)" json:"duration"`
	SortOrder int       `gorm:"column:sort_order;default:0;index" json:"sort_order"`
	IsActive  bool      `gorm:"default:true;index" json:"is_active"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (Tutorial) TableName() string {
	return "ac_tutorials"
}
