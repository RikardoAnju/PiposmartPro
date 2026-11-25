package model

import "time"

// AttendanceOvertime adalah pengajuan lembur setelah absensi kerja ditutup.
type AttendanceOvertime struct {
	ID               string     `gorm:"column:aot_id;primaryKey;size:36" json:"id"`
	OutletID         string     `gorm:"column:aot_outlet;size:20;index;not null" json:"outlet_id"`
	EmployeeID       string     `gorm:"column:aot_employee;size:30;index;not null" json:"employee_id"`
	WorkDate         time.Time  `gorm:"column:aot_work_date;type:date;index;not null" json:"work_date"`
	StartAt          time.Time  `gorm:"column:aot_start_at;not null" json:"start_at"`
	EndAt            time.Time  `gorm:"column:aot_end_at;not null" json:"end_at"`
	RequestedMinutes int        `gorm:"column:aot_requested_minutes;not null" json:"requested_minutes"`
	ApprovedMinutes  int        `gorm:"column:aot_approved_minutes;not null;default:0" json:"approved_minutes"`
	Reason           string     `gorm:"column:aot_reason;size:500;not null" json:"reason"`
	Status           string     `gorm:"column:aot_status;size:20;index;not null;default:PENDING" json:"status"`
	DecidedBy        string     `gorm:"column:aot_decided_by;size:36" json:"decided_by"`
	DecidedAt        *time.Time `gorm:"column:aot_decided_at" json:"decided_at"`
	CreatedAt        time.Time  `gorm:"column:aot_created;autoCreateTime" json:"created_at"`
}

func (AttendanceOvertime) TableName() string { return "ac_attendance_overtime" }
