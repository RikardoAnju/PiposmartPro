package model

import "time"

type NobuCallbackToken struct {
	ID        string    `gorm:"column:nct_id;primaryKey;size:40" json:"id"`
	TokenHash string    `gorm:"column:nct_token_hash;size:64;uniqueIndex" json:"-"`
	PartnerID string    `gorm:"column:nct_partner_id;size:64;index" json:"partner_id"`
	ExpiresAt time.Time `gorm:"column:nct_expires_at;index" json:"expires_at"`
	CreatedAt time.Time `gorm:"column:nct_created;autoCreateTime" json:"created_at"`
}

func (NobuCallbackToken) TableName() string { return "ac_nobu_callback_tokens" }

type NobuCallbackAudit struct {
	ID               string    `gorm:"column:nca_id;primaryKey;size:40" json:"id"`
	ExternalID       string    `gorm:"column:nca_external_id;size:64;index" json:"external_id"`
	PartnerID        string    `gorm:"column:nca_partner_id;size:64;index" json:"partner_id"`
	OrderReference   string    `gorm:"column:nca_order_reference;size:64;index" json:"order_reference"`
	BodyHash         string    `gorm:"column:nca_body_hash;size:64" json:"body_hash"`
	RequestBody      string    `gorm:"column:nca_request_body;type:longtext" json:"-"`
	RequestHeaders   string    `gorm:"column:nca_request_headers;type:json" json:"-"`
	SignatureValid   bool      `gorm:"column:nca_signature_valid" json:"signature_valid"`
	TokenValid       bool      `gorm:"column:nca_token_valid" json:"token_valid"`
	ProcessingStatus string    `gorm:"column:nca_processing_status;size:30;index" json:"processing_status"`
	ProcessingError  *string   `gorm:"column:nca_processing_error;type:text" json:"processing_error,omitempty"`
	CreatedAt        time.Time `gorm:"column:nca_created;autoCreateTime" json:"created_at"`
}

func (NobuCallbackAudit) TableName() string { return "ac_nobu_callback_audits" }

type OwnerPayable struct {
	ID          string    `gorm:"column:op_id;primaryKey;size:40" json:"id"`
	OrderID     string    `gorm:"column:op_order_id;size:60;index" json:"order_id"`
	PaymentID   string    `gorm:"column:op_payment_id;size:40;uniqueIndex" json:"payment_id"`
	OutletID    string    `gorm:"column:op_outlet_id;size:20;index" json:"outlet_id"`
	GrossAmount float64   `gorm:"column:op_gross_amount;type:decimal(18,2)" json:"gross_amount"`
	MDRAmount   float64   `gorm:"column:op_mdr_amount;type:decimal(18,2)" json:"mdr_amount"`
	PlatformFee float64   `gorm:"column:op_platform_fee;type:decimal(18,2)" json:"platform_fee"`
	NetAmount   float64   `gorm:"column:op_net_amount;type:decimal(18,2)" json:"net_amount"`
	Status      string    `gorm:"column:op_status;size:20;index" json:"status"`
	CreatedAt   time.Time `gorm:"column:op_created;autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time `gorm:"column:op_updated;autoUpdateTime" json:"updated_at"`
}

func (OwnerPayable) TableName() string { return "ac_owner_payables" }

type NobuFundLedger struct {
	ID          string    `gorm:"column:nfl_id;primaryKey;size:40" json:"id"`
	PaymentID   string    `gorm:"column:nfl_payment_id;size:40;uniqueIndex" json:"payment_id"`
	OutletID    string    `gorm:"column:nfl_outlet_id;size:20;index" json:"outlet_id"`
	GrossAmount float64   `gorm:"column:nfl_gross_amount;type:decimal(18,2)" json:"gross_amount"`
	MDRAmount   float64   `gorm:"column:nfl_mdr_amount;type:decimal(18,2)" json:"mdr_amount"`
	NetAmount   float64   `gorm:"column:nfl_net_amount;type:decimal(18,2)" json:"net_amount"`
	Status      string    `gorm:"column:nfl_status;size:20;index" json:"status"`
	CreatedAt   time.Time `gorm:"column:nfl_created;autoCreateTime" json:"created_at"`
}

func (NobuFundLedger) TableName() string { return "ac_nobu_fund_ledgers" }

type SettlementBatch struct {
	ID          string    `gorm:"column:sb_id;primaryKey;size:40" json:"id"`
	Reference   string    `gorm:"column:sb_reference;size:40;uniqueIndex" json:"reference"`
	TotalAmount float64   `gorm:"column:sb_total_amount;type:decimal(18,2)" json:"total_amount"`
	Status      string    `gorm:"column:sb_status;size:20;index" json:"status"`
	ProofURL    *string   `gorm:"column:sb_proof_url;type:text" json:"proof_url,omitempty"`
	AdminNote   *string   `gorm:"column:sb_admin_note;type:text" json:"admin_note,omitempty"`
	CreatedAt   time.Time `gorm:"column:sb_created;autoCreateTime" json:"created_at"`
	UpdatedAt   time.Time `gorm:"column:sb_updated;autoUpdateTime" json:"updated_at"`
}

func (SettlementBatch) TableName() string { return "ac_settlement_batches" }

type SettlementItem struct {
	ID        string    `gorm:"column:si_id;primaryKey;size:40" json:"id"`
	BatchID   string    `gorm:"column:si_batch_id;size:40;index" json:"batch_id"`
	PayableID string    `gorm:"column:si_payable_id;size:40;uniqueIndex" json:"payable_id"`
	OutletID  string    `gorm:"column:si_outlet_id;size:20;index" json:"outlet_id"`
	Amount    float64   `gorm:"column:si_amount;type:decimal(18,2)" json:"amount"`
	CreatedAt time.Time `gorm:"column:si_created;autoCreateTime" json:"created_at"`
}

func (SettlementItem) TableName() string { return "ac_settlement_items" }

type ReconciliationRecord struct {
	ID             string    `gorm:"column:rr_id;primaryKey;size:40" json:"id"`
	PaymentID      *string   `gorm:"column:rr_payment_id;size:40;index" json:"payment_id,omitempty"`
	Reference      string    `gorm:"column:rr_reference;size:64;index" json:"reference"`
	ExpectedAmount float64   `gorm:"column:rr_expected_amount;type:decimal(18,2)" json:"expected_amount"`
	ActualAmount   float64   `gorm:"column:rr_actual_amount;type:decimal(18,2)" json:"actual_amount"`
	Status         string    `gorm:"column:rr_status;size:20;index" json:"status"`
	Note           *string   `gorm:"column:rr_note;type:text" json:"note,omitempty"`
	CreatedAt      time.Time `gorm:"column:rr_created;autoCreateTime" json:"created_at"`
}

func (ReconciliationRecord) TableName() string { return "ac_reconciliation_records" }
