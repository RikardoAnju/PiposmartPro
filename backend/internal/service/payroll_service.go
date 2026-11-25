package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"time"

	"gorm.io/datatypes"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type PayrollService struct {
	db *gorm.DB
}

type PayrollSummary struct {
	PeriodeLabel   string           `json:"periode_label"`
	UnpaidCount    int64            `json:"belum_dibayar"`
	PaidCount      int64            `json:"sudah_dibayar"`
	TotalAmount    float64          `json:"total_harus_dibayar"`
	ConfigsPending []map[string]any `json:"configs_pending,omitempty"`
	Items          []map[string]any `json:"items,omitempty"`
	Upcoming       []map[string]any `json:"akan_datang,omitempty"`
	History        []map[string]any `json:"riwayat,omitempty"`
}

func NewPayrollService(db *gorm.DB) *PayrollService { return &PayrollService{db: db} }

func (s *PayrollService) normalizeType(t string) string {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "bulanan", "monthly":
		return "monthly"
	case "mingguan", "weekly":
		return "weekly"
	case "harian", "daily":
		return "daily"
	default:
		return "monthly"
	}
}

func (s *PayrollService) normalizeScheduleType(t string) string {
	switch strings.ToLower(strings.TrimSpace(t)) {
	case "fixed_date", "bulanan", "monthly":
		return "fixed_date"
	case "weekly_day", "every_week", "weekly", "mingguan":
		return "weekly_day"
	case "every_n_days":
		return "every_n_days"
	case "daily", "harian":
		return "daily"
	default:
		return "fixed_date"
	}
}

func (s *PayrollService) ensureCurrentPeriod(tx *gorm.DB, outletID string) (*model.PayrollPeriod, error) {
	now := time.Now()
	var period model.PayrollPeriod
	err := tx.Where("pp_outlet = ? AND pp_month = ? AND pp_year = ?", outletID, int(now.Month()), now.Year()).
		First(&period).Error
	if err == nil {
		return &period, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local)
	end := start.AddDate(0, 1, -1)
	period = model.PayrollPeriod{
		ID:        utils.GenNotifID(),
		OutletID:  outletID,
		Month:     int(now.Month()),
		Year:      now.Year(),
		StartDate: start,
		EndDate:   end,
		Status:    "active",
	}
	if err := tx.Create(&period).Error; err != nil {
		return nil, err
	}
	return &period, nil
}

func (s *PayrollService) upsertSalaryConfig(input model.SalaryConfig) (model.SalaryConfig, error) {
	// Pertahankan tipe gaji yang dipilih owner. Nominal dan jadwal memiliki
	// arti berbeda untuk bulanan, mingguan, dan harian.
	input.SalaryType = strings.ToLower(strings.TrimSpace(input.SalaryType))
	switch input.SalaryType {
	case "bulanan":
		input.SalaryType = "monthly"
	case "mingguan":
		input.SalaryType = "weekly"
	case "harian":
		input.SalaryType = "daily"
	}
	if input.SalaryType != "monthly" && input.SalaryType != "weekly" && input.SalaryType != "daily" {
		input.SalaryType = "daily"
	}
	input.ScheduleType = s.normalizeScheduleType(input.ScheduleType)

	err := s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Where("pg_id = ? AND pg_outlet = ? AND pg_deleted_at IS NULL", input.PegawaiID, input.OutletID).First(&model.Pegawai{}).Error; err != nil {
			return errors.New("pegawai tidak ditemukan")
		}

		var existing model.SalaryConfig
		if err := tx.Where("spc_outlet = ? AND spc_pegawai = ?", input.OutletID, input.PegawaiID).First(&existing).Error; err == nil {
			input.ID = existing.ID
			updates := map[string]any{
				"spc_salary_type":    input.SalaryType,
				"spc_amount":         input.Amount,
				"spc_schedule_type":  input.ScheduleType,
				"spc_pay_day":        input.PayDay,
				"spc_pay_day_name":   input.PayDayName,
				"spc_pay_every_days": input.PayEveryDays,
			}
			// IsActive=0 is also the zero value when older clients omit the field.
			// Preserve the current state unless deactivation was explicitly requested.
			if input.IsActive != 0 || existing.IsActive == 0 {
				updates["spc_is_active"] = input.IsActive
			}
			if err := tx.Model(&existing).Updates(updates).Error; err != nil {
				return err
			}
		} else {
			input.ID = utils.GenNotifID()
			if input.IsActive == 0 {
				input.IsActive = 1
			}
			if err := tx.Create(&input).Error; err != nil {
				return err
			}
		}

		period, err := s.ensureCurrentPeriod(tx, input.OutletID)
		if err != nil {
			return err
		}
		return tx.Model(&model.PayrollItem{}).
			Where("pi_outlet = ? AND pi_period = ? AND pi_pegawai = ? AND pi_status = ?",
				input.OutletID, period.ID, input.PegawaiID, "unpaid").
			Updates(map[string]any{
				"pi_status":     "deleted",
				"pi_lastupdate": time.Now(),
			}).Error
	})
	return input, err
}

func (s *PayrollService) GetConfigs(outletID string) ([]map[string]any, error) {
	var rows []map[string]any
	err := s.db.Table("ac_salary_config sc").
		Select(`
			sc.spc_id as id,
			sc.spc_pegawai as pegawai_id,
			sc.spc_salary_type as salary_type,
			sc.spc_amount as amount,
			sc.spc_schedule_type as schedule_type,
			sc.spc_pay_day as pay_day,
			sc.spc_pay_day_name as pay_day_name,
			sc.spc_pay_every_days as pay_every_days,
			sc.spc_is_active as is_active,
			pg.pg_nama as pegawai_nama,
			pg.pg_email as pegawai_email,
			rl.rl_nama as role_nama
		`).
		Joins("LEFT JOIN ac_pegawai pg ON pg.pg_id = sc.spc_pegawai").
		Joins("LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role").
		Where("sc.spc_outlet = ? AND pg.pg_deleted_at IS NULL", outletID).
		Order("pg.pg_nama ASC").
		Scan(&rows).Error
	return rows, err
}

func (s *PayrollService) GetPendingEmployees(outletID string) ([]map[string]any, error) {
	var rows []map[string]any
	err := s.db.Table("ac_pegawai pg").
		Select(`
			pg.pg_id as id,
			pg.pg_nama as nama,
			pg.pg_email as email,
			pg.pg_nohp as nohp,
			pg.pg_status as status,
			pg.pg_type as type,
			rl.rl_nama as role_nama,
			CASE WHEN sc.spc_id IS NULL THEN 0 ELSE 1 END as has_salary_config,
			sc.spc_salary_type as salary_type,
			sc.spc_amount as amount,
			sc.spc_schedule_type as schedule_type
		`).
		Joins("LEFT JOIN ac_salary_config sc ON sc.spc_pegawai = pg.pg_id AND sc.spc_outlet = pg.pg_outlet AND sc.spc_is_active = 1").
		Joins("LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role").
		Where("pg.pg_outlet = ? AND pg.pg_deleted_at IS NULL", outletID).
		Order("pg.pg_nama ASC").
		Scan(&rows).Error
	return rows, err
}

type attendanceAccrualResult struct {
	workDays        int
	alfaDays        int
	overtimeMinutes int
}

func payrollRequiresAttendance(salaryType string) bool {
	return strings.EqualFold(strings.TrimSpace(salaryType), "daily")
}

func formatOvertimeDuration(minutes int) string {
	if minutes <= 0 {
		return "0 menit"
	}
	hours, rest := minutes/60, minutes%60
	if hours > 0 && rest > 0 {
		return fmt.Sprintf("%d jam (%d menit)", hours, rest)
	}
	if hours > 0 {
		return fmt.Sprintf("%d jam", hours)
	}
	return fmt.Sprintf("%d menit", minutes)
}

// attendanceAccrual menghitung ringkasan absensi pegawai pada rentang [from, to)
// untuk dipakai perhitungan gaji harian.
func (s *PayrollService) attendanceAccrual(tx *gorm.DB, outletID, pegawaiID string, from, to time.Time) attendanceAccrualResult {
	var res attendanceAccrualResult
	fromStr := from.Format("2006-01-02")
	toStr := to.Format("2006-01-02")

	var rows []model.AttendanceRecord
	tx.Where("atr_outlet = ? AND atr_employee = ? AND atr_work_date >= ? AND atr_work_date < ?",
		outletID, pegawaiID, fromStr, toStr).Find(&rows)

	for _, r := range rows {
		switch strings.ToUpper(r.Status) {
		case "HADIR", "TERLAMBAT", "LEMBUR", "KERJA_HARI_LIBUR":
			// Kerja di hari libur belum boleh masuk payroll sebelum checkout,
			// karena durasi kerja dan upahnya belum dapat ditentukan.
			if r.HolidayLabel != "" && r.CheckOutAt == nil {
				continue
			}
			if r.CheckInAt != nil {
				res.workDays++
				res.overtimeMinutes += r.OvertimeMinutes
			}
		case "ALFA":
			res.alfaDays++
		}
	}
	return res
}

func (s *PayrollService) overtimeAmount(tx *gorm.DB, outletID string, minutes int, dailyRate float64) float64 {
	if minutes <= 0 {
		return 0
	}
	var atc model.AttendanceConfiguration
	if tx.Where("atc_outlet = ?", outletID).First(&atc).Error != nil {
		return 0
	}
	dayMinutes := (atc.EndHour*60 + atc.EndMinute) - (atc.StartHour*60 + atc.StartMinute)
	if dayMinutes <= 0 {
		return 0
	}
	return overtimePremium(minutes, dailyRate/float64(dayMinutes))
}

// overtimePremium applies the standard workday multiplier: 1.5x for the
// first overtime hour and 2x for every hour after it.
func overtimePremium(minutes int, hourlyRate float64) float64 {
	if minutes <= 0 || hourlyRate <= 0 {
		return 0
	}
	firstHour := minutes
	if firstHour > 60 {
		firstHour = 60
	}
	remaining := minutes - firstHour
	return (float64(firstHour) / 60 * hourlyRate * 1.5) +
		(float64(remaining) / 60 * hourlyRate * 2)
}

// shiftBasedOvertimeAmount derives the hourly rate from the configured shift,
// instead of assuming a fixed 173-hour month. This keeps overtime consistent
// with outlets whose shifts are longer/shorter than the statutory default.
func shiftBasedOvertimeAmount(minutes int, monthlyWage float64, workingDays, shiftMinutes int) float64 {
	if minutes <= 0 || monthlyWage <= 0 || workingDays <= 0 || shiftMinutes <= 0 {
		return 0
	}
	hourly := monthlyWage / (float64(workingDays) * float64(shiftMinutes) / 60)
	firstHour := minutes
	if firstHour > 60 {
		firstHour = 60
	}
	remaining := minutes - firstHour
	return (float64(firstHour) / 60 * hourly * 1.5) +
		(float64(remaining) / 60 * hourly * 2)
}

func (s *PayrollService) configuredShiftMinutes(tx *gorm.DB, outletID string) int {
	var cfg model.AttendanceConfiguration
	if tx.Where("atc_outlet = ?", outletID).First(&cfg).Error != nil {
		return 0
	}
	minutes := (cfg.EndHour*60 + cfg.EndMinute) - (cfg.StartHour*60 + cfg.StartMinute)
	if minutes <= 0 {
		minutes += 24 * 60
	}
	return minutes
}

func (s *PayrollService) generateItems(outletID string) (*PayrollSummary, error) {
	var summary PayrollSummary
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Serialize generate untuk outlet yang sama (FOR UPDATE pada baris outlet).
		// Mencegah scheduler & request GET yang bersamaan sama-sama membuat
		// period/item duplikat.
		var lockOutlet struct {
			ID string `gorm:"column:ot_id"`
		}
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Table("ac_outlet").Select("ot_id").
			Where("ot_id = ?", outletID).Scan(&lockOutlet).Error; err != nil {
			return err
		}

		period, err := s.ensureCurrentPeriod(tx, outletID)
		if err != nil {
			return err
		}
		summary.PeriodeLabel = fmt.Sprintf("%s %d", period.StartDate.Format("Jan"), period.Year)
		now := time.Now()

		var configs []model.SalaryConfig
		if err := tx.Where("spc_outlet = ? AND spc_is_active = 1", outletID).Find(&configs).Error; err != nil {
			return err
		}

		for _, cfg := range configs {
			// Hanya generate untuk pegawai AKTIF. Pegawai non-aktif (mis. addon
			// yang belum dibayar/aktivasi, status 0) tidak boleh mengakru gaji.
			if err := tx.Where("pg_id = ? AND pg_deleted_at IS NULL AND pg_status = 1", cfg.PegawaiID).First(&model.Pegawai{}).Error; err != nil {
				continue
			}

			// Gaji mingguan: paksa jadwal mingguan (1x per minggu) apa pun
			// schedule_type yang tersimpan, supaya tidak ter-generate tiap N hari
			// (memperbaiki config lama yang tersimpan weekly + every_n_days).
			if cfg.SalaryType == "weekly" {
				cfg.ScheduleType = "weekly_day"
				if cfg.PayDayName == nil || strings.TrimSpace(*cfg.PayDayName) == "" {
					def := "Senin"
					cfg.PayDayName = &def
				}
			}
			// Kompatibilitas konfigurasi lama: sebelumnya semua gaji harian
			// tersimpan sebagai fixed_date. Baca sebagai jadwal harian agar
			// pembayaran berikutnya tetap dibuat setelah pembayaran sebelumnya.
			if cfg.SalaryType == "daily" && s.normalizeScheduleType(cfg.ScheduleType) == "fixed_date" {
				cfg.ScheduleType = "daily"
			}

			dueDates := s.calcPayrollDueDates(period, cfg, now)
			// Buat draft untuk jadwal berikutnya agar estimasi memiliki ID dan
			// dapat diedit (bonus/potongan) sebelum tanggal pembayaran.
			if len(dueDates) == 0 {
				if next := s.nextUpcomingDue(cfg, now); next != nil {
					dueDates = []time.Time{*next}
				}
			}

			// Gaji bulanan hanya boleh menghasilkan SATU item per periode,
			// berapapun schedule_type-nya. Cegah ledakan N×gaji penuh bila
			// schedule_type mis-konfigurasi (mis. monthly + daily).
			if cfg.SalaryType == "monthly" && len(dueDates) > 1 {
				dueDates = dueDates[len(dueDates)-1:]
			}

			// Jangan backfill tanggal sebelum konfigurasi gaji dibuat, supaya
			// pegawai/config baru di tengah periode tidak dapat gaji mundur.
			cfgCreatedDay := time.Date(cfg.CreatedAt.Year(), cfg.CreatedAt.Month(), cfg.CreatedAt.Day(), 0, 0, 0, 0, time.Local)

			for _, dueDate := range dueDates {
				if dueDate.Before(cfgCreatedDay) {
					continue
				}
				var count int64
				if err := tx.Model(&model.PayrollItem{}).
					Where("pi_outlet = ? AND pi_period = ? AND pi_pegawai = ? AND DATE(pi_due_date) = DATE(?) AND pi_status <> ?", outletID, period.ID, cfg.PegawaiID, dueDate, "deleted").
					Count(&count).Error; err != nil {
					return err
				}
				if count > 0 {
					// Pertahankan ID item agar edit bonus/potongan tetap valid.
					var existing model.PayrollItem
					err := tx.Where("pi_outlet = ? AND pi_period = ? AND pi_pegawai = ? AND DATE(pi_due_date) = DATE(?) AND pi_status = ?", outletID, period.ID, cfg.PegawaiID, dueDate, "unpaid").Order("pi_created DESC").First(&existing).Error
					if errors.Is(err, gorm.ErrRecordNotFound) {
						// Item sudah dibayar/berstatus lain; tidak perlu dibuat ulang.
						continue
					}
					if err != nil {
						return err
					}
					// Absensi bisa masuk setelah draft payroll dibuat. Segarkan
					// komponen dasar untuk payroll harian yang masih unpaid agar
					// draft Rp0 berubah menjadi nominal terbaru.
					// Komponen lembur absensi harus dihitung ulang dari menit terbaru.
					if err := tx.Where("pic_item = ? AND pic_type = ? AND LOWER(pic_name) LIKE ?", existing.ID, "bonus", "%lembur%").Delete(&model.PayrollItemComponent{}).Error; err != nil {
						return err
					}
					if cfg.SalaryType == "daily" {
						windowStart := dueDate
						var lastPaid model.PayrollItem
						if tx.Where("pi_outlet = ? AND pi_period = ? AND pi_pegawai = ? AND pi_status = ?", outletID, period.ID, cfg.PegawaiID, "paid").Order("pi_due_date DESC").First(&lastPaid).Error == nil {
							paidOn := lastPaid.DueDate
							if lastPaid.PaidAt != nil {
								paidOn = *lastPaid.PaidAt
							}
							windowStart = paidOn.AddDate(0, 0, 1)
						}
						if s.normalizeScheduleType(cfg.ScheduleType) == "fixed_date" {
							windowStart = period.StartDate
						}
						if windowStart.Before(cfgCreatedDay) {
							windowStart = cfgCreatedDay
						}
						accrualEnd := dueDate.AddDate(0, 0, 1)
						if accrualEnd.After(time.Now().AddDate(0, 0, 1)) {
							accrualEnd = time.Now().AddDate(0, 0, 1)
						}
						latest := s.attendanceAccrual(tx, outletID, cfg.PegawaiID, windowStart, accrualEnd)
						if err := tx.Model(&existing).Updates(map[string]any{
							"pi_base_amount":      cfg.Amount * float64(latest.workDays),
							"pi_work_days":        latest.workDays,
							"pi_alfa_days":        latest.alfaDays,
							"pi_overtime_minutes": latest.overtimeMinutes,
						}).Error; err != nil {
							return err
						}
						existing.BaseAmount = cfg.Amount * float64(latest.workDays)
						existing.WorkDays = latest.workDays
						existing.AlfaDays = latest.alfaDays
						existing.OvertimeMinutes = latest.overtimeMinutes
						// Draft payroll dapat dibuat sebelum pegawai absen pulang.
						// Segarkan juga komponen bonus lembur dari absensi agar total
						// mengikuti overtime terbaru.
						if latest.overtimeMinutes > 0 {
							var atc model.AttendanceConfiguration
							if tx.Where("atc_outlet = ?", outletID).First(&atc).Error == nil {
								shiftMinutes := (atc.EndHour*60 + atc.EndMinute) - (atc.StartHour*60 + atc.StartMinute)
								if shiftMinutes > 0 {
									bonus := shiftBasedOvertimeAmount(latest.overtimeMinutes, cfg.Amount, 1, shiftMinutes)
									if err := tx.Create(&model.PayrollItemComponent{
										ID: utils.GenNotifID(), ItemID: existing.ID, Type: "bonus",
										Name:   fmt.Sprintf("Lembur %s", formatOvertimeDuration(latest.overtimeMinutes)),
										Amount: bonus, Source: "attendance",
									}).Error; err != nil {
										return err
									}
								}
							}
						}
					} else if cfg.SalaryType == "monthly" || cfg.SalaryType == "weekly" {
						// Payroll bulanan/mingguan dapat dibuat sebelum pegawai
						// melakukan absen masuk. Refresh metrik absensinya juga,
						// tanpa mengubah gaji pokok tetapnya. Jika sudah ada
						// pembayaran sebelumnya pada periode yang sama, hanya
						// hitung absensi setelah tanggal pembayaran tersebut.
						windowStart := period.StartDate
						if cfg.SalaryType == "weekly" {
							windowStart = dueDate.AddDate(0, 0, -6)
						}
						var lastPaid model.PayrollItem
						if tx.Where("pi_outlet = ? AND pi_period = ? AND pi_pegawai = ? AND pi_status = ?", outletID, period.ID, cfg.PegawaiID, "paid").Order("pi_due_date DESC").First(&lastPaid).Error == nil {
							paidOn := lastPaid.DueDate
							if lastPaid.PaidAt != nil {
								paidOn = *lastPaid.PaidAt
							}
							paidNextDay := paidOn.AddDate(0, 0, 1)
							if paidNextDay.After(windowStart) {
								windowStart = paidNextDay
							}
						}
						if windowStart.Before(cfgCreatedDay) {
							windowStart = cfgCreatedDay
						}
						accrualEnd := dueDate.AddDate(0, 0, 1)
						if accrualEnd.After(time.Now().AddDate(0, 0, 1)) {
							accrualEnd = time.Now().AddDate(0, 0, 1)
						}
						latest := s.attendanceAccrual(tx, outletID, cfg.PegawaiID, windowStart, accrualEnd)
						if err := tx.Model(&existing).Updates(map[string]any{
							"pi_work_days":        latest.workDays,
							"pi_alfa_days":        latest.alfaDays,
							"pi_overtime_minutes": latest.overtimeMinutes,
						}).Error; err != nil {
							return err
						}
						existing.WorkDays = latest.workDays
						existing.AlfaDays = latest.alfaDays
						existing.OvertimeMinutes = latest.overtimeMinutes
						// Refresh juga nominal potongan Alfa pada draft lama.
						// Sebelumnya hanya jumlah hari yang diperbarui sehingga
						// nilai lama (mis. dibagi hadir + Alfa) tetap tersimpan.
						{
							deduction := 0.0
							periodDays := s.effectiveWorkingDays(tx, outletID, windowStart, period.EndDate)
							if cfg.SalaryType == "weekly" {
								periodDays = 7
							}
							if periodDays > 0 {
								dailyRate := cfg.Amount / float64(periodDays)
								deduction = dailyRate * float64(latest.alfaDays)
							}
							if deduction > cfg.Amount {
								deduction = cfg.Amount
							}
							existing.DeductionAmount = deduction
							if err := tx.Model(&existing).Updates(map[string]any{
								"pi_deduction_amount": deduction,
							}).Error; err != nil {
								return err
							}
							// Ganti komponen Alfa lama agar nilai manual yang
							// tersimpan tidak menimpa perhitungan terbaru.
							tx.Where("pic_item = ? AND pic_type = ? AND LOWER(pic_name) LIKE ?", existing.ID, "deduction", "%alfa%").Delete(&model.PayrollItemComponent{})
							if deduction > 0 {
								if err := tx.Create(&model.PayrollItemComponent{
									ID: utils.GenNotifID(), ItemID: existing.ID, Type: "deduction",
									Name: fmt.Sprintf("Potongan ALFA %d hari", latest.alfaDays), Amount: deduction, Source: "attendance",
								}).Error; err != nil {
									return err
								}
							}
						}
						// Refresh bonus lembur juga. Sebelumnya hanya menit lembur
						// yang diperbarui, sehingga total tetap sama dengan gaji pokok.
						var overtimeBonus float64
						if latest.overtimeMinutes > 0 {
							bonusEnd := period.EndDate
							if cfg.SalaryType == "weekly" {
								bonusEnd = dueDate
							}
							workingDays := s.effectiveWorkingDays(tx, outletID, windowStart, bonusEnd)
							if cfg.SalaryType == "weekly" {
								workingDays = 7
							}
							if workingDays > 0 {
								overtimeBonus = shiftBasedOvertimeAmount(latest.overtimeMinutes, cfg.Amount, workingDays, s.configuredShiftMinutes(tx, outletID))
							}
						}
						if overtimeBonus > 0 {
							if err := tx.Create(&model.PayrollItemComponent{
								ID: utils.GenNotifID(), ItemID: existing.ID, Type: "bonus",
								Name:   fmt.Sprintf("Lembur %s", formatOvertimeDuration(latest.overtimeMinutes)),
								Amount: overtimeBonus, Source: "attendance",
							}).Error; err != nil {
								return err
							}
						}
					}
					// Gaji harian memang bergantung pada hari hadir. Gaji bulanan
					// dan mingguan adalah gaji tetap; absensi hanya memengaruhi
					// potongan dan bonus, bukan keberadaan payroll-nya.
					if payrollRequiresAttendance(cfg.SalaryType) && existing.WorkDays == 0 {
						if err := tx.Delete(&existing).Error; err != nil {
							return err
						}
						continue
					}
					var bonusAmount, deductionAmount float64
					tx.Model(&model.PayrollItemComponent{}).Where("pic_item = ? AND pic_type = ?", existing.ID, "bonus").Select("COALESCE(SUM(pic_amount),0)").Scan(&bonusAmount)
					tx.Model(&model.PayrollItemComponent{}).Where("pic_item = ? AND pic_type = ?", existing.ID, "deduction").Select("COALESCE(SUM(pic_amount),0)").Scan(&deductionAmount)
					netAmount := existing.BaseAmount + bonusAmount - deductionAmount
					if netAmount < 0 {
						netAmount = 0
					}
					if err := tx.Model(&existing).Updates(map[string]any{"pi_bonus_amount": bonusAmount, "pi_deduction_amount": deductionAmount, "pi_net_amount": netAmount}).Error; err != nil {
						return err
					}
					continue
				}

				base := cfg.Amount
				bonus := 0.0
				deduction := 0.0
				var acc attendanceAccrualResult
				var autoComps []model.PayrollItemComponent
				// Gaji Harian: bayar sesuai hari yang benar-benar dikerjakan.
				// Base = hari kerja aktual × tarif harian.
				// Bonus = total menit lembur × (tarif harian / menit kerja per hari).
				// Potongan = jumlah ALFA × tarif harian.
				if cfg.SalaryType == "daily" {
					windowStart := dueDate
					var lastPaid model.PayrollItem
					if tx.Where("pi_outlet = ? AND pi_period = ? AND pi_pegawai = ? AND pi_status = ?", outletID, period.ID, cfg.PegawaiID, "paid").Order("pi_due_date DESC").First(&lastPaid).Error == nil {
						paidOn := lastPaid.DueDate
						if lastPaid.PaidAt != nil {
							paidOn = *lastPaid.PaidAt
						}
						windowStart = paidOn.AddDate(0, 0, 1)
					}
					if s.normalizeScheduleType(cfg.ScheduleType) == "fixed_date" {
						windowStart = period.StartDate
					}
					if windowStart.Before(cfgCreatedDay) {
						windowStart = cfgCreatedDay
					}
					accrualEnd := dueDate.AddDate(0, 0, 1)
					if accrualEnd.After(now.AddDate(0, 0, 1)) {
						accrualEnd = now.AddDate(0, 0, 1)
					}
					acc = s.attendanceAccrual(tx, outletID, cfg.PegawaiID, windowStart, accrualEnd)
					base = cfg.Amount * float64(acc.workDays)
					if acc.overtimeMinutes > 0 {
						var atc model.AttendanceConfiguration
						if tx.Where("atc_outlet = ?", outletID).First(&atc).Error == nil {
							shiftMinutes := (atc.EndHour*60 + atc.EndMinute) - (atc.StartHour*60 + atc.StartMinute)
							if shiftMinutes > 0 {
								bonus = shiftBasedOvertimeAmount(acc.overtimeMinutes, cfg.Amount, 1, shiftMinutes)
								autoComps = append(autoComps, model.PayrollItemComponent{
									Type: "bonus", Name: fmt.Sprintf("Lembur %s", formatOvertimeDuration(acc.overtimeMinutes)),
									Amount: bonus, Source: "attendance",
								})
							}
						}
					}
				} else if cfg.SalaryType == "monthly" {
					// Gaji bulanan tetap dihitung dari absensi: tarif harian
					// = gaji pokok / hari kerja efektif dalam periode.
					accrualStart := period.StartDate
					if cfgCreatedDay.After(accrualStart) {
						accrualStart = cfgCreatedDay
					}
					workingDays := s.effectiveWorkingDays(tx, outletID, accrualStart, period.EndDate)
					if workingDays > 0 {
						acc = s.attendanceAccrual(
							tx, outletID, cfg.PegawaiID,
							accrualStart,
							func() time.Time {
								end := period.EndDate.AddDate(0, 0, 1)
								if end.After(now.AddDate(0, 0, 1)) {
									return now.AddDate(0, 0, 1)
								}
								return end
							}(),
						)
						dailyRate := 0.0
						if workingDays > 0 {
							dailyRate = cfg.Amount / float64(workingDays)
						}
						// Gaji bulanan tetap menjadi gaji pokok penuh; alfa
						// dipotong satu kali menggunakan tarif harian.
						base = cfg.Amount
						deduction = dailyRate * float64(acc.alfaDays)
						if deduction > base {
							deduction = base
						}
						if acc.alfaDays > 0 {
							autoComps = append(autoComps, model.PayrollItemComponent{
								Type: "deduction", Name: fmt.Sprintf("Potongan ALFA %d hari", acc.alfaDays),
								Amount: deduction, Source: "attendance",
							})
						}
						bonus = shiftBasedOvertimeAmount(acc.overtimeMinutes, cfg.Amount, workingDays, s.configuredShiftMinutes(tx, outletID))
						if bonus > 0 {
							autoComps = append(autoComps, model.PayrollItemComponent{
								Type: "bonus", Name: fmt.Sprintf("Upah Kerja Hari Libur %s", formatOvertimeDuration(acc.overtimeMinutes)), Amount: bonus, Source: "attendance",
							})
						}
					}
				} else if cfg.SalaryType == "weekly" {
					// Gaji mingguan dihitung prorata terhadap hari kerja efektif
					// pada minggu pembayaran. Hari libur mingguan/khusus tidak
					// menjadi pembagi, sedangkan alfa mengurangi gaji.
					accrualStart := dueDate.AddDate(0, 0, -6)
					if cfgCreatedDay.After(accrualStart) {
						accrualStart = cfgCreatedDay
					}
					accrualEnd := dueDate.AddDate(0, 0, 1)
					if accrualEnd.After(now.AddDate(0, 0, 1)) {
						accrualEnd = now.AddDate(0, 0, 1)
					}
					workingDays := 7
					if workingDays > 0 {
						acc = s.attendanceAccrual(tx, outletID, cfg.PegawaiID, accrualStart, accrualEnd)
						dailyRate := 0.0
						if workingDays > 0 {
							dailyRate = cfg.Amount / float64(workingDays)
						}
						// Gaji mingguan tetap menjadi nominal mingguan penuh;
						// alfa dipotong satu kali dari nominal tersebut.
						base = cfg.Amount
						deduction = dailyRate * float64(acc.alfaDays)
						if deduction > base {
							deduction = base
						}
						if acc.alfaDays > 0 {
							autoComps = append(autoComps, model.PayrollItemComponent{
								Type: "deduction", Name: fmt.Sprintf("Potongan ALFA %d hari", acc.alfaDays),
								Amount: deduction, Source: "attendance",
							})
						}
						bonus = s.overtimeAmount(tx, outletID, acc.overtimeMinutes, dailyRate)
						if bonus > 0 {
							autoComps = append(autoComps, model.PayrollItemComponent{
								Type: "bonus", Name: fmt.Sprintf("Lembur %s", formatOvertimeDuration(acc.overtimeMinutes)), Amount: bonus, Source: "attendance",
							})
						}
					}
				}
				net := base + bonus - deduction
				if net < 0 {
					net = 0
				}
				// Hanya payroll harian yang belum dapat dibentuk tanpa hari hadir.
				// Payroll tetap bulanan/mingguan harus tetap terlihat sejak setup.
				if payrollRequiresAttendance(cfg.SalaryType) && acc.workDays == 0 {
					continue
				}
				item := model.PayrollItem{
					ID:              utils.GenNotifID(),
					OutletID:        outletID,
					PeriodID:        period.ID,
					PegawaiID:       cfg.PegawaiID,
					SalaryType:      cfg.SalaryType,
					BaseAmount:      base,
					WorkDays:        acc.workDays,
					OvertimeMinutes: acc.overtimeMinutes,
					AlfaDays:        acc.alfaDays,
					BonusAmount:     bonus,
					DeductionAmount: deduction,
					NetAmount:       net,
					DueDate:         dueDate,
					Status:          "unpaid",
				}
				if err := tx.Create(&item).Error; err != nil {
					return err
				}
				for _, c := range autoComps {
					c.ID = utils.GenNotifID()
					c.ItemID = item.ID
					if err := tx.Create(&c).Error; err != nil {
						return err
					}
				}
				if err := s.upsertPayrollSnapshot(tx, item.ID); err != nil {
					return err
				}
			}
		}

		// Bersihkan duplikat unpaid yang mungkin terbentuk sebelum mekanisme
		// draft memakai ID stabil. Satu pegawai hanya boleh punya satu item
		// untuk kombinasi periode dan tanggal bayar yang sama.
		var unpaidItems []model.PayrollItem
		if err := tx.Where("pi_outlet = ? AND pi_status = ?", outletID, "unpaid").Find(&unpaidItems).Error; err != nil {
			return err
		}
		kept := make(map[string]model.PayrollItem)
		for _, candidate := range unpaidItems {
			key := fmt.Sprintf("%s|%s|%s", candidate.PeriodID, candidate.PegawaiID, candidate.DueDate.Format("2006-01-02"))
			if current, ok := kept[key]; !ok || candidate.CreatedAt.After(current.CreatedAt) {
				kept[key] = candidate
			}
		}
		for _, candidate := range unpaidItems {
			key := fmt.Sprintf("%s|%s|%s", candidate.PeriodID, candidate.PegawaiID, candidate.DueDate.Format("2006-01-02"))
			if kept[key].ID == candidate.ID {
				continue
			}
			if err := tx.Where("pic_item = ?", candidate.ID).Delete(&model.PayrollItemComponent{}).Error; err != nil {
				return err
			}
			if err := tx.Delete(&candidate).Error; err != nil {
				return err
			}
		}

		var unpaidCount, paidCount int64
		todayEnd := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, 0, time.Local)
		// Ringkasan Payroll Aktif hanya menghitung item unpaid pada periode
		// berjalan yang sudah jatuh tempo. Item mendatang dipisahkan di
		// summary.Upcoming dan tidak boleh ikut angka Aktif.
		if err := tx.Model(&model.PayrollItem{}).Where("pi_outlet = ? AND pi_period = ? AND pi_status = ?", outletID, period.ID, "paid").Distinct("pi_pegawai").Count(&paidCount).Error; err != nil {
			return err
		}

		if err := tx.Model(&model.PayrollItem{}).
			Where("pi_outlet = ? AND pi_period = ? AND pi_status = ? AND pi_due_date <= ? AND (pi_work_days > 0 OR pi_salary_type IN ?)", outletID, period.ID, "unpaid", todayEnd, []string{"monthly", "weekly"}).
			Distinct("pi_pegawai").Count(&unpaidCount).Error; err != nil {
			return err
		}
		var totalAmount float64
		if err := tx.Model(&model.PayrollItem{}).
			Where("pi_outlet = ? AND pi_period = ? AND pi_status = ? AND pi_due_date <= ? AND (pi_work_days > 0 OR pi_salary_type IN ?)", outletID, period.ID, "unpaid", todayEnd, []string{"monthly", "weekly"}).
			Select("COALESCE(SUM(pi_net_amount),0)").Scan(&totalAmount).Error; err != nil {
			return err
		}

		summary.UnpaidCount = unpaidCount
		summary.PaidCount = paidCount
		summary.TotalAmount = totalAmount
		summary.PeriodeLabel = fmt.Sprintf("%s %d", period.StartDate.Format("Jan"), period.Year)

		var items []map[string]any
		if err := tx.Table("ac_payroll_item pi").
			Select(`
				pi.pi_id as id,
				pi.pi_pegawai as pegawai_id,
				pi.pi_period as period_id,
				pi.pi_salary_type as salary_type,
				pi.pi_base_amount as base_amount,
					pi.pi_work_days as work_days,
					COALESCE((SELECT COUNT(*) FROM ac_attendance_leave al WHERE al.aal_outlet = pi.pi_outlet AND al.aal_employee = pi.pi_pegawai AND al.aal_work_date >= pe.pp_start_date AND al.aal_work_date <= pe.pp_end_date AND al.aal_status = 'APPROVED'), 0) as izin_days,
					pi.pi_overtime_minutes as overtime_minutes,
				pi.pi_alfa_days as alfa_days,
				pi.pi_bonus_amount as bonus_amount,
				pi.pi_deduction_amount as deduction_amount,
				CASE
					WHEN pi.pi_status = 'unpaid' THEN
						GREATEST(pi.pi_base_amount + pi.pi_bonus_amount - pi.pi_deduction_amount, 0)
					ELSE pi.pi_net_amount
				END as net_amount,
				pi.pi_due_date as due_date,
				pi.pi_status as status,
				pi.pi_payment_method as payment_method,
				pi.pi_paid_at as paid_at,
				COALESCE(ps.pis_pegawai_nama, pg.pg_nama, '(Pegawai dihapus)') as pegawai_nama,
				COALESCE(ps.pis_pegawai_email, pg.pg_email, '-') as pegawai_email,
				COALESCE(ps.pis_pegawai_nohp, pg.pg_nohp, '') as pegawai_nohp,
				COALESCE(ps.pis_role_nama, rl.rl_nama, '-') as role_nama,
				pe.pp_month as period_month,
				pe.pp_year as period_year,
				pe.pp_start_date as period_start,
				pe.pp_end_date as period_end,
				COALESCE(ps.pis_period_label, CONCAT(DATE_FORMAT(pe.pp_start_date, '%b'), ' ', pe.pp_year)) as period_label
			`).
			Joins("LEFT JOIN ac_pegawai pg ON pg.pg_id = pi.pi_pegawai").
			Joins("LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role").
			Joins("LEFT JOIN ac_payroll_period pe ON pe.pp_id = pi.pi_period").
			Joins("LEFT JOIN ac_payroll_item_snapshot ps ON ps.pis_item = pi.pi_id").
			Where("pi.pi_outlet = ? AND pi.pi_status <> ? AND (pi.pi_status = ? OR pi.pi_work_days > 0 OR pi.pi_salary_type IN ?)", outletID, "deleted", "paid", []string{"monthly", "weekly"}).
			Order("pi.pi_due_date ASC, COALESCE(ps.pis_pegawai_nama, pg.pg_nama) ASC, pi.pi_created ASC").
			Scan(&items).Error; err != nil {
			return err
		}

		// net_amount di ringkasan (dipakai untuk "Total yang harus dibayar")
		// harus ikut memakai nilai yang sudah dihitung ulang per baris di atas,
		// bukan SUM(pi_net_amount) mentah yang bisa tidak sinkron dengan
		// base/bonus/deduction-nya sendiri.
		//
		// Dijumlah PER PEGAWAI (base+bonus-deduction mentah, clamp ke 0
		// sekali di akhir), BUKAN menjumlahkan net_amount per baris yang
		// sudah di-clamp sendiri-sendiri di atas. Satu pegawai bisa punya
		// beberapa item unpaid dalam periode yang sama (mis. gaji harian);
		// kalau potongan manual di satu item lebih besar dari base+bonus
		// item itu sendiri, potongannya "hilang" saat dijumlah per item
		// alih-alih ikut mengurangi total gabungan pegawai tsb — sehingga
		// totalnya tidak sinkron dengan GetItemDetail (yang sudah memakai
		// cara agregat-lalu-clamp ini untuk tampilan "tunggakan").
		{
			perPegawai := map[string]float64{}
			for _, it := range items {
				if fmt.Sprint(it["status"]) != "unpaid" {
					continue
				}
				if fmt.Sprint(it["period_id"]) != period.ID {
					continue
				}
				due, ok := it["due_date"].(time.Time)
				if !ok || due.After(todayEnd) {
					continue
				}
				pegawaiID := fmt.Sprint(it["pegawai_id"])
				perPegawai[pegawaiID] += toFloat(it["base_amount"]) + toFloat(it["bonus_amount"]) - toFloat(it["deduction_amount"])
			}
			var recomputedTotal float64
			for _, amount := range perPegawai {
				if amount < 0 {
					amount = 0
				}
				recomputedTotal += amount
			}
			totalAmount = recomputedTotal
			summary.TotalAmount = totalAmount
		}

		summary.Items = items
		// Payroll "akan datang": untuk config aktif yang BELUM punya item di
		// periode ini (tanggal gajian bulan ini belum tiba, atau config baru
		// dibuat setelah tanggal gajian sehingga digeser ke jatuh tempo
		// berikutnya), hitung tanggal jatuh tempo berikutnya untuk ditampilkan
		// agar user tahu payroll terjadwal — bukan hilang. Tidak dipersist,
		// item asli tetap ter-generate otomatis saat periodenya tiba.
		// Item paid tidak boleh menghalangi pembuatan estimasi payroll berikutnya.
		// Hanya payroll unpaid dengan due date mendatang yang sudah memiliki
		// representasi di daftar Gaji Mendatang.
		futureUnpaid := make(map[string]bool)
		for _, item := range items {
			if fmt.Sprint(item["status"]) != "unpaid" {
				continue
			}
			due, ok := item["due_date"].(time.Time)
			if ok && due.After(todayEnd) {
				futureUnpaid[fmt.Sprint(item["pegawai_id"])] = true
			}
		}

		type pegawaiInfo struct {
			Nama string `gorm:"column:pg_nama"`
			Role string `gorm:"column:rl_nama"`
		}
		upcoming := make([]map[string]any, 0)
		for _, cfg := range configs {
			if futureUnpaid[cfg.PegawaiID] {
				continue
			}
			if cfg.SalaryType == "weekly" {
				cfg.ScheduleType = "weekly_day"
			}
			if cfg.SalaryType == "daily" && s.normalizeScheduleType(cfg.ScheduleType) == "fixed_date" {
				cfg.ScheduleType = "daily"
			}
			due := s.nextUpcomingDue(cfg, now)
			if due == nil {
				continue
			}
			// Payroll dengan tanggal hari ini sudah termasuk Aktif. Jangan
			// kirim ulang sebagai estimasi Gaji Mendatang.
			if !due.After(todayEnd) {
				continue
			}
			var info pegawaiInfo
			if err := tx.Table("ac_pegawai pg").
				Select("pg.pg_nama, rl.rl_nama").
				Joins("LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role").
				Where("pg.pg_id = ? AND pg.pg_deleted_at IS NULL AND pg.pg_status = 1", cfg.PegawaiID).
				Scan(&info).Error; err != nil {
				return err
			}
			if strings.TrimSpace(info.Nama) == "" {
				continue
			}
			workDays, alfaDays, overtimeMinutes := 0, 0, 0
			base, bonus, deduction := cfg.Amount, 0.0, 0.0
			if cfg.SalaryType == "monthly" || cfg.SalaryType == "daily" {
				accrualStart := period.StartDate
				cfgCreatedDay := time.Date(cfg.CreatedAt.Year(), cfg.CreatedAt.Month(), cfg.CreatedAt.Day(), 0, 0, 0, 0, time.Local)
				if cfgCreatedDay.After(accrualStart) {
					accrualStart = cfgCreatedDay
				}
				acc := s.attendanceAccrual(tx, outletID, cfg.PegawaiID, accrualStart, now.AddDate(0, 0, 1))
				if cfg.SalaryType == "daily" {
					base = cfg.Amount * float64(acc.workDays)
				} else if workingDays := s.effectiveWorkingDays(tx, outletID, accrualStart, now); workingDays > 0 {
					dailyRate := 0.0
					if workingDays > 0 {
						dailyRate = cfg.Amount / float64(workingDays)
					}
					base = cfg.Amount
					deduction = dailyRate * float64(acc.alfaDays)
				}
				if deduction > base {
					deduction = base
				}
				workDays, alfaDays, overtimeMinutes = acc.workDays, acc.alfaDays, acc.overtimeMinutes
			} else if cfg.SalaryType == "weekly" {
				accrualStart := due.AddDate(0, 0, -6)
				cfgCreatedDay := time.Date(cfg.CreatedAt.Year(), cfg.CreatedAt.Month(), cfg.CreatedAt.Day(), 0, 0, 0, 0, time.Local)
				if cfgCreatedDay.After(accrualStart) {
					accrualStart = cfgCreatedDay
				}
				acc := s.attendanceAccrual(tx, outletID, cfg.PegawaiID, accrualStart, due.AddDate(0, 0, 1))
				if workingDays := 7; workingDays > 0 {
					dailyRate := 0.0
					if workingDays > 0 {
						dailyRate = cfg.Amount / float64(workingDays)
					}
					base = cfg.Amount
					deduction = dailyRate * float64(acc.alfaDays)
				}
				if deduction > base {
					deduction = base
				}
				workDays, alfaDays, overtimeMinutes = acc.workDays, acc.alfaDays, acc.overtimeMinutes
			}
			net := base + bonus - deduction
			if net < 0 {
				net = 0
			}
			upcoming = append(upcoming, map[string]any{
				"pegawai_id":       cfg.PegawaiID,
				"pegawai_nama":     info.Nama,
				"role_nama":        info.Role,
				"salary_type":      cfg.SalaryType,
				"amount":           cfg.Amount,
				"base_amount":      base,
				"work_days":        workDays,
				"alfa_days":        alfaDays,
				"overtime_minutes": overtimeMinutes,
				"bonus_amount":     bonus,
				"deduction_amount": deduction,
				"net_amount":       net,
				"due_date":         due.Format("2006-01-02"),
			})
		}
		sort.Slice(upcoming, func(i, j int) bool {
			di, _ := upcoming[i]["due_date"].(string)
			dj, _ := upcoming[j]["due_date"].(string)
			if di != dj {
				return di < dj
			}
			ni, _ := upcoming[i]["pegawai_nama"].(string)
			nj, _ := upcoming[j]["pegawai_nama"].(string)
			return ni < nj
		})
		summary.Upcoming = upcoming
		// Payroll mendatang hanya ditampilkan sebagai estimasi terpisah.
		// Jangan masukkan ke total/count Payroll Aktif karena belum jatuh tempo.
		return nil
	})
	return &summary, err
}

// effectiveWorkingDays bepaalt het aantal werkdagen dalam periode payroll.
// Hari libur mingguan dan libur tanggal khusus tidak dihitung sebagai hari kerja.
func (s *PayrollService) effectiveWorkingDays(tx *gorm.DB, outletID string, start, end time.Time) int {
	var holidays []model.AttendanceHoliday
	if err := tx.Where("ath_outlet = ?", outletID).Find(&holidays).Error; err != nil {
		return 0
	}
	weekly := map[int]bool{}
	specific := map[string]bool{}
	for _, holiday := range holidays {
		if holiday.Weekday != nil {
			weekly[*holiday.Weekday] = true
		}
		if holiday.HolidayDate != nil {
			specific[holiday.HolidayDate.Format("2006-01-02")] = true
		}
	}
	count := 0
	for day := start; !day.After(end); day = day.AddDate(0, 0, 1) {
		if weekly[int(day.Weekday())] || specific[day.Format("2006-01-02")] {
			continue
		}
		count++
	}
	return count
}

// nextUpcomingDue menghitung tanggal jatuh tempo gaji berikutnya (>= hari ini
// dan >= tanggal config dibuat) untuk ditampilkan sebagai payroll "akan datang".
// Hanya untuk display — tidak membuat item.
func (s *PayrollService) nextUpcomingDue(cfg model.SalaryConfig, now time.Time) *time.Time {
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)
	created := time.Date(cfg.CreatedAt.Year(), cfg.CreatedAt.Month(), cfg.CreatedAt.Day(), 0, 0, 0, 0, time.Local)
	floor := today
	if created.After(floor) {
		floor = created
	}

	switch s.normalizeScheduleType(cfg.ScheduleType) {
	case "fixed_date":
		day := 1
		if cfg.PayDay != nil {
			day = *cfg.PayDay
		}
		if day < 1 {
			day = 1
		}
		y, m := floor.Year(), int(floor.Month())
		for i := 0; i < 24; i++ {
			lastDay := time.Date(y, time.Month(m)+1, 0, 0, 0, 0, 0, time.Local).Day()
			d := day
			if d > lastDay {
				d = lastDay
			}
			cand := time.Date(y, time.Month(m), d, 0, 0, 0, 0, time.Local)
			if !cand.Before(floor) {
				return &cand
			}
			m++
			if m > 12 {
				m = 1
				y++
			}
		}
	case "weekly_day":
		weekday := weekdayFromName(cfg.PayDayName)
		if weekday == nil {
			return nil
		}
		for i := 0; i < 7; i++ {
			cand := floor.AddDate(0, 0, i)
			if cand.Weekday() == *weekday {
				return &cand
			}
		}
	case "every_n_days":
		step := 1
		if cfg.PayEveryDays != nil && *cfg.PayEveryDays > 0 {
			step = *cfg.PayEveryDays
		}
		cand := floor.AddDate(0, 0, step)
		return &cand
	case "daily":
		return &floor
	}
	return nil
}

func (s *PayrollService) ListActive(outletID string) (*PayrollSummary, error) {
	return s.generateItems(outletID)
}

func (s *PayrollService) GenerateForAllOutlets() error {
	var outlets []struct {
		ID string `gorm:"column:ot_id"`
	}
	if err := s.db.Table("ac_outlet").
		Select("ot_id").
		Where("ot_status = 1").
		Scan(&outlets).Error; err != nil {
		return err
	}

	for _, outlet := range outlets {
		if _, err := s.generateItems(outlet.ID); err != nil {
			return err
		}
	}
	return nil
}

func (s *PayrollService) calcPayrollDueDate(period *model.PayrollPeriod, cfg model.SalaryConfig) time.Time {
	dates := s.calcPayrollDueDates(period, cfg, time.Now())
	if len(dates) == 0 {
		return time.Date(period.Year, time.Month(period.Month), 1, 0, 0, 0, 0, time.Local)
	}
	return dates[len(dates)-1]
}

func (s *PayrollService) calcPayrollDueDates(period *model.PayrollPeriod, cfg model.SalaryConfig, cutoff time.Time) []time.Time {
	periodStart := time.Date(period.Year, time.Month(period.Month), 1, 0, 0, 0, 0, time.Local)
	periodEnd := time.Date(period.Year, time.Month(period.Month)+1, 0, 0, 0, 0, 0, time.Local)
	if cutoff.Before(periodStart) {
		return nil
	}
	if cutoff.After(periodEnd) {
		cutoff = periodEnd
	}

	switch s.normalizeScheduleType(cfg.ScheduleType) {
	case "fixed_date":
		if cfg.PayDay == nil {
			return []time.Time{periodEnd}
		}
		day := *cfg.PayDay
		if day < 1 {
			day = 1
		}
		if day > periodEnd.Day() {
			day = periodEnd.Day()
		}
		due := time.Date(period.Year, time.Month(period.Month), day, 0, 0, 0, 0, time.Local)
		if due.After(cutoff) {
			return nil
		}
		return []time.Time{due}
	case "weekly_day":
		weekday := weekdayFromName(cfg.PayDayName)
		if weekday == nil {
			return []time.Time{periodEnd}
		}
		offset := (int(*weekday) - int(periodStart.Weekday()) + 7) % 7
		due := periodStart.AddDate(0, 0, offset)
		var dates []time.Time
		for !due.After(cutoff) {
			if !due.Before(periodStart) {
				dates = append(dates, due)
			}
			due = due.AddDate(0, 0, 7)
		}
		return dates
	case "every_n_days":
		if cfg.PayEveryDays == nil || *cfg.PayEveryDays <= 0 {
			return []time.Time{periodEnd}
		}
		step := *cfg.PayEveryDays
		due := periodStart.AddDate(0, 0, step)
		var dates []time.Time
		for !due.After(cutoff) {
			if !due.Before(periodStart) {
				dates = append(dates, due)
			}
			due = due.AddDate(0, 0, step)
		}
		return dates
	case "daily":
		var dates []time.Time
		for due := periodStart; !due.After(cutoff); due = due.AddDate(0, 0, 1) {
			dates = append(dates, due)
		}
		return dates
	default:
		if cutoff.Before(periodEnd) {
			return nil
		}
		return []time.Time{periodEnd}
	}
}

func (s *PayrollService) SaveConfig(outletID string, pegawaiID string, payload map[string]any) (model.SalaryConfig, error) {
	cfg := model.SalaryConfig{
		OutletID:     outletID,
		PegawaiID:    pegawaiID,
		SalaryType:   fmt.Sprint(payload["salary_type"]),
		ScheduleType: fmt.Sprint(payload["schedule_type"]),
		IsActive:     1,
	}
	if v, ok := payload["amount"].(float64); ok {
		cfg.Amount = v
	} else if v, ok := payload["amount"].(int); ok {
		cfg.Amount = float64(v)
	}
	if v, ok := payload["pay_day"].(float64); ok {
		val := int(v)
		cfg.PayDay = &val
	}
	if v, ok := payload["pay_day_name"].(string); ok && v != "" {
		cfg.PayDayName = &v
	}
	if v, ok := payload["pay_every_days"].(float64); ok {
		val := int(v)
		cfg.PayEveryDays = &val
	}
	if v, ok := payload["is_active"].(bool); ok && !v {
		cfg.IsActive = 0
	}
	return s.upsertSalaryConfig(cfg)
}

func (s *PayrollService) ListHistory(outletID string) ([]map[string]any, error) {
	var rows []map[string]any
	err := s.db.Table("ac_payroll_item pi").
		Select(`
			pi.pi_id as id,
			pi.pi_pegawai as pegawai_id,
			pi.pi_period as period_id,
			COALESCE(NULLIF(pi.pi_salary_type, ''), sc.spc_salary_type) as salary_type,
			pi.pi_base_amount as base_amount,
			pi.pi_work_days as work_days,
			COALESCE((SELECT COUNT(*) FROM ac_attendance_leave al WHERE al.aal_outlet = pi.pi_outlet AND al.aal_employee = pi.pi_pegawai AND al.aal_work_date >= pe.pp_start_date AND al.aal_work_date <= pe.pp_end_date AND al.aal_status = 'APPROVED'), 0) as izin_days,
			pi.pi_overtime_minutes as overtime_minutes,
			pi.pi_alfa_days as alfa_days,
			pi.pi_bonus_amount as bonus_amount,
			pi.pi_deduction_amount as deduction_amount,
			pi.pi_net_amount as net_amount,
			pi.pi_due_date as due_date,
			pi.pi_status as status,
			pi.pi_payment_method as payment_method,
			pi.pi_paid_at as paid_at,
			COALESCE(ps.pis_pegawai_nama, pg.pg_nama, '(Pegawai dihapus)') as pegawai_nama,
			COALESCE(ps.pis_pegawai_email, pg.pg_email, '-') as pegawai_email,
			COALESCE(ps.pis_pegawai_nohp, pg.pg_nohp, '') as pegawai_nohp,
			COALESCE(ps.pis_role_nama, rl.rl_nama, '-') as role_nama,
			pe.pp_month as period_month,
			pe.pp_year as period_year,
			pe.pp_start_date as period_start,
			pe.pp_end_date as period_end,
			COALESCE(ps.pis_period_label, CONCAT(DATE_FORMAT(pe.pp_start_date, '%b'), ' ', pe.pp_year)) as period_label
			`).
		Joins("LEFT JOIN ac_pegawai pg ON pg.pg_id = pi.pi_pegawai").
		Joins("LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role").
		Joins("LEFT JOIN ac_payroll_period pe ON pe.pp_id = pi.pi_period").
		Joins("LEFT JOIN ac_payroll_item_snapshot ps ON ps.pis_item = pi.pi_id").
		Joins("LEFT JOIN ac_salary_config sc ON sc.spc_outlet = pi.pi_outlet AND sc.spc_pegawai = pi.pi_pegawai AND sc.spc_is_active = 1").
		Where("pi.pi_outlet = ? AND pi.pi_status <> ?", outletID, "deleted").
		Order("COALESCE(pi.pi_paid_at, pi.pi_due_date) DESC, COALESCE(ps.pis_pegawai_nama, pg.pg_nama) ASC, pi.pi_created DESC").
		Scan(&rows).Error
	return rows, err
}

func (s *PayrollService) GetItemDetail(outletID, itemID string) (map[string]any, error) {
	var row map[string]any
	err := s.db.Table("ac_payroll_item pi").
		Select(`
			pi.pi_id as id,
			pi.pi_pegawai as pegawai_id,
			pi.pi_period as period_id,
			COALESCE(NULLIF(pi.pi_salary_type, ''), sc.spc_salary_type) as salary_type,
			pi.pi_base_amount as base_amount,
			pi.pi_work_days as work_days,
			COALESCE((SELECT COUNT(*) FROM ac_attendance_leave al WHERE al.aal_outlet = pi.pi_outlet AND al.aal_employee = pi.pi_pegawai AND al.aal_work_date >= pe.pp_start_date AND al.aal_work_date <= pe.pp_end_date AND al.aal_status = 'APPROVED'), 0) as izin_days,
			pi.pi_overtime_minutes as overtime_minutes,
			pi.pi_alfa_days as alfa_days,
			pi.pi_bonus_amount as bonus_amount,
			pi.pi_deduction_amount as deduction_amount,
			pi.pi_net_amount as net_amount,
			pi.pi_due_date as due_date,
			pi.pi_status as status,
			pi.pi_payment_method as payment_method,
			pi.pi_paid_at as paid_at,
			pi.pi_notes as notes,
			COALESCE(ps.pis_pegawai_nama, pg.pg_nama, '(Pegawai dihapus)') as pegawai_nama,
			COALESCE(ps.pis_pegawai_email, pg.pg_email, '-') as pegawai_email,
			COALESCE(ps.pis_pegawai_nohp, pg.pg_nohp, '') as pegawai_nohp,
			COALESCE(ps.pis_role_nama, rl.rl_nama, '-') as role_nama,
			pe.pp_month as period_month,
			pe.pp_year as period_year,
			pe.pp_start_date as period_start,
			pe.pp_end_date as period_end,
			COALESCE(ps.pis_period_label, CONCAT(DATE_FORMAT(pe.pp_start_date, '%b'), ' ', pe.pp_year)) as period_label
			`).
		Joins("LEFT JOIN ac_pegawai pg ON pg.pg_id = pi.pi_pegawai").
		Joins("LEFT JOIN ac_salary_config sc ON sc.spc_outlet = pi.pi_outlet AND sc.spc_pegawai = pi.pi_pegawai AND sc.spc_is_active = 1").
		Joins("LEFT JOIN ac_role rl ON rl.rl_id = pg.pg_role").
		Joins("LEFT JOIN ac_payroll_period pe ON pe.pp_id = pi.pi_period").
		Joins("LEFT JOIN ac_payroll_item_snapshot ps ON ps.pis_item = pi.pi_id").
		Where("pi.pi_outlet = ? AND pi.pi_id = ? AND pi.pi_status <> ?", outletID, itemID, "deleted").
		Limit(1).
		Scan(&row).Error
	if err != nil {
		return nil, err
	}
	if row == nil {
		return nil, errors.New("item payroll tidak ditemukan")
	}
	// Detail payroll unpaid harus membawa tunggakan item sebelumnya pada
	// periode yang sama, bukan hanya item jatuh tempo terbaru yang dibuka.
	if strings.EqualFold(fmt.Sprint(row["status"]), "unpaid") {
		var aggregate struct {
			BaseAmount      float64 `gorm:"column:base_amount"`
			WorkDays        int     `gorm:"column:work_days"`
			AlfaDays        int     `gorm:"column:alfa_days"`
			OvertimeMinutes int     `gorm:"column:overtime_minutes"`
			BonusAmount     float64 `gorm:"column:bonus_amount"`
			DeductionAmount float64 `gorm:"column:deduction_amount"`
			NetAmount       float64 `gorm:"column:net_amount"`
		}
		if err := s.db.Table("ac_payroll_item").
			Select(`COALESCE(SUM(pi_base_amount), 0) as base_amount,
				COALESCE(SUM(pi_work_days), 0) as work_days,
				COALESCE(SUM(pi_alfa_days), 0) as alfa_days,
				COALESCE(SUM(pi_overtime_minutes), 0) as overtime_minutes,
				COALESCE(SUM(pi_bonus_amount), 0) as bonus_amount,
				COALESCE(SUM(pi_deduction_amount), 0) as deduction_amount,
				COALESCE(SUM(pi_net_amount), 0) as net_amount`).
			Where("pi_outlet = ? AND pi_pegawai = ? AND pi_period = ? AND pi_status = ?",
				outletID, row["pegawai_id"], row["period_id"], "unpaid").
			Scan(&aggregate).Error; err != nil {
			return nil, err
		}
		row["base_amount"] = aggregate.BaseAmount
		row["work_days"] = aggregate.WorkDays
		row["alfa_days"] = aggregate.AlfaDays
		row["overtime_minutes"] = aggregate.OvertimeMinutes
		row["bonus_amount"] = aggregate.BonusAmount
		row["deduction_amount"] = aggregate.DeductionAmount
		// Hitung ulang net dari base+bonus-deduction yang baru di-SUM, jangan
		// percaya SUM(pi_net_amount) mentah-mentah: kolom net_amount pada
		// salah satu item unpaid bisa saja belum sinkron dengan bonus/
		// deduction-nya sendiri (mis. proses generate otomatis dan edit
		// manual komponen berjalan terpisah), sehingga totalnya menyimpang
		// dari breakdown komponen yang ditampilkan ke pengguna.
		combinedNet := aggregate.BaseAmount + aggregate.BonusAmount - aggregate.DeductionAmount
		if combinedNet < 0 {
			combinedNet = 0
		}
		row["net_amount"] = combinedNet
	}

	var relatedItemIDs []string
	if strings.EqualFold(fmt.Sprint(row["status"]), "paid") && row["paid_at"] != nil {
		var related []struct {
			ID              string  `gorm:"column:pi_id"`
			BaseAmount      float64 `gorm:"column:pi_base_amount"`
			WorkDays        int     `gorm:"column:pi_work_days"`
			AlfaDays        int     `gorm:"column:pi_alfa_days"`
			OvertimeMinutes int     `gorm:"column:pi_overtime_minutes"`
			BonusAmount     float64 `gorm:"column:bonus_amount"`
			DeductionAmount float64 `gorm:"column:deduction_amount"`
			NetAmount       float64 `gorm:"column:net_amount"`
		}
		if err := s.db.Table("ac_payroll_item").
			Select(`pi_id, pi_base_amount, pi_work_days, pi_alfa_days, pi_overtime_minutes,
				pi_bonus_amount as bonus_amount, pi_deduction_amount as deduction_amount, pi_net_amount as net_amount`).
			Where("pi_outlet = ? AND pi_pegawai = ? AND pi_period = ? AND pi_status = 'paid' AND pi_paid_at = ?",
				outletID, row["pegawai_id"], row["period_id"], row["paid_at"]).
			Scan(&related).Error; err == nil && len(related) > 1 {
			var base, bonus, deduction float64
			var workDays, alfaDays, overtimeMinutes int
			for _, it := range related {
				relatedItemIDs = append(relatedItemIDs, it.ID)
				base += it.BaseAmount
				workDays += it.WorkDays
				alfaDays += it.AlfaDays
				overtimeMinutes += it.OvertimeMinutes
				bonus += it.BonusAmount
				deduction += it.DeductionAmount
			}
			row["base_amount"] = base
			row["work_days"] = workDays
			row["alfa_days"] = alfaDays
			row["overtime_minutes"] = overtimeMinutes
			row["bonus_amount"] = bonus
			row["deduction_amount"] = deduction
			combinedNet := base + bonus - deduction
			if combinedNet < 0 {
				combinedNet = 0
			}
			row["net_amount"] = combinedNet
		}
	}

	var comps []map[string]any
	compQuery := s.db.Table("ac_payroll_item_component pc").
		Select(`
			pc.pic_id as id,
			pc.pic_item as item_id,
			pc.pic_type as type,
			pc.pic_name as name,
			pc.pic_amount as amount,
			pc.pic_source as source,
			pc.pic_created as created_at
		`)
	if len(relatedItemIDs) > 1 {
		compQuery = compQuery.Where("pc.pic_item IN ?", relatedItemIDs)
	} else {
		compQuery = compQuery.Where("pc.pic_item = ?", itemID)
	}
	if err := compQuery.Order("pc.pic_created ASC").Scan(&comps).Error; err != nil {
		return nil, err
	}
	// Satu lembur otomatis dengan durasi dan nominal yang sama hanya boleh
	// tampil sekali. Data lama dapat memiliki komponen attendance ganda akibat
	// regenerasi draft payroll.
	uniqueComps := make([]map[string]any, 0, len(comps))
	seenComps := make(map[string]struct{})
	for _, comp := range comps {
		// Source bisa berubah menjadi manual saat draft diedit, tetapi
		// komponen lembur yang sama tetap harus dihitung satu kali.
		key := fmt.Sprintf("%s|%s|%.2f",
			comp["type"], comp["name"], toFloat(comp["amount"]))
		if _, exists := seenComps[key]; exists {
			continue
		}
		seenComps[key] = struct{}{}
		uniqueComps = append(uniqueComps, comp)
	}
	if len(uniqueComps) != len(comps) && !strings.EqualFold(fmt.Sprint(row["status"]), "paid") {
		var bonus, deduction float64
		for _, comp := range uniqueComps {
			amount := toFloat(comp["amount"])
			if strings.EqualFold(fmt.Sprint(comp["type"]), "bonus") {
				bonus += amount
			} else if strings.EqualFold(fmt.Sprint(comp["type"]), "deduction") {
				deduction += amount
			}
		}
		base := toFloat(row["base_amount"])
		row["bonus_amount"] = bonus
		row["deduction_amount"] = deduction
		row["net_amount"] = math.Max(0, base+bonus-deduction)
	}
	row["components"] = uniqueComps
	return row, nil
}

func (s *PayrollService) UpdateItemComponents(outletID, itemID string, payload map[string]any) (map[string]any, error) {
	var response map[string]any
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var item model.PayrollItem
		if err := tx.Where("pi_id = ? AND pi_outlet = ? AND pi_status <> ?", itemID, outletID, "deleted").First(&item).Error; err != nil {
			return errors.New("item payroll tidak ditemukan")
		}
		if strings.ToLower(item.Status) == "paid" {
			return errors.New("item payroll sudah dibayar")
		}

		base := item.BaseAmount
		var bonusItems []model.PayrollItemComponent
		var deductionItems []model.PayrollItemComponent

		if v, ok := payload["base_amount"]; ok {
			base = toFloat(v)
		}

		if raw, ok := payload["components"].([]any); ok {
			for _, r := range raw {
				row, ok := r.(map[string]any)
				if !ok {
					continue
				}
				compType := strings.ToLower(fmt.Sprint(row["type"]))
				if compType == "base" {
					continue
				}
				name := fmt.Sprint(row["name"])
				amount := toFloat(row["amount"])
				if amount <= 0 {
					continue
				}
				comp := model.PayrollItemComponent{
					ID:     utils.GenNotifID(),
					ItemID: itemID,
					Type:   compType,
					Name:   name,
					Amount: amount,
					Source: "manual",
				}
				if compType == "deduction" {
					deductionItems = append(deductionItems, comp)
				} else {
					if compType == "" {
						comp.Type = "bonus"
					}
					bonusItems = append(bonusItems, comp)
				}
			}
		} else {
			if v, ok := payload["bonus_amount"]; ok {
				amount := toFloat(v)
				if amount > 0 {
					bonusItems = append(bonusItems, model.PayrollItemComponent{
						ID:     utils.GenNotifID(),
						ItemID: itemID,
						Type:   "bonus",
						Name:   "Bonus",
						Amount: amount,
						Source: "manual",
					})
				}
			}
			if v, ok := payload["deduction_amount"]; ok {
				amount := toFloat(v)
				if amount > 0 {
					deductionItems = append(deductionItems, model.PayrollItemComponent{
						ID:     utils.GenNotifID(),
						ItemID: itemID,
						Type:   "deduction",
						Name:   "Potongan",
						Amount: amount,
						Source: "manual",
					})
				}
			}
		}
		bonus := 0.0
		for _, c := range bonusItems {
			bonus += c.Amount
		}
		deduction := 0.0
		for _, c := range deductionItems {
			deduction += c.Amount
		}
		notes := stringPtr(fmt.Sprint(payload["notes"]))

		net := base + bonus - deduction
		if net < 0 {
			net = 0
		}

		if err := tx.Model(&item).Updates(map[string]any{
			"pi_base_amount":      base,
			"pi_bonus_amount":     bonus,
			"pi_deduction_amount": deduction,
			"pi_net_amount":       net,
			"pi_notes":            notes,
		}).Error; err != nil {
			return err
		}

		if err := tx.Where("pic_item = ?", itemID).Delete(&model.PayrollItemComponent{}).Error; err != nil {
			return err
		}
		components := []model.PayrollItemComponent{
			{
				ID:     utils.GenNotifID(),
				ItemID: itemID,
				Type:   "base",
				Name:   "Gaji Pokok",
				Amount: base,
				Source: "salary_config",
			},
		}
		components = append(components, bonusItems...)
		components = append(components, deductionItems...)
		for _, comp := range components {
			if err := tx.Create(&comp).Error; err != nil {
				return err
			}
		}
		if err := s.upsertPayrollSnapshot(tx, itemID); err != nil {
			return err
		}
		response = map[string]any{
			"item_id":    itemID,
			"base":       base,
			"bonus":      bonus,
			"deduction":  deduction,
			"net_amount": net,
			"components": components,
			"notes":      notes,
		}
		return nil
	})
	if err == nil {
		// Pastikan ringkasan/dashboard tidak membaca nilai payroll lama setelah
		// komponen potongan atau bonus diperbarui.
		s.invalidatePayrollExpenseCache(outletID)
	}
	return response, err
}

func (s *PayrollService) DeleteItem(outletID, itemID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var item model.PayrollItem
		if err := tx.Where("pi_id = ? AND pi_outlet = ? AND pi_status <> ?", itemID, outletID, "deleted").First(&item).Error; err != nil {
			return errors.New("item payroll tidak ditemukan")
		}
		if strings.ToLower(item.Status) == "paid" {
			return errors.New("item payroll sudah dibayar")
		}
		now := time.Now()
		if err := tx.Model(&item).Updates(map[string]any{
			"pi_status":     "deleted",
			"pi_lastupdate": &now,
		}).Error; err != nil {
			return err
		}
		return nil
	})
}

func (s *PayrollService) ensurePayrollExpenseCategory(tx *gorm.DB, outletID, userUpdate string) (string, error) {
	var category model.KategoriPengeluaran
	err := tx.Where("kp_outlet = ? AND LOWER(kp_kategori) = LOWER(?) AND kp_status = 1", outletID, "Gaji Pegawai").
		First(&category).Error
	if err == nil {
		return category.ID, nil
	}
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return "", err
	}

	category = model.KategoriPengeluaran{
		ID:         utils.GenKatPengeluaranID(tx, outletID),
		OutletID:   outletID,
		Kategori:   "Gaji Pegawai",
		Status:     1,
		UserUpdate: userUpdate,
	}
	if err := tx.Create(&category).Error; err != nil {
		return "", err
	}
	return category.ID, nil
}

var bulanSingkatID = [...]string{
	"", "Jan", "Feb", "Mar", "Apr", "Mei", "Jun",
	"Jul", "Agu", "Sep", "Okt", "Nov", "Des",
}

// formatTanggalID memformat tanggal jadi "02 Agu 2006" dengan singkatan bulan
// Bahasa Indonesia (bukan "Aug" bawaan Go).
func formatTanggalID(t time.Time) string {
	m := int(t.Month())
	bulan := "-"
	if m >= 1 && m <= 12 {
		bulan = bulanSingkatID[m]
	}
	return fmt.Sprintf("%02d %s %d", t.Day(), bulan, t.Year())
}

func (s *PayrollService) createPayrollExpense(tx *gorm.DB, outletID string, item model.PayrollItem, referenceNo, paidBy, paidByType string, paidAt time.Time, buktiPath string) error {
	categoryID, err := s.ensurePayrollExpenseCategory(tx, outletID, paidBy)
	if err != nil {
		return err
	}

	pegawaiName := "(Pegawai dihapus)"
	var snapshot model.PayrollItemSnapshot
	if err := tx.Where("pis_item = ?", item.ID).First(&snapshot).Error; err == nil {
		if strings.TrimSpace(snapshot.PegawaiNama) != "" {
			pegawaiName = snapshot.PegawaiNama
		}
	}
	if pegawaiName == "(Pegawai dihapus)" {
		var pegawai model.Pegawai
		if err := tx.Where("pg_id = ?", item.PegawaiID).First(&pegawai).Error; err == nil && strings.TrimSpace(pegawai.Nama) != "" {
			pegawaiName = pegawai.Nama
		}
	}

	desc := fmt.Sprintf("Pembayaran gaji %s - %s", pegawaiName, formatTanggalID(item.DueDate))

	expense := model.Pengeluaran{
		ID:             utils.GenPengeluaranID(tx, outletID),
		KategoriID:     categoryID,
		OutletID:       outletID,
		Tanggal:        paidAt,
		DueDate:        &item.DueDate,
		Total:          item.NetAmount,
		Keterangan:     desc,
		SourceType:     "payroll",
		SourceID:       item.ID,
		UserUpdate:     paidBy,
		UserUpdateType: paidByType,
	}

	// Lampirkan struk gaji (di-generate & di-upload dari app) sebagai bukti.
	if strings.TrimSpace(buktiPath) != "" {
		if buktiJSON, mErr := json.Marshal([]string{buktiPath}); mErr == nil {
			expense.Bukti = datatypes.JSON(buktiJSON)
		}
	}

	if err := tx.Create(&expense).Error; err != nil {
		return err
	}
	return nil
}

func (s *PayrollService) invalidatePayrollExpenseCache(outletID string) {
	database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
}

func validatePayrollDueDate(item model.PayrollItem, now time.Time) error {
	due := item.DueDate.In(time.Local)
	today := now.In(time.Local)
	if today.Year() < due.Year() ||
		(today.Year() == due.Year() && today.YearDay() < due.YearDay()) {
		return fmt.Errorf("pembayaran belum jatuh tempo (jadwal bayar %s)", due.Format("02 Jan 2006"))
	}
	return nil
}

func (s *PayrollService) MarkPaid(outletID, itemID, method, paidBy, paidByType, buktiPath string) (map[string]any, error) {
	var response map[string]any
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var item model.PayrollItem
		if err := tx.Where("pi_id = ? AND pi_outlet = ? AND pi_status <> ?", itemID, outletID, "deleted").First(&item).Error; err != nil {
			return errors.New("item payroll tidak ditemukan")
		}
		if strings.ToLower(item.Status) == "paid" {
			return errors.New("item payroll sudah dibayar")
		}
		now := time.Now()
		if err := validatePayrollDueDate(item, now); err != nil {
			return err
		}
		ref := fmt.Sprintf("PAY/%s/%s", time.Now().Format("20060102"), item.ID)
		if err := tx.Create(&model.PayrollPayment{
			ID:            utils.GenNotifID(),
			OutletID:      outletID,
			PeriodID:      item.PeriodID,
			TotalAmount:   item.NetAmount,
			PaymentMethod: method,
			ReferenceNo:   &ref,
			PaidBy:        &paidBy,
			PaidAt:        now,
			Status:        "success",
		}).Error; err != nil {
			return err
		}
		if err := tx.Model(&item).Updates(map[string]any{
			"pi_status":         "paid",
			"pi_payment_method": method,
			"pi_paid_at":        &now,
		}).Error; err != nil {
			return err
		}
		if err := s.upsertPayrollSnapshot(tx, itemID); err != nil {
			return err
		}
		if err := s.createPayrollExpense(tx, outletID, item, ref, paidBy, paidByType, now, buktiPath); err != nil {
			return err
		}
		response = map[string]any{
			"item_id":        item.ID,
			"period_id":      item.PeriodID,
			"payment_method": method,
			"reference_no":   ref,
			"due_date":       item.DueDate,
			"paid_at":        now,
			"total_amount":   item.NetAmount,
		}
		return nil
	})
	if err == nil {
		s.invalidatePayrollExpenseCache(outletID)
	}
	return response, err
}

func (s *PayrollService) MarkBulkPaid(outletID string, itemIDs []string, method, paidBy, paidByType string) (map[string]any, error) {
	var paidAt time.Time
	err := s.db.Transaction(func(tx *gorm.DB) error {
		type paymentGroup struct {
			items []model.PayrollItem
			total float64
		}
		groups := make(map[string]*paymentGroup)
		for _, id := range itemIDs {
			var item model.PayrollItem
			if err := tx.Where("pi_id = ? AND pi_outlet = ? AND pi_status <> ?", id, outletID, "deleted").First(&item).Error; err != nil {
				return errors.New("item payroll tidak ditemukan")
			}
			if strings.ToLower(item.Status) == "paid" {
				return errors.New("item payroll sudah dibayar")
			}
			if err := validatePayrollDueDate(item, time.Now()); err != nil {
				return err
			}
			key := item.PegawaiID + "|" + item.PeriodID
			group := groups[key]
			if group == nil {
				group = &paymentGroup{}
				groups[key] = group
			}
			group.items = append(group.items, item)
			// JANGAN jumlahkan item.NetAmount (sudah di-clamp ke 0 per item).
			// Kalau potongan manual di satu item lebih besar dari base+bonus
			// item itu sendiri, potongannya "hilang" saat dijumlah per item
			// alih-alih ikut mengurangi total gabungan yang benar-benar
			// dibayar & dicatat sebagai pengeluaran. Jumlahkan base/bonus/
			// deduction mentah dulu, clamp sekali di bawah — sama seperti
			// logika "tunggakan" di GetItemDetail yang sudah ditampilkan ke
			// pengguna sebelum konfirmasi bayar.
			group.total += item.BaseAmount + item.BonusAmount - item.DeductionAmount
		}
		now := time.Now()
		paidAt = now
		for _, group := range groups {
			if len(group.items) == 0 {
				continue
			}
			if group.total < 0 {
				group.total = 0
			}
			item := group.items[0]
			ref := fmt.Sprintf("PAY/%s/%s", now.Format("20060102"), utils.GenNotifID())
			if err := tx.Create(&model.PayrollPayment{ID: utils.GenNotifID(), OutletID: outletID, PeriodID: item.PeriodID, TotalAmount: group.total, PaymentMethod: method, ReferenceNo: &ref, PaidBy: &paidBy, PaidAt: now, Status: "success"}).Error; err != nil {
				return err
			}
			for _, groupItem := range group.items {
				if err := tx.Model(&model.PayrollItem{}).
					Where("pi_id = ? AND pi_outlet = ? AND pi_status = ?", groupItem.ID, outletID, "unpaid").
					Updates(map[string]any{"pi_status": "paid", "pi_payment_method": method, "pi_paid_at": &now}).Error; err != nil {
					return err
				}
				if err := s.upsertPayrollSnapshot(tx, groupItem.ID); err != nil {
					return err
				}
			}
			item.NetAmount = group.total
			if err := s.createPayrollExpense(tx, outletID, item, ref, paidBy, paidByType, now, ""); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	s.invalidatePayrollExpenseCache(outletID)
	return map[string]any{
		"item_ids":       itemIDs,
		"payment_method": method,
		"paid_at":        paidAt,
	}, nil
}

func (s *PayrollService) upsertPayrollSnapshot(tx *gorm.DB, itemID string) error {
	var item model.PayrollItem
	if err := tx.Where("pi_id = ?", itemID).First(&item).Error; err != nil {
		return err
	}

	var period model.PayrollPeriod
	if err := tx.Where("pp_id = ?", item.PeriodID).First(&period).Error; err != nil {
		return err
	}

	var pegawai model.Pegawai
	pegawaiNama := "(Pegawai dihapus)"
	pegawaiEmail := "-"
	pegawaiNoHP := ""
	roleNama := "-"
	if err := tx.Preload("Role").Where("pg_id = ?", item.PegawaiID).First(&pegawai).Error; err == nil && pegawai.DeletedAt == nil {
		if strings.TrimSpace(pegawai.Nama) != "" {
			pegawaiNama = pegawai.Nama
		}
		if strings.TrimSpace(pegawai.Email) != "" {
			pegawaiEmail = pegawai.Email
		}
		if strings.TrimSpace(pegawai.NoHP) != "" {
			pegawaiNoHP = pegawai.NoHP
		}
		if pegawai.Role != nil && strings.TrimSpace(pegawai.Role.Nama) != "" {
			roleNama = pegawai.Role.Nama
		}
	} else {
		var existing model.PayrollItemSnapshot
		if err := tx.Where("pis_item = ?", itemID).First(&existing).Error; err == nil {
			if strings.TrimSpace(existing.PegawaiNama) != "" {
				pegawaiNama = existing.PegawaiNama
			}
			if strings.TrimSpace(existing.PegawaiEmail) != "" {
				pegawaiEmail = existing.PegawaiEmail
			}
			if strings.TrimSpace(existing.PegawaiNoHP) != "" {
				pegawaiNoHP = existing.PegawaiNoHP
			}
			if strings.TrimSpace(existing.RoleNama) != "" {
				roleNama = existing.RoleNama
			}
		}
	}

	var comps []model.PayrollItemComponent
	if err := tx.Where("pic_item = ?", itemID).Order("pic_created ASC").Find(&comps).Error; err != nil {
		return err
	}
	componentsJSON, err := json.Marshal(comps)
	if err != nil {
		return err
	}

	payload := map[string]any{
		"item_id":          item.ID,
		"outlet_id":        item.OutletID,
		"pegawai_id":       item.PegawaiID,
		"pegawai_nama":     pegawaiNama,
		"pegawai_email":    pegawaiEmail,
		"pegawai_nohp":     pegawaiNoHP,
		"role_nama":        roleNama,
		"period_id":        item.PeriodID,
		"period_label":     fmt.Sprintf("%s %d", period.StartDate.Format("Jan"), period.Year),
		"salary_type":      item.SalaryType,
		"base_amount":      item.BaseAmount,
		"bonus_amount":     item.BonusAmount,
		"deduction_amount": item.DeductionAmount,
		"net_amount":       item.NetAmount,
		"due_date":         item.DueDate,
		"status":           item.Status,
		"payment_method":   item.PaymentMethod,
		"paid_at":          item.PaidAt,
		"components_json":  string(componentsJSON),
		"notes":            item.Notes,
	}

	var snapshot model.PayrollItemSnapshot
	if err := tx.Where("pis_item = ?", itemID).First(&snapshot).Error; err == nil {
		return tx.Model(&snapshot).Updates(map[string]any{
			"pis_outlet":           payload["outlet_id"],
			"pis_pegawai":          payload["pegawai_id"],
			"pis_pegawai_nama":     payload["pegawai_nama"],
			"pis_pegawai_email":    payload["pegawai_email"],
			"pis_pegawai_nohp":     payload["pegawai_nohp"],
			"pis_role_nama":        payload["role_nama"],
			"pis_period":           payload["period_id"],
			"pis_period_label":     payload["period_label"],
			"pis_salary_type":      payload["salary_type"],
			"pis_base_amount":      payload["base_amount"],
			"pis_bonus_amount":     payload["bonus_amount"],
			"pis_deduction_amount": payload["deduction_amount"],
			"pis_net_amount":       payload["net_amount"],
			"pis_due_date":         payload["due_date"],
			"pis_status":           payload["status"],
			"pis_payment_method":   payload["payment_method"],
			"pis_paid_at":          payload["paid_at"],
			"pis_components_json":  payload["components_json"],
			"pis_notes":            payload["notes"],
		}).Error
	}

	snapshot = model.PayrollItemSnapshot{
		ID:              utils.GenNotifID(),
		ItemID:          item.ID,
		OutletID:        item.OutletID,
		PegawaiID:       item.PegawaiID,
		PegawaiNama:     pegawaiNama,
		PegawaiEmail:    pegawaiEmail,
		PegawaiNoHP:     pegawaiNoHP,
		RoleNama:        roleNama,
		PeriodID:        item.PeriodID,
		PeriodLabel:     fmt.Sprintf("%s %d", period.StartDate.Format("Jan"), period.Year),
		SalaryType:      item.SalaryType,
		BaseAmount:      item.BaseAmount,
		BonusAmount:     item.BonusAmount,
		DeductionAmount: item.DeductionAmount,
		NetAmount:       item.NetAmount,
		DueDate:         item.DueDate,
		Status:          item.Status,
		PaymentMethod:   item.PaymentMethod,
		PaidAt:          item.PaidAt,
		ComponentsJSON:  string(componentsJSON),
		Notes:           item.Notes,
	}
	return tx.Create(&snapshot).Error
}

func toFloat(v any) float64 {
	switch x := v.(type) {
	case float64:
		return x
	case float32:
		return float64(x)
	case int:
		return float64(x)
	case int64:
		return float64(x)
	case string:
		s := strings.TrimSpace(x)
		if s == "" {
			return 0
		}
		if strings.Contains(s, ",") {
			// Format Indonesia: titik = pemisah ribuan, koma = desimal.
			s = strings.ReplaceAll(s, ".", "")
			s = strings.ReplaceAll(s, ",", ".")
		} else if strings.Count(s, ".") > 1 {
			// Beberapa titik → pasti pemisah ribuan (mis. "1.500.000").
			s = strings.ReplaceAll(s, ".", "")
		}
		// Satu titik saja dibiarkan sebagai desimal (mis. "1500.50").
		var n float64
		fmt.Sscanf(s, "%f", &n)
		return n
	default:
		return 0
	}
}

func stringPtr(v string) *string {
	if strings.TrimSpace(v) == "" {
		return nil
	}
	return &v
}

func weekdayFromName(name *string) *time.Weekday {
	if name == nil {
		return nil
	}
	switch strings.ToLower(strings.TrimSpace(*name)) {
	case "minggu", "sunday":
		w := time.Sunday
		return &w
	case "senin", "monday":
		w := time.Monday
		return &w
	case "selasa", "tuesday":
		w := time.Tuesday
		return &w
	case "rabu", "wednesday":
		w := time.Wednesday
		return &w
	case "kamis", "thursday":
		w := time.Thursday
		return &w
	case "jumat", "friday":
		w := time.Friday
		return &w
	case "sabtu", "saturday":
		w := time.Saturday
		return &w
	default:
		return nil
	}
}
