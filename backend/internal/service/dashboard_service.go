package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"time"

	"gorm.io/gorm"
)

type DashboardService struct {
	db *gorm.DB
}

func NewDashboardService(db *gorm.DB) *DashboardService {
	return &DashboardService{db: db}
}

func (s *DashboardService) GetSummary(outletID string) (map[string]interface{}, error) {
	var totalOmzet, totalPengeluaran float64
	var totalOrder, pelangganBaru int64

	now := time.Now()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())

	// 1. Hitung penjualan/omzet berdasarkan nilai order yang dibuat hari ini.
	s.db.Table("ac_transaksi").
		Where("tr_outlet = ? AND tr_status_order != 'Batal' AND tr_created >= ?", outletID, startOfDay).
		Select("COALESCE(SUM(tr_total), 0)").Scan(&totalOmzet)

	// 2. Hitung Pengeluaran Hari Ini
	s.db.Model(&model.Pengeluaran{}).
		Where("pg_outlet = ? AND pg_tanggal >= ?", outletID, startOfDay).
		Select("COALESCE(SUM(pg_total), 0)").Scan(&totalPengeluaran)

	// 3. Hitung Jumlah Order Masuk Hari Ini
	s.db.Model(&model.Transaksi{}).
		Where("tr_outlet = ? AND tr_created >= ?", outletID, startOfDay).
		Count(&totalOrder)

	// 4. Pelanggan Baru Hari Ini
	s.db.Model(&model.Pelanggan{}).
		Where("pl_outlet = ? AND pl_created >= ?", outletID, startOfDay).
		Count(&pelangganBaru)

	// 5. Data Grafik 7 Hari Terakhir
	type ChartData struct {
		Tanggal string  `json:"tanggal"`
		Omzet   float64 `json:"omzet"`
		Beban   float64 `json:"beban"`
	}
	var chart []ChartData

	for i := 6; i >= 0; i-- {
		d := now.AddDate(0, 0, -i)
		dateStr := d.Format("2006-01-02")

		var dailyOmzet, dailyExp float64
		s.db.Table("ac_transaksi").
			Where("tr_outlet = ? AND tr_status_order != 'Batal' AND DATE(tr_created) = ?", outletID, dateStr).
			Select("COALESCE(SUM(tr_total), 0)").Scan(&dailyOmzet)

		s.db.Model(&model.Pengeluaran{}).
			Where("pg_outlet = ? AND DATE(pg_tanggal) = ?", outletID, dateStr).
			Select("COALESCE(SUM(pg_total), 0)").Scan(&dailyExp)

		chart = append(chart, ChartData{
			Tanggal: d.Format("02 Jan"),
			Omzet:   dailyOmzet,
			Beban:   dailyExp,
		})
	}

	return map[string]interface{}{
		"omzet_hari_ini":       totalOmzet,
		"pengeluaran_hari_ini": totalPengeluaran,
		"profit_hari_ini":      totalOmzet - totalPengeluaran,
		"total_order_baru":     totalOrder,
		"pelanggan_baru":       pelangganBaru,
		"chart_7_hari":         chart,
	}, nil
}
