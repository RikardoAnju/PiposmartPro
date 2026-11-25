package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AttendanceService struct{ db *gorm.DB }

func NewAttendanceService(db *gorm.DB) *AttendanceService { return &AttendanceService{db: db} }

type AttendanceConfigInput struct {
	IsConfigured         *bool             `json:"is_configured"`
	StartHour            int               `json:"start_hour"`
	StartMinute          int               `json:"start_minute"`
	EndHour              int               `json:"end_hour"`
	EndMinute            int               `json:"end_minute"`
	LateToleranceMinutes int               `json:"late_tolerance_minutes"`
	AutoApproveLeave     bool              `json:"auto_approve_leave"`
	Shifts               []AttendanceShift `json:"shifts"`
}

type AttendanceShift struct {
	Name             string   `json:"name"`
	AutoApproveLeave *bool    `json:"auto_approve_leave,omitempty"`
	EmployeeIDs      []string `json:"employee_ids,omitempty"`
	StartHour        *int     `json:"start_hour,omitempty"`
	StartMinute      *int     `json:"start_minute,omitempty"`
	EndHour          *int     `json:"end_hour,omitempty"`
	EndMinute        *int     `json:"end_minute,omitempty"`
}

func validTime(h, m int) bool { return h >= 0 && h <= 23 && m >= 0 && m <= 59 }
func (s *AttendanceService) Get(outletID string) (map[string]any, error) {
	var cfg model.AttendanceConfiguration
	if err := s.db.Where("atc_outlet = ?", outletID).First(&cfg).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return map[string]any{"is_configured": false}, nil
		}
		return nil, err
	}
	var shifts []AttendanceShift
	_ = json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts)
	for i := range shifts {
		if shifts[i].StartHour == nil {
			shifts[i].StartHour = &cfg.StartHour
			shifts[i].StartMinute = &cfg.StartMinute
			shifts[i].EndHour = &cfg.EndHour
			shifts[i].EndMinute = &cfg.EndMinute
		}
		if shifts[i].AutoApproveLeave == nil {
			shifts[i].AutoApproveLeave = &cfg.AutoApproveLeave
		}
	}
	return map[string]any{"is_configured": true, "start_hour": cfg.StartHour, "start_minute": cfg.StartMinute, "end_hour": cfg.EndHour, "end_minute": cfg.EndMinute, "late_tolerance_minutes": cfg.LateToleranceMinutes, "auto_approve_leave": cfg.AutoApproveLeave, "shifts": shifts}, nil
}
func (s *AttendanceService) Save(outletID string, in AttendanceConfigInput) (map[string]any, error) {
	if in.IsConfigured != nil && !*in.IsConfigured {
		if err := s.db.Where("atc_outlet = ?", outletID).Delete(&model.AttendanceConfiguration{}).Error; err != nil {
			return nil, err
		}
		return map[string]any{"is_configured": false}, nil
	}
	if !validTime(in.StartHour, in.StartMinute) || !validTime(in.EndHour, in.EndMinute) {
		return nil, errors.New("jam absensi tidak valid")
	}
	if in.LateToleranceMinutes < 0 || in.LateToleranceMinutes > 180 {
		return nil, errors.New("toleransi keterlambatan harus antara 0 sampai 180 menit")
	}
	if len(in.Shifts) == 0 {
		return nil, errors.New("minimal satu shift harus dipilih")
	}
	// Older clients did not send employee_ids when editing a shift. Preserve
	// existing assignments in that case; an explicit empty array still means
	// the owner intentionally removed all employees from the shift.
	var existingConfig model.AttendanceConfiguration
	if err := s.db.Where("atc_outlet = ?", outletID).First(&existingConfig).Error; err == nil {
		var existingShifts []AttendanceShift
		if json.Unmarshal([]byte(existingConfig.ShiftsJSON), &existingShifts) == nil {
			assignedByName := make(map[string][]string, len(existingShifts))
			for _, shift := range existingShifts {
				assignedByName[shift.Name] = shift.EmployeeIDs
			}
			for i := range in.Shifts {
				if in.Shifts[i].EmployeeIDs == nil {
					in.Shifts[i].EmployeeIDs = assignedByName[in.Shifts[i].Name]
				}
			}
		}
	}
	for _, shift := range in.Shifts {
		if shift.Name == "" {
			return nil, errors.New("jadwal shift tidak valid")
		}
	}
	for i := range in.Shifts {
		if in.Shifts[i].AutoApproveLeave == nil {
			value := in.AutoApproveLeave
			in.Shifts[i].AutoApproveLeave = &value
		}
		if in.Shifts[i].StartHour == nil || in.Shifts[i].StartMinute == nil ||
			in.Shifts[i].EndHour == nil || in.Shifts[i].EndMinute == nil {
			in.Shifts[i].StartHour = &in.StartHour
			in.Shifts[i].StartMinute = &in.StartMinute
			in.Shifts[i].EndHour = &in.EndHour
			in.Shifts[i].EndMinute = &in.EndMinute
		}
		if !validTime(*in.Shifts[i].StartHour, *in.Shifts[i].StartMinute) ||
			!validTime(*in.Shifts[i].EndHour, *in.Shifts[i].EndMinute) {
			return nil, errors.New("jam shift tidak valid")
		}
	}
	seenShifts := make(map[string]struct{}, len(in.Shifts))
	// Satu karyawan boleh ditugaskan ke lebih dari satu shift. Ini diperlukan
	// untuk pola kerja rolling (misalnya pagi pada hari tertentu dan malam
	// pada hari lain). Gunakan set hanya untuk memvalidasi karyawan unik.
	assignedEmployees := make(map[string]struct{})
	for _, shift := range in.Shifts {
		if _, exists := seenShifts[shift.Name]; exists {
			return nil, errors.New("shift yang sama tidak boleh ditambahkan")
		}
		seenShifts[shift.Name] = struct{}{}
		for _, employeeID := range shift.EmployeeIDs {
			if employeeID != "" {
				assignedEmployees[employeeID] = struct{}{}
			}
		}
	}
	if len(assignedEmployees) > 0 {
		var employeeCount int64
		if err := s.db.Model(&model.Pegawai{}).
			Where("pg_outlet = ? AND pg_status = 1 AND pg_deleted_at IS NULL AND pg_id IN ?", outletID, keys(assignedEmployees)).
			Count(&employeeCount).Error; err != nil {
			return nil, err
		}
		if employeeCount != int64(len(assignedEmployees)) {
			return nil, errors.New("karyawan tidak valid untuk outlet ini")
		}
	}
	// The outlet hours cover the earliest start and latest end of all shifts.
	startHour, startMinute := *in.Shifts[0].StartHour, *in.Shifts[0].StartMinute
	endHour, endMinute := *in.Shifts[0].EndHour, *in.Shifts[0].EndMinute
	for _, shift := range in.Shifts[1:] {
		if *shift.StartHour*60+*shift.StartMinute < startHour*60+startMinute {
			startHour, startMinute = *shift.StartHour, *shift.StartMinute
		}
		if *shift.EndHour*60+*shift.EndMinute > endHour*60+endMinute {
			endHour, endMinute = *shift.EndHour, *shift.EndMinute
		}
	}
	in.StartHour, in.StartMinute = startHour, startMinute
	in.EndHour, in.EndMinute = endHour, endMinute
	shifts, _ := json.Marshal(in.Shifts)
	cfg := model.AttendanceConfiguration{OutletID: outletID, StartHour: in.StartHour, StartMinute: in.StartMinute, EndHour: in.EndHour, EndMinute: in.EndMinute, LateToleranceMinutes: in.LateToleranceMinutes, AutoApproveLeave: in.AutoApproveLeave, ShiftsJSON: string(shifts)}
	err := s.db.Where("atc_outlet = ?", outletID).Assign(cfg).FirstOrCreate(&cfg).Error
	if err != nil {
		return nil, err
	}
	removePrematureAlfaRecords(s.db, outletID, in.Shifts)
	return s.Get(outletID)
}

// removePrematureAlfaRecords menghapus Alfa hari ini yang terlanjur dibuat
// sebelum jam masuk, misalnya ketika owner mengubah shift menjadi 22.00–17.00
// setelah scheduler sempat membaca konfigurasi lama.
func removePrematureAlfaRecords(db *gorm.DB, outletID string, shifts []AttendanceShift) {
	var outlet model.Outlet
	if err := db.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return
	}
	loc := outlet.GetLocation()
	now := time.Now().In(loc)
	workDate := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)

	for _, shift := range shifts {
		if len(shift.EmployeeIDs) == 0 || shift.StartHour == nil || shift.StartMinute == nil {
			continue
		}
		startAt := time.Date(
			now.Year(), now.Month(), now.Day(),
			*shift.StartHour, *shift.StartMinute, 0, 0, loc,
		)
		if !now.Before(startAt) {
			continue
		}
		db.Where(
			"atr_outlet = ? AND atr_work_date = ? AND atr_status = ? AND atr_employee IN ?",
			outletID, workDate, "ALFA", shift.EmployeeIDs,
		).Delete(&model.AttendanceRecord{})
	}
}

func keys(values map[string]struct{}) []string {
	result := make([]string, 0, len(values))
	for key := range values {
		result = append(result, key)
	}
	return result
}

type AttendanceLocationInput struct {
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
}

type AttendanceLeaveInput struct {
	WorkDate     string `json:"work_date" binding:"required"`
	LeaveType    string `json:"leave_type"`
	Reason       string `json:"reason" binding:"required"`
	DurationDays int    `json:"duration_days"`
}

type AttendanceOvertimeInput struct {
	WorkDate string `json:"work_date" binding:"required"`
	StartAt  string `json:"start_at" binding:"required"`
	EndAt    string `json:"end_at" binding:"required"`
	Reason   string `json:"reason" binding:"required"`
}

type AttendanceOvertimeDecisionInput struct {
	Status          string `json:"status" binding:"required"`
	ApprovedMinutes int    `json:"approved_minutes"`
}

func (s *AttendanceService) RequestOvertime(outletID, employeeID string, in AttendanceOvertimeInput) (model.AttendanceOvertime, error) {
	var outlet model.Outlet
	if err := s.db.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return model.AttendanceOvertime{}, errors.New("outlet tidak ditemukan")
	}
	// Work date adalah tanggal lokal outlet, bukan UTC. Ini penting agar
	// pengajuan lembur menemukan record absensi pada hari yang sama.
	workDate, err := time.ParseInLocation("2006-01-02", in.WorkDate, outlet.GetLocation())
	if err != nil || strings.TrimSpace(in.Reason) == "" {
		return model.AttendanceOvertime{}, errors.New("data lembur tidak valid")
	}
	start, err1 := time.Parse(time.RFC3339, in.StartAt)
	end, err2 := time.Parse(time.RFC3339, in.EndAt)
	if err1 != nil || err2 != nil || !end.After(start) {
		return model.AttendanceOvertime{}, errors.New("waktu lembur tidak valid")
	}
	minutes := int(end.Sub(start).Minutes())
	if minutes < 1 || minutes > 720 {
		return model.AttendanceOvertime{}, errors.New("durasi lembur harus 1 sampai 720 menit")
	}
	var record model.AttendanceRecord
	if err := s.db.Where("atr_outlet = ? AND atr_employee = ? AND atr_work_date = ?", outletID, employeeID, workDate).First(&record).Error; err != nil || record.CheckInAt == nil {
		return model.AttendanceOvertime{}, errors.New("absensi kerja untuk tanggal tersebut tidak ditemukan")
	}
	var pending int64
	s.db.Model(&model.AttendanceOvertime{}).Where("aot_outlet = ? AND aot_employee = ? AND aot_work_date = ? AND aot_status IN ?", outletID, employeeID, workDate, []string{"PENDING", "APPROVED"}).Count(&pending)
	if pending > 0 {
		return model.AttendanceOvertime{}, errors.New("sudah ada pengajuan lembur aktif untuk tanggal tersebut")
	}
	o := model.AttendanceOvertime{ID: uuid.NewString(), OutletID: outletID, EmployeeID: employeeID, WorkDate: workDate, StartAt: start, EndAt: end, RequestedMinutes: minutes, Reason: strings.TrimSpace(in.Reason), Status: "PENDING"}
	return o, s.db.Create(&o).Error
}

func (s *AttendanceService) OvertimeRequests(outletID, employeeID, status string, limit, offset int) ([]model.AttendanceOvertime, bool, error) {
	q := s.db.Where("aot_outlet = ?", outletID).Order("aot_work_date DESC, aot_created DESC")
	if employeeID != "" {
		q = q.Where("aot_employee = ?", employeeID)
	}
	if strings.TrimSpace(status) != "" {
		q = q.Where("aot_status = ?", strings.ToUpper(strings.TrimSpace(status)))
	}
	var rows []model.AttendanceOvertime
	if limit > 50 {
		limit = 50
	}
	if limit > 0 {
		err := q.Offset(offset).Limit(limit + 1).Find(&rows).Error
		more := len(rows) > limit
		if more {
			rows = rows[:limit]
		}
		return rows, more, err
	}
	return rows, false, q.Find(&rows).Error
}

func (s *AttendanceService) DecideOvertime(outletID, overtimeID, decidedBy string, in AttendanceOvertimeDecisionInput) (model.AttendanceOvertime, error) {
	status := strings.ToUpper(strings.TrimSpace(in.Status))
	if status != "APPROVED" && status != "REJECTED" {
		return model.AttendanceOvertime{}, errors.New("status lembur harus APPROVED atau REJECTED")
	}
	var o model.AttendanceOvertime
	if err := s.db.Where("aot_id = ? AND aot_outlet = ?", overtimeID, outletID).First(&o).Error; err != nil {
		return o, errors.New("pengajuan lembur tidak ditemukan")
	}
	if o.Status != "PENDING" {
		return o, errors.New("pengajuan lembur sudah diproses")
	}
	approved := 0
	if status == "APPROVED" {
		approved = in.ApprovedMinutes
		if approved <= 0 {
			approved = o.RequestedMinutes
		}
		if approved > o.RequestedMinutes {
			approved = o.RequestedMinutes
		}
	}
	now := time.Now()
	updates := map[string]any{"aot_status": status, "aot_approved_minutes": approved, "aot_decided_by": decidedBy, "aot_decided_at": &now}
	tx := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&model.AttendanceOvertime{}).Where("aot_id = ?", o.ID).Updates(updates).Error; err != nil {
			return err
		}
		if status == "APPROVED" {
			return tx.Model(&model.AttendanceRecord{}).Where("atr_outlet = ? AND atr_employee = ? AND atr_work_date = ?", outletID, o.EmployeeID, o.WorkDate).Update("atr_overtime_minutes", approved).Error
		}
		return nil
	})
	if tx != nil {
		return o, tx
	}
	_ = s.db.Where("aot_id = ?", o.ID).First(&o).Error
	return o, nil
}

func (s *AttendanceService) RequestLeave(outletID, employeeID string, in AttendanceLeaveInput) (model.AttendanceLeave, error) {
	var outlet model.Outlet
	if err := s.db.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return model.AttendanceLeave{}, errors.New("outlet tidak ditemukan")
	}
	if outlet.Latitude == nil || outlet.Longitude == nil {
		return model.AttendanceLeave{}, errors.New("pengajuan izin belum dapat dilakukan: zonasi lokasi absensi belum diatur oleh owner")
	}
	var attendanceConfig model.AttendanceConfiguration
	if err := s.db.Where("atc_outlet = ?", outletID).First(&attendanceConfig).Error; err != nil || strings.TrimSpace(attendanceConfig.ShiftsJSON) == "" {
		return model.AttendanceLeave{}, errors.New("pengajuan izin belum dapat dilakukan: pengaturan absensi outlet belum selesai")
	}
	date, err := time.Parse("2006-01-02", in.WorkDate)
	if err != nil || strings.TrimSpace(in.Reason) == "" {
		return model.AttendanceLeave{}, errors.New("tanggal atau alasan izin tidak valid")
	}
	if in.DurationDays < 1 {
		in.DurationDays = 1
	}
	if in.DurationDays > 31 {
		return model.AttendanceLeave{}, errors.New("durasi izin maksimal 31 hari")
	}
	status := "PENDING"
	if s.leaveAutoApproved(outletID, employeeID) {
		status = "APPROVED"
	}
	leave := model.AttendanceLeave{}
	for index := 0; index < in.DurationDays; index++ {
		currentDate := date.AddDate(0, 0, index)
		leave = model.AttendanceLeave{ID: uuid.NewString(), OutletID: outletID, EmployeeID: employeeID, WorkDate: currentDate, LeaveType: in.LeaveType, Reason: strings.TrimSpace(in.Reason), Status: status}
		if err := s.db.Create(&leave).Error; err != nil {
			return leave, err
		}
	}
	return leave, nil
}

// leaveAutoApproved mengembalikan true bila outlet (atau shift pegawai) menyalakan
// opsi "Setujui Izin Otomatis".
func (s *AttendanceService) leaveAutoApproved(outletID, employeeID string) bool {
	var cfg model.AttendanceConfiguration
	if err := s.db.Where("atc_outlet = ?", outletID).First(&cfg).Error; err != nil {
		return false
	}
	auto := cfg.AutoApproveLeave
	var shifts []AttendanceShift
	if json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts) == nil {
		for _, sh := range shifts {
			if sh.AutoApproveLeave == nil {
				continue
			}
			for _, id := range sh.EmployeeIDs {
				if id == employeeID {
					auto = *sh.AutoApproveLeave
				}
			}
		}
	}
	return auto
}

type AttendanceLeaveDecisionInput struct {
	Status string `json:"status" binding:"required"`
	Reason string `json:"reason"`
}

// UpdateLeaveStatus dipakai owner untuk menyetujui / menolak / membatalkan
// keputusan atas satu pengajuan izin.
func (s *AttendanceService) UpdateLeaveStatus(outletID, leaveID, decidedBy string, in AttendanceLeaveDecisionInput) (model.AttendanceLeave, error) {
	status := strings.ToUpper(strings.TrimSpace(in.Status))
	switch status {
	case "APPROVED", "REJECTED", "PENDING":
	default:
		return model.AttendanceLeave{}, errors.New("status izin tidak valid")
	}

	var leave model.AttendanceLeave
	if err := s.db.Where("aal_id = ? AND aal_outlet = ?", leaveID, outletID).First(&leave).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return leave, errors.New("pengajuan izin tidak ditemukan")
		}
		return leave, err
	}

	if leave.Status == "APPROVED" && status != "APPROVED" {
		return leave, errors.New("izin yang sudah disetujui tidak dapat dibatalkan")
	}

	updates := map[string]any{"aal_status": status}
	if status == "REJECTED" {
		if strings.TrimSpace(in.Reason) == "" {
			return leave, errors.New("alasan penolakan wajib diisi")
		}
		updates["aal_reject_reason"] = strings.TrimSpace(in.Reason)
	} else {
		updates["aal_reject_reason"] = ""
	}
	if status == "PENDING" {
		updates["aal_decided_by"] = ""
		updates["aal_decided_at"] = nil
	} else {
		now := time.Now()
		updates["aal_decided_by"] = decidedBy
		updates["aal_decided_at"] = &now
	}

	if err := s.db.Model(&model.AttendanceLeave{}).Where("aal_id = ?", leaveID).Updates(updates).Error; err != nil {
		return leave, err
	}
	_ = s.db.Where("aal_id = ?", leaveID).First(&leave).Error
	return leave, nil
}

func (s *AttendanceService) LeaveRequests(outletID, employeeID, month string, limit, offset int) ([]model.AttendanceLeave, bool, error) {
	query := s.db.Where("aal_outlet = ?", outletID).Order("aal_work_date DESC, aal_created DESC")
	if employeeID != "" {
		query = query.Where("aal_employee = ?", employeeID)
	}
	if strings.TrimSpace(month) != "" {
		start, err := time.Parse("2006-01", month)
		if err != nil {
			return nil, false, errors.New("format bulan harus YYYY-MM")
		}
		query = query.Where("aal_work_date >= ? AND aal_work_date < ?", start, start.AddDate(0, 1, 0))
	}
	var requests []model.AttendanceLeave
	if limit > 0 {
		if limit > 50 {
			limit = 50
		}
		err := query.Offset(offset).Limit(limit + 1).Find(&requests).Error
		hasMore := len(requests) > limit
		if hasMore {
			requests = requests[:limit]
		}
		return requests, hasMore, err
	}
	return requests, false, query.Find(&requests).Error
}

func validCoordinates(latitude, longitude float64) bool {
	return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
}

func distanceMeters(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadius = 6371000.0
	latDelta := (lat2 - lat1) * math.Pi / 180
	lonDelta := (lon2 - lon1) * math.Pi / 180
	a := math.Sin(latDelta/2)*math.Sin(latDelta/2) +
		math.Cos(lat1*math.Pi/180)*math.Cos(lat2*math.Pi/180)*
			math.Sin(lonDelta/2)*math.Sin(lonDelta/2)
	return earthRadius * 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
}

// validateOutletProximity memastikan koordinat valid dan pegawai aktif, lalu
// menghitung jarak ke outlet. Tidak memeriksa jendela jam shift.
// Jika enforceRadius true, mengembalikan error saat di luar radius; jika false,
// tetap lolos tetapi mengembalikan insideRadius=false (dipakai untuk absen pulang
// ketika pegawai lupa dan sudah meninggalkan lokasi).
func (s *AttendanceService) validateOutletProximity(outletID, employeeID string, latitude, longitude float64, enforceRadius bool) (model.Outlet, float64, bool, error) {
	if !validCoordinates(latitude, longitude) {
		return model.Outlet{}, 0, false, errors.New("koordinat lokasi tidak valid")
	}
	var outlet model.Outlet
	if err := s.db.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return outlet, 0, false, errors.New("outlet tidak ditemukan")
	}
	if outlet.Latitude == nil || outlet.Longitude == nil {
		return outlet, 0, false, errors.New("lokasi outlet belum diatur oleh owner")
	}
	var employee model.Pegawai
	if err := s.db.Where("pg_id = ? AND pg_outlet = ? AND pg_status = 1 AND pg_deleted_at IS NULL", employeeID, outletID).First(&employee).Error; err != nil {
		return outlet, 0, false, errors.New("pegawai tidak aktif atau bukan bagian dari outlet ini")
	}
	distance := distanceMeters(*outlet.Latitude, *outlet.Longitude, latitude, longitude)
	radius := outlet.LocationRadius
	if radius <= 0 {
		radius = 5
	}
	// GPS ponsel dapat memiliki deviasi beberapa meter walaupun pegawai
	// berada di lokasi yang sama. Beri toleransi 10 meter di luar radius
	// konfigurasi agar tidak salah menandai lokasi sebagai di luar area.
	insideRadius := distance <= float64(radius+10)
	if enforceRadius && !insideRadius {
		return outlet, distance, false, fmt.Errorf("lokasi di luar radius outlet (%.0f meter, batas %d meter)", distance, radius)
	}
	return outlet, distance, insideRadius, nil
}

// validateEmployeeLocation memvalidasi lokasi lalu menentukan shift pegawai.
// Bila ignoreShiftWindow true (mis. hari libur / lembur), shift yang di-assign
// tetap dipakai walau di luar jam shift.
func (s *AttendanceService) validateEmployeeLocation(outletID, employeeID string, latitude, longitude float64, ignoreShiftWindow bool) (model.Outlet, string, float64, error) {
	outlet, distance, _, err := s.validateOutletProximity(outletID, employeeID, latitude, longitude, true)
	if err != nil {
		return outlet, "", distance, err
	}
	var cfg model.AttendanceConfiguration
	if err := s.db.Where("atc_outlet = ?", outletID).First(&cfg).Error; err != nil {
		return outlet, "", 0, errors.New("konfigurasi absensi belum diatur")
	}
	var shifts []AttendanceShift
	if err := json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts); err != nil {
		return outlet, "", 0, errors.New("konfigurasi shift tidak valid")
	}
	now := time.Now().In(outlet.GetLocation())
	minutes := now.Hour()*60 + now.Minute()
	shiftName := ""
	assignedShift := ""
	assignedStart, assignedEnd := 0, 0
	upcomingShift := ""
	upcomingStart, upcomingEnd := 0, 0
	upcomingDelta := 24 * 60
	for _, shift := range shifts {
		for _, assignedID := range shift.EmployeeIDs {
			if assignedID != employeeID {
				continue
			}
			assignedShift = shift.Name
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
			start, end := startHour*60+startMinute, endHour*60+endMinute
			assignedStart, assignedEnd = start, end
			// Jika pegawai datang sebelum beberapa shift yang ditugaskan,
			// pilih shift dengan jam mulai paling dekat, bukan shift terakhir
			// di JSON (yang bisa saja Shift Malam).
			if start <= end && minutes < start {
				delta := start - minutes
				if delta < upcomingDelta {
					upcomingShift, upcomingStart, upcomingEnd, upcomingDelta = shift.Name, start, end, delta
				}
			}
			// Jam selesai menjadi batas akhir absen masuk. Setelah shift
			// selesai, pegawai tidak boleh membuat absen masuk baru.
			// Untuk shift malam, rentang tetap melewati tengah malam.
			// Untuk shift siang, pegawai boleh check-in lebih awal dari jam
			// masuk selama belum melewati jam pulang. Kedatangan lebih awal
			// tetap dihitung HADIR, bukan TERLAMBAT.
			inShift := (start <= end && minutes <= end) ||
				(start > end && (minutes >= start || minutes <= end))
			if inShift {
				shiftName = shift.Name
			}
		}
	}
	if shiftName == "" && ignoreShiftWindow {
		shiftName = assignedShift
	}
	if shiftName == "" && upcomingShift != "" && minutes <= upcomingEnd {
		shiftName = upcomingShift
		assignedShift, assignedStart, assignedEnd = upcomingShift, upcomingStart, upcomingEnd
	}
	if shiftName == "" {
		if assignedShift != "" && assignedStart <= assignedEnd {
			if minutes > assignedEnd {
				return outlet, "", distance, fmt.Errorf("jadwal absensi %s sudah berakhir pada pukul %02d.%02d", assignedShift, assignedEnd/60, assignedEnd%60)
			}
		}
		return outlet, "", distance, errors.New("pegawai tidak sedang berada pada jam shift")
	}
	return outlet, shiftName, distance, nil
}

func (s *AttendanceService) CheckIn(outletID, employeeID string, in AttendanceLocationInput) (model.AttendanceRecord, error) {
	now := time.Now()
	var outlet model.Outlet
	if err := s.db.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return model.AttendanceRecord{}, errors.New("outlet tidak ditemukan")
	}
	localNow := now.In(outlet.GetLocation())

	// Hari libur: pegawai boleh absen kapan pun (dihitung lembur), jadi jendela
	// jam shift tidak dipaksakan.
	holidayLabel := s.holidayLabelFor(outletID, localNow)

	_, shiftName, distance, err := s.validateEmployeeLocation(outletID, employeeID, in.Latitude, in.Longitude, holidayLabel != "")
	if err != nil {
		return model.AttendanceRecord{}, err
	}
	// Jika pegawai lupa absen pulang di hari sebelumnya, tutup dulu record lama itu
	// agar tidak menggantung saat absen masuk hari ini dibuat.
	closeStaleOpenRecords(s.db, employeeID)
	workDate := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, outlet.GetLocation())
	var existing model.AttendanceRecord
	err = s.db.Where("atr_outlet = ? AND atr_employee = ? AND atr_work_date = ?", outletID, employeeID, workDate).First(&existing).Error
	if err == nil && existing.CheckInAt != nil {
		return existing, errors.New("pegawai sudah melakukan absen masuk hari ini")
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return existing, err
	}
	checkInLat, checkInLng, checkInDistance := in.Latitude, in.Longitude, distance
	status, lateMinutes := "HADIR", 0

	// Hari libur memiliki status tersendiri; lembur hanya untuk lewat jam shift.
	if holidayLabel != "" {
		status = "KERJA_HARI_LIBUR"
	} else {
		var cfg model.AttendanceConfiguration
		if s.db.Where("atc_outlet = ?", outletID).First(&cfg).Error == nil {
			var shifts []AttendanceShift
			_ = json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts)
			for _, shift := range shifts {
				if shift.Name != shiftName || shift.StartHour == nil || shift.StartMinute == nil {
					continue
				}
				start := *shift.StartHour*60 + *shift.StartMinute
				current := localNow.Hour()*60 + localNow.Minute()
				if current > start+cfg.LateToleranceMinutes {
					status = "TERLAMBAT"
					lateMinutes = current - start
				}
			}
		}
	}
	record := model.AttendanceRecord{ID: uuid.NewString(), OutletID: outletID, EmployeeID: employeeID, ShiftName: shiftName, Status: status, LateMinutes: lateMinutes, WorkDate: workDate, CheckInAt: &now, CheckInLat: &checkInLat, CheckInLng: &checkInLng, CheckInDistance: &checkInDistance, HolidayLabel: holidayLabel}
	if err == nil {
		record.ID = existing.ID
		record.CreatedAt = existing.CreatedAt
	}
	if dbErr := s.db.Save(&record).Error; dbErr != nil {
		return record, dbErr
	}
	return record, nil
}

func (s *AttendanceService) CheckOut(outletID, employeeID string, in AttendanceLocationInput) (model.AttendanceRecord, error) {
	// Absen pulang tidak menolak lokasi di luar radius: pegawai yang lupa absen
	// dan sudah di rumah tetap bisa menutup absensinya, hanya ditandai out_of_area
	// agar owner dapat meninjau.
	// Check-out normal wajib dilakukan di outlet. Lupa check-out ditutup
	// otomatis pada akhir shift oleh scheduler tanpa lembur.
	_, distance, _, err := s.validateOutletProximity(outletID, employeeID, in.Latitude, in.Longitude, true)
	if err != nil {
		return model.AttendanceRecord{}, err
	}
	var record model.AttendanceRecord
	approvedOvertimeMinutes := 0
	hasApprovedOvertime := false
	if err := s.db.Where("atr_outlet = ? AND atr_employee = ? AND atr_check_in_at IS NOT NULL AND atr_check_out_at IS NULL", outletID, employeeID).Order("atr_work_date DESC").First(&record).Error; err != nil {
		// Absensi reguler mungkin sudah ditutup otomatis pada jam selesai shift.
		// Selama masih ada pengajuan lembur yang berjalan, pegawai tetap boleh
		// melakukan check-out setelah lembur selesai.
		var overtime model.AttendanceOvertime
		if overtimeErr := s.db.Where("aot_outlet = ? AND aot_employee = ? AND aot_status IN ? AND aot_start_at <= ? AND aot_end_at >= ?", outletID, employeeID, []string{"PENDING", "APPROVED"}, time.Now(), time.Now()).Order("aot_work_date DESC, aot_created DESC").First(&overtime).Error; overtimeErr != nil {
			return record, errors.New("belum ada absen masuk yang aktif atau lembur yang berjalan")
		}
		if overtimeErr := s.db.Where("atr_outlet = ? AND atr_employee = ? AND atr_work_date = ? AND atr_check_in_at IS NOT NULL", outletID, employeeID, overtime.WorkDate).First(&record).Error; overtimeErr != nil {
			return record, errors.New("absensi kerja untuk lembur tidak ditemukan")
		}
	}
	var approvedOvertime model.AttendanceOvertime
	if err := s.db.Where("aot_outlet = ? AND aot_employee = ? AND aot_work_date = ? AND aot_status = ?", outletID, employeeID, record.WorkDate, "APPROVED").Order("aot_created DESC").First(&approvedOvertime).Error; err == nil {
		approvedOvertimeMinutes = approvedOvertime.ApprovedMinutes
		hasApprovedOvertime = approvedOvertimeMinutes > 0
	}
	now := time.Now()
	lat, lng, dist := in.Latitude, in.Longitude, distance
	record.CheckOutAt, record.CheckOutLat, record.CheckOutLng, record.CheckOutDistance = &now, &lat, &lng, &dist
	record.OutOfArea = false

	// Lembur hanya dihitung dari check-out valid yang dilakukan di outlet.
	var cfg model.AttendanceConfiguration
	if hasApprovedOvertime {
		record.OvertimeMinutes = approvedOvertimeMinutes
	} else if s.db.Where("atc_outlet = ?", outletID).First(&cfg).Error == nil {
		var shifts []AttendanceShift
		if json.Unmarshal([]byte(cfg.ShiftsJSON), &shifts) == nil {
			var shiftEndHour, shiftEndMinute int
			for _, shift := range shifts {
				if shift.Name != record.ShiftName {
					continue
				}
				if shift.EndHour != nil {
					shiftEndHour = *shift.EndHour
				} else {
					shiftEndHour = cfg.EndHour
				}
				if shift.EndMinute != nil {
					shiftEndMinute = *shift.EndMinute
				} else {
					shiftEndMinute = cfg.EndMinute
				}
			}
			if shiftEndHour > 0 || shiftEndMinute > 0 {
				outlet := model.Outlet{}
				s.db.Where("ot_id = ?", outletID).First(&outlet)
				localNow := now.In(outlet.GetLocation())
				shiftEnd := time.Date(localNow.Year(), localNow.Month(), localNow.Day(),
					shiftEndHour, shiftEndMinute, 0, 0, outlet.GetLocation())
				// Pada hari libur, pegawai tetap mendapat upah harian penuh.
				// Lembur hanya dihitung untuk waktu yang melewati jam selesai
				// shift, sama seperti pada hari kerja normal.
				// Checkout di luar radius tetap diperbolehkan agar pegawai yang sudah
				// meninggalkan outlet dapat menutup absensi; lokasinya tetap ditandai
				// melalui OutOfArea untuk ditinjau oleh owner.
				if localNow.After(shiftEnd) {
					overtime := localNow.Sub(shiftEnd)
					record.OvertimeMinutes = int(overtime.Minutes())
				}
			}
		}
	}

	if err := s.db.Save(&record).Error; err != nil {
		return record, err
	}
	return record, nil
}

func (s *AttendanceService) Records(outletID, date, month, employeeID string, limit, offset int) ([]model.AttendanceRecord, bool, error) {
	query := s.db.
		Joins("JOIN ac_pegawai pg ON pg.pg_id = ac_attendance_record.atr_employee").
		Where("ac_attendance_record.atr_outlet = ?", outletID).
		Where("ac_attendance_record.atr_work_date >= DATE(pg.pg_created)").
		Order("ac_attendance_record.atr_work_date DESC, ac_attendance_record.atr_check_in_at DESC")
	if employeeID != "" {
		query = query.Where("atr_employee = ?", employeeID)
	}
	if strings.TrimSpace(date) != "" {
		parsed, err := time.Parse("2006-01-02", date)
		if err != nil {
			return nil, false, errors.New("format tanggal harus YYYY-MM-DD")
		}
		query = query.Where("atr_work_date = ?", parsed)
	} else if strings.TrimSpace(month) != "" {
		start, err := time.Parse("2006-01", month)
		if err != nil {
			return nil, false, errors.New("format bulan harus YYYY-MM")
		}
		query = query.Where("atr_work_date >= ? AND atr_work_date < ?", start, start.AddDate(0, 1, 0))
	}
	var records []model.AttendanceRecord
	if limit > 0 {
		if limit > 50 {
			limit = 50
		}
		err := query.Offset(offset).Limit(limit + 1).Find(&records).Error
		hasMore := len(records) > limit
		if hasMore {
			records = records[:limit]
		}
		return records, hasMore, err
	}
	return records, false, query.Find(&records).Error
}

// ---------------------------------------------------------------------------
// Hari libur outlet
// ---------------------------------------------------------------------------

type AttendanceHolidayInput struct {
	Date    string `json:"date"`    // "2006-01-02" untuk tanggal spesifik
	Weekday *int   `json:"weekday"` // 0=Minggu ... 6=Sabtu untuk libur mingguan
	Label   string `json:"label"`
}

func (s *AttendanceService) Holidays(outletID string) ([]model.AttendanceHoliday, error) {
	var holidays []model.AttendanceHoliday
	err := s.db.Where("ath_outlet = ?", outletID).
		Order("ath_weekday IS NULL, ath_weekday ASC, ath_date ASC").
		Find(&holidays).Error
	return holidays, err
}

func (s *AttendanceService) AddHoliday(outletID string, in AttendanceHolidayInput) (model.AttendanceHoliday, error) {
	label := strings.TrimSpace(in.Label)
	if label == "" {
		return model.AttendanceHoliday{}, errors.New("nama hari libur wajib diisi")
	}
	holiday := model.AttendanceHoliday{ID: uuid.NewString(), OutletID: outletID, Label: label}

	switch {
	case in.Weekday != nil:
		if *in.Weekday < 0 || *in.Weekday > 6 {
			return holiday, errors.New("hari tidak valid (0-6)")
		}
		wd := *in.Weekday
		holiday.Weekday = &wd
		var dup int64
		s.db.Model(&model.AttendanceHoliday{}).
			Where("ath_outlet = ? AND ath_weekday = ?", outletID, wd).Count(&dup)
		if dup > 0 {
			return holiday, errors.New("hari libur mingguan itu sudah ada")
		}
	case strings.TrimSpace(in.Date) != "":
		parsed, err := time.Parse("2006-01-02", strings.TrimSpace(in.Date))
		if err != nil {
			return holiday, errors.New("format tanggal harus YYYY-MM-DD")
		}
		holiday.HolidayDate = &parsed
		var dup int64
		s.db.Model(&model.AttendanceHoliday{}).
			Where("ath_outlet = ? AND ath_date = ?", outletID, parsed).Count(&dup)
		if dup > 0 {
			return holiday, errors.New("tanggal libur itu sudah ada")
		}
	default:
		return holiday, errors.New("isi tanggal atau pilih hari mingguan")
	}

	if err := s.db.Create(&holiday).Error; err != nil {
		return holiday, err
	}
	return holiday, nil
}

func (s *AttendanceService) DeleteHoliday(outletID, holidayID string) error {
	res := s.db.Where("ath_id = ? AND ath_outlet = ?", holidayID, outletID).
		Delete(&model.AttendanceHoliday{})
	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("hari libur tidak ditemukan")
	}
	return nil
}

// holidayLabelFor mengembalikan label libur bila tanggal tersebut libur bagi outlet,
// atau string kosong bila hari kerja biasa.
func (s *AttendanceService) holidayLabelFor(outletID string, date time.Time) string {
	weekday := int(date.Weekday()) // 0=Minggu ... 6=Sabtu
	dateOnly := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, date.Location())

	var holidays []model.AttendanceHoliday
	if err := s.db.Where("ath_outlet = ? AND (ath_weekday = ? OR ath_date = ?)", outletID, weekday, dateOnly).
		Find(&holidays).Error; err != nil || len(holidays) == 0 {
		return ""
	}
	// Utamakan tanggal spesifik (mis. "HUT RI") di atas label mingguan.
	label := ""
	for _, h := range holidays {
		if h.HolidayDate != nil {
			return h.Label
		}
		label = h.Label
	}
	return label
}
