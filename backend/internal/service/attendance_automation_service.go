package service

import (
	"encoding/json"
	"github.com/google/uuid"
	"log"
	"sync"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/model"

	"gorm.io/gorm"
)

type AttendanceAutomationService struct {
	db *gorm.DB
	mu sync.Mutex
}

func NewAttendanceAutomationService(db *gorm.DB) *AttendanceAutomationService {
	return &AttendanceAutomationService{db: db}
}

func (s *AttendanceAutomationService) Start() {
	go func() {
		s.sweep()

		ticker := time.NewTicker(15 * time.Minute)
		defer ticker.Stop()

		for range ticker.C {
			s.sweep()
		}
	}()
}

func (s *AttendanceAutomationService) sweep() {
	s.mu.Lock()
	defer s.mu.Unlock()

	closeStaleOpenRecords(s.db, "")
	markAlfaRecords(s.db)
}

func attendanceShiftEndAt(
	workDate time.Time,
	cfg model.AttendanceConfiguration,
	shift AttendanceShift,
) time.Time {
	startHour, startMinute := cfg.StartHour, cfg.StartMinute
	endHour, endMinute := cfg.EndHour, cfg.EndMinute
	if shift.StartHour != nil {
		startHour = *shift.StartHour
	}
	if shift.StartMinute != nil {
		startMinute = *shift.StartMinute
	}
	if shift.EndHour != nil {
		endHour = *shift.EndHour
	}
	if shift.EndMinute != nil {
		endMinute = *shift.EndMinute
	}

	loc := workDate.Location()
	startAt := time.Date(
		workDate.Year(), workDate.Month(), workDate.Day(),
		startHour, startMinute, 0, 0, loc,
	)
	endAt := time.Date(
		workDate.Year(), workDate.Month(), workDate.Day(),
		endHour, endMinute, 0, 0, loc,
	)
	if !endAt.After(startAt) {
		endAt = endAt.AddDate(0, 0, 1)
	}
	return endAt
}

// markAlfaRecords membuat satu record ALFA untuk pegawai yang sudah ditugaskan
// ke shift, tidak memiliki absensi/izin pada hari ini, dan jam selesai shiftnya
// telah lewat. Record dibuat idempotent sehingga aman dijalankan berkala.
func markAlfaRecords(db *gorm.DB) {
	var configs []model.AttendanceConfiguration
	if err := db.Find(&configs).Error; err != nil {
		log.Printf("⚠️ attendance alfa: gagal mengambil konfigurasi: %v", err)
		return
	}
	for _, cfg := range configs {
		var outlet model.Outlet
		if err := db.Where("ot_id = ? AND ot_status = 1", cfg.OutletID).First(&outlet).Error; err != nil {
			continue
		}
		loc := outlet.GetLocation()
		now := time.Now().In(loc)
		var shifts []AttendanceShift
		if json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts) != nil {
			continue
		}
		// Backfill satu bulan terakhir agar hari yang terlewat sebelum scheduler
		// aktif juga muncul sebagai ALFA di riwayat kehadiran.
		for daysAgo := 0; daysAgo <= 31; daysAgo++ {
			workDate := time.Date(now.Year(), now.Month(), now.Day()-daysAgo, 0, 0, 0, 0, loc)
			if hasAttendanceHoliday(db, cfg.OutletID, workDate) {
				continue
			}
			for _, shift := range shifts {
				endAt := attendanceShiftEndAt(workDate, cfg, shift)
				if !now.After(endAt) {
					// Jadwal dapat diedit setelah scheduler sempat memakai jam lama.
					// Bersihkan ALFA tanpa check-in yang terlanjur dibuat sebelum
					// shift terbaru benar-benar selesai.
					if len(shift.EmployeeIDs) > 0 {
						db.Where(
							"atr_outlet = ? AND atr_employee IN ? AND atr_shift_name = ? AND atr_work_date = ? AND atr_status = ? AND atr_check_in_at IS NULL AND atr_check_out_at IS NULL",
							cfg.OutletID,
							shift.EmployeeIDs,
							shift.Name,
							workDate,
							"ALFA",
						).Delete(&model.AttendanceRecord{})
					}
					continue
				}
				for _, employeeID := range shift.EmployeeIDs {
					var employee model.Pegawai
					if db.Where("pg_id = ? AND pg_outlet = ? AND pg_status = 1 AND pg_deleted_at IS NULL", employeeID, cfg.OutletID).First(&employee).Error != nil {
						continue
					}
					// Karyawan baru tidak boleh mendapat ALFA sebelum tanggal
					// ditambahkan ke outlet.
					employeeStart := employee.CreatedAt.In(loc)
					employeeStartDate := time.Date(
						employeeStart.Year(),
						employeeStart.Month(),
						employeeStart.Day(),
						0, 0, 0, 0, loc,
					)
					if workDate.Before(employeeStartDate) {
						continue
					}
					var leave model.AttendanceLeave
					if db.Where("aal_outlet = ? AND aal_employee = ? AND aal_work_date = ? AND aal_status = ?", cfg.OutletID, employeeID, workDate, "APPROVED").First(&leave).Error == nil {
						continue
					}
					var existing model.AttendanceRecord
					if db.Where("atr_outlet = ? AND atr_employee = ? AND atr_work_date = ?", cfg.OutletID, employeeID, workDate).First(&existing).Error == nil {
						continue
					}
					record := model.AttendanceRecord{ID: uuid.NewString(), OutletID: cfg.OutletID, EmployeeID: employeeID, ShiftName: shift.Name, Status: "ALFA", WorkDate: workDate}
					if err := db.Create(&record).Error; err != nil {
						log.Printf("⚠️ attendance alfa: gagal membuat %s: %v", employeeID, err)
						continue
					}
					log.Printf("✅ attendance alfa: %s (%s) ditandai ALFA untuk %s", employeeID, cfg.OutletID, workDate.Format("2006-01-02"))
				}
			}
		}
	}
}

func hasAttendanceHoliday(db *gorm.DB, outletID string, date time.Time) bool {
	var holidays []model.AttendanceHoliday
	if db.Where("ath_outlet = ?", outletID).Find(&holidays).Error != nil {
		return false
	}
	weekday := int(date.Weekday())
	dateOnly := date.Format("2006-01-02")
	for _, h := range holidays {
		if h.HolidayDate != nil && h.HolidayDate.Format("2006-01-02") == dateOnly {
			return true
		}
		if h.Weekday != nil && *h.Weekday == weekday {
			return true
		}
	}
	return false
}

func closeStaleOpenRecords(db *gorm.DB, employeeID string) {
	q := db.Where("atr_check_in_at IS NOT NULL AND atr_check_out_at IS NULL")
	if employeeID != "" {
		q = q.Where("atr_employee = ?", employeeID)
	}

	var records []model.AttendanceRecord
	if err := q.Find(&records).Error; err != nil {
		log.Printf("⚠️ attendance auto-checkout: gagal ambil data: %v", err)
		return
	}

	outletCache := map[string]model.Outlet{}
	for _, rec := range records {
		if rec.CheckInAt == nil {
			continue
		}
		outlet, ok := outletCache[rec.OutletID]
		if !ok {
			if err := db.Where("ot_id = ?", rec.OutletID).First(&outlet).Error; err != nil {
				continue
			}
			outletCache[rec.OutletID] = outlet
		}
		loc := outlet.GetLocation()

		checkIn := rec.CheckInAt.In(loc)
		// Absensi yang lupa ditutup ditutup pada jam pulang shift, bukan
		// tengah malam. Dengan begitu riwayat tetap menunjukkan jam pulang
		// operasional yang sebenarnya, bukan 00:00.
		endHour, endMinute := shiftEndHour(db, rec.OutletID, rec.ShiftName)
		checkout := time.Date(checkIn.Year(), checkIn.Month(), checkIn.Day(), endHour, endMinute, 0, 0, loc)
		if !checkout.After(checkIn) {
			checkout = checkout.AddDate(0, 0, 1)
		}
		if time.Now().In(loc).Before(checkout) {
			continue
		}
		if err := db.Model(&model.AttendanceRecord{}).
			Where("atr_id = ?", rec.ID).
			Updates(map[string]any{
				"atr_check_out_at":     checkout,
				"atr_auto_checkout":    true,
				"atr_status":           "LUPA_ABSEN_PULANG",
				"atr_overtime_minutes": 0,
			}).Error; err != nil {
			log.Printf("⚠️ attendance auto-checkout: gagal tutup %s: %v", rec.ID, err)
			continue
		}
		log.Printf("✅ attendance auto-checkout: %s (%s) ditutup otomatis pada %s",
			rec.ID, rec.EmployeeID, checkout.Format("2006-01-02 15:04"))
	}
}

func shiftEndHour(db *gorm.DB, outletID, shiftName string) (int, int) {
	var cfg model.AttendanceConfiguration
	if err := db.Where("atc_outlet = ?", outletID).First(&cfg).Error; err != nil {
		return 17, 0
	}
	endH, endM := cfg.EndHour, cfg.EndMinute

	var shifts []AttendanceShift
	if json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts) == nil {
		for _, sh := range shifts {
			if sh.Name != shiftName {
				continue
			}
			if sh.EndHour != nil {
				endH = *sh.EndHour
			}
			if sh.EndMinute != nil {
				endM = *sh.EndMinute
			}
		}
	}
	if endH == 0 && endM == 0 {
		return 17, 0
	}
	return endH, endM
}
