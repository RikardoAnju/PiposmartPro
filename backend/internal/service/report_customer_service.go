package service

import (
	"strings"

	"github.com/RikardoAnju/PiposmartPro/internal/model"

	"gorm.io/gorm"
)

// normalizeGenderValues memetakan input filter jenis kelamin yang bebas
// (mis. "L", "laki-laki", "pria", "P", "perempuan", "wanita") ke daftar
// nilai lowercase yang mungkin tersimpan di kolom pl_jenis_kelamin.
// Mengembalikan nil bila input kosong atau bukan filter gender (mis. "semua"),
// sehingga pemanggil tidak menambahkan kondisi WHERE.
func normalizeGenderValues(raw string) []string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "l", "laki-laki", "laki", "pria", "male":
		return []string{"laki-laki", "pria", "l"}
	case "p", "perempuan", "wanita", "female":
		return []string{"perempuan", "wanita", "p"}
	default:
		return nil
	}
}

type CustomerReportService struct {
	db *gorm.DB
}

func NewCustomerReportService(db *gorm.DB) *CustomerReportService {
	return &CustomerReportService{db: db}
}

// GetCustomerSummary: Untuk Screen "Ringkasan Pelanggan" (Directory)
func (s *CustomerReportService) GetCustomerSummary(outletID string, search string) (model.CustomerSummaryResponse, error) {
	var res model.CustomerSummaryResponse
	res.List = []model.CustomerAgregat{}

	// 1. Total Pelanggan Keseluruhan
	s.db.Table("ac_pelanggan").Where("pl_outlet = ?", outletID).Count(&res.TotalPelanggan)

	// 2. List Pelanggan dengan Lifetime Value (Total Order & Nominal)
	query := `
		SELECT p.*, 
		       COUNT(t.tr_id) as total_order, 
		       COALESCE(SUM(t.tr_total), 0) as total_nominal
		FROM ac_pelanggan p
		LEFT JOIN ac_transaksi t ON p.pl_id = t.tr_pelanggan
			AND t.tr_status_order != 'Batal'
		WHERE p.pl_outlet = ?`

	params := []interface{}{outletID}
	if search != "" {
		query += " AND (p.pl_nama LIKE ? OR p.pl_nohp LIKE ?)"
		params = append(params, "%"+search+"%", "%"+search+"%")
	}

	query += " GROUP BY p.pl_id ORDER BY total_nominal DESC"

	err := s.db.Raw(query, params...).Scan(&res.List).Error
	return res, err
}

// GetCustomerGrowth: Fix Parse Error & Map Chart Data
func (s *CustomerReportService) GetCustomerGrowth(outletID string, start, end string) (model.CustomerGrowthResponse, error) {
	var res model.CustomerGrowthResponse
	res.DetailTable = []model.GrowthDetail{}
	res.NewCustomers = []model.GrowthCustomerDetail{}
	res.ChartData = []map[string]interface{}{} // Inisialisasi biar ga null

	// 1. Summary pelanggan baru (untuk detail pertumbuhan)
	// Kita scan ke struct temporary dulu biar GORM ga komplain soal ChartData/DetailTable
	var summary struct {
		TotalPelanggan int64 `json:"total_pelanggan"`
		TotalPria      int64 `json:"total_pria"`
		TotalWanita    int64 `json:"total_wanita"`
	}

	s.db.Table("ac_pelanggan").
		Select("COUNT(pl_id) as total_pelanggan, "+
			"COUNT(CASE WHEN LOWER(pl_jenis_kelamin) IN ('laki-laki', 'pria', 'l') THEN 1 END) as total_pria, "+
			"COUNT(CASE WHEN LOWER(pl_jenis_kelamin) IN ('perempuan', 'wanita', 'p') THEN 1 END) as total_wanita").
		Where("pl_outlet = ? AND pl_created BETWEEN ? AND ?", outletID, start, end).
		Scan(&summary)

	// Pindahin hasil scan ke response utama
	res.TotalPelanggan = summary.TotalPelanggan
	res.TotalPria = summary.TotalPria
	res.TotalWanita = summary.TotalWanita

	// 2. Summary pelanggan yang benar-benar bertransaksi pada periode aktif.
	// Ini dipakai untuk kartu utama supaya tidak tertukar dengan pelanggan baru.
	var transactionSummary struct {
		TotalPelanggan int64   `gorm:"column:total_pelanggan"`
		TotalPria      int64   `gorm:"column:total_pria"`
		TotalWanita    int64   `gorm:"column:total_wanita"`
		TotalOrder     int64   `gorm:"column:total_order"`
		TotalNominal   float64 `gorm:"column:total_nominal"`
	}

	err := s.db.Raw(`
		SELECT
			COUNT(DISTINCT p.pl_id) as total_pelanggan,
			COUNT(DISTINCT CASE WHEN LOWER(p.pl_jenis_kelamin) IN ('laki-laki', 'pria', 'l') THEN p.pl_id END) as total_pria,
			COUNT(DISTINCT CASE WHEN LOWER(p.pl_jenis_kelamin) IN ('perempuan', 'wanita', 'p') THEN p.pl_id END) as total_wanita,
			COUNT(t.tr_id) as total_order,
			COALESCE(SUM(t.tr_total), 0) as total_nominal
		FROM ac_transaksi t
		JOIN ac_pelanggan p ON p.pl_id = t.tr_pelanggan
		WHERE t.tr_outlet = ?
			AND t.tr_status_order != 'Batal'
			AND t.tr_created BETWEEN ? AND ?
	`, outletID, start, end).Scan(&transactionSummary).Error
	if err != nil {
		return res, err
	}

	res.TotalTransactingCustomers = transactionSummary.TotalPelanggan
	res.TransactingPria = transactionSummary.TotalPria
	res.TransactingWanita = transactionSummary.TotalWanita
	res.TotalOrder = transactionSummary.TotalOrder
	res.TotalNominal = transactionSummary.TotalNominal

	// 3. Detail Table Harian pelanggan baru (Grouping by Date & Gender)
	query := `
		SELECT 
			DATE(pl_created) as tanggal,
			COUNT(CASE WHEN LOWER(pl_jenis_kelamin) IN ('perempuan', 'wanita', 'p') THEN 1 END) as perempuan,
			COUNT(CASE WHEN LOWER(pl_jenis_kelamin) IN ('laki-laki', 'pria', 'l') THEN 1 END) as laki_laki,
			COUNT(pl_id) as total
		FROM ac_pelanggan
		WHERE pl_outlet = ? AND pl_created BETWEEN ? AND ?
		GROUP BY DATE(pl_created)
		ORDER BY tanggal ASC` // ASC biar chart-nya urut dari tanggal tua ke muda

	err = s.db.Raw(query, outletID, start, end).Scan(&res.DetailTable).Error
	if err != nil {
		return res, err
	}

	// 4. Detail pelanggan baru untuk export/report agar agregat gender bisa ditelusuri.
	newCustomerQuery := `
		SELECT
			DATE(pl_created) as tanggal,
			pl_nama as nama,
			pl_nohp as no_hp,
			pl_jenis_kelamin as jenis_kelamin
		FROM ac_pelanggan
		WHERE pl_outlet = ? AND pl_created BETWEEN ? AND ?
		ORDER BY pl_created ASC`

	err = s.db.Raw(newCustomerQuery, outletID, start, end).Scan(&res.NewCustomers).Error
	if err != nil {
		return res, err
	}

	// 5. Mapping ChartData dari DetailTable
	// Biar Chart di Flutter lo gampang bacanya
	for _, d := range res.DetailTable {
		chartRow := map[string]interface{}{
			"date":  d.Tanggal,
			"value": d.Total,
		}
		res.ChartData = append(res.ChartData, chartRow)
	}

	return res, nil
}

// GetTopCustomers: Untuk Screen 2 Tab "Top Pelanggan" (Podium Logic)
func (s *CustomerReportService) GetTopCustomers(outletID string, start, end string, jenisKelamin, activityStatus string, page, limit int) (model.TopCustomerResponse, error) {
	var res model.TopCustomerResponse
	res.Podium = []model.CustomerAgregat{}
	res.Others = []model.CustomerAgregat{}

	// Query Dasar untuk ranking pelanggan berdasarkan spending
	queryBase := `
		SELECT p.*,
		       COUNT(t.tr_id) as total_order,
		       COALESCE(SUM(t.tr_total), 0) as total_nominal
		FROM ac_pelanggan p
		LEFT JOIN ac_transaksi t ON p.pl_id = t.tr_pelanggan
			AND t.tr_outlet = ?
			AND t.tr_status_order != 'Batal'
			AND t.tr_created BETWEEN ? AND ?
		WHERE p.pl_outlet = ?`
	args := []interface{}{outletID, start, end, outletID}

	// Filter opsional berdasarkan jenis kelamin (normalisasi nilai bebas).
	if genderSet := normalizeGenderValues(jenisKelamin); genderSet != nil {
		queryBase += " AND LOWER(p.pl_jenis_kelamin) IN (?)"
		args = append(args, genderSet)
	}

	queryBase += ` GROUP BY p.pl_id`
	switch strings.ToLower(strings.TrimSpace(activityStatus)) {
	case "inactive":
		queryBase += " HAVING COUNT(t.tr_id) = 0"
	case "all":
		// No HAVING clause: include both active and inactive customers.
	default:
		queryBase += " HAVING COUNT(t.tr_id) > 0"
	}

	var summary model.TopCustomerSummary
	summaryQuery := "SELECT COUNT(*) total_customers, COALESCE(SUM(total_order),0) total_order, COALESCE(SUM(total_nominal),0) total_nominal FROM (" + queryBase + ") customer_rows"
	err := s.db.Raw(summaryQuery, args...).Scan(&summary).Error
	if err != nil {
		return res, err
	}
	orderSQL := " ORDER BY total_nominal DESC, total_order DESC, pl_nama ASC"
	if err := s.db.Raw(queryBase+orderSQL+" LIMIT 3", args...).Scan(&res.Podium).Error; err != nil {
		return res, err
	}
	remaining := summary.TotalCustomers - int64(len(res.Podium))
	if remaining < 0 {
		remaining = 0
	}
	offset := int64((page - 1) * limit)
	if err := s.db.Raw(queryBase+orderSQL+" LIMIT ? OFFSET ?", append(append([]interface{}{}, args...), limit, int64(len(res.Podium))+offset)...).Scan(&res.Others).Error; err != nil {
		return res, err
	}
	res.Summary = summary
	res.Page = page
	res.Limit = limit
	res.Total = summary.TotalCustomers
	if remaining > 0 {
		res.TotalPages = int((remaining + int64(limit) - 1) / int64(limit))
	}
	res.HasMore = int64(page*limit) < remaining

	return res, nil
}
