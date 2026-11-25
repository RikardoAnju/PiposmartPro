package model

import "time"

// CustomerDepositAccount is the customer balance for one outlet.
type CustomerDepositAccount struct {
	ID            string    `gorm:"column:cda_id;primaryKey;size:36" json:"id"`
	CustomerID    string    `gorm:"column:cda_customer;size:50;uniqueIndex:uq_deposit_customer_outlet" json:"customer_id"`
	OutletID      string    `gorm:"column:cda_outlet;size:20;uniqueIndex:uq_deposit_customer_outlet" json:"outlet_id"`
	BalanceRupiah float64   `gorm:"column:cda_balance_rupiah;not null;default:0" json:"balance_rupiah"`
	BalanceKg     float64   `gorm:"column:cda_balance_kg;not null;default:0" json:"balance_kg"`
	CreatedAt     time.Time `gorm:"column:cda_created;autoCreateTime" json:"created_at"`
	UpdatedAt     time.Time `gorm:"column:cda_updated;autoUpdateTime" json:"updated_at"`
}

func (CustomerDepositAccount) TableName() string { return "ac_customer_deposit_accounts" }

type CustomerDepositTopup struct {
	ID              string    `gorm:"column:cdt_id;primaryKey;size:36" json:"id"`
	AccountID       string    `gorm:"column:cdt_account;size:36;index" json:"account_id"`
	CustomerID      string    `gorm:"column:cdt_customer;size:50;index" json:"customer_id"`
	OutletID        string    `gorm:"column:cdt_outlet;size:20;index" json:"outlet_id"`
	DepositType     string    `gorm:"column:cdt_type;size:10" json:"deposit_type"`
	Value           float64   `gorm:"column:cdt_value" json:"value"`
	TotalPaid       float64   `gorm:"column:cdt_total_paid" json:"total_paid"`
	DiscountAmount  float64   `gorm:"column:cdt_discount;not null;default:0" json:"discount_amount"`
	PaymentMethodID string    `gorm:"column:cdt_payment_method;size:40" json:"payment_method_id"`
	Note            string    `gorm:"column:cdt_note" json:"note"`
	CreatedBy       string    `gorm:"column:cdt_created_by;size:60" json:"created_by"`
	RequestID       string    `gorm:"column:cdt_request_id;size:80;uniqueIndex" json:"request_id"`
	CreatedAt       time.Time `gorm:"column:cdt_created;autoCreateTime" json:"created_at"`
}

func (CustomerDepositTopup) TableName() string { return "ac_customer_deposit_topups" }

// CustomerDepositAdjustment records cash and balance changes on the day they
// occur without rewriting the original top-up.
type CustomerDepositAdjustment struct {
	ID              string    `gorm:"column:caj_id;primaryKey;size:36" json:"id"`
	TopupID         string    `gorm:"column:caj_topup;size:36;index" json:"topup_id"`
	AccountID       string    `gorm:"column:caj_account;size:36" json:"account_id"`
	CustomerID      string    `gorm:"column:caj_customer;size:50;index" json:"customer_id"`
	OutletID        string    `gorm:"column:caj_outlet;size:20;index" json:"outlet_id"`
	Kind            string    `gorm:"column:caj_kind;size:16" json:"kind"`
	DepositType     string    `gorm:"column:caj_type;size:10" json:"deposit_type"`
	ValueDelta      float64   `gorm:"column:caj_value_delta" json:"value_delta"`
	CashDelta       float64   `gorm:"column:caj_cash_delta" json:"cash_delta"`
	PaymentMethodID string    `gorm:"column:caj_payment_method;size:40" json:"payment_method_id"`
	Note            string    `gorm:"column:caj_note;size:500" json:"note"`
	CreatedBy       string    `gorm:"column:caj_created_by;size:60" json:"created_by"`
	CreatedByType   string    `gorm:"column:caj_created_by_type;size:20" json:"created_by_type"`
	RequestID       string    `gorm:"column:caj_request_id;size:80;uniqueIndex" json:"request_id"`
	CreatedAt       time.Time `gorm:"column:caj_created;autoCreateTime;index" json:"created_at"`
}

func (CustomerDepositAdjustment) TableName() string { return "ac_customer_deposit_adjustments" }

type CustomerDepositLedger struct {
	ID             string    `gorm:"column:cdl_id;primaryKey;size:36" json:"id"`
	AccountID      string    `gorm:"column:cdl_account;size:36;index" json:"account_id"`
	CustomerID     string    `gorm:"column:cdl_customer;size:50;index" json:"customer_id"`
	OutletID       string    `gorm:"column:cdl_outlet;size:20;index" json:"outlet_id"`
	EntryType      string    `gorm:"column:cdl_entry_type;size:16" json:"entry_type"`
	DepositType    string    `gorm:"column:cdl_type;size:10" json:"deposit_type"`
	Amount         float64   `gorm:"column:cdl_amount" json:"amount"`
	BalanceBefore  float64   `gorm:"column:cdl_balance_before" json:"balance_before"`
	BalanceAfter   float64   `gorm:"column:cdl_balance_after" json:"balance_after"`
	ReferenceID    string    `gorm:"column:cdl_reference;size:70;index" json:"reference_id"`
	Note           string    `gorm:"column:cdl_note" json:"note"`
	CreatedBy      string    `gorm:"column:cdl_created_by;size:60" json:"created_by"`
	CreatedByType  string    `gorm:"column:cdl_created_by_type;size:20;index" json:"created_by_type"`
	PaidAmount     float64   `gorm:"-" json:"paid_amount,omitempty"`
	DiscountAmount float64   `gorm:"-" json:"discount_amount,omitempty"`
	PaymentMethod  string    `gorm:"-" json:"payment_method,omitempty"`
	CreatedByName  string    `gorm:"-" json:"created_by_name,omitempty"`
	CreatedAt      time.Time `gorm:"column:cdl_created;autoCreateTime;index" json:"created_at"`
}

func (CustomerDepositLedger) TableName() string { return "ac_customer_deposit_ledger" }
