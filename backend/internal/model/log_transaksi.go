package model

import "time"

type LogTransaksi struct {
	ID                string    `gorm:"column:lr_id;primaryKey;size:80"`
	TransaksiID       string    `gorm:"column:lr_transaksi;size:60"`
	DetailTransaksiID *string   `gorm:"column:lr_detail_transaksi;size:80"`
	Scope             string    `gorm:"column:lr_scope"`  
	Field             string    `gorm:"column:lr_field"`
	OldValue          *string   `gorm:"column:lr_old_value"`
	NewValue          *string   `gorm:"column:lr_new_value"`
	ActorID           string    `gorm:"column:lr_actor_id;size:50"`
	ActorType         string    `gorm:"column:lr_actor_type"`
	CreatedAt         time.Time `gorm:"column:lr_created;autoCreateTime"`
	ActorName string `gorm:"-"`
}

func (LogTransaksi) TableName() string {
	return "ac_log_transaksi"
}