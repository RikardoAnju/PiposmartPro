package model

import "time"

type PegawaiHistory struct {
	ID        string    `gorm:"column:ph_id;primaryKey;size:36" json:"id"`
	OutletID  string    `gorm:"column:ph_outlet;size:20;index" json:"outlet_id"`
	PegawaiID string    `gorm:"column:ph_pegawai;size:36;index" json:"pegawai_id"`
	Action    string    `gorm:"column:ph_action;size:20;index" json:"action"`
	ActorID   *string   `gorm:"column:ph_actor_id;size:50" json:"actor_id,omitempty"`
	ActorType *string   `gorm:"column:ph_actor_type;size:20" json:"actor_type,omitempty"`
	Snapshot  string    `gorm:"column:ph_snapshot;type:longtext" json:"snapshot"`
	CreatedAt time.Time `gorm:"column:ph_created;autoCreateTime" json:"created_at"`
}

func (PegawaiHistory) TableName() string { return "ac_pegawai_history" }
