package model

import (
	"time"

	"gorm.io/datatypes"
)

// NotifMaster menyimpan konten pesan (1 baris untuk 1 broadcast)
type NotifMaster struct {
	ID            string         `gorm:"column:nm_id;primaryKey;size:60" json:"id"`
	Kategori      string         `gorm:"column:nm_kategori" json:"kategori"`
	Judul         string         `gorm:"column:nm_judul" json:"judul"`
	Pesan         string         `gorm:"column:nm_pesan" json:"pesan"`
	ImageURL      *string        `gorm:"column:nm_image_url" json:"image_url"`
	Type          string         `gorm:"column:nm_type;size:80;default:announcement" json:"type"`
	Payload       datatypes.JSON `gorm:"column:nm_payload;type:json" json:"payload"`
	CTALabel      string         `gorm:"column:nm_cta_label;size:80" json:"cta_label"`
	SchemaVersion int            `gorm:"column:nm_schema_version;default:1" json:"schema_version"`
	Source        string         `gorm:"column:nm_source;size:20;default:SYSTEM" json:"source"`
	UserUpdate    string         `gorm:"column:nm_userupdate" json:"user_update"`
	CreatedAt     time.Time      `gorm:"column:nm_created;autoCreateTime" json:"created_at"`
}

func (NotifMaster) TableName() string { return "ac_notif_master" }

// NotifReceiver menyimpan status per outlet (N baris per broadcast)
type NotifReceiver struct {
	ID uint `gorm:"column:nr_id;primaryKey;autoIncrement" json:"id"`
	// nm_id di master itu varchar(60), jadi di sini harus varchar(60) juga
	MasterID string `gorm:"column:nr_nm_id;size:60;index;index:idx_notif_receiver_master_status,priority:1" json:"master_id"`
	// ot_id di outlet itu varchar(20), jadi di sini harus varchar(20) juga
	OutletID           string     `gorm:"column:nr_outlet;size:20;index" json:"outlet_id"`
	RecipientActorID   string     `gorm:"column:nr_recipient_actor_id;size:60;index" json:"-"`
	RecipientActorType string     `gorm:"column:nr_recipient_actor_type;size:20;index" json:"-"`
	Status             int        `gorm:"column:nr_status;default:0;index:idx_notif_receiver_master_status,priority:2" json:"status"`
	ReadAt             *time.Time `gorm:"column:nr_read_at" json:"read_at"`

	// Definisikan relasi secara eksplisit agar GORM nggak bingung
	Master NotifMaster `gorm:"foreignKey:MasterID;references:ID" json:"content"`
}

func (NotifReceiver) TableName() string { return "ac_notif_receiver" }

type NotifEvent struct {
	ID         uint      `gorm:"column:ne_id;primaryKey;autoIncrement" json:"id"`
	MasterID   string    `gorm:"column:ne_nm_id;size:60;index;not null;index:idx_notif_event_master_type,priority:1" json:"master_id"`
	OutletID   string    `gorm:"column:ne_outlet;size:20;index;not null" json:"outlet_id"`
	ActorID    string    `gorm:"column:ne_actor_id;size:60" json:"actor_id"`
	ActorType  string    `gorm:"column:ne_actor_type;size:20" json:"actor_type"`
	EventType  string    `gorm:"column:ne_event_type;size:40;index;not null;index:idx_notif_event_master_type,priority:2" json:"event_type"`
	Target     string    `gorm:"column:ne_target;size:80" json:"target"`
	Reason     string    `gorm:"column:ne_reason;size:255" json:"reason"`
	Platform   string    `gorm:"column:ne_platform;size:20" json:"platform"`
	AppVersion string    `gorm:"column:ne_app_version;size:30" json:"app_version"`
	CreatedAt  time.Time `gorm:"column:ne_created;autoCreateTime" json:"created_at"`
}

func (NotifEvent) TableName() string { return "ac_notif_events" }

type NotifTemplate struct {
	ID             uint      `gorm:"column:nt_id;primaryKey;autoIncrement" json:"id"`
	Name           string    `gorm:"column:nt_name;size:120;not null;uniqueIndex:uq_notif_template_name" json:"name"`
	Description    string    `gorm:"column:nt_description;size:255" json:"description"`
	Title          string    `gorm:"column:nt_title;size:180;not null" json:"title"`
	Message        string    `gorm:"column:nt_message;type:text;not null" json:"message"`
	Category       string    `gorm:"column:nt_category;size:20;not null;default:INFO" json:"category"`
	Target         string    `gorm:"column:nt_target;size:80;not null;default:notification_detail" json:"target"`
	FallbackTarget string    `gorm:"column:nt_fallback_target;size:80" json:"fallback_target"`
	CTALabel       string    `gorm:"column:nt_cta_label;size:80" json:"cta_label"`
	IsActive       bool      `gorm:"column:nt_is_active;not null;default:true;index" json:"is_active"`
	CreatedBy      string    `gorm:"column:nt_created_by;size:120" json:"created_by"`
	UpdatedBy      string    `gorm:"column:nt_updated_by;size:120" json:"updated_by"`
	CreatedAt      time.Time `gorm:"column:nt_created;autoCreateTime" json:"created_at"`
	UpdatedAt      time.Time `gorm:"column:nt_updated;autoUpdateTime" json:"updated_at"`
}

func (NotifTemplate) TableName() string { return "ac_notif_templates" }

type LifecycleEvent struct {
	ID         uint           `gorm:"column:le_id;primaryKey;autoIncrement" json:"id"`
	EventID    string         `gorm:"column:le_event_id;size:80;uniqueIndex;not null" json:"event_id"`
	OutletID   string         `gorm:"column:le_outlet;size:20;index;not null" json:"outlet_id"`
	ActorID    string         `gorm:"column:le_actor_id;size:60;index" json:"actor_id"`
	ActorType  string         `gorm:"column:le_actor_type;size:20" json:"actor_type"`
	EventName  string         `gorm:"column:le_event_name;size:60;index;not null" json:"event_name"`
	Metadata   datatypes.JSON `gorm:"column:le_metadata;type:json" json:"metadata"`
	OccurredAt time.Time      `gorm:"column:le_occurred_at;index;not null" json:"occurred_at"`
	CreatedAt  time.Time      `gorm:"column:le_created;autoCreateTime" json:"created_at"`
}

func (LifecycleEvent) TableName() string { return "ac_lifecycle_events" }

type LifecycleAutomationRun struct {
	ID            uint       `gorm:"column:lar_id;primaryKey;autoIncrement" json:"id"`
	RuleKey       string     `gorm:"column:lar_rule_key;size:60;index;not null" json:"rule_key"`
	OutletID      string     `gorm:"column:lar_outlet;size:20;index;not null" json:"outlet_id"`
	SourceEventID string     `gorm:"column:lar_source_event_id;size:80;index" json:"source_event_id"`
	Status        string     `gorm:"column:lar_status;size:20;index;not null" json:"status"`
	Reason        string     `gorm:"column:lar_reason;size:255" json:"reason"`
	MasterID      string     `gorm:"column:lar_master_id;size:60;index" json:"master_id"`
	ConvertedAt   *time.Time `gorm:"column:lar_converted_at;index" json:"converted_at,omitempty"`
	CreatedAt     time.Time  `gorm:"column:lar_created;autoCreateTime;index" json:"created_at"`
}

func (LifecycleAutomationRun) TableName() string { return "ac_lifecycle_automation_runs" }

type LifecycleAutomationRule struct {
	Key            string    `gorm:"column:laru_key;primaryKey;size:60" json:"key"`
	Name           string    `gorm:"column:laru_name;size:120;not null" json:"name"`
	Description    string    `gorm:"column:laru_description;size:255" json:"description"`
	IsActive       bool      `gorm:"column:laru_is_active;not null;default:true;index" json:"is_active"`
	DelayHours     int       `gorm:"column:laru_delay_hours;not null;default:0" json:"delay_hours"`
	CooldownHours  int       `gorm:"column:laru_cooldown_hours;not null;default:24" json:"cooldown_hours"`
	ThresholdValue int       `gorm:"column:laru_threshold_value;not null;default:0" json:"threshold_value"`
	Priority       int       `gorm:"column:laru_priority;not null;default:50;index" json:"priority"`
	Title          string    `gorm:"column:laru_title;size:180;not null" json:"title"`
	Message        string    `gorm:"column:laru_message;type:text;not null" json:"message"`
	CTALabel       string    `gorm:"column:laru_cta_label;size:80" json:"cta_label"`
	Target         string    `gorm:"column:laru_target;size:80;not null" json:"target"`
	QuietStartHour int       `gorm:"column:laru_quiet_start_hour;not null;default:20" json:"quiet_start_hour"`
	QuietEndHour   int       `gorm:"column:laru_quiet_end_hour;not null;default:9" json:"quiet_end_hour"`
	UpdatedBy      string    `gorm:"column:laru_updated_by;size:120" json:"updated_by"`
	CreatedAt      time.Time `gorm:"column:laru_created;autoCreateTime" json:"created_at"`
	UpdatedAt      time.Time `gorm:"column:laru_updated;autoUpdateTime" json:"updated_at"`
}

func (LifecycleAutomationRule) TableName() string { return "ac_lifecycle_automation_rules" }
