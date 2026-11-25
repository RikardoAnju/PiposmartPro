package service

import (
	"log"
	"sync"
	"time"

	"gorm.io/gorm"
)

type PayrollAutomationService struct {
	db       *gorm.DB
	payroll  *PayrollService
	mu       sync.Mutex
	lastDate string
}

func NewPayrollAutomationService(db *gorm.DB) *PayrollAutomationService {
	return &PayrollAutomationService{
		db:      db,
		payroll: NewPayrollService(db),
	}
}

func (s *PayrollAutomationService) Start() {
	go func() {
		s.runSweep(true)

		ticker := time.NewTicker(time.Minute)
		defer ticker.Stop()

		for range ticker.C {
			now := time.Now()
			if now.Hour() == 0 && now.Minute() >= 5 {
				s.runSweep(false)
			}
		}
	}()
}

func (s *PayrollAutomationService) runSweep(force bool) {
	s.mu.Lock()
	defer s.mu.Unlock()

	today := time.Now().Format("2006-01-02")
	if !force && s.lastDate == today {
		return
	}

	if err := s.payroll.GenerateForAllOutlets(); err != nil {
		log.Printf("⚠️ payroll scheduler gagal generate payroll otomatis: %v", err)
		return
	}
	s.lastDate = today
	log.Printf("✅ payroll scheduler selesai generate payroll otomatis untuk %s", today)
}
