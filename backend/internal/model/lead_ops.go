package model

import (
	"time"

	"gorm.io/datatypes"
)

type LeadOpsSource struct {
	ID        string    `gorm:"column:los_id;primaryKey;size:36" json:"id"`
	Code      string    `gorm:"column:los_code;size:50;uniqueIndex" json:"code"`
	Name      string    `gorm:"column:los_name;size:100;uniqueIndex" json:"name"`
	Category  string    `gorm:"column:los_category;size:50;index" json:"category"`
	IsActive  bool      `gorm:"column:los_is_active;default:true" json:"is_active"`
	CreatedAt time.Time `gorm:"column:los_created;autoCreateTime" json:"created_at"`
	UpdatedAt time.Time `gorm:"column:los_updated;autoUpdateTime" json:"updated_at"`
}

func (LeadOpsSource) TableName() string {
	return "ac_lead_ops_sources"
}

type LeadOpsLead struct {
	ID                        string         `gorm:"column:lol_id;primaryKey;size:36" json:"id"`
	LeadCode                  string         `gorm:"column:lol_code;size:40;uniqueIndex" json:"lead_code"`
	LeadType                  string         `gorm:"column:lol_lead_type;size:50;index" json:"lead_type"`
	SourceID                  string         `gorm:"column:lol_source_id;size:36;index" json:"source_id"`
	SourceNameRaw             string         `gorm:"column:lol_source_name_raw;size:100" json:"source_name_raw"`
	SourceRef                 string         `gorm:"column:lol_source_ref;size:120;index" json:"source_ref"`
	OwnerCode                 string         `gorm:"column:lol_owner_code;size:50;index" json:"owner_code"`
	OwnerName                 string         `gorm:"column:lol_owner_name;size:150;index" json:"owner_name"`
	OutletName                string         `gorm:"column:lol_outlet_name;size:150;index" json:"outlet_name"`
	OwnerPhone                string         `gorm:"column:lol_owner_phone;size:30;index" json:"owner_phone"`
	OutletPhone               string         `gorm:"column:lol_outlet_phone;size:30;index" json:"outlet_phone"`
	City                      string         `gorm:"column:lol_city;size:100;index" json:"city"`
	Need                      string         `gorm:"column:lol_need;size:255" json:"need"`
	Notes                     string         `gorm:"column:lol_notes;type:text" json:"notes"`
	ProjectCreatedAt          *time.Time     `gorm:"column:lol_project_created_at" json:"project_created_at"`
	ProjectExpiredAt          *time.Time     `gorm:"column:lol_project_expired_at" json:"project_expired_at"`
	TotalTransactionsSnapshot int            `gorm:"column:lol_total_transactions_snapshot;default:0" json:"total_transactions_snapshot"`
	CurrentStatus             string         `gorm:"column:lol_current_status;size:50;index" json:"current_status"`
	CurrentScore              *int           `gorm:"column:lol_current_score" json:"current_score"`
	CurrentCallStatus         string         `gorm:"column:lol_current_call_status;size:50" json:"current_call_status"`
	CurrentChatStatus         string         `gorm:"column:lol_current_chat_status;size:50" json:"current_chat_status"`
	CurrentValidityStatus     string         `gorm:"column:lol_current_validity_status;size:50" json:"current_validity_status"`
	CurrentResultNote         string         `gorm:"column:lol_current_result_note;size:255" json:"current_result_note"`
	CurrentPICID              string         `gorm:"column:lol_current_pic_id;size:12;index" json:"current_pic_id"`
	CurrentDivision           string         `gorm:"column:lol_current_division;size:30;index" json:"current_division"`
	AssignedAt                *time.Time     `gorm:"column:lol_assigned_at" json:"assigned_at"`
	LastFollowUpAt            *time.Time     `gorm:"column:lol_last_followup_at" json:"last_followup_at"`
	NextFollowUpAt            *time.Time     `gorm:"column:lol_next_followup_at" json:"next_followup_at"`
	AuditNote                 string         `gorm:"column:lol_audit_note;type:text" json:"audit_note"`
	ImportedFrom              string         `gorm:"column:lol_imported_from;size:50" json:"imported_from"`
	ImportedBatchCode         string         `gorm:"column:lol_imported_batch_code;size:50;index" json:"imported_batch_code"`
	ImportedBy                string         `gorm:"column:lol_imported_by;size:12;index" json:"imported_by"`
	ImportedAt                time.Time      `gorm:"column:lol_imported_at;autoCreateTime;index" json:"imported_at"`
	RawPayload                datatypes.JSON `gorm:"column:lol_raw_payload;type:json" json:"raw_payload"`
	CreatedAt                 time.Time      `gorm:"column:lol_created;autoCreateTime" json:"created_at"`
	UpdatedAt                 time.Time      `gorm:"column:lol_updated;autoUpdateTime" json:"updated_at"`
}

func (LeadOpsLead) TableName() string {
	return "ac_lead_ops_leads"
}

type LeadOpsAssignment struct {
	ID               string     `gorm:"column:loa_id;primaryKey;size:36" json:"id"`
	LeadID           string     `gorm:"column:loa_lead_id;size:36;index" json:"lead_id"`
	AssignedByID     string     `gorm:"column:loa_assigned_by_id;size:12;index" json:"assigned_by_id"`
	AssignedToID     string     `gorm:"column:loa_assigned_to_id;size:12;index" json:"assigned_to_id"`
	Division         string     `gorm:"column:loa_division;size:30;index" json:"division"`
	AssignmentType   string     `gorm:"column:loa_assignment_type;size:30;index" json:"assignment_type"`
	AssignmentReason string     `gorm:"column:loa_assignment_reason;size:255" json:"assignment_reason"`
	Note             string     `gorm:"column:loa_note;type:text" json:"note"`
	Status           string     `gorm:"column:loa_status;size:20;default:'active';index" json:"status"`
	ReleasedAt       *time.Time `gorm:"column:loa_released_at" json:"released_at"`
	AssignedAt       time.Time  `gorm:"column:loa_assigned_at;autoCreateTime;index" json:"assigned_at"`
}

func (LeadOpsAssignment) TableName() string {
	return "ac_lead_ops_assignments"
}

type LeadOpsFollowUp struct {
	ID             string     `gorm:"column:lof_id;primaryKey;size:36" json:"id"`
	LeadID         string     `gorm:"column:lof_lead_id;size:36;index" json:"lead_id"`
	AssignmentID   string     `gorm:"column:lof_assignment_id;size:36;index" json:"assignment_id"`
	UserID         string     `gorm:"column:lof_user_id;size:12;index" json:"user_id"`
	FollowUpDate   time.Time  `gorm:"column:lof_followup_date;index" json:"followup_date"`
	Channel        string     `gorm:"column:lof_channel;size:30;index" json:"channel"`
	CallStatus     string     `gorm:"column:lof_call_status;size:50" json:"call_status"`
	ChatStatus     string     `gorm:"column:lof_chat_status;size:50" json:"chat_status"`
	ValidityStatus string     `gorm:"column:lof_validity_status;size:50" json:"validity_status"`
	ResultStatus   string     `gorm:"column:lof_result_status;size:50;index" json:"result_status"`
	Stage          string     `gorm:"column:lof_stage;size:50;index" json:"stage"`
	Outcome        string     `gorm:"column:lof_outcome;size:255" json:"outcome"`
	Note           string     `gorm:"column:lof_note;type:text" json:"note"`
	NextFollowUpAt *time.Time `gorm:"column:lof_next_followup_at" json:"next_followup_at"`
	CreatedAt      time.Time  `gorm:"column:lof_created;autoCreateTime;index" json:"created_at"`
}

func (LeadOpsFollowUp) TableName() string {
	return "ac_lead_ops_followups"
}

type LeadOpsStatusHistory struct {
	ID              string    `gorm:"column:lsh_id;primaryKey;size:36" json:"id"`
	LeadID          string    `gorm:"column:lsh_lead_id;size:36;index" json:"lead_id"`
	OldStatus       string    `gorm:"column:lsh_old_status;size:50" json:"old_status"`
	NewStatus       string    `gorm:"column:lsh_new_status;size:50;index" json:"new_status"`
	ChangedByUserID string    `gorm:"column:lsh_changed_by_user_id;size:12;index" json:"changed_by_user_id"`
	SourceEventType string    `gorm:"column:lsh_source_event_type;size:50" json:"source_event_type"`
	SourceEventID   string    `gorm:"column:lsh_source_event_id;size:36;index" json:"source_event_id"`
	Reason          string    `gorm:"column:lsh_reason;size:255" json:"reason"`
	CreatedAt       time.Time `gorm:"column:lsh_created;autoCreateTime;index" json:"created_at"`
}

func (LeadOpsStatusHistory) TableName() string {
	return "ac_lead_ops_status_history"
}

type LeadOpsOpportunity struct {
	ID                     string     `gorm:"column:loo_id;primaryKey;size:36" json:"id"`
	LeadID                 string     `gorm:"column:loo_lead_id;size:36;uniqueIndex" json:"lead_id"`
	PICUserID              string     `gorm:"column:loo_pic_user_id;size:12;index" json:"pic_user_id"`
	Stage                  string     `gorm:"column:loo_stage;size:50;index" json:"stage"`
	MembershipType         string     `gorm:"column:loo_membership_type;size:100" json:"membership_type"`
	TargetActivationPlan   string     `gorm:"column:loo_target_activation_plan;size:100" json:"target_activation_plan"`
	TargetActivationAmount float64    `gorm:"column:loo_target_activation_amount;type:decimal(18,2)" json:"target_activation_amount"`
	TargetAddonPlan        string     `gorm:"column:loo_target_addon_plan;size:100" json:"target_addon_plan"`
	TargetAddonAmount      float64    `gorm:"column:loo_target_addon_amount;type:decimal(18,2)" json:"target_addon_amount"`
	ActualActivationPkg    string     `gorm:"column:loo_actual_activation_package;size:100" json:"actual_activation_package"`
	ActualActivationAmount float64    `gorm:"column:loo_actual_activation_amount;type:decimal(18,2)" json:"actual_activation_amount"`
	ActualAddonName        string     `gorm:"column:loo_actual_addon_name;size:100" json:"actual_addon_name"`
	ActualAddonAmount      float64    `gorm:"column:loo_actual_addon_amount;type:decimal(18,2)" json:"actual_addon_amount"`
	ClosingStatus          string     `gorm:"column:loo_closing_status;size:50" json:"closing_status"`
	ClosingAmount          float64    `gorm:"column:loo_closing_amount;type:decimal(18,2)" json:"closing_amount"`
	ClosingDate            *time.Time `gorm:"column:loo_closing_date" json:"closing_date"`
	CreatedAt              time.Time  `gorm:"column:loo_created;autoCreateTime" json:"created_at"`
	UpdatedAt              time.Time  `gorm:"column:loo_updated;autoUpdateTime" json:"updated_at"`
}

func (LeadOpsOpportunity) TableName() string {
	return "ac_lead_ops_opportunities"
}
