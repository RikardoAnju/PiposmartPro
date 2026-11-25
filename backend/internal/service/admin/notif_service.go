package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/push"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"gorm.io/gorm"
	"time"
)

type BroadcastNavigation struct {
	Target         string `json:"target"`
	EntityID       string `json:"entity_id,omitempty"`
	ParentID       string `json:"parent_id,omitempty"`
	FallbackTarget string `json:"fallback_target,omitempty"`
	CTALabel       string `json:"cta_label,omitempty"`
}

type AdminNotifService interface {
	Broadcast(judul, pesan, kategori string, targetOutlets []string, imageURL *string, navigation BroadcastNavigation, adminEmail string) error
	GetDetailReceivers(masterID string) ([]map[string]interface{}, error)
	GetDetailPushTokens(masterID string) ([]map[string]interface{}, error)
	GetEntityOptions(target, outletID string) ([]map[string]interface{}, error)
	DeactivatePushToken(outletID string, token string) error
	DeleteBroadcast(masterID string) error
	ListTemplates(activeOnly bool) ([]model.NotifTemplate, error)
	CreateTemplate(template model.NotifTemplate) (model.NotifTemplate, error)
	UpdateTemplate(id uint, template model.NotifTemplate) (model.NotifTemplate, error)
	DeleteTemplate(id uint) error
	GetLifecycleOverview() (map[string]interface{}, error)
	UpdateLifecycleRule(key string, rule model.LifecycleAutomationRule, adminEmail string) (model.LifecycleAutomationRule, error)
	GetNotificationOutletOptions() ([]map[string]interface{}, error)
	GetHistory(filter NotificationHistoryFilter) (NotificationHistoryResult, error)
}

type NotificationHistoryFilter struct {
	Page, Limit                              int
	Search, Category, OutletID, Date, Source string
}

type NotificationHistoryResult struct {
	Items []map[string]interface{} `json:"items"`
	Page  int                      `json:"page"`
	Limit int                      `json:"limit"`
	Total int64                    `json:"total"`
}

func (s *adminNotifService) GetLifecycleOverview() (map[string]interface{}, error) {
	type statRow struct {
		RuleKey   string `gorm:"column:rule_key"`
		Sent      int64  `gorm:"column:sent"`
		Failed    int64  `gorm:"column:failed"`
		Converted int64  `gorm:"column:converted"`
	}
	var stats []statRow
	err := s.db.Model(&model.LifecycleAutomationRun{}).
		Select("lar_rule_key AS rule_key, SUM(CASE WHEN lar_status = 'sent' THEN 1 ELSE 0 END) AS sent, SUM(CASE WHEN lar_status = 'failed' THEN 1 ELSE 0 END) AS failed, SUM(CASE WHEN lar_converted_at IS NOT NULL THEN 1 ELSE 0 END) AS converted").
		Where("lar_created >= ?", time.Now().AddDate(0, 0, -30)).
		Group("lar_rule_key").Scan(&stats).Error
	if err != nil {
		return nil, err
	}
	var recent []model.LifecycleAutomationRun
	if err := s.db.Order("lar_created DESC").Limit(100).Find(&recent).Error; err != nil {
		return nil, err
	}
	var rules []model.LifecycleAutomationRule
	if err := s.db.Order("laru_priority DESC").Find(&rules).Error; err != nil {
		return nil, err
	}
	return map[string]interface{}{"rules": rules, "stats": stats, "recent_runs": recent}, nil
}

func (s *adminNotifService) UpdateLifecycleRule(key string, rule model.LifecycleAutomationRule, adminEmail string) (model.LifecycleAutomationRule, error) {
	rule.Title, rule.Message, rule.CTALabel, rule.Target = strings.TrimSpace(rule.Title), strings.TrimSpace(rule.Message), strings.TrimSpace(rule.CTALabel), strings.TrimSpace(rule.Target)
	if rule.Title == "" || rule.Message == "" {
		return rule, errors.New("judul dan pesan wajib diisi")
	}
	allowed := map[string]bool{"home": true, "service-list": true, "coin_management": true, "coin_topup_detail": true, "pro_activation": true}
	if !allowed[rule.Target] {
		return rule, errors.New("target lifecycle tidak valid")
	}
	if rule.DelayHours < 0 || rule.CooldownHours < 1 || rule.ThresholdValue < 0 || rule.Priority < 0 || rule.Priority > 100 || rule.QuietStartHour < 0 || rule.QuietStartHour > 23 || rule.QuietEndHour < 0 || rule.QuietEndHour > 23 {
		return rule, errors.New("konfigurasi waktu, threshold, atau prioritas tidak valid")
	}
	updates := map[string]interface{}{"laru_is_active": rule.IsActive, "laru_delay_hours": rule.DelayHours, "laru_cooldown_hours": rule.CooldownHours, "laru_threshold_value": rule.ThresholdValue, "laru_priority": rule.Priority, "laru_title": rule.Title, "laru_message": rule.Message, "laru_cta_label": rule.CTALabel, "laru_target": rule.Target, "laru_quiet_start_hour": rule.QuietStartHour, "laru_quiet_end_hour": rule.QuietEndHour, "laru_updated_by": adminEmail}
	result := s.db.Model(&model.LifecycleAutomationRule{}).Where("laru_key = ?", key).Updates(updates)
	if result.Error != nil {
		return rule, result.Error
	}
	if result.RowsAffected == 0 {
		return rule, gorm.ErrRecordNotFound
	}
	var saved model.LifecycleAutomationRule
	return saved, s.db.First(&saved, "laru_key = ?", key).Error
}

func (s *adminNotifService) ListTemplates(activeOnly bool) ([]model.NotifTemplate, error) {
	var rows []model.NotifTemplate
	query := s.db.Order("nt_name ASC")
	if activeOnly {
		query = query.Where("nt_is_active = ?", true)
	}
	err := query.Find(&rows).Error
	return rows, err
}

func (s *adminNotifService) validateTemplate(template *model.NotifTemplate) error {
	template.Name = strings.TrimSpace(template.Name)
	template.Title = strings.TrimSpace(template.Title)
	template.Message = strings.TrimSpace(template.Message)
	template.Category = strings.ToUpper(strings.TrimSpace(template.Category))
	template.Target = strings.TrimSpace(template.Target)
	if template.Name == "" || template.Title == "" || template.Message == "" {
		return errors.New("nama, judul, dan pesan template wajib diisi")
	}
	if template.Category != "INFO" && template.Category != "PROMO" && template.Category != "SISTEM" {
		return errors.New("kategori template tidak valid")
	}
	if template.Target == "" {
		template.Target = "notification_detail"
	}
	if _, ok := allowedAdminBroadcastTargets[template.Target]; !ok {
		return ErrInvalidNotificationTarget
	}
	return nil
}

func (s *adminNotifService) CreateTemplate(template model.NotifTemplate) (model.NotifTemplate, error) {
	if err := s.validateTemplate(&template); err != nil {
		return template, err
	}
	template.IsActive = true
	return template, s.db.Create(&template).Error
}

func (s *adminNotifService) UpdateTemplate(id uint, template model.NotifTemplate) (model.NotifTemplate, error) {
	if err := s.validateTemplate(&template); err != nil {
		return template, err
	}
	updates := map[string]interface{}{
		"nt_name": template.Name, "nt_description": template.Description,
		"nt_title": template.Title, "nt_message": template.Message,
		"nt_category": template.Category, "nt_target": template.Target,
		"nt_fallback_target": template.FallbackTarget, "nt_cta_label": template.CTALabel,
		"nt_is_active": template.IsActive, "nt_updated_by": template.UpdatedBy,
	}
	result := s.db.Model(&model.NotifTemplate{}).Where("nt_id = ?", id).Updates(updates)
	if result.Error != nil || result.RowsAffected == 0 {
		return template, gorm.ErrRecordNotFound
	}
	var saved model.NotifTemplate
	return saved, s.db.First(&saved, "nt_id = ?", id).Error
}

func (s *adminNotifService) DeleteTemplate(id uint) error {
	result := s.db.Delete(&model.NotifTemplate{}, "nt_id = ?", id)
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return gorm.ErrRecordNotFound
	}
	return nil
}

func (s *adminNotifService) GetEntityOptions(target, outletID string) ([]map[string]interface{}, error) {
	if strings.TrimSpace(outletID) == "" {
		return nil, ErrBroadcastTargetNotFound
	}
	var rows []map[string]interface{}
	switch target {
	case "customer_deposit_entry":
		err := s.db.Table("ac_customer_deposit_ledger AS l").
			Select("l.cdl_id AS id, l.cdl_customer AS parent_id, l.cdl_entry_type AS entry_type, l.cdl_type AS deposit_type, l.cdl_amount AS amount, l.cdl_created AS created_at, COALESCE(p.pl_nama, 'Pelanggan') AS customer_name").
			Joins("LEFT JOIN ac_pelanggan p ON p.pl_id = l.cdl_customer AND p.pl_outlet = l.cdl_outlet").
			Where("l.cdl_outlet = ?", outletID).
			Order("l.cdl_created DESC").Limit(100).Find(&rows).Error
		return rows, err
	case "expense_detail":
		err := s.db.Table("ac_pengeluaran AS pg").
			Select("pg.pg_id AS id, pg.pg_tanggal AS tanggal, pg.pg_total AS total, COALESCE(kp.kp_kategori, 'Umum') AS kategori").
			Joins("LEFT JOIN ac_kategori_pengeluaran kp ON kp.kp_id = pg.pg_kategori AND kp.kp_outlet = pg.pg_outlet").
			Where("pg.pg_outlet = ?", outletID).
			Order("pg.pg_tanggal DESC, pg.pg_created DESC").
			Limit(100).
			Find(&rows).Error
		return rows, err
	default:
		return nil, ErrInvalidNotificationTarget
	}
}

type adminNotifService struct {
	db *gorm.DB
}

var ErrBroadcastTargetNotFound = errors.New("target outlet tidak ditemukan")
var ErrInvalidNotificationTarget = errors.New("tujuan notifikasi tidak valid")
var ErrInvalidNotificationEntity = errors.New("entity notifikasi tidak valid untuk outlet tujuan")

var allowedBroadcastTargets = map[string]struct{}{
	"notification_detail":    {},
	"coin_management":        {},
	"addon_purchases":        {},
	"pro_activation":         {},
	"referral_dashboard":     {},
	"transaction_list":       {},
	"transaction_detail":     {},
	"customer_list":          {},
	"customer_detail":        {},
	"customer_deposit":       {},
	"customer_deposit_entry": {},
	"coin_topup_detail":      {},
	"addon_purchase_detail":  {},
	"expense_list":           {},
	"expense_detail":         {},
	"report_dashboard":       {},
}

var allowedAdminBroadcastTargets = map[string]struct{}{
	"notification_detail":   {},
	"coin_management":       {},
	"coin_topup_detail":     {},
	"addon_purchases":       {},
	"addon_purchase_detail": {},
	"pro_activation":        {},
	"referral_dashboard":    {},
	"report_dashboard":      {},
}

func NewAdminNotificationService(db *gorm.DB) AdminNotifService {
	return &adminNotifService{db}
}

func (s *adminNotifService) Broadcast(judul, pesan, kategori string, targetOutlets []string, imageURL *string, navigation BroadcastNavigation, adminEmail string) error {
	var finalIDs []string
	masterID := uuid.New().String()
	judul = utils.CleanNotificationText(judul, "Notifikasi AyoCuci")
	pesan = utils.CleanNotificationText(pesan, "Ada informasi baru dari AyoCuci.")
	kategori = strings.ToUpper(utils.CleanNotificationText(kategori, "SISTEM"))
	navigation.Target = strings.TrimSpace(navigation.Target)
	if navigation.Target == "" {
		navigation.Target = "notification_detail"
	}
	if _, allowed := allowedAdminBroadcastTargets[navigation.Target]; !allowed {
		return ErrInvalidNotificationTarget
	}
	payload := map[string]interface{}{
		"schema_version":    1,
		"notification_type": "admin_broadcast",
		"target":            navigation.Target,
	}
	if value := strings.TrimSpace(navigation.EntityID); value != "" {
		payload["entity_id"] = value
	}
	if value := strings.TrimSpace(navigation.ParentID); value != "" {
		payload["parent_id"] = value
	}
	if value := strings.TrimSpace(navigation.FallbackTarget); value != "" {
		payload["fallback_target"] = value
	}
	if value := strings.TrimSpace(navigation.CTALabel); value != "" {
		payload["cta_label"] = value
	}
	// 1. Logic Targeting
	isAll := false
	for _, id := range targetOutlets {
		if strings.EqualFold(strings.TrimSpace(id), "all") {
			isAll = true
			break
		}
	}

	if isAll {
		if err := s.db.Raw("SELECT ot_id FROM ac_outlet").Scan(&finalIDs).Error; err != nil {
			return err
		}
	} else {
		finalIDs = cleanOutletIDs(targetOutlets)
	}

	finalIDs = cleanOutletIDs(finalIDs)
	if len(finalIDs) == 0 {
		return ErrBroadcastTargetNotFound
	}
	if len(finalIDs) == 1 {
		payload["outlet_id"] = finalIDs[0]
	}
	if requiresEntityTarget(navigation.Target) {
		entityID := strings.TrimSpace(navigation.EntityID)
		if len(finalIDs) != 1 || entityID == "" {
			return ErrInvalidNotificationEntity
		}
		valid, err := s.entityBelongsToOutlet(navigation.Target, entityID, strings.TrimSpace(navigation.ParentID), finalIDs[0])
		if err != nil {
			return err
		}
		if !valid {
			return ErrInvalidNotificationEntity
		}
	}
	payloadJSON, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	// 2. Transactional DB Operation
	err = s.db.Transaction(func(tx *gorm.DB) error {
		var imageValue interface{}
		if imageURL != nil && *imageURL != "" {
			imageValue = *imageURL
		}

		// Simpan Master Konten (Cuma 1 baris)
		master := model.NotifMaster{
			ID: masterID, Kategori: kategori, Judul: judul, Pesan: pesan,
			ImageURL: imageURL, Type: "admin_broadcast", Payload: payloadJSON,
			CTALabel: navigation.CTALabel, SchemaVersion: 1, Source: "ADMIN",
			UserUpdate: adminEmail, CreatedAt: time.Now(),
		}
		if imageValue == nil {
			master.ImageURL = nil
		}
		if err := tx.Create(&master).Error; err != nil {
			return err
		}

		// Bulk Insert Receivers ke Database
		if len(finalIDs) > 0 {
			valueStrings := []string{}
			valueArgs := []interface{}{}

			for _, otID := range finalIDs {
				valueStrings = append(valueStrings, "(?, ?, 0)")
				valueArgs = append(valueArgs, masterID, otID)
			}

			// Eksekusi Bulk Insert Receiver ke DB (Sinkron/Blocking - Ini cepat)
			qReceiver := `INSERT INTO ac_notif_receiver (nr_nm_id, nr_outlet, nr_status) VALUES ` + strings.Join(valueStrings, ",")
			if err := tx.Exec(qReceiver, valueArgs...).Error; err != nil {
				return err
			}
		}
		return nil
	})

	if err != nil {
		return err
	}

	// 3. ASYNC BROADCAST (Solusi Stalled)
	// Kita jalankan di background supaya Admin Panel langsung dapet response 200 OK.
	go func(ids []string, t, p, k, mid string, img *string, navigationPayload map[string]interface{}) {
		pushPayload := map[string]string{
			"category":  k,
			"master_id": mid,
			"type":      "SYSTEM_ANNOUNCEMENT",
		}
		for key, value := range navigationPayload {
			pushPayload[key] = strings.TrimSpace(fmt.Sprint(value))
		}
		if img != nil && *img != "" {
			pushPayload["image_url"] = *img
		}

		tokens, err := push.ActiveTokensByOutletIDs(s.db, ids)
		if err == nil && len(tokens) > 0 {
			push.SendNotificationToTokens(
				context.Background(),
				tokens,
				t,
				p,
				pushPayload,
			)
		}

		for _, otID := range ids {
			outletPayload := map[string]string{}
			for key, value := range navigationPayload {
				outletPayload[key] = strings.TrimSpace(fmt.Sprint(value))
			}
			outletPayload["master_id"] = mid
			outletPayload["category"] = k
			outletPayload["outlet_id"] = otID
			wsPayload := map[string]interface{}{
				"type":    "SYSTEM_ANNOUNCEMENT",
				"title":   t,
				"message": p,
				"payload": outletPayload,
			}
			if img != nil && *img != "" {
				wsPayload["image_url"] = *img
				outletPayload["image_url"] = *img
			}
			// Kirim ke WebSocket tanpa mengganggu request HTTP utama
			utils.AppHub.BroadcastToOutlet(otID, wsPayload)
		}
	}(finalIDs, judul, pesan, kategori, masterID, imageURL, payload)

	return nil
}

func requiresEntityTarget(target string) bool {
	switch target {
	case "transaction_detail", "customer_detail", "customer_deposit", "customer_deposit_entry", "coin_topup_detail", "addon_purchase_detail", "expense_detail":
		return true
	default:
		return false
	}
}

func (s *adminNotifService) entityBelongsToOutlet(target, entityID, parentID, outletID string) (bool, error) {
	var count int64
	var query *gorm.DB
	switch target {
	case "transaction_detail":
		query = s.db.Model(&model.Transaksi{}).Where("tr_id = ? AND tr_outlet = ?", entityID, outletID)
	case "customer_detail", "customer_deposit":
		query = s.db.Model(&model.Pelanggan{}).Where("pl_id = ? AND pl_outlet = ?", entityID, outletID)
	case "customer_deposit_entry":
		if parentID == "" {
			return false, nil
		}
		query = s.db.Model(&model.CustomerDepositLedger{}).Where("cdl_id = ? AND cdl_customer = ? AND cdl_outlet = ?", entityID, parentID, outletID)
	case "coin_topup_detail":
		query = s.db.Model(&model.TopupKoin{}).Where("id = ? AND tk_outlet = ?", entityID, outletID)
	case "addon_purchase_detail":
		query = s.db.Model(&model.TransaksiAddon{}).Where("ha_id = ? AND ha_outlet = ?", entityID, outletID)
	case "expense_detail":
		query = s.db.Model(&model.Pengeluaran{}).Where("pg_id = ? AND pg_outlet = ?", entityID, outletID)
	default:
		return false, nil
	}
	if err := query.Count(&count).Error; err != nil {
		return false, err
	}
	return count > 0, nil
}

func cleanOutletIDs(ids []string) []string {
	seen := make(map[string]struct{}, len(ids))
	cleaned := make([]string, 0, len(ids))

	for _, id := range ids {
		trimmed := strings.TrimSpace(id)
		if trimmed == "" || strings.EqualFold(trimmed, "all") {
			continue
		}
		if _, exists := seen[trimmed]; exists {
			continue
		}
		seen[trimmed] = struct{}{}
		cleaned = append(cleaned, trimmed)
	}

	return cleaned
}

func (s *adminNotifService) GetNotificationOutletOptions() ([]map[string]interface{}, error) {
	var rows []map[string]interface{}
	err := s.db.Table("ac_outlet").Select("ot_id, ot_nama").Where("ot_status = ?", 1).Order("ot_nama ASC").Scan(&rows).Error
	return rows, err
}

func (s *adminNotifService) GetHistory(filter NotificationHistoryFilter) (NotificationHistoryResult, error) {
	if filter.Page < 1 {
		filter.Page = 1
	}
	if filter.Limit < 1 {
		filter.Limit = 25
	}
	if filter.Limit > 100 {
		filter.Limit = 100
	}

	base := s.db.Table("ac_notif_master AS m")
	if value := strings.TrimSpace(filter.Search); value != "" {
		like := "%" + value + "%"
		base = base.Where("(m.nm_judul LIKE ? OR m.nm_pesan LIKE ?)", like, like)
	}
	if value := strings.ToUpper(strings.TrimSpace(filter.Category)); value != "" && value != "ALL" {
		base = base.Where("m.nm_kategori = ?", value)
	}
	if value := strings.ToUpper(strings.TrimSpace(filter.Source)); value != "" && value != "ALL" {
		base = base.Where("COALESCE(NULLIF(m.nm_source, ''), CASE WHEN m.nm_userupdate = 'SYSTEM' THEN 'SYSTEM' ELSE 'ADMIN' END) = ?", value)
	}
	if value := strings.TrimSpace(filter.Date); value != "" {
		base = base.Where("m.nm_created >= ? AND m.nm_created < DATE_ADD(?, INTERVAL 1 DAY)", value, value)
	}
	if value := strings.TrimSpace(filter.OutletID); value != "" && value != "ALL" {
		base = base.Where("EXISTS (SELECT 1 FROM ac_notif_receiver rf WHERE rf.nr_nm_id = m.nm_id AND rf.nr_outlet = ?)", value)
	}

	var total int64
	if err := base.Session(&gorm.Session{}).Count(&total).Error; err != nil {
		return NotificationHistoryResult{}, err
	}
	var items []map[string]interface{}
	err := base.Session(&gorm.Session{}).
		Select(`m.nm_id id, m.nm_judul judul, m.nm_pesan pesan, m.nm_image_url image_url,
			m.nm_type notification_type, CAST(m.nm_payload AS CHAR) payload, m.nm_cta_label cta_label,
			m.nm_schema_version schema_version, m.nm_source source, m.nm_kategori kategori,
			m.nm_created created_at, m.nm_userupdate sender,
			(SELECT COUNT(*) FROM ac_notif_receiver r WHERE r.nr_nm_id = m.nm_id) total_target,
			(SELECT COUNT(*) FROM ac_notif_receiver r WHERE r.nr_nm_id = m.nm_id AND r.nr_status = 1) total_read,
			(SELECT COUNT(*) FROM ac_notif_events e WHERE e.ne_nm_id = m.nm_id AND e.ne_event_type = 'opened') total_opened,
			(SELECT COUNT(*) FROM ac_notif_events e WHERE e.ne_nm_id = m.nm_id AND e.ne_event_type = 'navigation_success') total_navigation_success,
			(SELECT COUNT(*) FROM ac_notif_events e WHERE e.ne_nm_id = m.nm_id AND e.ne_event_type IN ('navigation_fallback','navigation_denied')) total_navigation_failed`).
		Order("m.nm_created DESC").Offset((filter.Page - 1) * filter.Limit).Limit(filter.Limit).Scan(&items).Error
	return NotificationHistoryResult{Items: items, Page: filter.Page, Limit: filter.Limit, Total: total}, err
}

func (s *adminNotifService) GetDetailReceivers(masterID string) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	query := `
        SELECT 
            r.nr_outlet as outlet_id, 
            o.ot_nama as outlet_name,
            r.nr_status as status,
            r.nr_read_at as read_at
        FROM ac_notif_receiver r
        LEFT JOIN ac_outlet o
            ON r.nr_outlet COLLATE utf8mb4_unicode_ci = o.ot_id COLLATE utf8mb4_unicode_ci
        WHERE r.nr_nm_id = ?
        ORDER BY r.nr_status DESC, o.ot_nama ASC
    `
	err := s.db.Raw(query, masterID).Scan(&results).Error
	return results, err
}

func (s *adminNotifService) GetDetailPushTokens(masterID string) ([]map[string]interface{}, error) {
	type pushTokenRow struct {
		OutletID   string     `gorm:"column:outlet_id"`
		OutletName string     `gorm:"column:outlet_name"`
		Token      *string    `gorm:"column:token"`
		Platform   *string    `gorm:"column:platform"`
		AppVersion *string    `gorm:"column:app_version"`
		ActorID    *string    `gorm:"column:actor_id"`
		ActorType  *string    `gorm:"column:actor_type"`
		IsActive   *bool      `gorm:"column:is_active"`
		LastSeenAt *time.Time `gorm:"column:last_seen_at"`
		CreatedAt  *time.Time `gorm:"column:created_at"`
	}

	var rows []pushTokenRow
	query := `
        SELECT
            r.nr_outlet as outlet_id,
            o.ot_nama as outlet_name,
            pt.pt_token as token,
            pt.pt_platform as platform,
            pt.pt_app_version as app_version,
            pt.pt_actor_id as actor_id,
            pt.pt_actor_type as actor_type,
            pt.pt_is_active as is_active,
            pt.pt_last_seen_at as last_seen_at,
            pt.pt_created as created_at
        FROM ac_notif_receiver r
        LEFT JOIN ac_outlet o
            ON r.nr_outlet COLLATE utf8mb4_unicode_ci = o.ot_id COLLATE utf8mb4_unicode_ci
        LEFT JOIN ac_push_tokens pt
            ON pt.pt_outlet COLLATE utf8mb4_unicode_ci = r.nr_outlet COLLATE utf8mb4_unicode_ci
           AND pt.pt_is_active = 1
        WHERE r.nr_nm_id = ?
        ORDER BY o.ot_nama ASC, pt.pt_last_seen_at DESC, pt.pt_created DESC
    `
	if err := s.db.Raw(query, masterID).Scan(&rows).Error; err != nil {
		return nil, err
	}

	results := make([]map[string]interface{}, 0, len(rows))
	seen := make(map[string]struct{}, len(rows))
	for _, row := range rows {
		key := row.OutletID + "|" + strings.TrimSpace(derefString(row.ActorID)) + "|" + strings.TrimSpace(derefString(row.ActorType))
		if derefString(row.Token) == "" {
			key = row.OutletID + "|missing"
		}
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		results = append(results, map[string]interface{}{
			"outlet_id":    row.OutletID,
			"outlet_name":  row.OutletName,
			"token":        derefString(row.Token),
			"platform":     derefString(row.Platform),
			"app_version":  derefString(row.AppVersion),
			"actor_id":     derefString(row.ActorID),
			"actor_type":   derefString(row.ActorType),
			"is_active":    row.IsActive != nil && *row.IsActive,
			"last_seen_at": row.LastSeenAt,
			"created_at":   row.CreatedAt,
		})
	}

	return results, nil
}

func (s *adminNotifService) DeactivatePushToken(outletID string, token string) error {
	return push.DeactivateToken(s.db, token, outletID)
}

func (s *adminNotifService) DeleteBroadcast(masterID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		// 1. Hapus receiver dulu (FK constraint safe)
		if err := tx.Exec("DELETE FROM ac_notif_receiver WHERE nr_nm_id = ?", masterID).Error; err != nil {
			return err
		}
		// 2. Hapus master
		if err := tx.Exec("DELETE FROM ac_notif_master WHERE nm_id = ?", masterID).Error; err != nil {
			return err
		}
		return nil
	})
}

func derefString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}
