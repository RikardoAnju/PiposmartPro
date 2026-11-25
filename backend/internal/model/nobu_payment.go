package model

import "time"

// NobuPaymentTransaction stores provider references separately from legacy cash/manual payments.
type NobuPaymentTransaction struct {
	ID                   string     `gorm:"column:npt_id;primaryKey;size:40" json:"id"`
	OrderID              string     `gorm:"column:npt_order_id;size:60;index" json:"order_id"`
	OutletID             string     `gorm:"column:npt_outlet_id;size:20;index" json:"outlet_id"`
	Provider             string     `gorm:"column:npt_provider;size:20;index" json:"provider"`
	PartnerReferenceNo   string     `gorm:"column:npt_partner_reference_no;size:25;uniqueIndex" json:"partner_reference_no"`
	NobuReferenceNo      *string    `gorm:"column:npt_nobu_reference_no;size:64;index" json:"nobu_reference_no,omitempty"`
	PaymentReferenceNo   *string    `gorm:"column:npt_payment_reference_no;size:40;index" json:"payment_reference_no,omitempty"`
	RetrievalReferenceNo *string    `gorm:"column:npt_retrieval_reference_no;size:64" json:"retrieval_reference_no,omitempty"`
	ExternalID           string     `gorm:"column:npt_external_id;size:32;index" json:"external_id"`
	MerchantID           string     `gorm:"column:npt_merchant_id;size:64" json:"merchant_id"`
	SubMerchantID        string     `gorm:"column:npt_sub_merchant_id;size:32" json:"sub_merchant_id"`
	StoreID              string     `gorm:"column:npt_store_id;size:64" json:"store_id"`
	TerminalID           string     `gorm:"column:npt_terminal_id;size:25" json:"terminal_id"`
	AmountValue          string     `gorm:"column:npt_amount_value;size:20" json:"amount_value"`
	AmountCurrency       string     `gorm:"column:npt_amount_currency;size:3" json:"amount_currency"`
	NetAmount            *string    `gorm:"column:npt_net_amount;size:20" json:"net_amount,omitempty"`
	QRContent            *string    `gorm:"column:npt_qr_content;type:text" json:"qr_content,omitempty"`
	QRURL                *string    `gorm:"column:npt_qr_url;type:text" json:"qr_url,omitempty"`
	QRImage              *string    `gorm:"column:npt_qr_image;type:longtext" json:"-"`
	ProviderStatus       string     `gorm:"column:npt_provider_status;size:2;index" json:"provider_status"`
	InternalStatus       string     `gorm:"column:npt_internal_status;size:30;index" json:"internal_status"`
	ProviderStatusDesc   *string    `gorm:"column:npt_provider_status_desc;size:100" json:"provider_status_desc,omitempty"`
	PayerName            *string    `gorm:"column:npt_payer_name;size:40" json:"payer_name,omitempty"`
	PayerPhone           *string    `gorm:"column:npt_payer_phone;size:19" json:"-"`
	PaidAt               *time.Time `gorm:"column:npt_paid_at" json:"paid_at,omitempty"`
	QRExpiredAt          *time.Time `gorm:"column:npt_qr_expired_at" json:"qr_expired_at,omitempty"`
	CreatedAt            time.Time  `gorm:"column:npt_created;autoCreateTime" json:"created_at"`
	UpdatedAt            time.Time  `gorm:"column:npt_updated;autoUpdateTime" json:"updated_at"`
}

func (NobuPaymentTransaction) TableName() string { return "ac_nobu_payment_transactions" }

type NobuProviderEvent struct {
	ID                   string     `gorm:"column:npe_id;primaryKey;size:40" json:"id"`
	ExternalID           string     `gorm:"column:npe_external_id;size:32;index" json:"external_id"`
	PartnerReferenceNo   string     `gorm:"column:npe_partner_reference_no;size:25;index" json:"partner_reference_no"`
	EventType            string     `gorm:"column:npe_event_type;size:30" json:"event_type"`
	RequestHeaders       string     `gorm:"column:npe_request_headers;type:json" json:"-"`
	RequestBody          string     `gorm:"column:npe_request_body;type:longtext" json:"-"`
	SignatureValid       bool       `gorm:"column:npe_signature_valid" json:"signature_valid"`
	ProcessingStatus     string     `gorm:"column:npe_processing_status;size:30;index" json:"processing_status"`
	ProcessingError      *string    `gorm:"column:npe_processing_error;type:text" json:"-"`
	PaymentTransactionID *string    `gorm:"column:npe_payment_transaction_id;size:40;index" json:"payment_transaction_id,omitempty"`
	ReceivedAt           time.Time  `gorm:"column:npe_received_at;autoCreateTime" json:"received_at"`
	ProcessedAt          *time.Time `gorm:"column:npe_processed_at" json:"processed_at,omitempty"`
}

func (NobuProviderEvent) TableName() string { return "ac_nobu_provider_events" }
