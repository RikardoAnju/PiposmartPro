package model

import (
	"encoding/json"
	"time"
)

type AttendanceLeave struct {
	ID           string     `gorm:"column:aal_id;primaryKey;size:36" json:"id"`
	OutletID     string     `gorm:"column:aal_outlet;size:20;index;not null" json:"outlet_id"`
	EmployeeID   string     `gorm:"column:aal_employee;size:30;index;not null" json:"employee_id"`
	WorkDate     time.Time  `gorm:"column:aal_work_date;type:date;index;not null" json:"work_date"`
	LeaveType    string     `gorm:"column:aal_type;size:50;not null" json:"leave_type"`
	Reason       string     `gorm:"column:aal_reason;type:text;not null" json:"reason"`
	Status       string     `gorm:"column:aal_status;size:20;not null;default:PENDING" json:"status"`
	RejectReason string     `gorm:"column:aal_reject_reason;type:text;not null" json:"reject_reason"`
	DecidedBy    string     `gorm:"column:aal_decided_by;size:30;not null;default:''" json:"decided_by"`
	DecidedAt    *time.Time `gorm:"column:aal_decided_at" json:"decided_at"`
	CreatedAt    time.Time  `gorm:"column:aal_created;autoCreateTime" json:"created_at"`
}

func (AttendanceLeave) TableName() string { return "ac_attendance_leave" }

// MarshalJSON mengirim work_date sebagai tanggal murni (YYYY-MM-DD).
func (l AttendanceLeave) MarshalJSON() ([]byte, error) {
	type alias AttendanceLeave
	return json.Marshal(struct {
		alias
		WorkDate string `json:"work_date"`
	}{
		alias:    alias(l),
		WorkDate: l.WorkDate.Format("2006-01-02"),
	})
}
