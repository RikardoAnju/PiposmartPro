package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"database/sql"
	"fmt"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
	"math"
	"strings"
	"time"
)

type CustomerDepositService struct{ db *gorm.DB }

type CustomerDepositLedgerPage struct {
	Items          []model.CustomerDepositLedger `json:"items"`
	Page           int                           `json:"page"`
	Limit          int                           `json:"limit"`
	Total          int64                         `json:"total"`
	TotalPages     int                           `json:"total_pages"`
	LastActivityAt *time.Time                    `json:"last_activity_at,omitempty"`
}

const (
	maxCustomerDepositRupiah = 999999999
	maxCustomerDepositKg     = 999999
)

func validDepositPrecision(typ string, value, paid float64) bool {
	if math.IsNaN(value) || math.IsInf(value, 0) || math.IsNaN(paid) || math.IsInf(paid, 0) {
		return false
	}
	if math.Abs(paid-math.Round(paid)) > 0.000001 {
		return false
	}
	if typ == "KG" {
		return math.Abs(value*100-math.Round(value*100)) <= 0.000001
	}
	return math.Abs(value-math.Round(value)) <= 0.000001
}

func NewCustomerDepositService(db *gorm.DB) *CustomerDepositService {
	return &CustomerDepositService{db: db}
}

func (s *CustomerDepositService) Balance(customerID, outletID string) (model.CustomerDepositAccount, error) {
	var a model.CustomerDepositAccount
	err := s.db.Where("cda_customer = ? AND cda_outlet = ?", customerID, outletID).First(&a).Error
	if err == gorm.ErrRecordNotFound {
		return model.CustomerDepositAccount{ID: uuid.New().String(), CustomerID: customerID, OutletID: outletID}, nil
	}
	return a, err
}
func (s *CustomerDepositService) Ledger(customerID, outletID string) ([]model.CustomerDepositLedger, error) {
	result, err := s.LedgerPage(customerID, outletID, "", "", 1, 100000)
	return result.Items, err
}

func (s *CustomerDepositService) LedgerPage(customerID, outletID, startDate, endDate string, page, limit int) (CustomerDepositLedgerPage, error) {
	type ledgerRow struct {
		model.CustomerDepositLedger
		CreatedByName     string  `gorm:"column:created_by_name"`
		ResolvedActorType string  `gorm:"column:resolved_actor_type"`
		LedgerPaidAmount  float64 `gorm:"column:paid_amount"`
		DiscountAmount    float64 `gorm:"column:discount_amount"`
		MethodName        string  `gorm:"column:payment_method"`
	}
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 30
	}
	if limit > 100000 {
		limit = 100000
	}

	base := s.db.Table("ac_customer_deposit_ledger l").
		Where("l.cdl_customer = ? AND l.cdl_outlet = ?", customerID, outletID)
	if startDate != "" {
		base = base.Where("l.cdl_created >= ?", startDate+" 00:00:00")
	}
	if endDate != "" {
		if parsed, err := time.Parse("2006-01-02", endDate); err == nil {
			base = base.Where("l.cdl_created < ?", parsed.AddDate(0, 0, 1).Format("2006-01-02")+" 00:00:00")
		}
	}

	var total int64
	if err := base.Count(&total).Error; err != nil {
		return CustomerDepositLedgerPage{}, err
	}
	var lastActivity sql.NullTime
	if err := s.db.Table("ac_customer_deposit_ledger").
		Where("cdl_customer = ? AND cdl_outlet = ?", customerID, outletID).
		Select("MAX(cdl_created)").Scan(&lastActivity).Error; err != nil {
		return CustomerDepositLedgerPage{}, err
	}
	var lastActivityAt *time.Time
	if lastActivity.Valid {
		lastActivityAt = &lastActivity.Time
	}

	var scanned []ledgerRow
	err := base.
		Select(`l.*, COALESCE(CASE WHEN l.cdl_entry_type = 'TOP_UP' THEN t.cdt_total_paid ELSE aj.caj_cash_delta END, 0) AS paid_amount,
			COALESCE(CASE WHEN l.cdl_entry_type = 'TOP_UP' THEN t.cdt_discount ELSE 0 END, 0) AS discount_amount,
			COALESCE(t_method.mp_nama_metode, aj_method.mp_nama_metode, '') AS payment_method,
			COALESCE(NULLIF(pg.pg_nama, ''), NULLIF(u.usr_nama, ''), 'Sistem') AS created_by_name,
			CASE WHEN pg.pg_id IS NOT NULL THEN 'pegawai'
			     WHEN u.usr_id IS NOT NULL THEN 'user'
			     ELSE COALESCE(NULLIF(l.cdl_created_by_type, ''), 'system') END AS resolved_actor_type`).
		Joins("LEFT JOIN ac_pegawai pg ON l.cdl_created_by = pg.pg_id AND (l.cdl_created_by_type = 'pegawai' OR l.cdl_created_by_type = '')").
		Joins("LEFT JOIN ac_customer_deposit_topups t ON l.cdl_reference = t.cdt_id AND l.cdl_entry_type = 'TOP_UP'").
		Joins("LEFT JOIN ac_customer_deposit_adjustments aj ON l.cdl_reference = aj.caj_id AND l.cdl_entry_type IN ('CORRECTION', 'REFUND')").
		Joins("LEFT JOIN ac_metode_pembayaran t_method ON t_method.mp_id = t.cdt_payment_method").
		Joins("LEFT JOIN ac_metode_pembayaran aj_method ON aj_method.mp_id = aj.caj_payment_method").
		Joins("LEFT JOIN ac_user u ON l.cdl_created_by = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND (l.cdl_created_by_type = 'user' OR l.cdl_created_by_type = '')").
		Order("l.cdl_created DESC").
		Limit(limit).Offset((page - 1) * limit).
		Scan(&scanned).Error
	rows := make([]model.CustomerDepositLedger, 0, len(scanned))
	for _, row := range scanned {
		entry := row.CustomerDepositLedger
		entry.CreatedByName = row.CreatedByName
		entry.PaidAmount = row.LedgerPaidAmount
		entry.DiscountAmount = row.DiscountAmount
		entry.PaymentMethod = row.MethodName
		if row.ResolvedActorType != "" {
			entry.CreatedByType = row.ResolvedActorType
		}
		rows = append(rows, entry)
	}
	totalPages := 0
	if total > 0 {
		totalPages = int((total + int64(limit) - 1) / int64(limit))
	}
	return CustomerDepositLedgerPage{
		Items:          rows,
		Page:           page,
		Limit:          limit,
		Total:          total,
		TotalPages:     totalPages,
		LastActivityAt: lastActivityAt,
	}, err
}
func (s *CustomerDepositService) LedgerEntry(customerID, entryID, outletID string) (model.CustomerDepositLedger, error) {
	rows, err := s.Ledger(customerID, outletID)
	if err != nil {
		return model.CustomerDepositLedger{}, err
	}
	for _, row := range rows {
		if row.ID == entryID {
			return row, nil
		}
	}
	return model.CustomerDepositLedger{}, gorm.ErrRecordNotFound
}
func (s *CustomerDepositService) TopUp(customerID, outletID, actorID, actorType, requestID, typ, paymentMethod, note string, value, paid, discount float64) (model.CustomerDepositAccount, error) {
	if typ != "RUPIAH" && typ != "KG" {
		return model.CustomerDepositAccount{}, fmt.Errorf("deposit_type harus RUPIAH atau KG")
	}
	if value <= 0 || paid < 0 || discount < 0 {
		return model.CustomerDepositAccount{}, fmt.Errorf("nilai deposit tidak valid")
	}
	if !validDepositPrecision(typ, value, paid) || math.Abs(discount-math.Round(discount)) > 0.000001 {
		return model.CustomerDepositAccount{}, fmt.Errorf("rupiah dan kas harus bilangan bulat; kiloan maksimal 2 desimal")
	}
	if typ == "RUPIAH" && value > maxCustomerDepositRupiah {
		return model.CustomerDepositAccount{}, fmt.Errorf("maksimal deposit rupiah Rp999.999.999")
	}
	if typ == "KG" && value > maxCustomerDepositKg {
		return model.CustomerDepositAccount{}, fmt.Errorf("maksimal deposit kiloan 999.999 kg")
	}
	if paid > maxCustomerDepositRupiah {
		return model.CustomerDepositAccount{}, fmt.Errorf("maksimal kas diterima Rp999.999.999")
	}
	if typ == "RUPIAH" && paid > value {
		return model.CustomerDepositAccount{}, fmt.Errorf("kas diterima tidak boleh melebihi nominal deposit")
	}
	if typ == "RUPIAH" && math.Abs((paid+discount)-value) > 0.000001 {
		return model.CustomerDepositAccount{}, fmt.Errorf("kas diterima ditambah diskon harus sama dengan nominal deposit")
	}
	var configuredMethod model.MetodePembayaran
	if paymentMethod == "" || s.db.Where("mp_id = ? AND mp_outlet = ? AND mp_status = 1", paymentMethod, outletID).First(&configuredMethod).Error != nil {
		return model.CustomerDepositAccount{}, fmt.Errorf("metode pembayaran tidak valid atau tidak aktif")
	}
	if strings.EqualFold(strings.TrimSpace(configuredMethod.Kategori), "QRIS") && strings.EqualFold(strings.TrimSpace(configuredMethod.Nama), "QRIS Nobu") {
		return model.CustomerDepositAccount{}, fmt.Errorf("QRIS Nobu belum tersedia untuk top up deposit")
	}
	if requestID != "" {
		var previous model.CustomerDepositTopup
		if err := s.db.Where("cdt_request_id = ?", requestID).First(&previous).Error; err == nil {
			return s.Balance(customerID, outletID)
		}
	}
	var out model.CustomerDepositAccount
	var topupID string
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var a model.CustomerDepositAccount
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("cda_customer = ? AND cda_outlet = ?", customerID, outletID).First(&a).Error; err == gorm.ErrRecordNotFound {
			a = model.CustomerDepositAccount{ID: uuid.New().String(), CustomerID: customerID, OutletID: outletID}
			if err := tx.Create(&a).Error; err != nil {
				return err
			}
		} else if err != nil {
			return err
		}
		before := a.BalanceRupiah
		if typ == "KG" {
			before = a.BalanceKg
		}
		if typ == "KG" {
			a.BalanceKg += value
		} else {
			a.BalanceRupiah += value
		}
		if err := tx.Save(&a).Error; err != nil {
			return err
		}
		topupID = uuid.New().String()
		if err := tx.Create(&model.CustomerDepositTopup{ID: topupID, AccountID: a.ID, CustomerID: customerID, OutletID: outletID, DepositType: typ, Value: value, TotalPaid: paid, DiscountAmount: discount, PaymentMethodID: paymentMethod, Note: note, CreatedBy: actorID, RequestID: requestID}).Error; err != nil {
			return err
		}
		if err := tx.Create(&model.CustomerDepositLedger{ID: uuid.New().String(), AccountID: a.ID, CustomerID: customerID, OutletID: outletID, EntryType: "TOP_UP", DepositType: typ, Amount: value, BalanceBefore: before, BalanceAfter: before + value, ReferenceID: topupID, Note: note, CreatedBy: actorID, CreatedByType: actorType}).Error; err != nil {
			return err
		}
		out = a
		return nil
	})
	// Dua request dengan idempotency key yang sama dapat tiba nyaris bersamaan.
	// Unique index memastikan hanya satu transaksi tersimpan; request lainnya
	// tetap dianggap sukses setelah transaksi pertama selesai.
	if err != nil && requestID != "" {
		var existing int64
		if lookupErr := s.db.Model(&model.CustomerDepositTopup{}).Where("cdt_request_id = ?", requestID).Count(&existing).Error; lookupErr == nil && existing > 0 {
			return s.Balance(customerID, outletID)
		}
	}
	if err == nil {
		database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID))
		database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID))
		database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
			"type": "DEPOSIT_UPDATED",
			"payload": map[string]interface{}{
				"customer_id": customerID,
				"topup_id":    topupID,
			},
		})
	}
	return out, err
}

// AdjustTopUp records an audited correction or refund. Corrections restate the
// original top-up period without creating cash movement today. Refunds remain
// dated cash outflows and therefore require an active payment method.
func (s *CustomerDepositService) AdjustTopUp(customerID, outletID, topupID, actorID, actorType, requestID, kind, methodID, note string, value, paid, expectedValue, expectedPaid float64) (model.CustomerDepositAdjustment, error) {
	var out model.CustomerDepositAdjustment
	if requestID == "" || strings.TrimSpace(note) == "" || len(note) > 500 || (kind != "CORRECTION" && kind != "REFUND") {
		return out, fmt.Errorf("jenis, alasan, dan request_id wajib diisi")
	}
	if math.IsNaN(value) || math.IsInf(value, 0) || math.IsNaN(paid) || math.IsInf(paid, 0) || value < 0 || paid < 0 {
		return out, fmt.Errorf("nilai koreksi tidak valid")
	}
	if kind == "REFUND" && value <= 0 {
		return out, fmt.Errorf("nominal pengembalian harus lebih besar dari nol")
	}
	if value > maxCustomerDepositRupiah || paid > maxCustomerDepositRupiah {
		return out, fmt.Errorf("nominal penyesuaian melebihi batas")
	}
	if kind == "REFUND" {
		if methodID == "" {
			return out, fmt.Errorf("metode pengembalian kas wajib dipilih")
		}
		var method model.MetodePembayaran
		if err := s.db.Where("mp_id = ? AND mp_outlet = ? AND mp_status = 1", methodID, outletID).First(&method).Error; err != nil {
			return out, fmt.Errorf("metode pembayaran tidak valid")
		}
		if strings.EqualFold(strings.TrimSpace(method.Kategori), "QRIS") && strings.EqualFold(strings.TrimSpace(method.Nama), "QRIS Nobu") {
			return out, fmt.Errorf("QRIS Nobu belum tersedia untuk refund deposit")
		}
	}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// Lock the account first so concurrent usage/top-ups cannot make the
		// balance negative while this adjustment is being approved.
		var topup model.CustomerDepositTopup
		if err := tx.Where("cdt_id = ? AND cdt_customer = ? AND cdt_outlet = ?", topupID, customerID, outletID).First(&topup).Error; err != nil {
			return fmt.Errorf("top up tidak ditemukan")
		}
		if kind == "CORRECTION" {
			methodID = topup.PaymentMethodID
		}
		var account model.CustomerDepositAccount
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("cda_id = ? AND cda_customer = ? AND cda_outlet = ?", topup.AccountID, customerID, outletID).First(&account).Error; err != nil {
			return fmt.Errorf("saldo deposit tidak ditemukan")
		}
		var previous model.CustomerDepositAdjustment
		if err := tx.Where("caj_request_id = ?", requestID).First(&previous).Error; err == nil {
			if previous.TopupID != topupID || previous.CustomerID != customerID {
				return fmt.Errorf("request_id sudah digunakan")
			}
			out = previous
			return nil
		}
		var totals struct {
			Value float64 `gorm:"column:value_delta"`
			Cash  float64 `gorm:"column:cash_delta"`
		}
		if err := tx.Model(&model.CustomerDepositAdjustment{}).
			Select("COALESCE(SUM(caj_value_delta), 0) AS value_delta, COALESCE(SUM(caj_cash_delta), 0) AS cash_delta").
			Where("caj_topup = ? AND caj_outlet = ?", topupID, outletID).Scan(&totals).Error; err != nil {
			return err
		}
		currentValue := topup.Value + totals.Value
		currentPaid := topup.TotalPaid + totals.Cash
		if topup.DepositType == "KG" && value > maxCustomerDepositKg {
			return fmt.Errorf("maksimal deposit kiloan 999.999 kg")
		}
		if !validDepositPrecision(topup.DepositType, value, paid) {
			return fmt.Errorf("rupiah dan kas harus bilangan bulat; kiloan maksimal 2 desimal")
		}
		if math.Abs(currentValue-expectedValue) > 0.000001 || math.Abs(currentPaid-expectedPaid) > 0.000001 {
			return fmt.Errorf("top up telah berubah; muat ulang detail sebelum menyetujui")
		}
		before := account.BalanceRupiah
		if topup.DepositType == "KG" {
			before = account.BalanceKg
		}
		valueDelta, cashDelta, calcErr := calculateDepositAdjustment(kind, value, paid, currentValue, currentPaid, before)
		if calcErr != nil {
			return calcErr
		}
		if topup.DepositType == "KG" {
			account.BalanceKg += valueDelta
		} else {
			account.BalanceRupiah += valueDelta
		}
		if err := tx.Save(&account).Error; err != nil {
			return err
		}
		out = model.CustomerDepositAdjustment{
			ID: uuid.New().String(), TopupID: topupID, AccountID: account.ID,
			CustomerID: customerID, OutletID: outletID, Kind: kind,
			DepositType: topup.DepositType, ValueDelta: valueDelta,
			CashDelta: cashDelta, PaymentMethodID: methodID, Note: strings.TrimSpace(note),
			CreatedBy: actorID, CreatedByType: actorType, RequestID: requestID,
		}
		if err := tx.Create(&out).Error; err != nil {
			return err
		}
		ledgerAmount := valueDelta
		if kind == "REFUND" {
			ledgerAmount = -valueDelta
		}
		return tx.Create(&model.CustomerDepositLedger{
			ID: uuid.New().String(), AccountID: account.ID, CustomerID: customerID,
			OutletID: outletID, EntryType: kind, DepositType: topup.DepositType,
			Amount: ledgerAmount, BalanceBefore: before, BalanceAfter: before + valueDelta,
			ReferenceID: out.ID, Note: out.Note, CreatedBy: actorID, CreatedByType: actorType,
		}).Error
	})
	if err == nil {
		database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID))
		database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID))
		database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
			"type": "DEPOSIT_UPDATED", "payload": map[string]interface{}{
				"customer_id": customerID, "topup_id": topupID,
			},
		})
	}
	return out, err
}

func calculateDepositAdjustment(kind string, value, paid, currentValue, currentPaid, balance float64) (float64, float64, error) {
	var valueDelta, cashDelta float64
	if kind == "CORRECTION" {
		valueDelta = value - currentValue
		cashDelta = paid - currentPaid
	} else {
		valueDelta = -value
		cashDelta = -paid
	}
	if math.Abs(valueDelta) < 0.000001 && math.Abs(cashDelta) < 0.000001 {
		return 0, 0, fmt.Errorf("tidak ada selisih untuk dikoreksi")
	}
	if currentValue+valueDelta < -0.000001 || currentPaid+cashDelta < -0.000001 {
		return 0, 0, fmt.Errorf("koreksi melebihi nilai top up tersisa")
	}
	if balance+valueDelta < -0.000001 {
		return 0, 0, fmt.Errorf("saldo sudah terpakai; koreksi atau refund tidak dapat diproses")
	}
	return valueDelta, cashDelta, nil
}

func (s *CustomerDepositService) AdjustmentState(customerID, outletID, topupID string) (map[string]interface{}, error) {
	var topup model.CustomerDepositTopup
	if err := s.db.Where("cdt_id = ? AND cdt_customer = ? AND cdt_outlet = ?", topupID, customerID, outletID).First(&topup).Error; err != nil {
		return nil, fmt.Errorf("top up tidak ditemukan")
	}
	var totals struct {
		Value float64 `gorm:"column:value_delta"`
		Cash  float64 `gorm:"column:cash_delta"`
		Count int64   `gorm:"column:adjustment_count"`
	}
	if err := s.db.Model(&model.CustomerDepositAdjustment{}).
		Select("COALESCE(SUM(caj_value_delta), 0) AS value_delta, COALESCE(SUM(caj_cash_delta), 0) AS cash_delta, COUNT(*) AS adjustment_count").
		Where("caj_topup = ? AND caj_outlet = ?", topupID, outletID).Scan(&totals).Error; err != nil {
		return nil, err
	}
	// Keep the original top-up immutable, but expose each dated adjustment so
	// the client can explain deposit movement separately from cash movement.
	type adjustmentEvent struct {
		ID            string    `json:"id" gorm:"column:id"`
		Kind          string    `json:"kind" gorm:"column:kind"`
		ValueDelta    float64   `json:"value_delta" gorm:"column:value_delta"`
		CashDelta     float64   `json:"cash_delta" gorm:"column:cash_delta"`
		PaymentMethod string    `json:"payment_method" gorm:"column:payment_method"`
		Note          string    `json:"note" gorm:"column:note"`
		CreatedByName string    `json:"created_by_name" gorm:"column:created_by_name"`
		CreatedAt     time.Time `json:"created_at" gorm:"column:created_at"`
	}
	events := make([]adjustmentEvent, 0)
	if err := s.db.Table("ac_customer_deposit_adjustments a").
		Select(`a.caj_id AS id, a.caj_kind AS kind, a.caj_value_delta AS value_delta,
			a.caj_cash_delta AS cash_delta, COALESCE(mp.mp_nama_metode, '') AS payment_method,
			a.caj_note AS note, COALESCE(NULLIF(pg.pg_nama, ''), NULLIF(u.usr_nama, ''), 'Sistem') AS created_by_name,
			a.caj_created AS created_at`).
		Joins("LEFT JOIN ac_metode_pembayaran mp ON mp.mp_id = a.caj_payment_method").
		Joins("LEFT JOIN ac_pegawai pg ON pg.pg_id = a.caj_created_by AND a.caj_created_by_type = 'pegawai'").
		Joins("LEFT JOIN ac_user u ON a.caj_created_by = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND a.caj_created_by_type = 'user'").
		Where("a.caj_topup = ? AND a.caj_customer = ? AND a.caj_outlet = ?", topupID, customerID, outletID).
		Order("a.caj_created ASC, a.caj_id ASC").Scan(&events).Error; err != nil {
		return nil, err
	}
	return map[string]interface{}{
		"deposit_type":      topup.DepositType,
		"current_value":     topup.Value + totals.Value,
		"current_paid":      topup.TotalPaid + totals.Cash,
		"original_value":    topup.Value,
		"original_paid":     topup.TotalPaid,
		"adjustment_count":  totals.Count,
		"events":            events,
		"payment_method_id": topup.PaymentMethodID,
		"topup_created_at":  topup.CreatedAt,
	}, nil
}
