package model

import "time"

// AttendanceConfiguration menyimpan aturan absensi yang berlaku untuk satu outlet.
type AttendanceConfiguration struct {
	OutletID             string    `gorm:"column:atc_outlet;primaryKey;size:20" json:"outlet_id"`
	StartHour            int       `gorm:"column:atc_start_hour" json:"start_hour"`
	StartMinute          int       `gorm:"column:atc_start_minute" json:"start_minute"`
	EndHour              int       `gorm:"column:atc_end_hour" json:"end_hour"`
	EndMinute            int       `gorm:"column:atc_end_minute" json:"end_minute"`
	LateToleranceMinutes int       `gorm:"column:atc_late_tolerance_minutes;not null;default:0" json:"late_tolerance_minutes"`
	AutoApproveLeave     bool      `gorm:"column:atc_auto_approve_leave;default:false" json:"auto_approve_leave"`
	ShiftsJSON           string    `gorm:"column:atc_shifts_json;type:longtext" json:"-"`
	UpdatedAt            time.Time `gorm:"column:atc_lastupdate;autoUpdateTime" json:"updated_at"`
}

func (AttendanceConfiguration) TableName() string { return "ac_attendance_configuration" }
