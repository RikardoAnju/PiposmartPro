package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"fmt"
	"time"

	"gorm.io/gorm"
)

type SummaryService struct {
	db *gorm.DB
}

func NewSummaryService(db *gorm.DB) *SummaryService {
	return &SummaryService{db: db}
}

func (s *SummaryService) getOutletLocation(outletID string) *time.Location {
	var ot model.Outlet
	if err := s.db.Select("ot_timezone").Where("ot_id = ?", outletID).First(&ot).Error; err != nil {
		return time.FixedZone("WIB", 7*3600)
	}
	return ot.GetLocation()
}

func (s *SummaryService) GetDashboardSummary(outletID string) (model.HomeSummaryDTO, error) {
	cacheKey := fmt.Sprintf("summary:dashboard:%s", outletID)
	var summary model.HomeSummaryDTO

	if database.GetCache(cacheKey, &summary) {
		return summary, nil
	}

	loc := s.getOutletLocation(outletID)
	now := time.Now().In(loc) // Gunakan waktu lokal outlet

	// SOLUSI TERBAIK: Pakai Range BETWEEN yang sudah dikonversi ke timezone DB (+07:00)
	dbLoc := time.FixedZone("WIB", 7*3600)
	startLocal := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	endLocal := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, 0, loc)

	startDB := startLocal.In(dbLoc).Format("2006-01-02 15:04:05")
	endDB := endLocal.In(dbLoc).Format("2006-01-02 15:04:05")

	// 1. PENDAPATAN HARI INI: pembayaran langsung + uang top up deposit.
	// Pemakaian deposit dikeluarkan karena uangnya sudah diterima saat top up.
	s.db.Table("ac_dp_transaksi dp").
		Joins("JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id").
		Where("t.tr_outlet = ? AND t.tr_status_order != ? AND dp.dptr_tanggal_dp BETWEEN ? AND ? AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')", outletID, "Batal", startDB, endDB).
		Select("COALESCE(SUM(dp.dptr_jumlah_dp), 0)").
		Scan(&summary.PendapatanHariIni)
	var topUpIncome float64
	s.db.Table("ac_customer_deposit_cash_events").
		Where("cdt_outlet = ? AND cdt_created BETWEEN ? AND ?", outletID, startDB, endDB).
		Select("COALESCE(SUM(cdt_total_paid), 0)").
		Scan(&topUpIncome)
	summary.PendapatanHariIni += topUpIncome

	// 2. PENJUALAN (Omzet Nota Hari Ini - Non Batal)
	s.db.Table("ac_transaksi").
		Where("tr_outlet = ? AND tr_created BETWEEN ? AND ? AND tr_status_order != ?", outletID, startDB, endDB, "Batal").
		Select("COALESCE(SUM(tr_total), 0)").
		Scan(&summary.Penjualan)

	// 3. TOTAL TRANSAKSI
	s.db.Table("ac_transaksi").
		Where("tr_outlet = ? AND tr_status_order != ? AND tr_created BETWEEN ? AND ?", outletID, "Batal", startDB, endDB).
		Count(&summary.TotalTransaksi)

	// 4. PENGELUARAN
	s.db.Table("ac_pengeluaran").
		Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, startDB, endDB).
		Select("COALESCE(SUM(pg_total), 0)").
		Scan(&summary.Pengeluaran)

	summary.ServerTime = now.Format("2006-01-02 15:04:05")

	// Store in Cache (5 min TTL)
	database.SetCache(cacheKey, summary, 5*time.Minute)

	return summary, nil
}

func (s *SummaryService) GetAggregatedSummary(outletID string) (map[string]interface{}, error) {
	cacheKey := fmt.Sprintf("summary:aggregated:v4:%s", outletID)
	var cachedData map[string]interface{}

	if database.GetCache(cacheKey, &cachedData) {
		return cachedData, nil
	}

	loc := s.getOutletLocation(outletID)
	now := time.Now().In(loc)
	dbLoc := time.FixedZone("WIB", 7*3600)

	startLocal := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	endLocal := time.Date(now.Year(), now.Month(), now.Day(), 23, 59, 59, 0, loc)

	todayStart := startLocal.In(dbLoc).Format("2006-01-02 15:04:05")
	todayEnd := endLocal.In(dbLoc).Format("2006-01-02 15:04:05")
	nowDB := now.In(dbLoc).Format("2006-01-02 15:04:05")

	counts := make(map[string]int64)
	items := make(map[string][]model.QueueDTO)

	estimateExpr := "COALESCE(t.tr_estimate, (SELECT MAX(dtr_ready_at) FROM ac_detail_transaksi WHERE dtr_transaksi = t.tr_id))"
	categories := map[string]string{
		"Pesanan Terlambat": fmt.Sprintf("t.tr_status_order NOT IN ('Selesai', 'Batal') AND %s < ?", estimateExpr),
		"Harus Selesai":     fmt.Sprintf("t.tr_status_order NOT IN ('Selesai', 'Batal') AND %s >= ? AND %s <= ?", estimateExpr, estimateExpr),
		"Baru Masuk":        fmt.Sprintf("t.tr_status_order NOT IN ('Selesai', 'Batal') AND t.tr_created >= ? AND t.tr_created <= ? AND (%s IS NULL OR %s > ?)", estimateExpr, estimateExpr),
		"Selesai":           "t.tr_status_order = 'Selesai' AND t.tr_lastupdate >= ? AND t.tr_lastupdate <= ?",
	}

	for key, condition := range categories {
		var result []model.QueueDTO
		baseQuery := s.db.Table("ac_transaksi t").
			Joins("LEFT JOIN ac_detail_transaksi d ON d.dtr_transaksi = t.tr_id").
			Where("t.tr_outlet = ?", outletID)

		switch key {
		case "Pesanan Terlambat":
			baseQuery = baseQuery.Where(condition, nowDB)
		case "Harus Selesai":
			baseQuery = baseQuery.Where(condition, nowDB, todayEnd)
		case "Baru Masuk":
			baseQuery = baseQuery.Where(condition, todayStart, todayEnd, todayEnd)
		default:
			baseQuery = baseQuery.Where(condition, todayStart, todayEnd)
		}

		var total int64
		if err := baseQuery.Session(&gorm.Session{}).
			Distinct("t.tr_id").
			Count(&total).Error; err != nil {
			items[key] = []model.QueueDTO{}
			counts[key] = 0
			continue
		}

		query := baseQuery.Session(&gorm.Session{}).
			Select(`t.tr_id, t.tr_id as tr_invoice, p.pl_nama as pelanggan_nama, 
                    t.tr_total as tr_total, 
                    t.tr_status_pembayaran, t.tr_status_order, t.tr_created,
                    COALESCE(t.tr_estimate, MAX(d.dtr_ready_at)) as tr_estimate`).
			Joins("LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id")

		// Grouping & Execute
		err := query.Group("t.tr_id, p.pl_nama, t.tr_total, t.tr_status_pembayaran, t.tr_status_order, t.tr_created, t.tr_estimate").
			Order("t.tr_created DESC").
			Limit(20).
			Scan(&result).Error

		if err != nil {
			items[key] = []model.QueueDTO{}
			counts[key] = 0
		} else {
			items[key] = result
			counts[key] = total
		}
	}

	res := map[string]interface{}{
		"counts": counts,
		"items":  items,
	}

	// Store in Cache (5 min TTL)
	database.SetCache(cacheKey, res, 5*time.Minute)

	return res, nil
}
