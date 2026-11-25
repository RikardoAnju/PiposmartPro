package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/datatypes"
	"gorm.io/gorm"
)

type LeadOpsImportItem struct {
	LeadType          string                 `json:"lead_type"`
	CustomerName      string                 `json:"customer_name"`
	OwnerName         string                 `json:"owner_name"`
	OutletName        string                 `json:"outlet_name"`
	Phone             string                 `json:"phone"`
	OwnerPhone        string                 `json:"owner_phone"`
	OutletPhone       string                 `json:"outlet_phone"`
	City              string                 `json:"city"`
	Need              string                 `json:"need"`
	Notes             string                 `json:"notes"`
	SourceRef         string                 `json:"source_ref"`
	OwnerCode         string                 `json:"owner_code"`
	TotalTransactions int                    `json:"total_transactions_snapshot"`
	RawPayload        map[string]interface{} `json:"raw_payload"`
}

type LeadOpsAssignInput struct {
	Division         string `json:"division"`
	AdminID          string `json:"admin_id"`
	AssignmentType   string `json:"assignment_type"`
	AssignmentReason string `json:"assignment_reason"`
	Note             string `json:"note"`
}

type LeadOpsFollowUpInput struct {
	Stage          string     `json:"stage"`
	Channel        string     `json:"channel"`
	CallStatus     string     `json:"call_status"`
	ChatStatus     string     `json:"chat_status"`
	ValidityStatus string     `json:"validity_status"`
	ResultStatus   string     `json:"result_status"`
	Outcome        string     `json:"outcome"`
	Notes          string     `json:"notes"`
	NextFollowUpAt *time.Time `json:"next_followup_at"`
}

type LeadOpsOpportunityInput struct {
	Stage                  string     `json:"stage"`
	MembershipType         string     `json:"membership_type"`
	TargetActivationPlan   string     `json:"target_activation_plan"`
	TargetActivationAmount float64    `json:"target_activation_amount"`
	TargetAddonPlan        string     `json:"target_addon_plan"`
	TargetAddonAmount      float64    `json:"target_addon_amount"`
	ActualActivationPkg    string     `json:"actual_activation_package"`
	ActualActivationAmount float64    `json:"actual_activation_amount"`
	ActualAddonName        string     `json:"actual_addon_name"`
	ActualAddonAmount      float64    `json:"actual_addon_amount"`
	ClosingStatus          string     `json:"closing_status"`
	ClosingAmount          float64    `json:"closing_amount"`
	ClosingDate            *time.Time `json:"closing_date"`
}

type LeadOpsListFilter struct {
	Search     string
	Status     string
	Division   string
	AssigneeID string
	Limit      int
}

type LeadOpsLeadRow struct {
	ID                    string     `json:"id"`
	LeadCode              string     `json:"lead_code"`
	LeadType              string     `json:"lead_type"`
	SourceName            string     `json:"source_name"`
	SourceNameRaw         string     `json:"source_name_raw"`
	SourceRef             string     `json:"source_ref"`
	OwnerCode             string     `json:"owner_code"`
	OwnerName             string     `json:"owner_name"`
	OutletName            string     `json:"outlet_name"`
	Phone                 string     `json:"phone"`
	OwnerPhone            string     `json:"owner_phone"`
	OutletPhone           string     `json:"outlet_phone"`
	City                  string     `json:"city"`
	Need                  string     `json:"need"`
	Notes                 string     `json:"notes"`
	CurrentStatus         string     `json:"current_status"`
	CurrentDivision       string     `json:"current_division"`
	CurrentPICID          string     `json:"current_pic_id"`
	CurrentPICName        string     `json:"current_pic_name"`
	CurrentCallStatus     string     `json:"current_call_status"`
	CurrentChatStatus     string     `json:"current_chat_status"`
	CurrentValidityStatus string     `json:"current_validity_status"`
	CurrentResultNote     string     `json:"current_result_note"`
	AssignedAt            *time.Time `json:"assigned_at"`
	LastFollowUpAt        *time.Time `json:"last_followup_at"`
	NextFollowUpAt        *time.Time `json:"next_followup_at"`
	ImportedAt            time.Time  `json:"imported_at"`
	ImportedBy            string     `json:"imported_by"`
	ImportedByName        string     `json:"imported_by_name"`
	AssignmentCount       int64      `json:"assignment_count"`
	FollowUpCount         int64      `json:"followup_count"`
}

type LeadOpsAssignmentRow struct {
	ID               string    `json:"id"`
	LeadID           string    `json:"lead_id"`
	LeadCode         string    `json:"lead_code"`
	OwnerName        string    `json:"owner_name"`
	OutletName       string    `json:"outlet_name"`
	Phone            string    `json:"phone"`
	Division         string    `json:"division"`
	AssignedByID     string    `json:"assigned_by_id"`
	AssignedByName   string    `json:"assigned_by_name"`
	AssignedToID     string    `json:"assigned_to_id"`
	AssignedToName   string    `json:"assigned_to_name"`
	AssignmentType   string    `json:"assignment_type"`
	AssignmentReason string    `json:"assignment_reason"`
	Note             string    `json:"note"`
	AssignedAt       time.Time `json:"assigned_at"`
}

type LeadOpsFollowUpRow struct {
	ID             string     `json:"id"`
	LeadID         string     `json:"lead_id"`
	AssignmentID   string     `json:"assignment_id"`
	UserID         string     `json:"user_id"`
	UserName       string     `json:"user_name"`
	FollowUpDate   time.Time  `json:"followup_date"`
	Channel        string     `json:"channel"`
	CallStatus     string     `json:"call_status"`
	ChatStatus     string     `json:"chat_status"`
	ValidityStatus string     `json:"validity_status"`
	ResultStatus   string     `json:"result_status"`
	Stage          string     `json:"stage"`
	Outcome        string     `json:"outcome"`
	Notes          string     `json:"notes"`
	NextFollowUpAt *time.Time `json:"next_followup_at"`
	CreatedAt      time.Time  `json:"created_at"`
}

type LeadOpsStatusHistoryRow struct {
	ID              string    `json:"id"`
	OldStatus       string    `json:"old_status"`
	NewStatus       string    `json:"new_status"`
	ChangedByUserID string    `json:"changed_by_user_id"`
	ChangedByName   string    `json:"changed_by_name"`
	SourceEventType string    `json:"source_event_type"`
	SourceEventID   string    `json:"source_event_id"`
	Reason          string    `json:"reason"`
	CreatedAt       time.Time `json:"created_at"`
}

type LeadOpsOpportunityRow struct {
	ID                     string     `json:"id"`
	LeadID                 string     `json:"lead_id"`
	PICUserID              string     `json:"pic_user_id"`
	PICUserName            string     `json:"pic_user_name"`
	Stage                  string     `json:"stage"`
	MembershipType         string     `json:"membership_type"`
	TargetActivationPlan   string     `json:"target_activation_plan"`
	TargetActivationAmount float64    `json:"target_activation_amount"`
	TargetAddonPlan        string     `json:"target_addon_plan"`
	TargetAddonAmount      float64    `json:"target_addon_amount"`
	ActualActivationPkg    string     `json:"actual_activation_package"`
	ActualActivationAmount float64    `json:"actual_activation_amount"`
	ActualAddonName        string     `json:"actual_addon_name"`
	ActualAddonAmount      float64    `json:"actual_addon_amount"`
	ClosingStatus          string     `json:"closing_status"`
	ClosingAmount          float64    `json:"closing_amount"`
	ClosingDate            *time.Time `json:"closing_date"`
	CreatedAt              time.Time  `json:"created_at"`
	UpdatedAt              time.Time  `json:"updated_at"`
}

type LeadOpsDetail struct {
	Lead          LeadOpsLeadRow            `json:"lead"`
	Assignments   []LeadOpsAssignmentRow    `json:"assignments"`
	FollowUps     []LeadOpsFollowUpRow      `json:"followups"`
	StatusHistory []LeadOpsStatusHistoryRow `json:"status_history"`
	Opportunity   *LeadOpsOpportunityRow    `json:"opportunity,omitempty"`
}

type LeadOpsSummary struct {
	TotalLeads       int64 `json:"total_leads"`
	NewLeads         int64 `json:"new_leads"`
	AssignedLeads    int64 `json:"assigned_leads"`
	ContactedLeads   int64 `json:"contacted_leads"`
	PotentialLeads   int64 `json:"potential_leads"`
	DemoLeads        int64 `json:"demo_leads"`
	ConvertedLeads   int64 `json:"converted_leads"`
	LostLeads        int64 `json:"lost_leads"`
	OverdueFollowups int64 `json:"overdue_followups"`
}

type LeadOpsAdminOption struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type LeadOpsActorProfile struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Email       string `json:"email"`
	RoleName    string `json:"role_name"`
	IsMaster    bool   `json:"is_master"`
	IsMarketing bool   `json:"is_marketing"`
}

type LeadOpsService interface {
	ImportLeads(source string, items []LeadOpsImportItem, actorID string) ([]model.LeadOpsLead, error)
	ListLeads(filter LeadOpsListFilter) ([]LeadOpsLeadRow, error)
	ListMyLeads(filter LeadOpsListFilter, actorID string) ([]LeadOpsLeadRow, error)
	GetLeadDetail(id string) (*LeadOpsDetail, error)
	AssignLead(leadID string, input LeadOpsAssignInput, actorID string) (*model.LeadOpsAssignment, error)
	ReassignLead(leadID string, input LeadOpsAssignInput, actorID string) (*model.LeadOpsAssignment, error)
	ReleaseLead(leadID string, actorID string, note string) error
	AddFollowUp(leadID string, input LeadOpsFollowUpInput, actorID string) (*model.LeadOpsFollowUp, error)
	UpsertOpportunity(leadID string, input LeadOpsOpportunityInput, actorID string) (*model.LeadOpsOpportunity, error)
	ListAssignments(limit int) ([]LeadOpsAssignmentRow, error)
	GetSummary() (*LeadOpsSummary, error)
	GetMySummary(actorID string) (*LeadOpsSummary, error)
	ListAdminOptions() ([]LeadOpsAdminOption, error)
	GetActorProfile(actorID string) (*LeadOpsActorProfile, error)
	SeedSampleData(actorID string) (map[string]interface{}, error)
}

type leadOpsService struct {
	db *gorm.DB
}

func NewLeadOpsService(db *gorm.DB) LeadOpsService {
	return &leadOpsService{db: db}
}

func (s *leadOpsService) ImportLeads(source string, items []LeadOpsImportItem, actorID string) ([]model.LeadOpsLead, error) {
	if len(items) == 0 {
		return nil, fmt.Errorf("minimal 1 data lead diperlukan")
	}

	sourceModel, err := s.findOrCreateSource(strings.TrimSpace(source))
	if err != nil {
		return nil, err
	}

	leads := make([]model.LeadOpsLead, 0, len(items))
	err = s.db.Transaction(func(tx *gorm.DB) error {
		for _, item := range items {
			ownerName := firstNonEmpty(item.OwnerName, item.CustomerName)
			phone := firstNonEmpty(item.Phone, item.OwnerPhone, item.OutletPhone)
			outletName := strings.TrimSpace(item.OutletName)
			if strings.TrimSpace(ownerName) == "" || strings.TrimSpace(phone) == "" {
				return fmt.Errorf("owner_name/customer_name dan nomor hp wajib diisi")
			}

			if err := s.ensureLeadNotDuplicate(tx, item.OwnerCode, item.OwnerPhone, item.OutletPhone, ownerName, outletName); err != nil {
				return err
			}

			payload := item.RawPayload
			if payload == nil {
				payload = map[string]interface{}{}
			}
			payload["owner_name"] = ownerName
			payload["owner_phone"] = strings.TrimSpace(item.OwnerPhone)
			payload["outlet_name"] = outletName
			payload["outlet_phone"] = strings.TrimSpace(item.OutletPhone)

			rawJSON, err := json.Marshal(payload)
			if err != nil {
				return fmt.Errorf("gagal serialisasi payload lead: %w", err)
			}

			leadID := uuid.New().String()
			lead := model.LeadOpsLead{
				ID:                        leadID,
				LeadCode:                  s.generateLeadCode(),
				LeadType:                  normalizeOrDefault(item.LeadType, "new_download"),
				SourceID:                  sourceModel.ID,
				SourceNameRaw:             strings.TrimSpace(source),
				SourceRef:                 strings.TrimSpace(item.SourceRef),
				OwnerCode:                 strings.TrimSpace(item.OwnerCode),
				OwnerName:                 strings.TrimSpace(ownerName),
				OutletName:                outletName,
				OwnerPhone:                strings.TrimSpace(item.OwnerPhone),
				OutletPhone:               strings.TrimSpace(item.OutletPhone),
				City:                      strings.TrimSpace(item.City),
				Need:                      strings.TrimSpace(item.Need),
				Notes:                     strings.TrimSpace(item.Notes),
				TotalTransactionsSnapshot: item.TotalTransactions,
				CurrentStatus:             "new",
				ImportedFrom:              "manual",
				ImportedBatchCode:         time.Now().Format("20060102-150405"),
				ImportedBy:                actorID,
				ImportedAt:                time.Now(),
				RawPayload:                datatypes.JSON(rawJSON),
			}

			if err := tx.Create(&lead).Error; err != nil {
				return fmt.Errorf("gagal menyimpan lead: %w", err)
			}

			if err := s.appendStatusHistory(tx, lead.ID, "", "new", actorID, "import", lead.ID, "import lead baru"); err != nil {
				return err
			}

			leads = append(leads, lead)
		}
		return nil
	})
	return leads, err
}

func (s *leadOpsService) ListLeads(filter LeadOpsListFilter) ([]LeadOpsLeadRow, error) {
	return s.listLeadsWithAssignee(filter, "")
}

func (s *leadOpsService) ListMyLeads(filter LeadOpsListFilter, actorID string) ([]LeadOpsLeadRow, error) {
	return s.listLeadsWithAssignee(filter, actorID)
}

func (s *leadOpsService) listLeadsWithAssignee(filter LeadOpsListFilter, actorID string) ([]LeadOpsLeadRow, error) {
	if filter.Limit <= 0 || filter.Limit > 500 {
		filter.Limit = 100
	}

	query := s.db.Table("ac_lead_ops_leads l").
		Select(`
			l.lol_id as id,
			l.lol_code as lead_code,
			l.lol_lead_type as lead_type,
			COALESCE(src.los_name, l.lol_source_name_raw) as source_name,
			l.lol_source_name_raw as source_name_raw,
			l.lol_source_ref as source_ref,
			l.lol_owner_code as owner_code,
			l.lol_owner_name as owner_name,
			l.lol_outlet_name as outlet_name,
			COALESCE(NULLIF(l.lol_owner_phone, ''), l.lol_outlet_phone) as phone,
			l.lol_owner_phone as owner_phone,
			l.lol_outlet_phone as outlet_phone,
			l.lol_city as city,
			l.lol_need as need,
			l.lol_notes as notes,
			l.lol_current_status as current_status,
			l.lol_current_division as current_division,
			l.lol_current_pic_id as current_pic_id,
			COALESCE(pic.adm_nama, '') as current_pic_name,
			l.lol_current_call_status as current_call_status,
			l.lol_current_chat_status as current_chat_status,
			l.lol_current_validity_status as current_validity_status,
			l.lol_current_result_note as current_result_note,
			l.lol_assigned_at as assigned_at,
			l.lol_last_followup_at as last_followup_at,
			l.lol_next_followup_at as next_followup_at,
			l.lol_imported_at as imported_at,
			l.lol_imported_by as imported_by,
			COALESCE(imp.adm_nama, '') as imported_by_name,
			(SELECT COUNT(*) FROM ac_lead_ops_assignments x WHERE x.loa_lead_id = l.lol_id) as assignment_count,
			(SELECT COUNT(*) FROM ac_lead_ops_followups y WHERE y.lof_lead_id = l.lol_id) as followup_count
		`).
		Joins("LEFT JOIN ac_lead_ops_sources src ON src.los_id = l.lol_source_id").
		Joins("LEFT JOIN ac_admin pic ON pic.adm_id = l.lol_current_pic_id").
		Joins("LEFT JOIN ac_admin imp ON imp.adm_id = l.lol_imported_by")

	if filter.Search != "" {
		like := "%" + strings.ToLower(strings.TrimSpace(filter.Search)) + "%"
		query = query.Where(`
			LOWER(l.lol_owner_name) LIKE ? OR
			LOWER(l.lol_outlet_name) LIKE ? OR
			LOWER(l.lol_owner_phone) LIKE ? OR
			LOWER(l.lol_outlet_phone) LIKE ? OR
			LOWER(l.lol_code) LIKE ? OR
			LOWER(l.lol_owner_code) LIKE ?`,
			like, like, like, like, like, like)
	}
	if filter.Status != "" {
		query = query.Where("l.lol_current_status = ?", filter.Status)
	}
	if filter.Division != "" {
		query = query.Where("l.lol_current_division = ?", filter.Division)
	}
	if filter.AssigneeID != "" {
		query = query.Where("l.lol_current_pic_id = ?", filter.AssigneeID)
	}
	if actorID != "" {
		query = query.Where("l.lol_current_pic_id = ?", actorID)
	}

	var rows []LeadOpsLeadRow
	err := query.Order("l.lol_imported_at DESC").Limit(filter.Limit).Scan(&rows).Error
	return rows, err
}

func (s *leadOpsService) GetLeadDetail(id string) (*LeadOpsDetail, error) {
	var lead LeadOpsLeadRow
	err := s.db.Table("ac_lead_ops_leads l").
		Select(`
			l.lol_id as id,
			l.lol_code as lead_code,
			l.lol_lead_type as lead_type,
			COALESCE(src.los_name, l.lol_source_name_raw) as source_name,
			l.lol_source_name_raw as source_name_raw,
			l.lol_source_ref as source_ref,
			l.lol_owner_code as owner_code,
			l.lol_owner_name as owner_name,
			l.lol_outlet_name as outlet_name,
			COALESCE(NULLIF(l.lol_owner_phone, ''), l.lol_outlet_phone) as phone,
			l.lol_owner_phone as owner_phone,
			l.lol_outlet_phone as outlet_phone,
			l.lol_city as city,
			l.lol_need as need,
			l.lol_notes as notes,
			l.lol_current_status as current_status,
			l.lol_current_division as current_division,
			l.lol_current_pic_id as current_pic_id,
			COALESCE(pic.adm_nama, '') as current_pic_name,
			l.lol_current_call_status as current_call_status,
			l.lol_current_chat_status as current_chat_status,
			l.lol_current_validity_status as current_validity_status,
			l.lol_current_result_note as current_result_note,
			l.lol_assigned_at as assigned_at,
			l.lol_last_followup_at as last_followup_at,
			l.lol_next_followup_at as next_followup_at,
			l.lol_imported_at as imported_at,
			l.lol_imported_by as imported_by,
			COALESCE(imp.adm_nama, '') as imported_by_name,
			(SELECT COUNT(*) FROM ac_lead_ops_assignments x WHERE x.loa_lead_id = l.lol_id) as assignment_count,
			(SELECT COUNT(*) FROM ac_lead_ops_followups y WHERE y.lof_lead_id = l.lol_id) as followup_count
		`).
		Joins("LEFT JOIN ac_lead_ops_sources src ON src.los_id = l.lol_source_id").
		Joins("LEFT JOIN ac_admin pic ON pic.adm_id = l.lol_current_pic_id").
		Joins("LEFT JOIN ac_admin imp ON imp.adm_id = l.lol_imported_by").
		Where("l.lol_id = ? OR l.lol_code = ?", id, id).
		Scan(&lead).Error
	if err != nil {
		return nil, err
	}
	if lead.ID == "" {
		return nil, gorm.ErrRecordNotFound
	}

	assignments, err := s.ListAssignmentsByLead(lead.ID)
	if err != nil {
		return nil, err
	}
	followups, err := s.listFollowUpsByLead(lead.ID)
	if err != nil {
		return nil, err
	}
	history, err := s.listStatusHistoryByLead(lead.ID)
	if err != nil {
		return nil, err
	}
	opportunity, err := s.getOpportunityByLead(lead.ID)
	if err != nil {
		return nil, err
	}

	return &LeadOpsDetail{
		Lead:          lead,
		Assignments:   assignments,
		FollowUps:     followups,
		StatusHistory: history,
		Opportunity:   opportunity,
	}, nil
}

func (s *leadOpsService) AssignLead(leadID string, input LeadOpsAssignInput, actorID string) (*model.LeadOpsAssignment, error) {
	return s.assignLeadInternal(leadID, input, actorID, false)
}

func (s *leadOpsService) ReassignLead(leadID string, input LeadOpsAssignInput, actorID string) (*model.LeadOpsAssignment, error) {
	input.AssignmentType = normalizeOrDefault(input.AssignmentType, "switch_pic")
	return s.assignLeadInternal(leadID, input, actorID, true)
}

func (s *leadOpsService) assignLeadInternal(leadID string, input LeadOpsAssignInput, actorID string, releaseOld bool) (*model.LeadOpsAssignment, error) {
	assignment := &model.LeadOpsAssignment{}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var lead model.LeadOpsLead
		if err := tx.First(&lead, "lol_id = ?", leadID).Error; err != nil {
			return err
		}

		var assignee model.Admin
		if err := tx.First(&assignee, "adm_id = ?", input.AdminID).Error; err != nil {
			return fmt.Errorf("admin tujuan tidak ditemukan")
		}

		now := time.Now()
		oldPICID := lead.CurrentPICID
		oldStatus := lead.CurrentStatus
		assignmentType := normalizeOrDefault(input.AssignmentType, "initial")
		if oldPICID != "" && assignmentType == "initial" {
			assignmentType = "switch_pic"
		}

		if releaseOld && oldPICID != "" {
			_ = tx.Model(&model.LeadOpsAssignment{}).
				Where("loa_lead_id = ? AND loa_status = ?", leadID, "active").
				Updates(map[string]interface{}{
					"loa_status":      "released",
					"loa_released_at": now,
				}).Error
		}

		newAssignment := model.LeadOpsAssignment{
			ID:               uuid.New().String(),
			LeadID:           leadID,
			AssignedByID:     actorID,
			AssignedToID:     input.AdminID,
			Division:         normalizeOrDefault(input.Division, "marketing"),
			AssignmentType:   assignmentType,
			AssignmentReason: strings.TrimSpace(input.AssignmentReason),
			Note:             strings.TrimSpace(input.Note),
			AssignedAt:       now,
		}
		if err := tx.Create(&newAssignment).Error; err != nil {
			return err
		}

		nextStatus := "assigned"
		if assignmentType == "switch_pic" {
			nextStatus = "reassigned"
		}
		if err := tx.Model(&model.LeadOpsLead{}).Where("lol_id = ?", leadID).Updates(map[string]interface{}{
			"lol_current_status":   nextStatus,
			"lol_current_division": newAssignment.Division,
			"lol_current_pic_id":   input.AdminID,
			"lol_assigned_at":      now,
		}).Error; err != nil {
			return err
		}

		if err := s.appendStatusHistory(tx, leadID, oldStatus, nextStatus, actorID, "assignment", newAssignment.ID, firstNonEmpty(input.AssignmentReason, assignmentType)); err != nil {
			return err
		}

		*assignment = newAssignment
		return nil
	})
	return assignment, err
}

func (s *leadOpsService) ReleaseLead(leadID string, actorID string, note string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var lead model.LeadOpsLead
		if err := tx.First(&lead, "lol_id = ?", leadID).Error; err != nil {
			return err
		}
		now := time.Now()
		if err := tx.Model(&model.LeadOpsAssignment{}).
			Where("loa_lead_id = ? AND loa_status = ?", leadID, "active").
			Updates(map[string]interface{}{
				"loa_status":      "released",
				"loa_released_at": now,
			}).Error; err != nil {
			return err
		}
		if err := tx.Model(&model.LeadOpsLead{}).Where("lol_id = ?", leadID).Updates(map[string]interface{}{
			"lol_current_status": "queued",
			"lol_current_pic_id": "",
		}).Error; err != nil {
			return err
		}
		return s.appendStatusHistory(tx, leadID, lead.CurrentStatus, "queued", actorID, "release", leadID, note)
	})
}

func (s *leadOpsService) AddFollowUp(leadID string, input LeadOpsFollowUpInput, actorID string) (*model.LeadOpsFollowUp, error) {
	record := &model.LeadOpsFollowUp{}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var lead model.LeadOpsLead
		if err := tx.First(&lead, "lol_id = ?", leadID).Error; err != nil {
			return err
		}

		var latestAssignment model.LeadOpsAssignment
		assignmentID := ""
		if err := tx.Where("loa_lead_id = ?", leadID).Order("loa_assigned_at DESC").First(&latestAssignment).Error; err == nil {
			assignmentID = latestAssignment.ID
		}

		now := time.Now()
		nextStatus := mapFollowUpStageToLeadStatus(input.Stage, input.ResultStatus)

		followup := model.LeadOpsFollowUp{
			ID:             uuid.New().String(),
			LeadID:         leadID,
			AssignmentID:   assignmentID,
			UserID:         actorID,
			FollowUpDate:   now,
			Channel:        normalizeOrDefault(input.Channel, "whatsapp"),
			CallStatus:     strings.TrimSpace(input.CallStatus),
			ChatStatus:     strings.TrimSpace(input.ChatStatus),
			ValidityStatus: strings.TrimSpace(input.ValidityStatus),
			ResultStatus:   strings.TrimSpace(input.ResultStatus),
			Stage:          normalizeOrDefault(input.Stage, "contacted"),
			Outcome:        strings.TrimSpace(input.Outcome),
			Note:           strings.TrimSpace(input.Notes),
			NextFollowUpAt: input.NextFollowUpAt,
			CreatedAt:      now,
		}
		if err := tx.Create(&followup).Error; err != nil {
			return err
		}

		if err := tx.Model(&model.LeadOpsLead{}).Where("lol_id = ?", leadID).Updates(map[string]interface{}{
			"lol_current_status":          nextStatus,
			"lol_current_call_status":     strings.TrimSpace(input.CallStatus),
			"lol_current_chat_status":     strings.TrimSpace(input.ChatStatus),
			"lol_current_validity_status": strings.TrimSpace(input.ValidityStatus),
			"lol_current_result_note":     strings.TrimSpace(input.Outcome),
			"lol_last_followup_at":        now,
			"lol_next_followup_at":        input.NextFollowUpAt,
		}).Error; err != nil {
			return err
		}

		if err := s.appendStatusHistory(tx, leadID, lead.CurrentStatus, nextStatus, actorID, "followup", followup.ID, firstNonEmpty(input.ResultStatus, input.Outcome)); err != nil {
			return err
		}

		*record = followup
		return nil
	})
	return record, err
}

func (s *leadOpsService) UpsertOpportunity(leadID string, input LeadOpsOpportunityInput, actorID string) (*model.LeadOpsOpportunity, error) {
	record := &model.LeadOpsOpportunity{}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var lead model.LeadOpsLead
		if err := tx.First(&lead, "lol_id = ?", leadID).Error; err != nil {
			return err
		}

		var opportunity model.LeadOpsOpportunity
		err := tx.Where("loo_lead_id = ?", leadID).First(&opportunity).Error
		if err != nil && err != gorm.ErrRecordNotFound {
			return err
		}

		stage := normalizeOrDefault(input.Stage, "potential")
		now := time.Now()

		if err == gorm.ErrRecordNotFound {
			opportunity = model.LeadOpsOpportunity{
				ID:        uuid.New().String(),
				LeadID:    leadID,
				PICUserID: lead.CurrentPICID,
				CreatedAt: now,
			}
		}

		opportunity.Stage = stage
		opportunity.MembershipType = strings.TrimSpace(input.MembershipType)
		opportunity.TargetActivationPlan = strings.TrimSpace(input.TargetActivationPlan)
		opportunity.TargetActivationAmount = input.TargetActivationAmount
		opportunity.TargetAddonPlan = strings.TrimSpace(input.TargetAddonPlan)
		opportunity.TargetAddonAmount = input.TargetAddonAmount
		opportunity.ActualActivationPkg = strings.TrimSpace(input.ActualActivationPkg)
		opportunity.ActualActivationAmount = input.ActualActivationAmount
		opportunity.ActualAddonName = strings.TrimSpace(input.ActualAddonName)
		opportunity.ActualAddonAmount = input.ActualAddonAmount
		opportunity.ClosingStatus = strings.TrimSpace(input.ClosingStatus)
		opportunity.ClosingAmount = input.ClosingAmount
		opportunity.ClosingDate = input.ClosingDate
		opportunity.PICUserID = lead.CurrentPICID
		opportunity.UpdatedAt = now

		if err == gorm.ErrRecordNotFound {
			if err := tx.Create(&opportunity).Error; err != nil {
				return err
			}
		} else {
			if err := tx.Save(&opportunity).Error; err != nil {
				return err
			}
		}

		if err := tx.Model(&model.LeadOpsLead{}).Where("lol_id = ?", leadID).Update("lol_current_status", stageToLeadStatus(stage)).Error; err != nil {
			return err
		}
		if err := s.appendStatusHistory(tx, leadID, lead.CurrentStatus, stageToLeadStatus(stage), actorID, "opportunity", opportunity.ID, stage); err != nil {
			return err
		}

		*record = opportunity
		return nil
	})
	return record, err
}

func (s *leadOpsService) ListAssignments(limit int) ([]LeadOpsAssignmentRow, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	var rows []LeadOpsAssignmentRow
	err := s.db.Table("ac_lead_ops_assignments a").
		Select(`
			a.loa_id as id,
			a.loa_lead_id as lead_id,
			l.lol_code as lead_code,
			l.lol_owner_name as owner_name,
			l.lol_outlet_name as outlet_name,
			COALESCE(NULLIF(l.lol_owner_phone, ''), l.lol_outlet_phone) as phone,
			a.loa_division as division,
			a.loa_assigned_by_id as assigned_by_id,
			COALESCE(ab.adm_nama, '') as assigned_by_name,
			a.loa_assigned_to_id as assigned_to_id,
			COALESCE(at.adm_nama, '') as assigned_to_name,
			a.loa_assignment_type as assignment_type,
			a.loa_assignment_reason as assignment_reason,
			a.loa_note as note,
			a.loa_assigned_at as assigned_at
		`).
		Joins("JOIN ac_lead_ops_leads l ON l.lol_id = a.loa_lead_id").
		Joins("LEFT JOIN ac_admin ab ON ab.adm_id = a.loa_assigned_by_id").
		Joins("LEFT JOIN ac_admin at ON at.adm_id = a.loa_assigned_to_id").
		Order("a.loa_assigned_at DESC").
		Limit(limit).
		Scan(&rows).Error
	return rows, err
}

func (s *leadOpsService) ListAssignmentsByLead(leadID string) ([]LeadOpsAssignmentRow, error) {
	var rows []LeadOpsAssignmentRow
	err := s.db.Table("ac_lead_ops_assignments a").
		Select(`
			a.loa_id as id,
			a.loa_lead_id as lead_id,
			l.lol_code as lead_code,
			l.lol_owner_name as owner_name,
			l.lol_outlet_name as outlet_name,
			COALESCE(NULLIF(l.lol_owner_phone, ''), l.lol_outlet_phone) as phone,
			a.loa_division as division,
			a.loa_assigned_by_id as assigned_by_id,
			COALESCE(ab.adm_nama, '') as assigned_by_name,
			a.loa_assigned_to_id as assigned_to_id,
			COALESCE(at.adm_nama, '') as assigned_to_name,
			a.loa_assignment_type as assignment_type,
			a.loa_assignment_reason as assignment_reason,
			a.loa_note as note,
			a.loa_assigned_at as assigned_at
		`).
		Joins("JOIN ac_lead_ops_leads l ON l.lol_id = a.loa_lead_id").
		Joins("LEFT JOIN ac_admin ab ON ab.adm_id = a.loa_assigned_by_id").
		Joins("LEFT JOIN ac_admin at ON at.adm_id = a.loa_assigned_to_id").
		Where("a.loa_lead_id = ?", leadID).
		Order("a.loa_assigned_at DESC").
		Scan(&rows).Error
	return rows, err
}

func (s *leadOpsService) GetSummary() (*LeadOpsSummary, error) {
	summary := &LeadOpsSummary{}
	s.db.Model(&model.LeadOpsLead{}).Count(&summary.TotalLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "new").Count(&summary.NewLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "assigned").Count(&summary.AssignedLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "contacted").Count(&summary.ContactedLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "potential").Count(&summary.PotentialLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "demo").Count(&summary.DemoLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "converted").Count(&summary.ConvertedLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_status = ?", "lost").Count(&summary.LostLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_next_followup_at IS NOT NULL AND lol_next_followup_at < ?", time.Now()).Count(&summary.OverdueFollowups)
	return summary, nil
}

func (s *leadOpsService) GetMySummary(actorID string) (*LeadOpsSummary, error) {
	summary := &LeadOpsSummary{}
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ?", actorID).Count(&summary.TotalLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "new").Count(&summary.NewLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "assigned").Count(&summary.AssignedLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "contacted").Count(&summary.ContactedLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "potential").Count(&summary.PotentialLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "demo").Count(&summary.DemoLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "converted").Count(&summary.ConvertedLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_current_status = ?", actorID, "lost").Count(&summary.LostLeads)
	s.db.Model(&model.LeadOpsLead{}).Where("lol_current_pic_id = ? AND lol_next_followup_at IS NOT NULL AND lol_next_followup_at < ?", actorID, time.Now()).Count(&summary.OverdueFollowups)
	return summary, nil
}

func (s *leadOpsService) ListAdminOptions() ([]LeadOpsAdminOption, error) {
	var rows []LeadOpsAdminOption
	err := s.db.Table("ac_admin").Select("adm_id as id, adm_nama as name").Order("adm_nama ASC").Scan(&rows).Error
	return rows, err
}

func (s *leadOpsService) GetActorProfile(actorID string) (*LeadOpsActorProfile, error) {
	var admin model.Admin
	if err := s.db.Preload("Role").Where("adm_id = ?", actorID).First(&admin).Error; err != nil {
		return nil, err
	}
	roleName := ""
	isMarketing := false
	if admin.Role != nil {
		roleName = admin.Role.Nama
		if strings.Contains(strings.ToLower(roleName), "marketing") {
			isMarketing = true
		}
	}
	return &LeadOpsActorProfile{
		ID:          admin.ID,
		Name:        admin.Nama,
		Email:       admin.Email,
		RoleName:    roleName,
		IsMaster:    admin.IsMaster,
		IsMarketing: isMarketing,
	}, nil
}

func (s *leadOpsService) SeedSampleData(actorID string) (map[string]interface{}, error) {
	var admins []model.Admin
	if err := s.db.Order("adm_created ASC").Find(&admins).Error; err != nil {
		return nil, err
	}
	if len(admins) == 0 {
		return nil, fmt.Errorf("tidak ada admin untuk dijadikan PIC sample")
	}

	sources := []string{"Data Piposmart", "TikTok", "Facebook", "Sales Lapangan", "Referral"}
	for _, source := range sources {
		if _, err := s.findOrCreateSource(source); err != nil {
			return nil, err
		}
	}

	sampleItems := []struct {
		Source string
		Item   LeadOpsImportItem
	}{
		{"Data Piposmart", LeadOpsImportItem{LeadType: "new_download", OwnerName: "Mustika Rinii", OutletName: "Zahwa Laundrily", OwnerPhone: "081284545772", OutletPhone: "081284545772", City: "Bandung", Need: "Trial aplikasi", SourceRef: "sheet-sample-1", OwnerCode: "OWN-14258"}},
		{"Data Piposmart", LeadOpsImportItem{LeadType: "new_download", OwnerName: "Pin Laundry", OutletName: "Pin Laundry", OwnerPhone: "085320875159", OutletPhone: "085320875159", City: "Bandung", Need: "Belum respon", SourceRef: "sheet-sample-2", OwnerCode: "OWN-14259"}},
		{"TikTok", LeadOpsImportItem{LeadType: "ads", OwnerName: "Andi Nofiana", OutletName: "AN Laundry", OwnerPhone: "085240394825", OutletPhone: "085240394825", City: "Jakarta", Need: "Demo aplikasi", SourceRef: "tiktok-campaign-1", OwnerCode: "OWN-00022"}},
	}

	created := 0
	assigned := 0
	followed := 0

	for index, sample := range sampleItems {
		leads, err := s.ImportLeads(sample.Source, []LeadOpsImportItem{sample.Item}, actorID)
		if err != nil {
			if strings.Contains(strings.ToLower(err.Error()), "sudah ada") {
				continue
			}
			return nil, err
		}
		if len(leads) == 0 {
			continue
		}
		created++

		pic := admins[index%len(admins)]
		if _, err := s.AssignLead(leads[0].ID, LeadOpsAssignInput{
			Division:         "marketing",
			AdminID:          pic.ID,
			AssignmentType:   "initial",
			AssignmentReason: "seed sample",
			Note:             "assignment sample otomatis",
		}, actorID); err == nil {
			assigned++
		}

		if _, err := s.AddFollowUp(leads[0].ID, LeadOpsFollowUpInput{
			Stage:        "contacted",
			Channel:      "whatsapp",
			CallStatus:   "NO CALL",
			ChatStatus:   "SENT",
			ResultStatus: "belum_respon",
			Outcome:      "Sample follow-up pertama",
			Notes:        "Diisi otomatis dari seed sample",
		}, actorID); err == nil {
			followed++
		}
	}

	return map[string]interface{}{
		"created_leads":    created,
		"assigned_leads":   assigned,
		"followup_records": followed,
	}, nil
}

func (s *leadOpsService) listFollowUpsByLead(leadID string) ([]LeadOpsFollowUpRow, error) {
	var rows []LeadOpsFollowUpRow
	err := s.db.Table("ac_lead_ops_followups f").
		Select(`
			f.lof_id as id,
			f.lof_lead_id as lead_id,
			f.lof_assignment_id as assignment_id,
			f.lof_user_id as user_id,
			COALESCE(a.adm_nama, '') as user_name,
			f.lof_followup_date as followup_date,
			f.lof_channel as channel,
			f.lof_call_status as call_status,
			f.lof_chat_status as chat_status,
			f.lof_validity_status as validity_status,
			f.lof_result_status as result_status,
			f.lof_stage as stage,
			f.lof_outcome as outcome,
			f.lof_note as notes,
			f.lof_next_followup_at as next_followup_at,
			f.lof_created as created_at
		`).
		Joins("LEFT JOIN ac_admin a ON a.adm_id = f.lof_user_id").
		Where("f.lof_lead_id = ?", leadID).
		Order("f.lof_followup_date DESC, f.lof_created DESC").
		Scan(&rows).Error
	return rows, err
}

func (s *leadOpsService) listStatusHistoryByLead(leadID string) ([]LeadOpsStatusHistoryRow, error) {
	var rows []LeadOpsStatusHistoryRow
	err := s.db.Table("ac_lead_ops_status_history h").
		Select(`
			h.lsh_id as id,
			h.lsh_old_status as old_status,
			h.lsh_new_status as new_status,
			h.lsh_changed_by_user_id as changed_by_user_id,
			COALESCE(a.adm_nama, '') as changed_by_name,
			h.lsh_source_event_type as source_event_type,
			h.lsh_source_event_id as source_event_id,
			h.lsh_reason as reason,
			h.lsh_created as created_at
		`).
		Joins("LEFT JOIN ac_admin a ON a.adm_id = h.lsh_changed_by_user_id").
		Where("h.lsh_lead_id = ?", leadID).
		Order("h.lsh_created DESC").
		Scan(&rows).Error
	return rows, err
}

func (s *leadOpsService) getOpportunityByLead(leadID string) (*LeadOpsOpportunityRow, error) {
	var row LeadOpsOpportunityRow
	err := s.db.Table("ac_lead_ops_opportunities o").
		Select(`
			o.loo_id as id,
			o.loo_lead_id as lead_id,
			o.loo_pic_user_id as pic_user_id,
			COALESCE(a.adm_nama, '') as pic_user_name,
			o.loo_stage as stage,
			o.loo_membership_type as membership_type,
			o.loo_target_activation_plan as target_activation_plan,
			o.loo_target_activation_amount as target_activation_amount,
			o.loo_target_addon_plan as target_addon_plan,
			o.loo_target_addon_amount as target_addon_amount,
			o.loo_actual_activation_package as actual_activation_package,
			o.loo_actual_activation_amount as actual_activation_amount,
			o.loo_actual_addon_name as actual_addon_name,
			o.loo_actual_addon_amount as actual_addon_amount,
			o.loo_closing_status as closing_status,
			o.loo_closing_amount as closing_amount,
			o.loo_closing_date as closing_date,
			o.loo_created as created_at,
			o.loo_updated as updated_at
		`).
		Joins("LEFT JOIN ac_admin a ON a.adm_id = o.loo_pic_user_id").
		Where("o.loo_lead_id = ?", leadID).
		Scan(&row).Error
	if err != nil {
		return nil, err
	}
	if row.ID == "" {
		return nil, nil
	}
	return &row, nil
}

func (s *leadOpsService) ensureLeadNotDuplicate(tx *gorm.DB, ownerCode, ownerPhone, outletPhone, ownerName, outletName string) error {
	query := tx.Model(&model.LeadOpsLead{})
	if ownerCode != "" {
		var count int64
		if err := query.Where("lol_owner_code = ? AND lol_owner_code != ''", ownerCode).Count(&count).Error; err == nil && count > 0 {
			return fmt.Errorf("lead dengan owner_code %s sudah ada", ownerCode)
		}
	}

	phone := firstNonEmpty(ownerPhone, outletPhone)
	if phone != "" {
		var count int64
		if err := tx.Model(&model.LeadOpsLead{}).Where("lol_owner_phone = ? OR lol_outlet_phone = ?", phone, phone).Count(&count).Error; err == nil && count > 0 {
			return fmt.Errorf("lead dengan nomor hp %s sudah ada", phone)
		}
	}

	if ownerName != "" && outletName != "" {
		var count int64
		if err := tx.Model(&model.LeadOpsLead{}).Where("LOWER(lol_owner_name) = ? AND LOWER(lol_outlet_name) = ?", strings.ToLower(ownerName), strings.ToLower(outletName)).Count(&count).Error; err == nil && count > 0 {
			return fmt.Errorf("lead %s / %s sudah ada", ownerName, outletName)
		}
	}
	return nil
}

func (s *leadOpsService) appendStatusHistory(tx *gorm.DB, leadID, oldStatus, newStatus, actorID, eventType, eventID, reason string) error {
	history := model.LeadOpsStatusHistory{
		ID:              uuid.New().String(),
		LeadID:          leadID,
		OldStatus:       oldStatus,
		NewStatus:       newStatus,
		ChangedByUserID: actorID,
		SourceEventType: eventType,
		SourceEventID:   eventID,
		Reason:          reason,
		CreatedAt:       time.Now(),
	}
	return tx.Create(&history).Error
}

func (s *leadOpsService) findOrCreateSource(source string) (*model.LeadOpsSource, error) {
	code := slugify(source)
	var found model.LeadOpsSource
	if err := s.db.Where("los_code = ? OR los_name = ?", code, source).First(&found).Error; err == nil {
		return &found, nil
	}

	category := "manual"
	switch code {
	case "data-piposmart", "piposmart":
		category = "platform"
	case "tiktok", "facebook", "instagram":
		category = "ads"
	case "sales-lapangan", "sales-agen-ayo-cuci":
		category = "field"
	case "referral":
		category = "referral"
	}

	found = model.LeadOpsSource{
		ID:       uuid.New().String(),
		Code:     code,
		Name:     source,
		Category: category,
		IsActive: true,
	}
	if err := s.db.Create(&found).Error; err != nil {
		return nil, fmt.Errorf("gagal menyimpan source lead: %w", err)
	}
	return &found, nil
}

func (s *leadOpsService) generateLeadCode() string {
	return "LD/" + time.Now().Format("20060102") + "/" + strings.ToUpper(uuid.New().String()[:8])
}

func normalizeOrDefault(value, fallback string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return fallback
	}
	return value
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		value = strings.TrimSpace(value)
		if value != "" {
			return value
		}
	}
	return ""
}

func slugify(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	replacer := strings.NewReplacer("/", "-", "_", "-", " ", "-", ".", "-", "(", "", ")", "")
	value = replacer.Replace(value)
	for strings.Contains(value, "--") {
		value = strings.ReplaceAll(value, "--", "-")
	}
	return strings.Trim(value, "-")
}

func mapFollowUpStageToLeadStatus(stage, result string) string {
	stage = strings.ToLower(strings.TrimSpace(stage))
	result = strings.ToLower(strings.TrimSpace(result))

	switch {
	case stage == "converted" || stage == "won":
		return "converted"
	case stage == "demo":
		return "demo"
	case stage == "potential" || stage == "qualified" || stage == "interested" || result == "prospect" || result == "trial" || result == "interest":
		return "potential"
	case stage == "lost" || stage == "unqualified" || stage == "rejected" || result == "uninterest":
		return "lost"
	case result == "fitur_tidak_sesuai" || result == "invalid":
		return "invalid"
	case result == "belum_respon" || stage == "no_response":
		return "no_response"
	case stage == "contacted" || stage == "followed_up":
		return "contacted"
	default:
		return "assigned"
	}
}

func stageToLeadStatus(stage string) string {
	switch strings.ToLower(strings.TrimSpace(stage)) {
	case "potential":
		return "potential"
	case "demo_scheduled", "training", "demo":
		return "demo"
	case "closing", "won":
		return "converted"
	case "lost":
		return "lost"
	default:
		return "potential"
	}
}
