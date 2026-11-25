package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type DepositReportService struct{ db *gorm.DB }

func NewDepositReportService(db *gorm.DB) *DepositReportService {
	return &DepositReportService{db: db}
}

func (s *DepositReportService) GetAnalytics(outletID, customerID, start, end string) (map[string]interface{}, error) {
	ledgerWhere := "l.cdl_outlet = ?"
	ledgerParams := []interface{}{outletID}
	topupWhere := "t.cdt_outlet = ?"
	topupParams := []interface{}{outletID}
	accountWhere := "a.cda_outlet = ?"
	accountParams := []interface{}{outletID}
	if start != "" && end != "" {
		ledgerWhere += " AND l.cdl_created BETWEEN ? AND ?"
		ledgerParams = append(ledgerParams, start, end)
		topupWhere += " AND t.cdt_created BETWEEN ? AND ?"
		topupParams = append(topupParams, start, end)
	}
	if customerID != "" {
		ledgerWhere += " AND l.cdl_customer = ?"
		ledgerParams = append(ledgerParams, customerID)
		topupWhere += " AND t.cdt_customer = ?"
		topupParams = append(topupParams, customerID)
		accountWhere += " AND a.cda_customer = ?"
		accountParams = append(accountParams, customerID)
	}

	cacheKey := fmt.Sprintf("finance:deposit_analytics:v4:%s:%s:%s:%s", outletID, customerID, start, end)
	var cached map[string]interface{}
	if database.GetCache(cacheKey, &cached) {
		return cached, nil
	}

	type analytics struct {
		TotalTopUpRupiah     float64 `json:"total_top_up_rupiah"`
		TotalTopUpKg         float64 `json:"total_top_up_kg"`
		TotalUsageRupiah     float64 `json:"total_usage_rupiah"`
		TotalUsageKg         float64 `json:"total_usage_kg"`
		TotalRefundRupiah    float64 `json:"total_refund_rupiah"`
		TotalRefundKg        float64 `json:"total_refund_kg"`
		TotalPaidTopUpRupiah float64 `json:"total_paid_top_up_rupiah"`
		TotalPaidTopUpKg     float64 `json:"total_paid_top_up_kg"`
		TotalDiscountRupiah  float64 `json:"total_discount_rupiah"`
		TotalDiscountKg      float64 `json:"total_discount_kg"`
		CurrentRupiah        float64 `json:"current_rupiah"`
		CurrentKg            float64 `json:"current_kg"`
	}
	var result analytics
	type ledgerTotals struct {
		TotalTopUpRupiah  float64 `gorm:"column:total_top_up_rupiah"`
		TotalTopUpKg      float64 `gorm:"column:total_top_up_kg"`
		TotalUsageRupiah  float64 `gorm:"column:total_usage_rupiah"`
		TotalUsageKg      float64 `gorm:"column:total_usage_kg"`
		TotalRefundRupiah float64 `gorm:"column:total_refund_rupiah"`
		TotalRefundKg     float64 `gorm:"column:total_refund_kg"`
	}
	var ledger ledgerTotals
	ledgerSQL := fmt.Sprintf(`SELECT
		GREATEST(COALESCE(SUM(CASE WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') IN ('TOPUP', 'CORRECTION') AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_top_up_rupiah,
		GREATEST(COALESCE(SUM(CASE WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') IN ('TOPUP', 'CORRECTION') AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_top_up_kg,
		GREATEST(COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE_REVERSAL' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_usage_rupiah,
		GREATEST(COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE_REVERSAL' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_usage_kg,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0) AS total_refund_rupiah,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0) AS total_refund_kg
		FROM ac_customer_deposit_ledger l WHERE %s`, ledgerWhere)
	if err := s.db.Raw(ledgerSQL, ledgerParams...).Scan(&ledger).Error; err != nil {
		return nil, err
	}
	result.TotalTopUpRupiah = ledger.TotalTopUpRupiah
	result.TotalTopUpKg = ledger.TotalTopUpKg
	result.TotalUsageRupiah = ledger.TotalUsageRupiah
	result.TotalUsageKg = ledger.TotalUsageKg
	result.TotalRefundRupiah = ledger.TotalRefundRupiah
	result.TotalRefundKg = ledger.TotalRefundKg
	var paid struct {
		TotalPaidTopUpRupiah float64 `gorm:"column:total_paid_top_up_rupiah"`
		TotalPaidTopUpKg     float64 `gorm:"column:total_paid_top_up_kg"`
		TotalDiscountRupiah  float64 `gorm:"column:total_discount_rupiah"`
		TotalDiscountKg      float64 `gorm:"column:total_discount_kg"`
	}
	paidSQL := fmt.Sprintf(`SELECT
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'RUPIAH' THEN t.cdt_total_paid ELSE 0 END), 0) AS total_paid_top_up_rupiah,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'KG' THEN t.cdt_total_paid ELSE 0 END), 0) AS total_paid_top_up_kg,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'RUPIAH' THEN t.cdt_discount ELSE 0 END), 0) AS total_discount_rupiah,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'KG' THEN t.cdt_discount ELSE 0 END), 0) AS total_discount_kg
		FROM ac_customer_deposit_cash_events t WHERE %s`, topupWhere)
	if err := s.db.Raw(paidSQL, topupParams...).Scan(&paid).Error; err != nil {
		return nil, err
	}
	result.TotalPaidTopUpRupiah = paid.TotalPaidTopUpRupiah
	result.TotalPaidTopUpKg = paid.TotalPaidTopUpKg
	result.TotalDiscountRupiah = paid.TotalDiscountRupiah
	result.TotalDiscountKg = paid.TotalDiscountKg
	var balance struct {
		CurrentRupiah float64 `gorm:"column:current_rupiah"`
		CurrentKg     float64 `gorm:"column:current_kg"`
	}
	balanceSQL := fmt.Sprintf("SELECT COALESCE(SUM(a.cda_balance_rupiah), 0) AS current_rupiah, COALESCE(SUM(a.cda_balance_kg), 0) AS current_kg FROM ac_customer_deposit_accounts a WHERE %s", accountWhere)
	if err := s.db.Raw(balanceSQL, accountParams...).Scan(&balance).Error; err != nil {
		return nil, err
	}
	result.CurrentRupiah = balance.CurrentRupiah
	result.CurrentKg = balance.CurrentKg

	data := map[string]interface{}{"analytics": result}
	database.SetCache(cacheKey, data, 30*time.Second)
	return data, nil
}


func (s *DepositReportService) GetReport(outletID, start, end, activityType, depositType, customerID string, page, limit int) (map[string]interface{}, error) {
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	where := []string{"l.cdl_outlet = ?", "l.cdl_created BETWEEN ? AND ?"}
	params := []interface{}{outletID, start, end}
	if activityType != "" {
		if strings.EqualFold(activityType, "USAGE") {
			where = append(where, "UPPER(TRIM(l.cdl_entry_type)) IN ('USAGE', 'USAGE_REVERSAL')")
		} else {
			where = append(where, "REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') = REPLACE(UPPER(TRIM(?)), '_', '')")
			params = append(params, activityType)
		}
	}
	if depositType != "" {
		where = append(where, "UPPER(TRIM(l.cdl_type)) = UPPER(TRIM(?))")
		params = append(params, depositType)
	}
	if customerID != "" {
		where = append(where, "l.cdl_customer = ?")
		params = append(params, customerID)
	}
	whereSQL := strings.Join(where, " AND ")

	summaryWhere := []string{"l.cdl_outlet = ?", "l.cdl_created BETWEEN ? AND ?"}
	summaryParams := []interface{}{outletID, start, end}
	if depositType != "" {
		summaryWhere = append(summaryWhere, "UPPER(TRIM(l.cdl_type)) = UPPER(TRIM(?))")
		summaryParams = append(summaryParams, depositType)
	}
	if customerID != "" {
		summaryWhere = append(summaryWhere, "l.cdl_customer = ?")
		summaryParams = append(summaryParams, customerID)
	}
	summaryWhereSQL := strings.Join(summaryWhere, " AND ")

	cacheKey := fmt.Sprintf("finance:deposit_report:v5:%s:%s:%s:%s:%s:%s:%d:%d", outletID, start, end, activityType, depositType, customerID, page, limit)
	var cached map[string]interface{}
	if database.GetCache(cacheKey, &cached) {
		return cached, nil
	}

	type row struct {
		ID             string  `json:"id"`
		EntryType      string  `gorm:"column:activity_type" json:"activity_type"`
		DepositType    string  `json:"deposit_type"`
		Amount         float64 `json:"amount"`
		PaidAmount     float64 `gorm:"column:paid_amount" json:"paid_amount,omitempty"`
		DiscountAmount float64 `gorm:"column:discount_amount" json:"discount_amount,omitempty"`
		BalanceBefore  float64 `json:"balance_before"`
		BalanceAfter   float64 `json:"balance_after"`
		CustomerID     string  `json:"customer_id"`
		CustomerName   string  `json:"customer_name"`
		ReferenceID    string  `json:"reference_id"`
		ReferenceType  string  `json:"reference_type"`
		PaymentMethod  string  `json:"payment_method"`
		Note           string  `json:"note"`
		CreatedBy      string  `json:"created_by"`
		CreatedByName  string  `json:"created_by_name"`
		CreatedAt      string  `json:"created_at"`
	}
	var rows []row
	selectSQL := `
		l.cdl_id AS id,
		CASE
			WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') = 'TOPUP' THEN 'TOP_UP'
			ELSE UPPER(TRIM(l.cdl_entry_type))
		END AS activity_type,
		UPPER(TRIM(l.cdl_type)) AS deposit_type,
		l.cdl_amount AS amount,
		COALESCE(CASE WHEN l.cdl_entry_type = 'TOP_UP' THEN topup.cdt_total_paid ELSE adjustment.caj_cash_delta END, 0) AS paid_amount,
		COALESCE(CASE WHEN l.cdl_entry_type = 'TOP_UP' THEN topup.cdt_discount ELSE 0 END, 0) AS discount_amount,
		l.cdl_balance_before AS balance_before,
		l.cdl_balance_after AS balance_after,
		l.cdl_customer AS customer_id,
		COALESCE(NULLIF(p.pl_nama, ''), 'Tanpa Nama') AS customer_name,
		l.cdl_reference AS reference_id,
		CASE
			WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') = 'TOPUP' THEN 'TOP_UP'
			WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE' THEN 'TRANSACTION'
			WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE_REVERSAL' THEN 'TRANSACTION'
			WHEN UPPER(TRIM(l.cdl_entry_type)) IN ('REFUND', 'CORRECTION') THEN 'DEPOSIT_ADJUSTMENT'
			ELSE 'OTHER'
		END AS reference_type,
		COALESCE(mp.mp_nama_metode, adjustment_method.mp_nama_metode, '') AS payment_method,
		l.cdl_note AS note,
		l.cdl_created_by AS created_by,
		COALESCE(NULLIF(pg.pg_nama, ''), NULLIF(u.usr_nama, ''), 'Sistem') AS created_by_name,
		DATE_FORMAT(l.cdl_created, '%Y-%m-%dT%H:%i:%s') AS created_at`
	query := fmt.Sprintf(`SELECT %s
		FROM ac_customer_deposit_ledger l
		LEFT JOIN ac_pelanggan p ON p.pl_id = l.cdl_customer
		LEFT JOIN ac_customer_deposit_topups topup ON topup.cdt_id = l.cdl_reference
		LEFT JOIN ac_customer_deposit_adjustments adjustment ON adjustment.caj_id = l.cdl_reference AND l.cdl_entry_type IN ('CORRECTION', 'REFUND')
		LEFT JOIN ac_metode_pembayaran mp ON mp.mp_id = topup.cdt_payment_method
		LEFT JOIN ac_metode_pembayaran adjustment_method ON adjustment_method.mp_id = adjustment.caj_payment_method
		LEFT JOIN ac_pegawai pg ON pg.pg_id = l.cdl_created_by AND l.cdl_created_by_type = 'pegawai'
		LEFT JOIN ac_user u ON l.cdl_created_by = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND l.cdl_created_by_type = 'user'
		WHERE %s ORDER BY l.cdl_created DESC LIMIT ? OFFSET ?`, selectSQL, whereSQL)
	queryParams := append(append([]interface{}{}, params...), limit, (page-1)*limit)
	if err := s.db.Raw(query, queryParams...).Scan(&rows).Error; err != nil {
		return nil, err
	}

	var header struct {
		TotalEntries         int64   `json:"total_entries" gorm:"column:total_entries"`
		TotalTopUp           float64 `json:"total_top_up" gorm:"column:total_top_up"`
		TotalUsage           float64 `json:"total_usage" gorm:"column:total_usage"`
		TotalRefund          float64 `json:"total_refund" gorm:"column:total_refund"`
		TotalTopUpRupiah     float64 `json:"total_top_up_rupiah" gorm:"column:total_top_up_rupiah"`
		TotalTopUpKg         float64 `json:"total_top_up_kg" gorm:"column:total_top_up_kg"`
		TotalUsageRupiah     float64 `json:"total_usage_rupiah" gorm:"column:total_usage_rupiah"`
		TotalUsageKg         float64 `json:"total_usage_kg" gorm:"column:total_usage_kg"`
		TotalRefundRupiah    float64 `json:"total_refund_rupiah" gorm:"column:total_refund_rupiah"`
		TotalRefundKg        float64 `json:"total_refund_kg" gorm:"column:total_refund_kg"`
		TotalPaidTopUpRupiah float64 `json:"total_paid_top_up_rupiah" gorm:"column:total_paid_top_up_rupiah"`
		TotalPaidTopUpKg     float64 `json:"total_paid_top_up_kg" gorm:"column:total_paid_top_up_kg"`
		TotalDiscountRupiah  float64 `json:"total_discount_rupiah" gorm:"column:total_discount_rupiah"`
		TotalDiscountKg      float64 `json:"total_discount_kg" gorm:"column:total_discount_kg"`
		CustomersActive      int64   `json:"customers_active" gorm:"column:customers_active"`
		CurrentRupiah        float64 `json:"current_rupiah" gorm:"column:current_rupiah"`
		CurrentKg            float64 `json:"current_kg" gorm:"column:current_kg"`
	}
	countSQL := fmt.Sprintf(`SELECT COUNT(*) AS total_entries,
		GREATEST(COALESCE(SUM(CASE WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') IN ('TOPUP', 'CORRECTION') THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_top_up,
		GREATEST(COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE_REVERSAL' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_usage,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' THEN l.cdl_amount ELSE 0 END), 0) AS total_refund,
		GREATEST(COALESCE(SUM(CASE WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') IN ('TOPUP', 'CORRECTION') AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_top_up_rupiah,
		GREATEST(COALESCE(SUM(CASE WHEN REPLACE(UPPER(TRIM(l.cdl_entry_type)), '_', '') IN ('TOPUP', 'CORRECTION') AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_top_up_kg,
		GREATEST(COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE_REVERSAL' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_usage_rupiah,
		GREATEST(COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0) - COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'USAGE_REVERSAL' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0), 0) AS total_usage_kg,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'RUPIAH' THEN l.cdl_amount ELSE 0 END), 0) AS total_refund_rupiah,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(l.cdl_entry_type)) = 'REFUND' AND UPPER(TRIM(l.cdl_type)) = 'KG' THEN l.cdl_amount ELSE 0 END), 0) AS total_refund_kg,
		COUNT(DISTINCT l.cdl_customer) AS customers_active
		FROM ac_customer_deposit_ledger l WHERE %s`, summaryWhereSQL)
	if err := s.db.Raw(countSQL, summaryParams...).Scan(&header).Error; err != nil {
		return nil, err
	}

	var paid struct {
		Rupiah         float64 `gorm:"column:total_paid_top_up_rupiah"`
		Kg             float64 `gorm:"column:total_paid_top_up_kg"`
		DiscountRupiah float64 `gorm:"column:total_discount_rupiah"`
		DiscountKg     float64 `gorm:"column:total_discount_kg"`
	}
	topupWhere := []string{"t.cdt_outlet = ?", "t.cdt_created BETWEEN ? AND ?"}
	topupParams := []interface{}{outletID, start, end}
	if depositType != "" {
		topupWhere = append(topupWhere, "UPPER(TRIM(t.cdt_type)) = UPPER(TRIM(?))")
		topupParams = append(topupParams, depositType)
	}
	if customerID != "" {
		topupWhere = append(topupWhere, "t.cdt_customer = ?")
		topupParams = append(topupParams, customerID)
	}
	paidSQL := fmt.Sprintf(`SELECT
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'RUPIAH' THEN t.cdt_total_paid ELSE 0 END), 0) AS total_paid_top_up_rupiah,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'KG' THEN t.cdt_total_paid ELSE 0 END), 0) AS total_paid_top_up_kg,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'RUPIAH' THEN t.cdt_discount ELSE 0 END), 0) AS total_discount_rupiah,
		COALESCE(SUM(CASE WHEN UPPER(TRIM(t.cdt_type)) = 'KG' THEN t.cdt_discount ELSE 0 END), 0) AS total_discount_kg
		FROM ac_customer_deposit_cash_events t WHERE %s`, strings.Join(topupWhere, " AND "))
	if err := s.db.Raw(paidSQL, topupParams...).Scan(&paid).Error; err != nil {
		return nil, err
	}
	header.TotalPaidTopUpRupiah = paid.Rupiah
	header.TotalPaidTopUpKg = paid.Kg
	header.TotalDiscountRupiah = paid.DiscountRupiah
	header.TotalDiscountKg = paid.DiscountKg
	var balance struct {
		CurrentRupiah float64 `gorm:"column:current_rupiah"`
		CurrentKg     float64 `gorm:"column:current_kg"`
	}
	balanceQuery := s.db.Table("ac_customer_deposit_accounts a").Where("a.cda_outlet = ?", outletID)
	if customerID != "" {
		balanceQuery = balanceQuery.Where("a.cda_customer = ?", customerID)
	}
	if err := balanceQuery.Select("COALESCE(SUM(a.cda_balance_rupiah), 0) AS current_rupiah, COALESCE(SUM(a.cda_balance_kg), 0) AS current_kg").Scan(&balance).Error; err != nil {
		return nil, err
	}
	header.CurrentRupiah = balance.CurrentRupiah
	header.CurrentKg = balance.CurrentKg

	result := map[string]interface{}{"header": header, "data": rows, "page": page, "limit": limit}
	database.SetCache(cacheKey, result, 30*time.Second)
	return result, nil
}
