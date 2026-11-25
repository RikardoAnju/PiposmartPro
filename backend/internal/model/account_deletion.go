package model

import "time"

type AccountDeletion struct {
	ID           uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	ActorID      string    `gorm:"column:ad_actor_id;size:50;not null;index" json:"actor_id"`
	ActorType    string    `gorm:"column:ad_actor_type;size:20;not null;index" json:"actor_type"`
	ActorName    string    `gorm:"column:ad_actor_name;size:150" json:"actor_name,omitempty"`
	ActorEmail   string    `gorm:"column:ad_actor_email;size:150" json:"actor_email,omitempty"`
	ActorPhone   string    `gorm:"column:ad_actor_phone;size:30" json:"actor_phone,omitempty"`
	Reason       string    `gorm:"column:ad_reason;size:100;not null" json:"reason"`
	ReasonDetail string    `gorm:"column:ad_reason_detail;type:text" json:"reason_detail,omitempty"`
	Snapshot     string    `gorm:"column:ad_snapshot;type:longtext" json:"snapshot,omitempty"`
	CreatedAt    time.Time `gorm:"column:ad_created;autoCreateTime" json:"created_at"`
}
