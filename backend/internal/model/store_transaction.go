package model

import "time"

type StoreTransaction struct {
	ID                    string     `gorm:"column:st_id;primaryKey;size:50" json:"st_id"`
	Platform              string     `gorm:"column:st_platform;size:20;index" json:"st_platform"`
	Store                 string     `gorm:"column:st_store;size:30" json:"st_store"`
	ProductID             string     `gorm:"column:st_product_id;size:120;index" json:"st_product_id"`
	ProductType           string     `gorm:"column:st_product_type;size:30;index" json:"st_product_type"`
	TransactionID         string     `gorm:"column:st_transaction_id;size:120;uniqueIndex" json:"st_transaction_id"`
	OriginalTransactionID *string    `gorm:"column:st_original_transaction_id;size:120" json:"st_original_transaction_id"`
	OwnerUserID           uint       `gorm:"column:st_owner_user_id;index" json:"st_owner_user_id"`
	OutletID              *string    `gorm:"column:st_outlet_id;size:50;index" json:"st_outlet_id"`
	PurchaseToken         *string    `gorm:"column:st_purchase_token;type:text" json:"st_purchase_token"`
	ReceiptPayload        *string    `gorm:"column:st_receipt_payload;type:longtext" json:"st_receipt_payload"`
	Status                string     `gorm:"column:st_status;size:30;index" json:"st_status"`
	GrantStatus           string     `gorm:"column:st_grant_status;size:30" json:"st_grant_status"`
	CoinAmount            int        `gorm:"column:st_coin_amount;default:0" json:"st_coin_amount"`
	ProActivated          bool       `gorm:"column:st_pro_activated;default:false" json:"st_pro_activated"`
	Environment           string     `gorm:"column:st_environment;size:20" json:"st_environment"`
	VerifiedAt            *time.Time `gorm:"column:st_verified_at" json:"st_verified_at"`
	GrantedAt             *time.Time `gorm:"column:st_granted_at" json:"st_granted_at"`
	CreatedAt             time.Time  `gorm:"column:st_created;autoCreateTime" json:"st_created"`
	UpdatedAt             *time.Time `gorm:"column:st_lastupdate;autoUpdateTime" json:"st_lastupdate"`
}

func (StoreTransaction) TableName() string {
	return "ac_store_transactions"
}
