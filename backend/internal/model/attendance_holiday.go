package model

import (
	"encoding/json"
	"time"
)

// AttendanceHoliday menyimpan hari libur sebuah outlet. Satu baris mewakili salah
// satu dari:
//   - libur mingguan berulang  -> Weekday diisi (0=Minggu ... 6=Sabtu), HolidayDate nil
//   - tanggal libur spesifik   -> HolidayDate diisi, Weekday nil
type AttendanceHoliday struct {
	ID          string     `gorm:"column:ath_id;primaryKey;size:36" json:"id"`
	OutletID    string     `gorm:"column:ath_outlet;size:20;index;not null" json:"outlet_id"`
	HolidayDate *time.Time `gorm:"column:ath_date;type:date;index" json:"date"`
	Weekday     *int       `gorm:"column:ath_weekday" json:"weekday"`
	Label       string     `gorm:"column:ath_label;size:120;not null" json:"label"`
	CreatedAt   time.Time  `gorm:"column:ath_created;autoCreateTime" json:"created_at"`
}

func (AttendanceHoliday) TableName() string { return "ac_attendance_holiday" }

// MarshalJSON mengirim date sebagai tanggal murni (YYYY-MM-DD) atau null.
func (h AttendanceHoliday) MarshalJSON() ([]byte, error) {
	type alias AttendanceHoliday
	var date *string
	if h.HolidayDate != nil {
		s := h.HolidayDate.Format("2006-01-02")
		date = &s
	}
	return json.Marshal(struct {
		alias
		HolidayDate *string `json:"date"`
	}{
		alias:       alias(h),
		HolidayDate: date,
	})
}
