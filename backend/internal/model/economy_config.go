// internal/model/economy_config.go
package model

type EconomyConfig struct {
    Key   string `gorm:"column:cfg_key;primaryKey;size:50" json:"cfg_key"`
    Value string `gorm:"column:cfg_value;not null" json:"cfg_value"`
    Type  string `gorm:"column:cfg_type;size:20;default:'amount'" json:"cfg_type"` // 'amount', 'percentage', 'text'
    Desc  string `gorm:"column:cfg_desc" json:"cfg_desc"`
}

func (EconomyConfig) TableName() string {
    return "ac_config_economy"
}