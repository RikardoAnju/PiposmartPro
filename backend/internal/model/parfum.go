package model

import "time"

type Parfum struct {
    ID             string     `gorm:"column:pf_id;primaryKey;size:40"` 
    OutletID       string     `gorm:"column:pf_outlet;size:20"`
    Nama           string     `gorm:"column:pf_nama"`
    Status         int        `gorm:"column:pf_status;default:1"`
    CreatedAt      time.Time  `gorm:"column:pf_created;autoCreateTime"`
    UpdatedAt      *time.Time `gorm:"column:pf_lastupdate;autoUpdateTime"`
    
    // DIUBAH: Dari uint menjadi string
    UserUpdate     string     `gorm:"column:pf_userupdate;size:50"`
    UserUpdateType string     `gorm:"column:pf_userupdate_type"`
}

func (Parfum) TableName() string {
    return "ac_parfum"
}