package model

import "time"

type AppSetting struct {
	ID                      uint       `gorm:"column:aps_id;primaryKey;autoIncrement" json:"aps_id"`
	WhatsappNumber          *string    `gorm:"column:aps_whatsapp" json:"whatsapp_number"`
	InstagramUsername       *string    `gorm:"column:aps_instagram" json:"instagram_username"`
	FacebookUsername        *string    `gorm:"column:aps_facebook" json:"facebook_username"`
	Email                   *string    `gorm:"column:aps_email" json:"email"`
	TiktokUsername          *string    `gorm:"column:aps_tiktok" json:"tiktok_username"`
	WebsiteUrl              *string    `gorm:"column:aps_website" json:"website_url"`
	PlaystoreUrl            *string    `gorm:"column:aps_playstore" json:"playstore_url"`
	AppstoreUrl             *string    `gorm:"column:aps_appstore" json:"appstore_url"`
	AppVersion              *string    `gorm:"column:aps_app_version" json:"app_version"`
	MinimumSupportedVersion *string    `gorm:"column:aps_min_supported_version" json:"minimum_supported_version"`
	AppVersionIOS              *string `gorm:"column:aps_app_version_ios" json:"app_version_ios"`
	MinimumSupportedVersionIOS *string `gorm:"column:aps_min_supported_version_ios" json:"minimum_supported_version_ios"`
	UpdatedAt               *time.Time `gorm:"column:aps_updated_at;autoUpdateTime" json:"updated_at"`
}

func (AppSetting) TableName() string {
	return "ac_app_settings"
}
