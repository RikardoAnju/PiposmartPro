package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"math"
	"strings"
	"time"

	"gorm.io/gorm"
)

type ReportService struct {
	db *gorm.DB
}

func NewReportService(db *gorm.DB) *ReportService {
	return &ReportService{db: db}
}

func reportCSVValues(raw string) []string {
	values := make([]string, 0)
	for _, value := range strings.Split(raw, ",") {
		value = strings.TrimSpace(value)
		if value != "" && !strings.EqualFold(value, "Semua") {
			values = append(values, value)
		}
	}
	return values
}

func (s *ReportService) GetAllTransactionReport(outletID string, start, end string, status string, statusPembayaran string, search string, customerID string, page int, limit int) (map[string]interface{}, error) {
	db := s.db.Session(&gorm.Session{})
	statuses := reportCSVValues(status)
	paymentStatuses := reportCSVValues(statusPembayaran)

	// ── 1. Header (aggregate) ────────────────────────────────
	type header struct {
		TotalTransaksi  int64   `json:"total_transaksi"`
		TotalPendapatan float64 `json:"total_pendapatan"`
		Trend           string  `json:"trend"`
	}
	var h header

	headerSQL := `
		SELECT 
			COUNT(t.tr_id) as total_transaksi,
			COALESCE(SUM(CASE WHEN t.tr_status_order != 'Batal' THEN t.tr_total ELSE 0 END), 0) as total_pendapatan
		FROM ac_transaksi t`
	headerWhere := " WHERE t.tr_outlet = ? AND t.tr_created BETWEEN ? AND ?"
	headerArgs := []interface{}{outletID, start, end}

	if len(statuses) > 0 {
		headerWhere += " AND t.tr_status_order IN ?"
		headerArgs = append(headerArgs, statuses)
	}
	if len(paymentStatuses) > 0 {
		headerWhere += " AND t.tr_status_pembayaran IN ?"
		headerArgs = append(headerArgs, paymentStatuses)
	}
	if search != "" {
		headerSQL += " LEFT JOIN ac_pelanggan p ON p.pl_id = t.tr_pelanggan"
		headerWhere += " AND (p.pl_nama LIKE ? OR t.tr_id LIKE ?)"
		headerArgs = append(headerArgs, "%"+search+"%", "%"+search+"%")
	}
	if customerID != "" {
		headerWhere += " AND t.tr_pelanggan = ?"
		headerArgs = append(headerArgs, customerID)
	}

	db.Raw(headerSQL+headerWhere, headerArgs...).Scan(&h)
	h.Trend = "+12%"

	// ── 2. Count total rows for pagination ───────────────────
	var total int64
	countSQL := "SELECT COUNT(t.tr_id) FROM ac_transaksi t"
	countWhere := " WHERE t.tr_outlet = ? AND t.tr_created BETWEEN ? AND ?"
	countArgs := []interface{}{outletID, start, end}

	if len(statuses) > 0 {
		countWhere += " AND t.tr_status_order IN ?"
		countArgs = append(countArgs, statuses)
	}
	if len(paymentStatuses) > 0 {
		countWhere += " AND t.tr_status_pembayaran IN ?"
		countArgs = append(countArgs, paymentStatuses)
	}
	if search != "" {
		countSQL += " LEFT JOIN ac_pelanggan p ON p.pl_id = t.tr_pelanggan"
		countWhere += " AND (p.pl_nama LIKE ? OR t.tr_id LIKE ?)"
		countArgs = append(countArgs, "%"+search+"%", "%"+search+"%")
	}
	if customerID != "" {
		countWhere += " AND t.tr_pelanggan = ?"
		countArgs = append(countArgs, customerID)
	}

	db.Raw(countSQL+countWhere, countArgs...).Scan(&total)

	// ── 3. Main list query — single raw SQL, no Preload ──────
	listSQL := `
		SELECT 
			t.tr_id                 as id,
			t.tr_outlet             as outlet_id,
			t.tr_status_order       as status_order,
			t.tr_created            as created_at,
			t.tr_pelanggan          as pelanggan_id,
			t.tr_parfum             as parfum_id,
			t.tr_diskon             as diskon_id,
			t.tr_total_kotor        as total_kotor,
			t.tr_potongan_diskon    as potongan_diskon,
			t.tr_rounding           as rounding_amount,
			t.tr_total              as total_akhir,
			t.tr_status_pembayaran  as status_pembayaran,
			t.tr_catatan            as catatan,
			t.tr_lastupdate         as updated_at,
			t.tr_jemput_alamat      as jemput_alamat,
			t.tr_jemput_biaya       as jemput_biaya,
			t.tr_antar_alamat       as antar_alamat,
			t.tr_antar_biaya        as antar_biaya,
			t.tr_estimate           as tr_estimate,
			t.tr_kasir_nama         as kasir_name,

			COALESCE(p.pl_nama, '')  as pelanggan_nama,
			COALESCE(p.pl_nohp, '')  as pelanggan_nohp,

			COALESCE((SELECT mp.mp_nama_metode 
				FROM ac_dp_transaksi dp 
				JOIN ac_metode_pembayaran mp ON mp.mp_id = dp.dptr_metode_pembayaran 
				WHERE dp.dptr_transaksi = t.tr_id 
				ORDER BY dp.dptr_tanggal_dp DESC 
				LIMIT 1), '') as metode_pembayaran,

			COALESCE((SELECT SUM(dptr_jumlah_dp) 
				FROM ac_dp_transaksi 
				WHERE dptr_transaksi = t.tr_id), 0) as dp_amount

		FROM ac_transaksi t
		LEFT JOIN ac_pelanggan p ON p.pl_id = t.tr_pelanggan`

	listWhere := " WHERE t.tr_outlet = ? AND t.tr_created BETWEEN ? AND ?"
	listArgs := []interface{}{outletID, start, end}

	if len(statuses) > 0 {
		listWhere += " AND t.tr_status_order IN ?"
		listArgs = append(listArgs, statuses)
	}
	if len(paymentStatuses) > 0 {
		listWhere += " AND t.tr_status_pembayaran IN ?"
		listArgs = append(listArgs, paymentStatuses)
	}
	if search != "" {
		listWhere += " AND (p.pl_nama LIKE ? OR t.tr_id LIKE ?)"
		listArgs = append(listArgs, "%"+search+"%", "%"+search+"%")
	}
	if customerID != "" {
		listWhere += " AND t.tr_pelanggan = ?"
		listArgs = append(listArgs, customerID)
	}

	offset := (page - 1) * limit
	listWhere += " ORDER BY t.tr_created DESC LIMIT ? OFFSET ?"
	listArgs = append(listArgs, limit, offset)

	var list []map[string]interface{}
	db.Raw(listSQL+listWhere, listArgs...).Scan(&list)

	// ── 4. Post-process: estimate fallback + restructure pelanggan ──
	for i := range list {
		row := list[i]

		// Fallback tr_estimate
		if row["tr_estimate"] == nil {
			if created, ok := row["created_at"].(time.Time); ok {
				estimated := created.Add(48 * time.Hour)
				row["tr_estimate"] = estimated
			}
		}

		// Nest pelanggan object for Flutter compatibility
		row["pelanggan"] = map[string]interface{}{
			"id":    row["pelanggan_id"],
			"nama":  row["pelanggan_nama"],
			"no_hp": row["pelanggan_nohp"],
		}
		delete(row, "pelanggan_nama")
		delete(row, "pelanggan_nohp")
	}

	return map[string]interface{}{
		"header": h,
		"data":   list,
		"total":  total,
		"page":   page,
		"limit":  limit,
	}, nil
}

// GetOperationalSummary: Untuk Bottom Sheet "Ringkasan"
func (s *ReportService) GetOperationalSummary(outletID string, start, end string) (model.OperationalSummaryResponse, error) {
	var res model.OperationalSummaryResponse

	db := s.db.Session(&gorm.Session{})
	db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order = 'Siap Ambil' AND tr_created BETWEEN ? AND ?", outletID, start, end).Count(&res.BelumDiambil)
	db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order = 'Selesai' AND tr_created BETWEEN ? AND ?", outletID, start, end).Count(&res.SudahDiambil)
	db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order IN ('Selesai', 'Siap Ambil') AND tr_created BETWEEN ? AND ?", outletID, start, end).Count(&res.Selesai)

	return res, nil
}

func (s *ReportService) GetServiceReport(outletID string, start, end string, page, limit int) (model.ServiceReportResponse, error) {
	res := model.ServiceReportResponse{}
	res.List = []model.ServiceBreakdown{}
	res.Header.TotalQuantity = map[string]float64{"kg": 0, "pcs": 0, "m": 0, "koin": 0}

	type serviceDetailRow struct {
		DetailID     string
		TransaksiID  string
		ID           string
		NamaLayanan  string
		NamaKategori string
		Qty          float64
		Satuan       string
		Subtotal     float64
		TrTotalKotor float64
		TrTotal      float64
	}

	var rows []serviceDetailRow

	query := `
		SELECT 
			dt.dtr_id as detail_id,
			dt.dtr_transaksi as transaksi_id,
			dt.dtr_layanan as id, 
			dt.dtr_nama_layanan as nama_layanan, 
			COALESCE(ly.ly_nama, '') as nama_kategori,
			dt.dtr_qty as qty, 
			dt.dtr_satuan as satuan, 
			dt.dtr_subtotal as subtotal,
			COALESCE(t.tr_total_kotor, 0) as tr_total_kotor,
			COALESCE(t.tr_total, 0) as tr_total
		FROM ac_detail_transaksi dt
		JOIN ac_transaksi t ON t.tr_id = dt.dtr_transaksi
		LEFT JOIN ac_jenis_produk jp ON jp.jp_id = dt.dtr_layanan
		LEFT JOIN ac_layanan ly ON ly.ly_id = jp.jp_layanan
		WHERE t.tr_outlet = ? AND t.tr_status_order != 'Batal' AND t.tr_created BETWEEN ? AND ?
		ORDER BY dt.dtr_transaksi, dt.dtr_id`

	db := s.db.Session(&gorm.Session{})
	err := db.Raw(query, outletID, start, end).Scan(&rows).Error
	if err != nil {
		return res, err
	}

	grouped := map[string]*model.ServiceBreakdown{}
	transactionIDs := map[string]struct{}{}
	order := []string{}

	flushTransaction := func(txRows []serviceDetailRow) {
		if len(txRows) == 0 {
			return
		}

		serviceSubtotal := 0.0
		for _, row := range txRows {
			serviceSubtotal += row.Subtotal
		}

		values := make([]float64, len(txRows))
		targetTotal := math.Round(serviceSubtotal)

		for i, row := range txRows {
			value := row.Subtotal
			if value < 0 {
				value = 0
			}
			values[i] = value
		}

		allocatedBeforeLast := 0.0

		for i, row := range txRows {
			allocated := math.Floor(values[i])
			if i == len(txRows)-1 {
				allocated = targetTotal - allocatedBeforeLast
				if allocated < 0 {
					allocated = 0
				}
			}

			key := row.ID + "\x00" + row.NamaLayanan + "\x00" + row.NamaKategori + "\x00" + strings.ToLower(row.Satuan)
			item, exists := grouped[key]
			if !exists {
				grouped[key] = &model.ServiceBreakdown{
					ID:           row.ID,
					NamaLayanan:  row.NamaLayanan,
					NamaKategori: row.NamaKategori,
					Satuan:       row.Satuan,
				}
				order = append(order, key)
				item = grouped[key]
			}

			item.TotalPesanan++
			item.Qty += row.Qty
			item.TotalHarga += allocated
			allocatedBeforeLast += allocated
		}
	}

	currentTransaction := ""
	currentRows := []serviceDetailRow{}
	for _, row := range rows {
		transactionIDs[row.TransaksiID] = struct{}{}
		if currentTransaction != "" && row.TransaksiID != currentTransaction {
			flushTransaction(currentRows)
			currentRows = []serviceDetailRow{}
		}
		currentTransaction = row.TransaksiID
		currentRows = append(currentRows, row)
	}
	flushTransaction(currentRows)

	for _, key := range order {
		res.List = append(res.List, *grouped[key])
	}

	for i := 0; i < len(res.List)-1; i++ {
		for j := i + 1; j < len(res.List); j++ {
			if res.List[j].TotalHarga > res.List[i].TotalHarga {
				res.List[i], res.List[j] = res.List[j], res.List[i]
			}
		}
	}

	var totalQtyKg, totalQtyPcs, totalQtyM, totalQtyKoin float64
	res.Header.TotalPesanan = int64(len(transactionIDs))
	for i, item := range res.List {
		res.Header.TotalLayanan++
		res.Header.TotalHarga += item.TotalHarga

		unit := strings.ToLower(item.Satuan)
		switch unit {
		case "kg", "kilogram", "kilo":
			totalQtyKg += item.Qty
		case "pcs", "biji", "buah":
			totalQtyPcs += item.Qty
		case "mtr", "m", "meter":
			totalQtyM += item.Qty
		case "koin", "coin":
			totalQtyKoin += item.Qty
		}

		// Kita normalisasi satuannya di list biar rapi di UI
		res.List[i].Satuan = unit
	}

	res.Header.TotalQuantity = map[string]float64{
		"kg":   totalQtyKg,
		"pcs":  totalQtyPcs,
		"m":    totalQtyM,
		"koin": totalQtyKoin,
	}

	res.Page = page
	res.Limit = limit
	res.Total = len(res.List)
	res.TotalPages = (res.Total + limit - 1) / limit
	startIndex := (page - 1) * limit
	if startIndex >= res.Total {
		res.List = []model.ServiceBreakdown{}
	} else {
		endIndex := startIndex + limit
		if endIndex > res.Total {
			endIndex = res.Total
		}
		res.List = res.List[startIndex:endIndex]
	}
	res.HasMore = page*limit < res.Total

	return res, nil
}
