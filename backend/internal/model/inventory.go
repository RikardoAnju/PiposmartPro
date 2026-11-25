package model

import "time"

type InventoryCategory struct {
	ID        string    `gorm:"column:ic_id;primaryKey;size:50" json:"id"`
	OutletID  string    `gorm:"column:ic_outlet;size:20;index" json:"outlet_id"`
	Name      string    `gorm:"column:ic_name;size:100" json:"name"`
	IconKey   string    `gorm:"column:ic_icon_key;size:80" json:"icon_key"`
	SortOrder int       `gorm:"column:ic_sort_order" json:"sort_order"`
	Status    int       `gorm:"column:ic_status;default:1" json:"status"`
	CreatedAt time.Time `gorm:"column:ic_created;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:ic_lastupdate;autoUpdateTime" json:"updated_at"`
}

func (InventoryCategory) TableName() string { return "ac_inventory_category" }

type InventoryItem struct {
	ID              string    `gorm:"column:ii_id;primaryKey;size:60" json:"id"`
	OutletID        string    `gorm:"column:ii_outlet;size:20;index" json:"outlet_id"`
	CategoryID      string    `gorm:"column:ii_category_id;size:50;index" json:"category_id"`
	Name            string    `gorm:"column:ii_name;size:120" json:"name"`
	Unit            string    `gorm:"column:ii_unit;size:20" json:"unit"`
	Stock           float64   `gorm:"column:ii_stock" json:"stock"`
	MinimumStock    float64   `gorm:"column:ii_minimum_stock" json:"minimum_stock"`
	Status          int       `gorm:"column:ii_status;default:1" json:"status"`
	CreatedAt       time.Time `gorm:"column:ii_created;autoCreateTime" json:"created_at"`
	UpdatedAt       time.Time `gorm:"column:ii_lastupdate;autoUpdateTime" json:"updated_at"`
	CategoryName    string    `gorm:"->" json:"category_name,omitempty"`
	CategoryIconKey string    `gorm:"->" json:"category_icon_key,omitempty"`
}

func (InventoryItem) TableName() string { return "ac_inventory_item" }

type InventoryStockMovement struct {
	ID          string    `gorm:"column:ism_id;primaryKey;size:70" json:"id"`
	OutletID    string    `gorm:"column:ism_outlet;size:20;index" json:"outlet_id"`
	ItemID      string    `gorm:"column:ism_item_id;size:60;index" json:"item_id"`
	Type        string    `gorm:"column:ism_type;size:20" json:"type"`
	Quantity    float64   `gorm:"column:ism_quantity" json:"quantity"`
	StockBefore float64   `gorm:"column:ism_stock_before" json:"stock_before"`
	StockAfter  float64   `gorm:"column:ism_stock_after" json:"stock_after"`
	Note        string    `gorm:"column:ism_note;size:255" json:"note"`
	ActorID     string    `gorm:"column:ism_actor_id;size:50" json:"actor_id"`
	ActorType   string    `gorm:"column:ism_actor_type;size:20" json:"actor_type"`
	CreatedAt   time.Time `gorm:"column:ism_created;autoCreateTime" json:"created_at"`
}

func (InventoryStockMovement) TableName() string { return "ac_inventory_stock_movement" }

type InventorySetting struct {
	OutletID          string    `gorm:"column:is_outlet;primaryKey;size:20" json:"outlet_id"`
	ReminderEnabled   bool      `gorm:"column:is_reminder_enabled" json:"reminder_enabled"`
	ReminderFrequency string    `gorm:"column:is_reminder_frequency;size:20" json:"reminder_frequency"`
	ReminderDay       string    `gorm:"column:is_reminder_day;size:15" json:"reminder_day"`
	ReminderHour      int       `gorm:"column:is_reminder_hour" json:"reminder_hour"`
	ReminderMinute    int       `gorm:"column:is_reminder_minute" json:"reminder_minute"`
	UpdatedAt         time.Time `gorm:"column:is_lastupdate;autoUpdateTime" json:"updated_at"`
}

func (InventorySetting) TableName() string { return "ac_inventory_setting" }
