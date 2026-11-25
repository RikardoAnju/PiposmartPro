package model

import "time"

const (
	FeatureRequestStatusSubmitted   = "SUBMITTED"
	FeatureRequestStatusUnderReview = "UNDER_REVIEW"
	FeatureRequestStatusInProgress  = "IN_PROGRESS"
	FeatureRequestStatusCompleted   = "COMPLETED"
	FeatureRequestStatusNotPlanned  = "NOT_PLANNED"
)

type FeatureRequest struct {
	ID            string     `gorm:"column:fr_id;primaryKey;size:36" json:"id"`
	OutletID      string     `gorm:"column:fr_outlet_id;size:20;index" json:"outlet_id"`
	CreatorID     string     `gorm:"column:fr_creator_id;size:50;not null" json:"creator_id"`
	CreatorType   string     `gorm:"column:fr_creator_type;size:20;not null" json:"creator_type"`
	CreatorName   string     `gorm:"column:fr_creator_name;size:160;not null" json:"creator_name"`
	Title         string     `gorm:"column:fr_title;size:160;not null" json:"title"`
	Description   string     `gorm:"column:fr_description;type:text;not null" json:"description"`
	Status        string     `gorm:"column:fr_status;size:24;not null;default:'SUBMITTED';index" json:"status"`
	AdminNote     string     `gorm:"column:fr_admin_note;type:text" json:"admin_note"`
	StatusUpdated *time.Time `gorm:"column:fr_status_updated_at" json:"status_updated_at,omitempty"`
	CreatedAt     time.Time  `gorm:"column:fr_created_at;autoCreateTime;index" json:"created_at"`
	UpdatedAt     time.Time  `gorm:"column:fr_updated_at;autoUpdateTime" json:"updated_at"`
}

func (FeatureRequest) TableName() string { return "ac_feature_requests" }

type FeatureRequestVote struct {
	ID               string    `gorm:"column:frv_id;primaryKey;size:36" json:"id"`
	FeatureRequestID string    `gorm:"column:frv_request_id;size:36;not null;uniqueIndex:uq_feature_request_voter,priority:1;index" json:"feature_request_id"`
	VoterID          string    `gorm:"column:frv_voter_id;size:50;not null;uniqueIndex:uq_feature_request_voter,priority:2" json:"voter_id"`
	VoterType        string    `gorm:"column:frv_voter_type;size:20;not null;uniqueIndex:uq_feature_request_voter,priority:3" json:"voter_type"`
	CreatedAt        time.Time `gorm:"column:frv_created_at;autoCreateTime" json:"created_at"`
}

func (FeatureRequestVote) TableName() string { return "ac_feature_request_votes" }

type FeatureRequestAttachment struct {
	ID               string    `gorm:"column:fra_id;primaryKey;size:36" json:"id"`
	FeatureRequestID string    `gorm:"column:fra_request_id;size:36;not null;index" json:"feature_request_id"`
	FileURL          string    `gorm:"column:fra_file_url;size:500;not null" json:"file_url"`
	CreatedAt        time.Time `gorm:"column:fra_created_at;autoCreateTime" json:"created_at"`
}

func (FeatureRequestAttachment) TableName() string { return "ac_feature_request_attachments" }
