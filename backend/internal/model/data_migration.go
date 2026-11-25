package model

import "time"

// DataMigration mencatat patch data satu kali. Berbeda dari AutoMigrate yang
// aman dijalankan berulang, patch permission default tidak boleh menghapus
// keputusan owner setelah owner mengubah role secara manual.
type DataMigration struct {
	Key       string    `gorm:"column:dm_key;primaryKey;size:100"`
	AppliedAt time.Time `gorm:"column:dm_applied_at;autoCreateTime"`
}

func (DataMigration) TableName() string {
	return "ac_data_migrations"
}
