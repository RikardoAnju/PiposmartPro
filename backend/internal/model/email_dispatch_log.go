package model

import "time"

type EmailDispatchLog struct {
	ID           uint       `gorm:"column:edl_id;primaryKey;autoIncrement" json:"id"`
	Category     string     `gorm:"column:edl_category;size:60;index" json:"category"`
	Email        string     `gorm:"column:edl_email;size:191;index" json:"email"`
	UserID       *uint      `gorm:"column:edl_user_id;index" json:"user_id,omitempty"`
	OutletID     *string    `gorm:"column:edl_outlet_id;size:20;index" json:"outlet_id,omitempty"`
	DispatchDate string     `gorm:"column:edl_dispatch_date;size:20;index" json:"dispatch_date"`
	Status       string     `gorm:"column:edl_status;size:30;index" json:"status"`
	Subject      string     `gorm:"column:edl_subject;size:191" json:"subject"`
	Provider     string     `gorm:"column:edl_provider;size:30" json:"provider"`
	ProviderID   *string    `gorm:"column:edl_provider_id;size:191" json:"provider_id,omitempty"`
	Message      *string    `gorm:"column:edl_message;type:text" json:"message,omitempty"`
	SentAt       *time.Time `gorm:"column:edl_sent_at" json:"sent_at,omitempty"`
	CreatedAt    time.Time  `gorm:"column:edl_created;autoCreateTime" json:"created_at"`
	UpdatedAt    *time.Time `gorm:"column:edl_lastupdate;autoUpdateTime" json:"updated_at,omitempty"`
}

func (EmailDispatchLog) TableName() string {
	return "ac_email_dispatch_logs"
}
