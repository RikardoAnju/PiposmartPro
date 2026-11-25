package service

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/notifier"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type NotifAutomationService struct{ db *gorm.DB }

func NewNotifAutomationService(db *gorm.DB) *NotifAutomationService {
	return &NotifAutomationService{db: db}
}

const (
	ruleExpiry       = "LANGGANAN_EXPIRE"
	ruleCoin         = "KOIN_MENIPIS"
	ruleTopupPending = "LIFECYCLE_TOPUP_PENDING"
	ruleTopupViewed  = "LIFECYCLE_TOPUP_ABANDONED"
	ruleOnboardingH1 = "LIFECYCLE_ONBOARDING_H1"
	ruleOnboardingH2 = "LIFECYCLE_ONBOARDING_H2"
	ruleOnboardingH3 = "LIFECYCLE_ONBOARDING_H3"
	ruleInactive     = "LIFECYCLE_INACTIVE"
	ruleBirthday     = "CUSTOMER_BIRTHDAY"
)

var defaultLifecycleRules = []model.LifecycleAutomationRule{
	{Key: ruleExpiry, Name: "Trial hampir selesai", Description: "Ingatkan aktivasi PRO saat masa trial mendekati akhir.", IsActive: true, CooldownHours: 24, ThresholdValue: 3, Priority: 100, Title: "Masa aktif akan berakhir", Message: "Masa aktif akunmu segera berakhir. Aktivasi PRO agar semua fitur tetap dapat digunakan.", CTALabel: "Aktivasi PRO", Target: "pro_activation", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleCoin, Name: "Koin menipis", Description: "Ingatkan top up ketika saldo koin mencapai ambang batas.", IsActive: true, CooldownHours: 24, ThresholdValue: 10, Priority: 90, Title: "Koin hampir habis", Message: "Sisa koinmu tinggal sedikit. Isi ulang sekarang agar aktivitas outlet tidak terhambat.", CTALabel: "Top Up Koin", Target: "coin_management", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleTopupPending, Name: "Tagihan top up pending", Description: "Lanjutkan tagihan top up yang sudah dibuat tetapi belum dibayar.", IsActive: true, DelayHours: 2, CooldownHours: 48, Priority: 80, Title: "Top up belum selesai", Message: "Tagihan top up-mu masih menunggu pembayaran. Lanjutkan sebelum masa pembayarannya berakhir.", CTALabel: "Lanjutkan Pembayaran", Target: "coin_topup_detail", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleTopupViewed, Name: "Top up belum dimulai", Description: "Follow-up halaman top up yang ditinggalkan tanpa membuat tagihan.", IsActive: true, DelayHours: 2, CooldownHours: 48, Priority: 70, Title: "Masih ingin top up koin?", Message: "Kamu sempat membuka halaman top up. Pilih paket yang sesuai dan lanjutkan kapan saja.", CTALabel: "Pilih Paket", Target: "coin_management", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleOnboardingH1, Name: "Onboarding H+1", Description: "Ajak owner baru kembali membuka dan mencoba aplikasi.", IsActive: true, DelayHours: 24, CooldownHours: 720, Priority: 60, Title: "Yuk, mulai gunakan AyoCuci", Message: "Outletmu sudah siap. Buka AyoCuci dan kenali fitur yang membantu operasional harianmu.", CTALabel: "Buka AyoCuci", Target: "home", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleOnboardingH2, Name: "Onboarding H+2", Description: "Ajak owner membuat layanan pertama.", IsActive: true, DelayHours: 48, CooldownHours: 720, Priority: 55, Title: "Siapkan layanan pertamamu", Message: "Tambahkan layanan dan harga agar outletmu siap menerima transaksi.", CTALabel: "Buat Layanan", Target: "service-list", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleOnboardingH3, Name: "Onboarding H+3", Description: "Ajak owner mencatat transaksi pertama.", IsActive: true, DelayHours: 72, CooldownHours: 720, Priority: 50, Title: "Catat transaksi pertamamu", Message: "Layananmu sudah siap. Coba buat transaksi pertama untuk mulai memakai AyoCuci.", CTALabel: "Mulai Transaksi", Target: "home", QuietStartHour: 20, QuietEndHour: 9},
	{Key: ruleInactive, Name: "Reaktivasi outlet", Description: "Ajak kembali outlet yang tidak bertransaksi beberapa hari.", IsActive: true, DelayHours: 72, CooldownHours: 168, Priority: 40, Title: "Sudah beberapa hari tidak bertemu", Message: "Yuk kembali ke AyoCuci dan lanjutkan kelola outletmu dengan lebih praktis.", CTALabel: "Kembali ke AyoCuci", Target: "home", QuietStartHour: 20, QuietEndHour: 9},
}

type lifecycleCandidate struct {
	rule                    model.LifecycleAutomationRule
	outlet                  model.Outlet
	sourceEventID, entityID string
}

func (s *NotifAutomationService) Start() {
	if err := s.SeedLifecycleRules(); err != nil {
		log.Printf("lifecycle seed gagal: %v", err)
	}
	go func() {
		time.Sleep(30 * time.Second)
		s.runSweep()
		ticker := time.NewTicker(time.Hour)
		defer ticker.Stop()
		for range ticker.C {
			s.runSweep()
		}
	}()
}
func (s *NotifAutomationService) SeedLifecycleRules() error {
	for _, r := range defaultLifecycleRules {
		if err := s.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&r).Error; err != nil {
			return err
		}
	}
	return nil
}
func (s *NotifAutomationService) runSweep() {
	s.runBirthdaySweep()
	s.reconcileConversions()
	var rules []model.LifecycleAutomationRule
	if err := s.db.Where("laru_is_active = ?", true).Order("laru_priority DESC").Find(&rules).Error; err != nil {
		log.Printf("lifecycle rules gagal: %v", err)
		return
	}
	for _, r := range rules {
		rows, err := s.candidates(r)
		if err != nil {
			log.Printf("lifecycle %s gagal: %v", r.Key, err)
			continue
		}
		for _, c := range rows {
			s.dispatch(c)
		}
	}
}

func (s *NotifAutomationService) runBirthdaySweep() {
	var outlets []model.Outlet
	if err := s.db.Where("ot_status = ?", 1).Find(&outlets).Error; err != nil {
		log.Printf("birthday scheduler gagal mengambil outlet: %v", err)
		return
	}
	for _, outlet := range outlets {
		now := time.Now().In(outlet.GetLocation())
		if now.Hour() < 8 || now.Hour() >= 18 {
			continue
		}
		var customers []model.Pelanggan
		if err := s.db.Where("pl_outlet = ? AND pl_tanggal_lahir IS NOT NULL AND MONTH(pl_tanggal_lahir) = ? AND DAY(pl_tanggal_lahir) = ?", outlet.ID, int(now.Month()), now.Day()).Find(&customers).Error; err != nil {
			log.Printf("birthday scheduler outlet %s gagal: %v", outlet.ID, err)
			continue
		}
		for _, customer := range customers {
			sourceID := fmt.Sprintf("%s:%d", customer.ID, now.Year())
			var count int64
			s.db.Model(&model.LifecycleAutomationRun{}).
				Where("lar_rule_key = ? AND lar_outlet = ? AND lar_source_event_id = ? AND lar_status = ?", ruleBirthday, outlet.ID, sourceID, "sent").Count(&count)
			if count > 0 {
				continue
			}
			payload := map[string]interface{}{
				"target": "customer_detail", "entity_id": customer.ID,
				"customer_id": customer.ID, "cta_label": "Lihat Pelanggan",
				"notification_type": "customer_birthday",
			}
			err := notifier.CreateOwnerNotification(s.db, outlet, "PELANGGAN", "Pelanggan berulang tahun", fmt.Sprintf("%s berulang tahun hari ini. Kirim ucapan untuk menjaga hubungan dengan pelanggan.", customer.Nama), payload)
			status, reason := "sent", ""
			if err != nil {
				status, reason = "failed", err.Error()
			}
			s.db.Create(&model.LifecycleAutomationRun{RuleKey: ruleBirthday, OutletID: outlet.ID, SourceEventID: sourceID, Status: status, Reason: reason})
		}
	}
}

func (s *NotifAutomationService) candidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	switch r.Key {
	case ruleCoin:
		return s.coinCandidates(r)
	case ruleExpiry:
		return s.expiryCandidates(r)
	case ruleTopupPending:
		return s.pendingCandidates(r)
	case ruleTopupViewed:
		return s.abandonedCandidates(r)
	case ruleOnboardingH1, ruleOnboardingH2, ruleOnboardingH3:
		return s.onboardingCandidates(r)
	case ruleInactive:
		return s.inactiveCandidates(r)
	}
	return nil, nil
}
func wrap(r model.LifecycleAutomationRule, os []model.Outlet) []lifecycleCandidate {
	out := make([]lifecycleCandidate, 0, len(os))
	for _, o := range os {
		out = append(out, lifecycleCandidate{rule: r, outlet: o})
	}
	return out
}
func (s *NotifAutomationService) outlets(q *gorm.DB) ([]model.Outlet, error) {
	var rows []model.Outlet
	err := q.Where("ot_status = ?", 1).Find(&rows).Error
	return rows, err
}
func (s *NotifAutomationService) coinCandidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	o, e := s.outlets(s.db.Where("ot_koin <= ?", r.ThresholdValue))
	return wrap(r, o), e
}
func (s *NotifAutomationService) expiryCandidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	now := time.Now()
	o, e := s.outlets(s.db.Where("ot_activated_at IS NULL AND ot_trial_at BETWEEN ? AND ?", now, now.Add(time.Duration(r.ThresholdValue)*24*time.Hour)))
	return wrap(r, o), e
}
func (s *NotifAutomationService) pendingCandidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	var rows []model.TopupKoin
	err := s.db.Where("tk_status IN ? AND tk_created <= ? AND tk_expired_at > ?", []string{"pending", "challenge"}, time.Now().Add(-time.Duration(r.DelayHours)*time.Hour), time.Now()).Order("tk_created DESC").Find(&rows).Error
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	out := []lifecycleCandidate{}
	for _, x := range rows {
		if seen[x.OutletID] {
			continue
		}
		seen[x.OutletID] = true
		var o model.Outlet
		if s.db.Where("ot_id = ? AND ot_status = ?", x.OutletID, 1).First(&o).Error == nil {
			out = append(out, lifecycleCandidate{rule: r, outlet: o, entityID: x.ID})
		}
	}
	return out, nil
}
func (s *NotifAutomationService) abandonedCandidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	var es []model.LifecycleEvent
	err := s.db.Where("le_event_name = ? AND le_occurred_at BETWEEN ? AND ?", "coin_topup_viewed", time.Now().Add(-24*time.Hour), time.Now().Add(-time.Duration(r.DelayHours)*time.Hour)).Order("le_occurred_at DESC").Find(&es).Error
	if err != nil {
		return nil, err
	}
	seen := map[string]bool{}
	out := []lifecycleCandidate{}
	for _, e := range es {
		if seen[e.OutletID] {
			continue
		}
		seen[e.OutletID] = true
		var n int64
		s.db.Model(&model.TopupKoin{}).Where("tk_outlet = ? AND tk_created >= ?", e.OutletID, e.OccurredAt).Count(&n)
		if n > 0 {
			continue
		}
		var o model.Outlet
		if s.db.Where("ot_id = ? AND ot_status = ?", e.OutletID, 1).First(&o).Error == nil {
			out = append(out, lifecycleCandidate{rule: r, outlet: o, sourceEventID: e.EventID})
		}
	}
	return out, nil
}
func (s *NotifAutomationService) onboardingCandidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	start := time.Now().Add(-time.Duration(r.DelayHours+24) * time.Hour)
	end := time.Now().Add(-time.Duration(r.DelayHours) * time.Hour)
	os, err := s.outlets(s.db.Where("ot_created BETWEEN ? AND ?", start, end))
	if err != nil {
		return nil, err
	}
	out := []lifecycleCandidate{}
	for _, o := range os {
		var n int64
		switch r.Key {
		case ruleOnboardingH1:
			// Abaikan sesi registrasi pertama; H+1 dianggap berhasil bila owner
			// benar-benar kembali membuka aplikasi setelah fase awal onboarding.
			s.db.Model(&model.LifecycleEvent{}).Where("le_outlet = ? AND le_event_name = ? AND le_occurred_at > ?", o.ID, "app_opened", o.CreatedAt.Add(12*time.Hour)).Count(&n)
		case ruleOnboardingH2:
			s.db.Model(&model.Layanan{}).Where("ly_outlet = ?", o.ID).Count(&n)
		case ruleOnboardingH3:
			s.db.Model(&model.Transaksi{}).Where("tr_outlet = ?", o.ID).Count(&n)
		}
		if n == 0 {
			out = append(out, lifecycleCandidate{rule: r, outlet: o})
		}
	}
	return out, nil
}
func (s *NotifAutomationService) inactiveCandidates(r model.LifecycleAutomationRule) ([]lifecycleCandidate, error) {
	type row struct {
		OutletID string `gorm:"column:outlet_id"`
	}
	var rows []row
	err := s.db.Model(&model.Transaksi{}).Select("tr_outlet AS outlet_id").Group("tr_outlet").Having("MAX(tr_created) BETWEEN ? AND ?", time.Now().Add(-30*24*time.Hour), time.Now().Add(-time.Duration(r.DelayHours)*time.Hour)).Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := []lifecycleCandidate{}
	for _, x := range rows {
		var o model.Outlet
		if s.db.Where("ot_id = ? AND ot_status = ?", x.OutletID, 1).First(&o).Error == nil {
			out = append(out, lifecycleCandidate{rule: r, outlet: o})
		}
	}
	return out, nil
}

func (s *NotifAutomationService) dispatch(c lifecycleCandidate) {
	if s.quiet(c.outlet, c.rule) || s.recent(c.outlet.ID, c.rule.Key, c.rule.CooldownHours) || s.capped(c.outlet.ID) {
		return
	}
	p := map[string]interface{}{"target": c.rule.Target, "cta_label": c.rule.CTALabel, "notification_type": strings.ToLower(c.rule.Key)}
	if c.entityID != "" {
		p["entity_id"] = c.entityID
		p["topup_id"] = c.entityID
	}
	err := notifier.CreateOutletNotification(s.db, c.outlet.ID, "LIFECYCLE", c.rule.Title, c.rule.Message, p)
	status, reason := "sent", ""
	if err != nil {
		status, reason = "failed", err.Error()
	}
	if err = s.db.Create(&model.LifecycleAutomationRun{RuleKey: c.rule.Key, OutletID: c.outlet.ID, SourceEventID: c.sourceEventID, Status: status, Reason: reason}).Error; err != nil {
		log.Printf("lifecycle run gagal: %v", err)
	}
}
func (s *NotifAutomationService) quiet(o model.Outlet, r model.LifecycleAutomationRule) bool {
	h := time.Now().In(o.GetLocation()).Hour()
	if r.QuietStartHour == r.QuietEndHour {
		return false
	}
	if r.QuietStartHour > r.QuietEndHour {
		return h >= r.QuietStartHour || h < r.QuietEndHour
	}
	return h >= r.QuietStartHour && h < r.QuietEndHour
}
func (s *NotifAutomationService) recent(outlet, key string, hours int) bool {
	if hours < 1 {
		hours = 1
	}
	var n int64
	s.db.Model(&model.LifecycleAutomationRun{}).Where("lar_outlet = ? AND lar_rule_key = ? AND lar_status = ? AND lar_created >= ?", outlet, key, "sent", time.Now().Add(-time.Duration(hours)*time.Hour)).Count(&n)
	return n > 0
}
func (s *NotifAutomationService) capped(outlet string) bool {
	var n int64
	s.db.Model(&model.LifecycleAutomationRun{}).Where("lar_outlet = ? AND lar_status = ? AND lar_created >= ?", outlet, "sent", time.Now().Add(-24*time.Hour)).Count(&n)
	return n > 0
}
func (s *NotifAutomationService) reconcileConversions() {
	var runs []model.LifecycleAutomationRun
	if s.db.Where("lar_status = ? AND lar_converted_at IS NULL AND lar_created >= ?", "sent", time.Now().AddDate(0, 0, -30)).Find(&runs).Error != nil {
		return
	}
	for _, r := range runs {
		var n int64
		switch r.RuleKey {
		case ruleTopupPending, ruleTopupViewed, ruleCoin:
			s.db.Model(&model.TopupKoin{}).Where("tk_outlet = ? AND tk_status IN ? AND tk_created >= ?", r.OutletID, []string{"success", "completed"}, r.CreatedAt).Count(&n)
		case ruleExpiry:
			s.db.Model(&model.Outlet{}).Where("ot_id = ? AND ot_activated_at >= ?", r.OutletID, r.CreatedAt).Count(&n)
		case ruleOnboardingH2:
			s.db.Model(&model.Layanan{}).Where("ly_outlet = ? AND ly_created >= ?", r.OutletID, r.CreatedAt).Count(&n)
		case ruleOnboardingH3, ruleInactive:
			s.db.Model(&model.Transaksi{}).Where("tr_outlet = ? AND tr_created >= ?", r.OutletID, r.CreatedAt).Count(&n)
		default:
			s.db.Model(&model.LifecycleEvent{}).Where("le_outlet = ? AND le_event_name = ? AND le_occurred_at >= ?", r.OutletID, "app_opened", r.CreatedAt).Count(&n)
		}
		if n > 0 {
			now := time.Now()
			s.db.Model(&r).Update("lar_converted_at", &now)
		}
	}
}
