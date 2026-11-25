package model

import "time"

type ReferralReward struct {
	ID                  uint      `gorm:"column:rr_id;primaryKey;autoIncrement" json:"rr_id"`
	ReferrerUserID      uint      `gorm:"column:rr_referrer_user;not null;index" json:"rr_referrer_user"`
	ReferredUserID      uint      `gorm:"column:rr_referred_user;not null;index" json:"rr_referred_user"`
	ReferredOutletID    string    `gorm:"column:rr_referred_outlet;size:20;not null" json:"rr_referred_outlet"`
	RewardAmount        int       `gorm:"column:rr_reward_amount;not null" json:"rr_reward_amount"`
	Percent             int       `gorm:"column:rr_percent;not null;default:0" json:"rr_percent"` // tambah ini
	Type                string    `gorm:"column:rr_type;size:30;default:'recruit'" json:"rr_type"`
	ReferenceID         string    `gorm:"column:rr_reference_id;size:60" json:"rr_reference_id"`
	Status              string    `gorm:"column:rr_status;size:30;default:'credited'" json:"rr_status"`
	CoinAmount          int       `gorm:"column:rr_coin_amount;not null;default:0" json:"rr_coin_amount"`
	CoinStatus          string    `gorm:"column:rr_coin_status;size:30;default:'unclaimed'" json:"rr_coin_status"`
	CoinClaimedOutletID *string   `gorm:"column:rr_coin_claimed_outlet;size:20" json:"rr_coin_claimed_outlet"`
	CreatedAt           time.Time `gorm:"column:rr_created;autoCreateTime" json:"rr_created"`
	UpdatedAt           time.Time `gorm:"column:rr_lastupdate;autoUpdateTime" json:"rr_lastupdate"`
}

func (ReferralReward) TableName() string {
	return "ac_referral_rewards"
}

type ReferralPayoutItem struct {
	ID        uint      `gorm:"column:rpi_id;primaryKey;autoIncrement" json:"rpi_id"`
	PayoutID  string    `gorm:"column:rpi_payout_id;size:40;not null;index" json:"rpi_payout_id"`
	RewardID  uint      `gorm:"column:rpi_reward_id;not null;index" json:"rpi_reward_id"`
	Amount    int       `gorm:"column:rpi_amount;not null" json:"rpi_amount"`
	CreatedAt time.Time `gorm:"column:rpi_created;autoCreateTime" json:"rpi_created"`
}

func (ReferralPayoutItem) TableName() string {
	return "ac_referral_payout_items"
}

type ReferralWalletHistory struct {
	ID            uint      `gorm:"column:rwh_id;primaryKey;autoIncrement" json:"rwh_id"`
	UserID        uint      `gorm:"column:rwh_user;not null;index" json:"rwh_user"`
	Amount        int       `gorm:"column:rwh_amount;not null" json:"rwh_amount"`
	BalanceAfter  int       `gorm:"column:rwh_balance_after;not null" json:"rwh_balance_after"`
	Type          string    `gorm:"column:rwh_type;size:40;not null" json:"rwh_type"`
	ReferenceType string    `gorm:"column:rwh_reference_type;size:40" json:"rwh_reference_type"`
	ReferenceID   string    `gorm:"column:rwh_reference_id;size:60" json:"rwh_reference_id"`
	Description   string    `gorm:"column:rwh_description;type:text" json:"rwh_description"`
	CreatedAt     time.Time `gorm:"column:rwh_created;autoCreateTime" json:"rwh_created"`
}

func (ReferralWalletHistory) TableName() string {
	return "ac_referral_wallet_history"
}

type ReferralPayoutRequest struct {
	ID              string     `gorm:"column:rp_id;primaryKey;size:40" json:"rp_id"`
	UserID          uint       `gorm:"column:rp_user;not null;index" json:"rp_user"`
	PayoutAccountID *uint      `gorm:"column:rp_payout_account_id;index" json:"rp_payout_account_id"`
	Amount          int        `gorm:"column:rp_amount;not null" json:"rp_amount"`
	Status          string     `gorm:"column:rp_status;size:20;default:'pending'" json:"rp_status"`
	BankName        string     `gorm:"column:rp_bank_name;size:100;not null" json:"rp_bank_name"`
	AccountName     string     `gorm:"column:rp_account_name;size:120;not null" json:"rp_account_name"`
	AccountNumber   string     `gorm:"column:rp_account_number;size:60;not null" json:"rp_account_number"`
	Note            *string    `gorm:"column:rp_note;type:text" json:"rp_note"`
	AdminNote       *string    `gorm:"column:rp_admin_note;type:text" json:"rp_admin_note"`
	ProcessedAt     *time.Time `gorm:"column:rp_processed_at" json:"rp_processed_at"`
	CompletedAt     *time.Time `gorm:"column:rp_completed_at" json:"rp_completed_at"`
	CreatedAt       time.Time  `gorm:"column:rp_created;autoCreateTime" json:"rp_created"`
	UpdatedAt       time.Time  `gorm:"column:rp_lastupdate;autoUpdateTime" json:"rp_lastupdate"`
}

func (ReferralPayoutRequest) TableName() string {
	return "ac_referral_payout_requests"
}

type ReferralPayoutAccount struct {
	ID            uint      `gorm:"column:rpa_id;primaryKey;autoIncrement" json:"rpa_id"`
	UserID        uint      `gorm:"column:rpa_user;not null;index" json:"rpa_user"`
	BankName      string    `gorm:"column:rpa_bank_name;size:100;not null" json:"rpa_bank_name"`
	AccountName   string    `gorm:"column:rpa_account_name;size:120;not null" json:"rpa_account_name"`
	AccountNumber string    `gorm:"column:rpa_account_number;size:60;not null" json:"rpa_account_number"`
	IsDefault     bool      `gorm:"column:rpa_is_default;default:false" json:"rpa_is_default"`
	CreatedAt     time.Time `gorm:"column:rpa_created;autoCreateTime" json:"rpa_created"`
	UpdatedAt     time.Time `gorm:"column:rpa_lastupdate;autoUpdateTime" json:"rpa_lastupdate"`
}

func (ReferralPayoutAccount) TableName() string {
	return "ac_referral_payout_accounts"
}
