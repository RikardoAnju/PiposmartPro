package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type FinanceService struct {
	db *gorm.DB
}

func NewFinanceService(db *gorm.DB) *FinanceService {
	return &FinanceService{db: db}
}

func (s *FinanceService) GetOutletLocation(outletID string) *time.Location {
	var ot model.Outlet
	if err := s.db.Select("ot_timezone").Where("ot_id = ?", outletID).First(&ot).Error; err != nil {
		return time.FixedZone("WIB", 7*3600)
	}
	return ot.GetLocation()
}

// sumCashIncome returns money received during a period. Deposit usage is an
// internal settlement and is not new cash; the cash event is the top up.
func (s *FinanceService) sumCashIncome(outletID, start, end string) float64 {
	var total float64
	s.db.Raw(`
		SELECT COALESCE(SUM(amount), 0) FROM (
			SELECT dp.dptr_jumlah_dp AS amount
			FROM ac_dp_transaksi dp
			JOIN ac_transaksi t ON t.tr_id = dp.dptr_transaksi
			WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal'
			  AND dp.dptr_tanggal_dp BETWEEN ? AND ?
			  AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
			UNION ALL
			SELECT cdt_total_paid
			FROM ac_customer_deposit_cash_events
			WHERE cdt_outlet = ? AND cdt_created BETWEEN ? AND ?
		) cash_income`, outletID, start, end, outletID, start, end).Scan(&total)
	return total
}

// =============================================================================
// DASHBOARD & OMSET METHODS
// =============================================================================

// Helper untuk menghitung persentase kenaikan/penurunan
func calculateTrend(current, previous float64) float64 {
	if previous == 0 {
		if current > 0 {
			return 100
		}
		return 0
	}
	return ((current - previous) / previous) * 100
}

// GetFinanceSummary mengambil data angka dan trend (Perbandingan periode sekarang vs sebelumnya)
func (s *FinanceService) GetFinanceSummary(outletID string, start, end string) (model.FinanceSummary, error) {
	cacheKey := fmt.Sprintf("finance:summary:v2:%s:%s:%s", outletID, start, end)
	var res model.FinanceSummary
	if database.GetCache(cacheKey, &res) {
		return res, nil
	}

	// 1. AMBIL DATA SEKARANG
	loc := s.GetOutletLocation(outletID)
	dbLoc := time.FixedZone("WIB", 7*3600)

	// Convert input start/end (WIB/Server context) ke local outlet context jika perlu
	// Tapi biasanya input start/end sudah dalam format YYYY-MM-DD 00:00:00 (Local Outlet)
	// Kita berasumsi start/end dari controller sudah mewakili "Hari di Outlet"
	// Jadi kita perlu parse start/end sebagai waktu LOCAL outlet, lalu convert ke DB time (+07:00)

	layout := "2006-01-02 15:04:05"
	sTime, _ := time.ParseInLocation(layout, start, loc)
	eTime, _ := time.ParseInLocation(layout, end, loc)

	startDB := sTime.In(dbLoc).Format(layout)
	endDB := eTime.In(dbLoc).Format(layout)

	// Hitung durasi untuk mencari periode pembanding (Kemarin/Minggu Lalu)
	diff := eTime.Sub(sTime)
	prevStartDB := sTime.Add(-diff - time.Second).In(dbLoc).Format(layout)
	prevEndDB := sTime.Add(-time.Second).In(dbLoc).Format(layout)

	var curr model.FinanceSummary
	var rawCurr struct {
		TotalOmset     float64
		TotalTransaksi int64
	}
	s.db.Table("ac_transaksi").Select("COALESCE(SUM(tr_total), 0) as total_omset, COUNT(tr_id) as total_transaksi").
		Where("tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ?", outletID, startDB, endDB).Scan(&rawCurr)

	curr.TotalOmset = rawCurr.TotalOmset
	curr.TotalTransaksi = rawCurr.TotalTransaksi

	curr.TotalIncome = s.sumCashIncome(outletID, startDB, endDB)

	s.db.Table("ac_pengeluaran").Select("COALESCE(SUM(pg_total), 0)").
		Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, startDB, endDB).Scan(&curr.TotalExpense)

	s.db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order = 'Selesai' AND tr_created BETWEEN ? AND ?", outletID, startDB, endDB).Count(&curr.PesananDiambil)

	// FORCE LABA RUGI = INCOME - EXPENSE
	curr.ProfitLoss = curr.TotalIncome - curr.TotalExpense

	// 2. AMBIL DATA PERIODE SEBELUMNYA
	var prev model.FinanceSummary
	var rawPrev struct {
		TotalOmset     float64
		TotalTransaksi int64
	}
	s.db.Table("ac_transaksi").Select("COALESCE(SUM(tr_total), 0) as total_omset, COUNT(tr_id) as total_transaksi").
		Where("tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ?", outletID, prevStartDB, prevEndDB).Scan(&rawPrev)

	prev.TotalOmset = rawPrev.TotalOmset
	prev.TotalTransaksi = rawPrev.TotalTransaksi

	prev.TotalIncome = s.sumCashIncome(outletID, prevStartDB, prevEndDB)

	s.db.Table("ac_pengeluaran").Select("COALESCE(SUM(pg_total), 0)").
		Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, prevStartDB, prevEndDB).Scan(&prev.TotalExpense)

	s.db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order = 'Selesai' AND tr_created BETWEEN ? AND ?", outletID, prevStartDB, prevEndDB).Count(&prev.PesananDiambil)

	prev.ProfitLoss = prev.TotalIncome - prev.TotalExpense

	// 3. KALKULASI TREND
	res = curr
	res.ProfitLoss = curr.ProfitLoss // Redundant but safe
	res.OmsetTrend = calculateTrend(curr.TotalOmset, prev.TotalOmset)
	res.IncomeTrend = calculateTrend(curr.TotalIncome, prev.TotalIncome)
	res.ExpenseTrend = calculateTrend(curr.TotalExpense, prev.TotalExpense)
	res.ProfitLossTrend = calculateTrend(curr.ProfitLoss, prev.ProfitLoss)
	res.TransaksiTrend = calculateTrend(float64(curr.TotalTransaksi), float64(prev.TotalTransaksi))
	res.PesananTrend = calculateTrend(float64(curr.PesananDiambil), float64(prev.PesananDiambil))

	database.SetCache(cacheKey, res, 5*time.Minute)

	return res, nil
}

// GetFinanceChart mengambil data harian untuk grafik (Biasanya 30 hari)
func (s *FinanceService) GetFinanceChart(outletID string, start, end string) ([]model.DailyChartData, error) {
	cacheKey := fmt.Sprintf("finance:chart:v2:%s:%s:%s", outletID, start, end)
	var chartData []model.DailyChartData
	if database.GetCache(cacheKey, &chartData) {
		return chartData, nil
	}

	loc := s.GetOutletLocation(outletID)
	dbLoc := time.FixedZone("WIB", 7*3600)
	layout := "2006-01-02 15:04:05"

	sTime, _ := time.ParseInLocation(layout, start, loc)
	eTime, _ := time.ParseInLocation(layout, end, loc)
	startDB := sTime.In(dbLoc).Format(layout)
	endDB := eTime.In(dbLoc).Format(layout)

	// Untuk grouping harian di grafik, kita harus menyesuaikan offset agar "Hari" dihitung berdasarkan timezone outlet.
	// Kita gunakan offset interval di SQL.
	offsetMinutes := 0
	switch loc.String() {
	case "WITA":
		offsetMinutes = 60 // WITA (+8) vs DB (+7)
	case "WIT":
		offsetMinutes = 120 // WIT (+9) vs DB (+7)
	}

	// Logic grouping harian menggunakan offsetMinutes sebagai parameter query
	query := `
        SELECT dates.date, 
               COALESCE(SUM(t.tr_total), 0) as omset, 
               COALESCE((
                   SELECT SUM(dp.dptr_jumlah_dp)
                   FROM ac_dp_transaksi dp
                   JOIN ac_transaksi paid_trx ON paid_trx.tr_id = dp.dptr_transaksi
                   WHERE paid_trx.tr_outlet = ?
                     AND paid_trx.tr_status_order != 'Batal'
                     AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
                     AND DATE(DATE_ADD(dp.dptr_tanggal_dp, INTERVAL ? MINUTE)) = dates.date
               ), 0) + COALESCE((
                   SELECT SUM(cdt.cdt_total_paid)
                   FROM ac_customer_deposit_cash_events cdt
                   WHERE cdt.cdt_outlet = ?
                     AND DATE(DATE_ADD(cdt.cdt_created, INTERVAL ? MINUTE)) = dates.date
               ), 0) as income,
               COALESCE((SELECT SUM(pg_total) FROM ac_pengeluaran WHERE pg_outlet = ? AND DATE(DATE_ADD(pg_tanggal, INTERVAL ? MINUTE)) = dates.date), 0) as expense,
               COALESCE(COUNT(t.tr_id), 0) as total_order
        FROM (
            SELECT DATE(DATE_ADD(tr_created, INTERVAL ? MINUTE)) as date FROM ac_transaksi WHERE tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ? 
            UNION 
            SELECT DATE(DATE_ADD(dp.dptr_tanggal_dp, INTERVAL ? MINUTE)) as date
            FROM ac_dp_transaksi dp
            JOIN ac_transaksi paid_trx ON paid_trx.tr_id = dp.dptr_transaksi
            WHERE paid_trx.tr_outlet = ? AND paid_trx.tr_status_order != 'Batal'
              AND dp.dptr_tanggal_dp BETWEEN ? AND ?
              AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
            UNION
            SELECT DATE(DATE_ADD(cdt_created, INTERVAL ? MINUTE)) as date
            FROM ac_customer_deposit_cash_events
            WHERE cdt_outlet = ? AND cdt_created BETWEEN ? AND ?
            UNION
            SELECT DATE(DATE_ADD(pg_tanggal, INTERVAL ? MINUTE)) as date FROM ac_pengeluaran WHERE pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?
        ) dates 
        LEFT JOIN ac_transaksi t ON DATE(DATE_ADD(t.tr_created, INTERVAL ? MINUTE)) = dates.date AND t.tr_outlet = ? AND t.tr_status_order != 'Batal' 
        GROUP BY dates.date 
        ORDER BY dates.date ASC`

	err := s.db.Raw(query,
		outletID, offsetMinutes,
		outletID, offsetMinutes,
		outletID, offsetMinutes,
		offsetMinutes, outletID, startDB, endDB,
		offsetMinutes, outletID, startDB, endDB,
		offsetMinutes, outletID, startDB, endDB,
		offsetMinutes, outletID, startDB, endDB,
		offsetMinutes, outletID).Scan(&chartData).Error

	if err == nil {
		database.SetCache(cacheKey, chartData, 10*time.Minute)
	}

	return chartData, err
}

func (s *FinanceService) GetOmsetReport(outletID string, start, end, statusBayar string, page, limit int) (map[string]interface{}, error) {
	var summary struct {
		TotalOmset     float64 `json:"total_omset"`
		TotalTransaksi int64   `json:"total_transaksi"`
	}
	var list []struct {
		Tanggal        string  `json:"tanggal"`
		TotalOmset     float64 `json:"total_omset"`
		TotalTransaksi int64   `json:"total_transaksi"`
	}
	query := s.db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ?", outletID, start, end)
	if statusBayar != "" {
		if statusBayar == "DP" {
			query = query.Where("tr_status_pembayaran = 'Belum Lunas' AND COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = tr_id), 0) > 0")
		} else {
			query = query.Where("tr_status_pembayaran = ?", statusBayar)
		}
	}
	query.Select("COALESCE(SUM(tr_total), 0) as total_omset, COUNT(tr_id) as total_transaksi").Scan(&summary)
	var totalDays int64
	query.Distinct("DATE(tr_created)").Count(&totalDays)
	query.Select("DATE(tr_created) as tanggal, SUM(tr_total) as total_omset, COUNT(tr_id) as total_transaksi").Group("DATE(tr_created)").Order("DATE(tr_created) DESC").Limit(limit).Offset((page - 1) * limit).Scan(&list)

	// Query metode pembayaran — mirip pola GetIncomeReport / GetProfitLossReport
	metodeQuery := `SELECT mp.mp_id as id, mp.mp_nama_metode as nama, SUM(dp.dptr_jumlah_dp) as nominal
		FROM ac_dp_transaksi dp
		JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id
		JOIN ac_metode_pembayaran mp ON dp.dptr_metode_pembayaran = mp.mp_id
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal' AND dp.dptr_tanggal_dp BETWEEN ? AND ?`
	metodeParams := []interface{}{outletID, start, end}
	if statusBayar != "" {
		if statusBayar == "DP" {
			metodeQuery += " AND t.tr_status_pembayaran = 'Belum Lunas' AND COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = t.tr_id), 0) > 0"
		} else {
			metodeQuery += " AND t.tr_status_pembayaran = ?"
			metodeParams = append(metodeParams, statusBayar)
		}
	}
	metodeQuery += " GROUP BY mp.mp_id, mp.mp_nama_metode ORDER BY nominal DESC"
	metodePembayaran := []map[string]interface{}{}
	s.db.Raw(metodeQuery, metodeParams...).Scan(&metodePembayaran)

	return map[string]interface{}{"header": summary, "list": list, "metode_pembayaran": metodePembayaran, "page": page, "limit": limit, "total": totalDays, "total_pages": int((totalDays + int64(limit) - 1) / int64(limit)), "has_more": int64(page*limit) < totalDays}, nil
}

func (s *FinanceService) GetOmsetDetail(outletID string, date string, statusBayar string, page int, limit int) (map[string]interface{}, error) {
	query := `
        SELECT 
            t.tr_id as id,
            t.tr_id as tr_invoice,
            t.tr_outlet as outlet_id,
            t.tr_status_order as status_order,
            t.tr_created as created_at,
            t.tr_created as updated_at,
            t.tr_total as total_akhir,
            t.tr_total as total_kotor,
            t.tr_status_pembayaran as status_pembayaran,
            COALESCE(t.tr_catatan, '') as catatan,
            COALESCE(t.tr_diskon, 0) as potongan_diskon,
            0 as rounding_amount,
            COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = t.tr_id), 0) as dp_amount,
            t.tr_total - COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = t.tr_id), 0) as sisa_bayar,
            p.pl_nama as pelanggan_nama,
            COALESCE(t.tr_estimate, DATE_ADD(t.tr_created, INTERVAL 2 DAY)) as tr_estimate,
            (
                SELECT CASE dp2.dptr_metode_pembayaran
                    WHEN 'DEPOSIT_RUPIAH' THEN 'Deposit Rupiah'
                    WHEN 'DEPOSIT_KG' THEN 'Deposit Kg'
                    ELSE COALESCE(mp.mp_nama_metode, dp2.dptr_metode_pembayaran)
                END
                FROM ac_dp_transaksi dp2
                LEFT JOIN ac_metode_pembayaran mp ON dp2.dptr_metode_pembayaran = mp.mp_id 
                WHERE dp2.dptr_transaksi = t.tr_id 
                ORDER BY dp2.dptr_tanggal_dp DESC 
                LIMIT 1
            ) as metode_pembayaran
        FROM ac_transaksi t
        LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
        WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal' AND DATE(t.tr_created) = ?`

	if statusBayar != "" {
		if statusBayar == "DP" {
			query += " AND t.tr_status_pembayaran = 'Belum Lunas' AND COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = t.tr_id), 0) > 0"
		} else {
			query += " AND t.tr_status_pembayaran = '" + statusBayar + "'"
		}
	}

	// Aggregate header (total rows + summed nominal) over the FULL filtered set,
	// independent of pagination, so the client's summary card is correct without
	// having to load every page first.
	var agg struct {
		TotalTransaksi int64   `json:"total_transaksi"`
		TotalNominal   float64 `json:"total_nominal"`
	}
	aggQuery := "SELECT COUNT(*) as total_transaksi, COALESCE(SUM(total_akhir), 0) as total_nominal FROM (" + query + ") as agg_table"
	s.db.Raw(aggQuery, outletID, date).Scan(&agg)

	query += " ORDER BY t.tr_created DESC LIMIT ? OFFSET ?"

	var results []map[string]interface{}
	offset := (page - 1) * limit
	err := s.db.Raw(query, outletID, date, limit, offset).Scan(&results).Error

	return map[string]interface{}{
		"data":   results,
		"total":  agg.TotalTransaksi,
		"header": agg,
		"page":   page,
		"limit":  limit,
	}, err
}

// =============================================================================
// EXPENSE (PENGELUARAN) METHODS
// =============================================================================

func (s *FinanceService) GetExpenseAnalisa(outletID string, start, end string, page, limit int) (map[string]interface{}, error) {
	cacheKey := fmt.Sprintf("finance:expense:analisa:v2:%s:%s:%s:%d:%d", outletID, start, end, page, limit)
	var cachedRes map[string]interface{}
	if database.GetCache(cacheKey, &cachedRes) {
		return cachedRes, nil
	}

	var summaryData struct {
		TotalExpense   float64 `json:"total_expense"`
		TotalTransaksi int64   `json:"total_transaksi"`
	}
	var kategoriData struct {
		KategoriTop   string  `gorm:"column:kategori_terbesar"`
		TotalKategori float64 `gorm:"column:nominal_kategori_terbesar"`
	}
	s.db.Table("ac_pengeluaran").Select("COALESCE(SUM(pg_total), 0) as total_expense, COUNT(pg_id) as total_transaksi").Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, start, end).Scan(&summaryData)
	s.db.Table("ac_pengeluaran pg").Select("kp.kp_kategori as kategori_terbesar, SUM(pg.pg_total) as nominal_kategori_terbesar").Joins("JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").Where("pg.pg_outlet = ? AND pg.pg_tanggal BETWEEN ? AND ?", outletID, start, end).Group("kp.kp_id, kp.kp_kategori").Order("nominal_kategori_terbesar DESC").Limit(1).Scan(&kategoriData)
	var listByDate []struct {
		Tanggal        string  `json:"tanggal"`
		Total          float64 `json:"total"`
		TotalTransaksi int64   `json:"total_transaksi"`
	}
	var totalDays int64
	s.db.Table("ac_pengeluaran").Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, start, end).Distinct("DATE(pg_tanggal)").Count(&totalDays)
	s.db.Table("ac_pengeluaran").Select("DATE(pg_tanggal) as tanggal, SUM(pg_total) as total, COUNT(pg_id) as total_transaksi").Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, start, end).Group("DATE(pg_tanggal)").Order("tanggal DESC").Limit(limit).Offset((page - 1) * limit).Scan(&listByDate)

	finalRes := map[string]interface{}{"summary": map[string]interface{}{"total_expense": summaryData.TotalExpense, "total_transaksi": summaryData.TotalTransaksi, "kategori_terbesar": kategoriData.KategoriTop, "nominal_kategori_terbesar": kategoriData.TotalKategori}, "list": listByDate, "page": page, "limit": limit, "total": totalDays, "total_pages": int((totalDays + int64(limit) - 1) / int64(limit)), "has_more": int64(page*limit) < totalDays}
	database.SetCache(cacheKey, finalRes, 10*time.Minute)

	return finalRes, nil
}

func (s *FinanceService) GetExpenseByCategory(outletID string, start, end string) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	s.db.Table("ac_pengeluaran pg").Select("kp.kp_kategori as nama_kategori, kp.kp_id as id_kategori, SUM(pg.pg_total) as total_nominal").Joins("JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").Where("pg.pg_outlet = ? AND pg.pg_tanggal BETWEEN ? AND ?", outletID, start, end).Group("kp.kp_id, kp.kp_kategori").Order("total_nominal DESC").Scan(&results)
	return results, nil
}

func (s *FinanceService) GetExpenseDetail(outletID string, start, end, kategoriID string, page int, limit int) (map[string]interface{}, error) {
	var list []model.Pengeluaran
	query := `SELECT pg.*, kp.kp_id as kp_id, kp.kp_kategori as kp_nama, COALESCE(u.usr_nama, p.pg_nama, 'System') as lr_actor_name FROM ac_pengeluaran pg LEFT JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id LEFT JOIN ac_user u ON pg.pg_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND pg.pg_userupdate_type = 'user' LEFT JOIN ac_pegawai p ON pg.pg_userupdate = p.pg_id AND pg.pg_userupdate_type = 'pegawai' WHERE pg.pg_outlet = ?`
	params := []interface{}{outletID}
	if kategoriID != "" {
		query += " AND pg.pg_kategori = ?"
		params = append(params, kategoriID)
	}
	if start != "" && end != "" {
		query += " AND pg.pg_tanggal BETWEEN ? AND ?"
		params = append(params, start, end)
	}

	// Aggregate header (total rows + summed nominal) over the FULL filtered set,
	// independent of pagination, so the client's summary card is correct without
	// having to load every page first.
	var agg struct {
		TotalTransaksi int64   `json:"total_transaksi"`
		TotalNominal   float64 `json:"total_nominal"`
	}
	aggQuery := "SELECT COUNT(*) as total_transaksi, COALESCE(SUM(pg_total), 0) as total_nominal FROM (" + query + ") as agg_table"
	s.db.Raw(aggQuery, params...).Scan(&agg)

	query += " ORDER BY pg.pg_tanggal DESC LIMIT ? OFFSET ?"
	params = append(params, limit, (page-1)*limit)

	type rowScan struct {
		model.Pengeluaran
		KpID      string `gorm:"column:kp_id"`
		KpNama    string `gorm:"column:kp_nama"`
		ActorName string `gorm:"column:lr_actor_name"`
	}
	var rows []rowScan
	s.db.Raw(query, params...).Scan(&rows)
	for _, r := range rows {
		p := r.Pengeluaran
		p.KategoriNama = r.KpNama
		p.KategoriID = r.KpID
		p.UserUpdateNama = r.ActorName
		list = append(list, p)
	}
	return map[string]interface{}{
		"data":   list,
		"total":  agg.TotalTransaksi,
		"header": agg,
		"page":   page,
		"limit":  limit,
	}, nil
}

// =============================================================================
// INCOME (PENDAPATAN) METHODS
// =============================================================================

func (s *FinanceService) GetIncomeReport(outletID string, start, end, metodeID string, page, limit int) (map[string]interface{}, error) {
	var header struct {
		TotalIncome float64 `json:"total_income"`
	}
	unionSQL := `
		SELECT DATE(dp.dptr_tanggal_dp) as tanggal,
			COALESCE(mp.mp_nama_metode, dp.dptr_metode_pembayaran) as metode_nama,
			COALESCE(mp.mp_kategori, 'Pembayaran') as metode_kategori,
			SUM(dp.dptr_jumlah_dp) as total_harian_per_metode
		FROM ac_dp_transaksi dp
		JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id
		LEFT JOIN ac_metode_pembayaran mp ON dp.dptr_metode_pembayaran = mp.mp_id
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal'
			AND dp.dptr_tanggal_dp BETWEEN ? AND ?
			AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')`
	params := []interface{}{outletID, start, end}
	if metodeID != "" {
		unionSQL += " AND (mp.mp_id = ? OR mp.mp_nama_metode = ?)"
		params = append(params, metodeID, metodeID)
	}
	unionSQL += ` GROUP BY DATE(dp.dptr_tanggal_dp), mp.mp_id, dp.dptr_metode_pembayaran
		UNION ALL
		SELECT DATE(cdt.cdt_created) as tanggal,
			COALESCE(mp2.mp_nama_metode, 'Top Up Deposit') as metode_nama,
			COALESCE(mp2.mp_kategori, 'Deposit') as metode_kategori,
			SUM(cdt.cdt_total_paid) as total_harian_per_metode
		FROM ac_customer_deposit_cash_events cdt
		LEFT JOIN ac_metode_pembayaran mp2 ON cdt.cdt_payment_method = mp2.mp_id
		WHERE cdt.cdt_outlet = ? AND cdt.cdt_created BETWEEN ? AND ?
		  AND cdt.cdt_total_paid <> 0`
	params = append(params, outletID, start, end)
	if metodeID != "" {
		unionSQL += " AND (mp2.mp_id = ? OR mp2.mp_nama_metode = ?)"
		params = append(params, metodeID, metodeID)
	}
	unionSQL += " GROUP BY DATE(cdt.cdt_created), mp2.mp_id, cdt.cdt_payment_method, metode_nama, metode_kategori"
	if err := s.db.Raw("SELECT COALESCE(SUM(total_harian_per_metode),0) total_income FROM ("+unionSQL+") income_total", params...).Scan(&header).Error; err != nil {
		return nil, err
	}
	var totalDays int64
	if err := s.db.Raw("SELECT COUNT(DISTINCT tanggal) FROM ("+unionSQL+") income_count", params...).Scan(&totalDays).Error; err != nil {
		return nil, err
	}
	// DATE(...) is returned by the MySQL driver as time.Time because the DSN
	// enables parseTime. Keep that native type while scanning, then normalize it
	// back to MySQL's DATE representation before using it in the IN clause.
	// Scanning directly into []string can produce RFC3339 values, which do not
	// match DATE columns and makes the paginated list empty while the header is
	// still correctly populated.
	var pagedDateValues []time.Time
	if err := s.db.Raw("SELECT DISTINCT tanggal FROM ("+unionSQL+") income_dates ORDER BY tanggal DESC LIMIT ? OFFSET ?", append(append([]interface{}{}, params...), limit, (page-1)*limit)...).Scan(&pagedDateValues).Error; err != nil {
		return nil, err
	}
	pagedDates := formatIncomeReportDates(pagedDateValues)
	type rawIncome struct {
		Tanggal      string  `gorm:"column:tanggal"`
		MetodeNama   string  `gorm:"column:metode_nama"`
		MetodeKat    string  `gorm:"column:metode_kategori"`
		TotalNominal float64 `gorm:"column:total_harian_per_metode"`
	}
	var rows []rawIncome
	if len(pagedDates) > 0 {
		if err := s.db.Raw("SELECT * FROM ("+unionSQL+") income_rows WHERE tanggal IN ? ORDER BY tanggal DESC", append(append([]interface{}{}, params...), pagedDates)...).Scan(&rows).Error; err != nil {
			return nil, err
		}
	}
	type DailyBreakdown struct {
		Nama    string  `json:"nama"`
		Nominal float64 `json:"nominal"`
	}
	type DailyIncome struct {
		Tanggal     string           `json:"tanggal"`
		TotalHarian float64          `json:"total_harian"`
		Breakdown   []DailyBreakdown `json:"breakdown"`
	}
	var finalData []DailyIncome
	dailyMap := make(map[string]*DailyIncome)
	for _, r := range rows {
		if _, ok := dailyMap[r.Tanggal]; !ok {
			dailyMap[r.Tanggal] = &DailyIncome{Tanggal: r.Tanggal, TotalHarian: 0, Breakdown: []DailyBreakdown{}}
		}
		dailyMap[r.Tanggal].TotalHarian += r.TotalNominal
		dailyMap[r.Tanggal].Breakdown = append(dailyMap[r.Tanggal].Breakdown, DailyBreakdown{Nama: r.MetodeNama, Nominal: r.TotalNominal})
	}
	processedDates := make(map[string]bool)
	for _, r := range rows {
		if !processedDates[r.Tanggal] {
			finalData = append(finalData, *dailyMap[r.Tanggal])
			processedDates[r.Tanggal] = true
		}
	}
	return map[string]interface{}{"header": header, "list": finalData, "page": page, "limit": limit, "total": totalDays, "total_pages": int((totalDays + int64(limit) - 1) / int64(limit)), "has_more": int64(page*limit) < totalDays}, nil
}

func formatIncomeReportDates(values []time.Time) []string {
	dates := make([]string, len(values))
	for i, value := range values {
		dates[i] = value.Format("2006-01-02")
	}
	return dates
}

func (s *FinanceService) GetIncomeActiveMethods(outletID string, start, end string) ([]map[string]interface{}, error) {
	var results []map[string]interface{}
	query := `SELECT DISTINCT mp.mp_id as id, mp.mp_nama_metode as nama
		FROM ac_dp_transaksi dp
		JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id
		JOIN ac_metode_pembayaran mp ON dp.dptr_metode_pembayaran = mp.mp_id
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal'
		  AND dp.dptr_tanggal_dp BETWEEN ? AND ?
		  AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
		UNION
		SELECT DISTINCT mp2.mp_id as id, mp2.mp_nama_metode as nama
		FROM ac_customer_deposit_cash_events cdt
		JOIN ac_metode_pembayaran mp2 ON cdt.cdt_payment_method = mp2.mp_id
		WHERE cdt.cdt_outlet = ? AND cdt.cdt_created BETWEEN ? AND ?
		  AND cdt.cdt_total_paid <> 0
		ORDER BY nama ASC`
	err := s.db.Raw(query, outletID, start, end, outletID, start, end).Scan(&results).Error
	return results, err
}

// =============================================================================
// PIUTANG & LABA RUGI METHODS
// =============================================================================

func (s *FinanceService) GetPiutangReport(outletID string, start, end string, search string, status string, page, limit int) (map[string]interface{}, error) {
	loc := s.GetOutletLocation(outletID)
	now := time.Now().In(loc)
	jatuhTempoList := []model.Transaksi{}
	belumJatuhTempoList := []model.Transaksi{}
	base := `SELECT debt_rows.* FROM (
		SELECT t.*, p.pl_id as p_id, p.pl_nama as p_nama, p.pl_kode as p_kode,
			p.pl_nohp as p_nohp,
			COALESCE((SELECT MAX(dtr_ready_at) FROM ac_detail_transaksi WHERE dtr_transaksi = t.tr_id), t.tr_estimate, t.tr_created) as max_ready_at,
			COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = t.tr_id), 0) as total_bayar_dp,
			GREATEST(t.tr_total - COALESCE((SELECT SUM(dptr_jumlah_dp) FROM ac_dp_transaksi WHERE dptr_transaksi = t.tr_id), 0), 0) as remaining_debt
		FROM ac_transaksi t
		LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal' AND t.tr_created BETWEEN ? AND ?`
	params := []interface{}{outletID, start, end}
	if search != "" {
		base += " AND (p.pl_nama LIKE ? OR t.tr_id LIKE ?)"
		params = append(params, "%"+search+"%", "%"+search+"%")
	}
	base += ") debt_rows WHERE debt_rows.remaining_debt > 0"

	var summary struct {
		TotalJatuhTempo      float64 `gorm:"column:total_jatuh_tempo"`
		CountJatuhTempo      int64   `gorm:"column:count_jatuh_tempo"`
		TotalBelumJatuhTempo float64 `gorm:"column:total_belum_jatuh_tempo"`
		CountBelumJatuhTempo int64   `gorm:"column:count_belum_jatuh_tempo"`
	}
	summarySQL := `SELECT
		COALESCE(SUM(CASE WHEN max_ready_at < ? THEN remaining_debt ELSE 0 END), 0) total_jatuh_tempo,
		COUNT(DISTINCT CASE WHEN max_ready_at < ? THEN COALESCE(NULLIF(p_id,''), p_nama) END) count_jatuh_tempo,
		COALESCE(SUM(CASE WHEN max_ready_at >= ? THEN remaining_debt ELSE 0 END), 0) total_belum_jatuh_tempo,
		COUNT(DISTINCT CASE WHEN max_ready_at >= ? THEN COALESCE(NULLIF(p_id,''), p_nama) END) count_belum_jatuh_tempo
		FROM (` + base + `) summary_rows`
	summaryArgs := append([]interface{}{now, now, now, now}, params...)
	if err := s.db.Raw(summarySQL, summaryArgs...).Scan(&summary).Error; err != nil {
		return nil, err
	}

	listSQL := base
	listArgs := append([]interface{}{}, params...)
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "jatuh_tempo":
		listSQL += " AND max_ready_at < ?"
		listArgs = append(listArgs, now)
	case "belum_jatuh_tempo":
		listSQL += " AND max_ready_at >= ?"
		listArgs = append(listArgs, now)
	}
	var total int64
	if err := s.db.Raw("SELECT COUNT(*) FROM ("+listSQL+") count_rows", listArgs...).Scan(&total).Error; err != nil {
		return nil, err
	}
	listSQL += " ORDER BY tr_created DESC LIMIT ? OFFSET ?"
	listArgs = append(listArgs, limit, (page-1)*limit)
	type rowScan struct {
		model.Transaksi
		PId        string    `gorm:"column:p_id"`
		PNama      string    `gorm:"column:p_nama"`
		PKode      string    `gorm:"column:p_kode"`
		PNohp      string    `gorm:"column:p_nohp"`
		MaxReadyAt time.Time `gorm:"column:max_ready_at"`
		TotalBayar float64   `gorm:"column:total_bayar_dp"`
	}
	var rows []rowScan
	if err := s.db.Raw(listSQL, listArgs...).Scan(&rows).Error; err != nil {
		return nil, err
	}
	for _, r := range rows {
		t := r.Transaksi
		t.Pelanggan = model.Pelanggan{ID: r.PId, Nama: r.PNama, Kode: r.PKode, NoHP: r.PNohp}
		t.DPAmount = r.TotalBayar
		t.SisaBayar = t.Total - r.TotalBayar
		if t.SisaBayar < 0 {
			t.SisaBayar = 0
		}
		if r.MaxReadyAt.Before(now) {
			jatuhTempoList = append(jatuhTempoList, t)
		} else {
			belumJatuhTempoList = append(belumJatuhTempoList, t)
		}
	}
	return map[string]interface{}{
		"summary": map[string]interface{}{
			"total_jatuh_tempo":       summary.TotalJatuhTempo,
			"count_jatuh_tempo":       summary.CountJatuhTempo,
			"total_belum_jatuh_tempo": summary.TotalBelumJatuhTempo,
			"count_belum_jatuh_tempo": summary.CountBelumJatuhTempo,
		},
		"jatuh_tempo":       jatuhTempoList,
		"belum_jatuh_tempo": belumJatuhTempoList,
		"page":              page, "limit": limit, "total": total,
		"total_pages": int((total + int64(limit) - 1) / int64(limit)),
		"has_more":    int64(page*limit) < total,
	}, nil
}

func (s *FinanceService) GetProfitLossReport(outletID string, start, end string) (map[string]interface{}, error) {
	cacheKey := fmt.Sprintf("finance:profit_loss:v5:%s:%s:%s", outletID, start, end)
	var cachedRes map[string]interface{}
	if database.GetCache(cacheKey, &cachedRes) {
		return cachedRes, nil
	}

	var summary struct {
		Omset          float64 `json:"total_omset"`
		Income         float64 `json:"total_income"`
		CashIncome     float64 `json:"total_cash_income"`
		DepositTopup   float64 `json:"total_deposit_topup"`
		Expense        float64 `json:"total_expense"`
		TotalTransaksi int64   `json:"total_transaksi"`
		TotalPayments  int64   `json:"total_payments"`
	}

	// 1. Hitung total penjualan berdasarkan transaksi dibuat.
	s.db.Table("ac_transaksi").Select("COALESCE(SUM(tr_total), 0) as total_omset").
		Where("tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ?", outletID, start, end).
		Scan(&summary)

	// 2. Pendapatan diakui ketika uang diterima. Top up deposit masuk sebagai
	// pendapatan pada saat top up, sedangkan pemakaian saldo deposit untuk
	// membayar layanan dikecualikan agar tidak dihitung dua kali.
	summary.CashIncome = s.sumCashIncome(outletID, start, end)
	summary.Income = summary.CashIncome
	s.db.Table("ac_customer_deposit_cash_events").Select("COALESCE(SUM(cdt_total_paid), 0)").
		Where("cdt_outlet = ? AND cdt_created BETWEEN ? AND ?", outletID, start, end).Scan(&summary.DepositTopup)
	s.db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ?", outletID, start, end).Count(&summary.TotalTransaksi)
	s.db.Table("ac_dp_transaksi dp").Joins("JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id").
		Select("COUNT(dp.dptr_id)").
		Where("t.tr_outlet = ? AND t.tr_status_order != 'Batal' AND dp.dptr_tanggal_dp BETWEEN ? AND ?", outletID, start, end).
		Scan(&summary.TotalPayments)
	var depositPaymentCount int64
	s.db.Model(&model.CustomerDepositTopup{}).Where("cdt_outlet = ? AND cdt_created BETWEEN ? AND ?", outletID, start, end).Count(&depositPaymentCount)
	summary.TotalPayments += depositPaymentCount

	// 3. Hitung Total Expense
	s.db.Table("ac_pengeluaran").Select("COALESCE(SUM(pg_total), 0)").
		Where("pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?", outletID, start, end).
		Scan(&summary.Expense)

	// 4. Query harian. Omset tetap ditampilkan sebagai nilai transaksi,
	// sedangkan income mengikuti pengakuan pendapatan berbasis penerimaan kas.
	queryHarian := `
		SELECT 
			dates.date, 
			COALESCE((
				SELECT SUM(t2.tr_total)
				FROM ac_transaksi t2
				WHERE t2.tr_outlet = ? AND t2.tr_status_order != 'Batal'
				  AND DATE(t2.tr_created) = dates.date
			), 0) as omset,
			COALESCE((
				SELECT SUM(dp2.dptr_jumlah_dp)
				FROM ac_dp_transaksi dp2
				JOIN ac_transaksi t3 ON dp2.dptr_transaksi = t3.tr_id
				WHERE t3.tr_outlet = ? AND t3.tr_status_order != 'Batal'
				  AND DATE(dp2.dptr_tanggal_dp) = dates.date
				  AND dp2.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
			), 0) + COALESCE((
				SELECT SUM(cdt2.cdt_total_paid)
				FROM ac_customer_deposit_cash_events cdt2
				WHERE cdt2.cdt_outlet = ? AND DATE(cdt2.cdt_created) = dates.date
			), 0) as income,
			COALESCE((
				SELECT SUM(pg_total) 
				FROM ac_pengeluaran 
				WHERE pg_outlet = ? AND DATE(pg_tanggal) = dates.date
			), 0) as expense 
		FROM (
			SELECT DATE(tr_created) as date FROM ac_transaksi WHERE tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created BETWEEN ? AND ? 
			UNION 
			SELECT DATE(dptr_tanggal_dp) as date FROM ac_dp_transaksi dp JOIN ac_transaksi t3 ON dp.dptr_transaksi = t3.tr_id WHERE t3.tr_outlet = ? AND t3.tr_status_order != 'Batal' AND dp.dptr_tanggal_dp BETWEEN ? AND ?
			UNION 
			SELECT DATE(cdt_created) as date FROM ac_customer_deposit_cash_events WHERE cdt_outlet = ? AND cdt_created BETWEEN ? AND ?
			UNION 
			SELECT DATE(pg_tanggal) as date FROM ac_pengeluaran WHERE pg_outlet = ? AND pg_tanggal BETWEEN ? AND ?
		) dates
		ORDER BY dates.date DESC`

	type dailyRow struct {
		Date    string  `gorm:"column:date"`
		Omset   float64 `gorm:"column:omset"`
		Income  float64 `gorm:"column:income"`
		Expense float64 `gorm:"column:expense"`
	}

	var rawHarian []dailyRow
	s.db.Raw(queryHarian,
		outletID, outletID, outletID, outletID,
		outletID, start, end,
		outletID, start, end,
		outletID, start, end,
		outletID, start, end,
	).Scan(&rawHarian)

	var listHarian []map[string]interface{}
	for _, row := range rawHarian {
		listHarian = append(listHarian, map[string]interface{}{
			"date":      row.Date,
			"omset":     row.Omset,
			"income":    row.Income,
			"expense":   row.Expense,
			"laba_rugi": row.Income - row.Expense,
		})
	}

	var listMetode []map[string]interface{}
	s.db.Raw(`SELECT mp.mp_id as id, mp.mp_nama_metode as nama, SUM(dp.dptr_jumlah_dp) as nominal
		FROM ac_dp_transaksi dp
		JOIN ac_metode_pembayaran mp ON dp.dptr_metode_pembayaran = mp.mp_id
		JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal'
		  AND dp.dptr_tanggal_dp BETWEEN ? AND ?
		  AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
		GROUP BY mp.mp_id, mp.mp_nama_metode
		UNION ALL
		SELECT COALESCE(mp2.mp_id, 'DEPOSIT_TOP_UP') as id,
			COALESCE(mp2.mp_nama_metode, 'Top Up Deposit') as nama,
			SUM(cdt.cdt_total_paid) as nominal
		FROM ac_customer_deposit_cash_events cdt
		LEFT JOIN ac_metode_pembayaran mp2 ON cdt.cdt_payment_method = mp2.mp_id
		WHERE cdt.cdt_outlet = ? AND cdt.cdt_created BETWEEN ? AND ?
		  AND cdt.cdt_total_paid <> 0
		GROUP BY mp2.mp_id, mp2.mp_nama_metode`, outletID, start, end, outletID, start, end).Scan(&listMetode)

	var listKategori []map[string]interface{}
	s.db.Table("ac_pengeluaran pg").Select("kp.kp_id as id, kp.kp_kategori as nama, SUM(pg.pg_total) as nominal").
		Joins("JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id").
		Where("pg.pg_outlet = ? AND pg.pg_tanggal BETWEEN ? AND ?", outletID, start, end).
		Group("kp.kp_id").Scan(&listKategori)

	finalRes := map[string]interface{}{
		"summary": map[string]interface{}{
			"total_omset":         summary.Omset,
			"total_income":        summary.Income,
			"total_cash_income":   summary.CashIncome,
			"total_deposit_topup": summary.DepositTopup,
			"total_expense":       summary.Expense,
			"profit_loss":         summary.Income - summary.Expense,
			"total_transaksi":     summary.TotalTransaksi,
			"total_payments":      summary.TotalPayments,
		},
		"detail_pendapatan":  listHarian,
		"metode_pembayaran":  listMetode,
		"detail_pengeluaran": listKategori,
	}
	database.SetCache(cacheKey, finalRes, 10*time.Minute)

	return finalRes, nil
}

// GetProfitLossDetailMetode: Bottomsheet list akumulasi harian per metode pembayaran terpilih
func (s *FinanceService) GetProfitLossDetailMetode(outletID string, start, end string, metodeID string) ([]map[string]interface{}, error) {
	// Inisialisasi biar baliknya [] bukan null
	results := []map[string]interface{}{}

	query := `SELECT * FROM (
		SELECT DATE(dp.dptr_tanggal_dp) as tanggal, mp.mp_nama_metode as kategori, SUM(dp.dptr_jumlah_dp) as nominal
		FROM ac_dp_transaksi dp
		JOIN ac_metode_pembayaran mp ON dp.dptr_metode_pembayaran = mp.mp_id
		JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id
		WHERE t.tr_outlet = ? 
          AND t.tr_status_order != 'Batal'
          AND dp.dptr_tanggal_dp BETWEEN ? AND ? 
          AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
          AND mp.mp_id = ?
		GROUP BY DATE(dp.dptr_tanggal_dp), mp.mp_nama_metode
		UNION ALL
		SELECT DATE(cdt.cdt_created) as tanggal,
			COALESCE(mp2.mp_nama_metode, 'Top Up Deposit') as kategori,
			SUM(cdt.cdt_total_paid) as nominal
		FROM ac_customer_deposit_cash_events cdt
		LEFT JOIN ac_metode_pembayaran mp2 ON cdt.cdt_payment_method = mp2.mp_id
		WHERE cdt.cdt_outlet = ? AND cdt.cdt_created BETWEEN ? AND ?
		  AND cdt.cdt_total_paid <> 0
		  AND COALESCE(mp2.mp_id, 'DEPOSIT_TOP_UP') = ?
		GROUP BY DATE(cdt.cdt_created), mp2.mp_nama_metode
	) payment_rows ORDER BY tanggal DESC`

	err := s.db.Raw(query, outletID, start, end, metodeID, outletID, start, end, metodeID).Scan(&results).Error
	return results, err
}

// GetProfitLossDetailPengeluaran: Bottomsheet list akumulasi harian per kategori pengeluaran terpilih
func (s *FinanceService) GetProfitLossDetailPengeluaran(outletID string, start, end string, kategoriID string) (map[string]interface{}, error) {
	// Inisialisasi biar baliknya [] bukan null
	results := []map[string]interface{}{}

	query := `
		SELECT DATE(pg.pg_tanggal) as tanggal, kp.kp_kategori as kategori, SUM(pg.pg_total) as nominal
		FROM ac_pengeluaran pg
		JOIN ac_kategori_pengeluaran kp ON pg.pg_kategori = kp.kp_id
		WHERE pg.pg_outlet = ? 
          AND pg.pg_tanggal BETWEEN ? AND ? 
          AND kp.kp_id = ?
		GROUP BY DATE(pg.pg_tanggal), kp.kp_kategori
		ORDER BY tanggal DESC`

	err := s.db.Raw(query, outletID, start, end, kategoriID).Scan(&results).Error
	if err != nil {
		return nil, err
	}

	detail, err := s.GetExpenseDetail(outletID, start, end, kategoriID, 1, 10000)
	if err != nil {
		return nil, err
	}

	return map[string]interface{}{
		"akumulasi_harian":   results,
		"detail_pengeluaran": detail,
	}, nil
}

func (s *FinanceService) GetIncomeDetail(outletID string, start, end string, metodeNama string, page, limit int) (map[string]interface{}, error) {
	query := `SELECT * FROM (
		SELECT
			dp.dptr_id as id,
			'ORDER_PAYMENT' as source_type,
			dp.dptr_transaksi as transaction_id,
			t.tr_pelanggan as customer_id,
			dp.dptr_tanggal_dp as tanggal_pembayaran,
			dp.dptr_jumlah_dp as nominal_bayar,
			t.tr_total as total_akhir,
			t.tr_status_pembayaran as status_pembayaran_akhir,
			COALESCE(p.pl_nama, 'Tanpa Nama') as pelanggan_nama,
			mp.mp_nama_metode as metode_nama,
			mp.mp_kategori as metode_kategori,
			'' as deposit_type,
			'' as reference_id,
			0 as balance_after,
			'' as created_by,
			'' as created_by_name,
			t.tr_created as tanggal_transaksi,
			(SELECT COUNT(*) FROM ac_dp_transaksi dp2
			 WHERE dp2.dptr_transaksi = dp.dptr_transaksi
			   AND dp2.dptr_tanggal_dp < dp.dptr_tanggal_dp) as payment_index
		FROM ac_dp_transaksi dp
		JOIN ac_transaksi t ON dp.dptr_transaksi = t.tr_id
		JOIN ac_metode_pembayaran mp ON dp.dptr_metode_pembayaran = mp.mp_id
		LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal'
		  AND dp.dptr_tanggal_dp BETWEEN ? AND ?
		  AND dp.dptr_metode_pembayaran NOT IN ('DEPOSIT_RUPIAH', 'DEPOSIT_KG')
		UNION ALL
		SELECT
			cdt.cdt_id as id,
			CASE WHEN cdt.cdt_event_type = 'TOP_UP' THEN 'DEPOSIT_TOP_UP' ELSE 'DEPOSIT_ADJUSTMENT' END as source_type,
			'' as transaction_id,
			cdt.cdt_customer as customer_id,
			cdt.cdt_created as tanggal_pembayaran,
			cdt.cdt_total_paid as nominal_bayar,
			cdt.cdt_total_paid as total_akhir,
			CASE cdt.cdt_event_type WHEN 'CORRECTION' THEN 'Koreksi Deposit' WHEN 'REFUND' THEN 'Refund Deposit' ELSE 'Top Up Deposit' END as status_pembayaran_akhir,
			COALESCE(p2.pl_nama, 'Tanpa Nama') as pelanggan_nama,
			COALESCE(mp2.mp_nama_metode, 'Top Up Deposit') as metode_nama,
			COALESCE(mp2.mp_kategori, 'Deposit') as metode_kategori,
			COALESCE(l2.cdl_type, cdt.cdt_type) as deposit_type,
			cdt.cdt_id as reference_id,
			COALESCE(l2.cdl_balance_after, 0) as balance_after,
			COALESCE(l2.cdl_created_by, cdt.cdt_created_by) as created_by,
			COALESCE(NULLIF(pg2.pg_nama, ''), NULLIF(u2.usr_nama, ''), 'Sistem') as created_by_name,
			cdt.cdt_created as tanggal_transaksi,
			0 as payment_index
		FROM ac_customer_deposit_cash_events cdt
		LEFT JOIN ac_pelanggan p2 ON cdt.cdt_customer = p2.pl_id
		LEFT JOIN ac_metode_pembayaran mp2 ON cdt.cdt_payment_method = mp2.mp_id
		LEFT JOIN ac_customer_deposit_ledger l2 ON l2.cdl_reference = cdt.cdt_id AND l2.cdl_entry_type IN ('TOP_UP', 'CORRECTION', 'REFUND')
		LEFT JOIN ac_pegawai pg2 ON l2.cdl_created_by = pg2.pg_id AND l2.cdl_created_by_type = 'pegawai'
		LEFT JOIN ac_user u2 ON l2.cdl_created_by = CAST(u2.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND l2.cdl_created_by_type = 'user'
		WHERE cdt.cdt_outlet = ? AND cdt.cdt_created BETWEEN ? AND ?
		  AND cdt.cdt_total_paid <> 0
	) income_rows WHERE 1 = 1`

	params := []interface{}{outletID, start, end}
	params = append(params, outletID, start, end)
	if metodeNama != "" {
		query += " AND metode_nama = ?"
		params = append(params, metodeNama)
	}

	// Aggregate header (total rows + summed nominal) over the FULL filtered set,
	// independent of pagination, so the client's summary card is correct without
	// having to load every page first.
	var agg struct {
		TotalTransaksi int64   `json:"total_transaksi"`
		TotalNominal   float64 `json:"total_nominal"`
	}
	aggQuery := "SELECT COUNT(*) as total_transaksi, COALESCE(SUM(nominal_bayar), 0) as total_nominal FROM (" + query + ") as agg_table"
	s.db.Raw(aggQuery, params...).Scan(&agg)

	query += " ORDER BY tanggal_pembayaran DESC LIMIT ? OFFSET ?"
	offset := (page - 1) * limit
	params = append(params, limit, offset)

	var list []model.IncomeDetailRow
	err := s.db.Raw(query, params...).Scan(&list).Error
	if err != nil {
		return nil, err
	}

	// Post-process payment types
	for i := range list {
		row := &list[i]
		if row.SourceType == "DEPOSIT_TOP_UP" {
			row.PaymentType = "Top Up Deposit"
		} else if row.SourceType == "DEPOSIT_ADJUSTMENT" {
			row.PaymentType = row.StatusPembayaranAkhir
		} else if row.PaymentIndex > 0 {
			row.PaymentType = "Pelunasan"
		} else if row.NominalBayar >= row.TotalAkhir {
			row.PaymentType = "Lunas"
		} else {
			row.PaymentType = "DP"
		}
	}

	return map[string]interface{}{
		"data":   list,
		"total":  agg.TotalTransaksi,
		"header": agg,
		"page":   page,
		"limit":  limit,
	}, nil
}
