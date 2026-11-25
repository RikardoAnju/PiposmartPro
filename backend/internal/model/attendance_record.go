package model

import (
	"encoding/json"
	"time"
)

// AttendanceRecord menyimpan bukti lokasi saat pegawai masuk dan pulang.
type AttendanceRecord struct {
	ID               string     `gorm:"column:atr_id;primaryKey;size:36" json:"id"`
	OutletID         string     `gorm:"column:atr_outlet;size:20;index;not null" json:"outlet_id"`
	EmployeeID       string     `gorm:"column:atr_employee;size:30;index;not null" json:"employee_id"`
	ShiftName        string     `gorm:"column:atr_shift_name;size:100;not null" json:"shift_name"`
	Status           string     `gorm:"column:atr_status;size:20;not null;default:HADIR" json:"status"`
	LateMinutes      int        `gorm:"column:atr_late_minutes;not null;default:0" json:"late_minutes"`
	OvertimeMinutes  int        `gorm:"column:atr_overtime_minutes;not null;default:0" json:"overtime_minutes"`
	WorkDate         time.Time  `gorm:"column:atr_work_date;type:date;index;not null" json:"work_date"`
	CheckInAt        *time.Time `gorm:"column:atr_check_in_at" json:"check_in_at"`
	CheckInLat       *float64   `gorm:"column:atr_check_in_lat" json:"check_in_lat"`
	CheckInLng       *float64   `gorm:"column:atr_check_in_lng" json:"check_in_lng"`
	CheckInDistance  *float64   `gorm:"column:atr_check_in_distance" json:"check_in_distance"`
	CheckOutAt       *time.Time `gorm:"column:atr_check_out_at" json:"check_out_at"`
	CheckOutLat      *float64   `gorm:"column:atr_check_out_lat" json:"check_out_lat"`
	CheckOutLng      *float64   `gorm:"column:atr_check_out_lng" json:"check_out_lng"`
	CheckOutDistance *float64   `gorm:"column:atr_check_out_distance" json:"check_out_distance"`
	AutoCheckout     bool       `gorm:"column:atr_auto_checkout;not null;default:false" json:"auto_checkout"`
	OutOfArea        bool       `gorm:"column:atr_out_of_area;not null;default:false" json:"out_of_area"`
	HolidayLabel     string     `gorm:"column:atr_holiday_label;size:120;not null;default:''" json:"holiday_label"`
	CreatedAt        time.Time  `gorm:"column:atr_created;autoCreateTime" json:"created_at"`
	UpdatedAt        *time.Time `gorm:"column:atr_lastupdate;autoUpdateTime" json:"updated_at"`
}

func (AttendanceRecord) TableName() string { return "ac_attendance_record" }

// MarshalJSON mengirim work_date sebagai tanggal murni (YYYY-MM-DD) agar klien
// tidak salah menghitung hari akibat offset timezone.
func (r AttendanceRecord) MarshalJSON() ([]byte, error) {
	type alias AttendanceRecord
	return json.Marshal(struct {
		alias
		WorkDate string `json:"work_date"`
	}{
		alias:    alias(r),
		WorkDate: r.WorkDate.Format("2006-01-02"),
	})
}
