package model

import "time"

type PushToken struct {
	ID         uint      `gorm:"column:pt_id;primaryKey;autoIncrement" json:"id"`
	Token      string    `gorm:"column:pt_token;size:255;not null;uniqueIndex:udx_push_token_outlet,priority:1" json:"token"`
	OutletID   string    `gorm:"column:pt_outlet;size:20;not null;index;uniqueIndex:udx_push_token_outlet,priority:2" json:"outlet_id"`
	ActorID    string    `gorm:"column:pt_actor_id;size:30;index" json:"actor_id"`
	ActorType  string    `gorm:"column:pt_actor_type;size:20;index" json:"actor_type"`
	Platform   string    `gorm:"column:pt_platform;size:20" json:"platform"`
	AppVersion string    `gorm:"column:pt_app_version;size:32" json:"app_version"`
	IsActive   bool      `gorm:"column:pt_is_active;default:true;index" json:"is_active"`
	LastSeenAt time.Time `gorm:"column:pt_last_seen_at;autoUpdateTime" json:"last_seen_at"`
	CreatedAt  time.Time `gorm:"column:pt_created;autoCreateTime" json:"created_at"`
	UpdatedAt  time.Time `gorm:"column:pt_updated;autoUpdateTime" json:"updated_at"`
}

func (PushToken) TableName() string { return "ac_push_tokens" }
