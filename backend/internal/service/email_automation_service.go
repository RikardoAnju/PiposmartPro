package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"errors"
	"fmt"
	"log"
	"strings"
	"time"

	"gorm.io/gorm"
)

type EmailAutomationService struct {
	db         *gorm.DB
	emailSvc   *EmailService
	summarySvc *SummaryService
}

type ownerOutletEmailRow struct {
	OutletID   string `gorm:"column:outlet_id"`
	OutletName string `gorm:"column:outlet_name"`
	Timezone   string `gorm:"column:timezone"`
	UserID     uint   `gorm:"column:user_id"`
	UserName   string `gorm:"column:user_name"`
	Email      string `gorm:"column:email"`
}

func NewEmailAutomationService(db *gorm.DB) *EmailAutomationService {
	return &EmailAutomationService{
		db:         db,
		emailSvc:   NewEmailService(),
		summarySvc: NewSummaryService(db),
	}
}

func (s *EmailAutomationService) Start() {
	go func() {
		s.runDailyOwnerReportSweep()

		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()

		for range ticker.C {
			s.runDailyOwnerReportSweep()
		}
	}()
}

func (s *EmailAutomationService) runDailyOwnerReportSweep() {
	var rows []ownerOutletEmailRow
	if err := s.db.Table("ac_outlet o").
		Select("o.ot_id as outlet_id, o.ot_nama as outlet_name, o.ot_timezone as timezone, u.usr_id as user_id, u.usr_nama as user_name, u.usr_email as email").
		Joins("JOIN ac_user u ON u.usr_id = o.ot_user").
		Where("o.ot_status = 1 AND u.usr_status = 1 AND COALESCE(u.usr_email, '') <> ''").
		Scan(&rows).Error; err != nil {
		log.Printf("⚠️ email scheduler gagal ambil outlet owner: %v", err)
		return
	}

	for _, row := range rows {
		loc := outletTimezone(row.Timezone)
		nowLocal := time.Now().In(loc)
		if nowLocal.Hour() != 21 || nowLocal.Minute() > 9 {
			continue
		}

		dispatchDate := nowLocal.Format("2006-01-02")
		alreadySent, err := s.wasReportSent(row.OutletID, dispatchDate)
		if err != nil {
			log.Printf("⚠️ email scheduler gagal cek log outlet %s: %v", row.OutletID, err)
			continue
		}
		if alreadySent {
			continue
		}

		hasTransactions, err := s.hasTransactionsOnLocalDay(row.OutletID, nowLocal, loc)
		if err != nil {
			log.Printf("⚠️ email scheduler gagal cek transaksi outlet %s: %v", row.OutletID, err)
			continue
		}
		if !hasTransactions {
			continue
		}

		if err := s.sendDailyOwnerReport(row, nowLocal, loc); err != nil {
			log.Printf("⚠️ email scheduler gagal kirim report outlet %s: %v", row.OutletID, err)
		}
	}
}

func (s *EmailAutomationService) wasReportSent(outletID, dispatchDate string) (bool, error) {
	var count int64
	err := s.db.Model(&model.EmailDispatchLog{}).
		Where("edl_category = ? AND edl_outlet_id = ? AND edl_dispatch_date = ? AND edl_status = ?", "daily_owner_report", outletID, dispatchDate, "sent").
		Count(&count).Error
	return count > 0, err
}

func (s *EmailAutomationService) hasTransactionsOnLocalDay(outletID string, localNow time.Time, loc *time.Location) (bool, error) {
	dbLoc := time.FixedZone("WIB", 7*3600)
	startLocal := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, loc)
	endLocal := time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 23, 59, 59, 0, loc)

	startDB := startLocal.In(dbLoc).Format("2006-01-02 15:04:05")
	endDB := endLocal.In(dbLoc).Format("2006-01-02 15:04:05")

	var count int64
	err := s.db.Model(&model.Transaksi{}).
		Where("tr_outlet = ? AND tr_status_order != ? AND tr_created BETWEEN ? AND ?", outletID, "Batal", startDB, endDB).
		Count(&count).Error
	return count > 0, err
}

func (s *EmailAutomationService) sendDailyOwnerReport(row ownerOutletEmailRow, localNow time.Time, loc *time.Location) error {
	summary, err := s.summarySvc.GetDashboardSummary(row.OutletID)
	if err != nil {
		return err
	}

	dispatchDate := localNow.Format("2006-01-02")
	sendResult, sendErr := s.emailSvc.SendOwnerDailyReport(
		row.Email,
		row.UserName,
		row.OutletName,
		time.Date(localNow.Year(), localNow.Month(), localNow.Day(), 0, 0, 0, 0, loc),
		summary.TotalTransaksi,
		summary.Penjualan,
		summary.PendapatanHariIni,
		summary.Pengeluaran,
	)

	status := "sent"
	provider := "resend"
	var providerID *string
	var message *string
	now := time.Now()
	sentAt := &now

	if sendResult != nil {
		provider = sendResult.Provider
		if id := strings.TrimSpace(sendResult.ID); id != "" {
			providerID = &id
		}
		if reason := strings.TrimSpace(sendResult.Reason); reason != "" {
			message = &reason
		}
	}

	if sendErr != nil {
		status = "failed"
		sentAt = nil
		msg := sendErr.Error()
		message = &msg
	}

	outletID := row.OutletID
	userID := row.UserID
	subject := fmt.Sprintf("Ringkasan Harian %s - %s", strings.TrimSpace(row.OutletName), localNow.Format("02 January 2006"))
	entry := model.EmailDispatchLog{
		Category:     "daily_owner_report",
		Email:        row.Email,
		UserID:       &userID,
		OutletID:     &outletID,
		DispatchDate: dispatchDate,
		Status:       status,
		Subject:      subject,
		Provider:     provider,
		ProviderID:   providerID,
		Message:      message,
		SentAt:       sentAt,
	}
	if createErr := s.db.Create(&entry).Error; createErr != nil {
		return createErr
	}

	return sendErr
}

func outletTimezone(code string) *time.Location {
	switch strings.TrimSpace(strings.ToUpper(code)) {
	case "WITA":
		return time.FixedZone("WITA", 8*3600)
	case "WIT":
		return time.FixedZone("WIT", 9*3600)
	default:
		return time.FixedZone("WIB", 7*3600)
	}
}

func (s *EmailAutomationService) RunDailyOwnerReportNow() error {
	if s.db == nil {
		return errors.New("db tidak tersedia")
	}
	s.runDailyOwnerReportSweep()
	return nil
}
