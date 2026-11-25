package model

import "time"

// OTPRequestLog menyimpan audit request OTP untuk admin panel.
type OTPRequestLog struct {
	ID        uint      `gorm:"column:ol_id;primaryKey;autoIncrement" json:"id"`
	Phone     string    `gorm:"column:ol_phone;size:25;index" json:"phone"`
	Email     *string   `gorm:"column:ol_email;size:191;index" json:"email,omitempty"`
	Flow      string    `gorm:"column:ol_flow;size:40;index" json:"flow"`
	Event     string    `gorm:"column:ol_event;size:40;index" json:"event"`
	Provider  string    `gorm:"column:ol_provider;size:30;default:fonnte" json:"provider"`
	OTPCode   *string   `gorm:"column:ol_otp_code;size:10" json:"otp_code,omitempty"`
	Message   string    `gorm:"column:ol_message;type:text" json:"message"`
	CreatedAt time.Time `gorm:"column:ol_created;autoCreateTime" json:"created_at"`
}

func (OTPRequestLog) TableName() string { return "ac_otp_request_logs" }
