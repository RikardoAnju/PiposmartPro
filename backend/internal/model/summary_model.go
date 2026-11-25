// internal/model/summary_model.go
package model

type HomeSummaryDTO struct {
	PendapatanHariIni float64 `json:"pendapatan_hari_ini"`
	Penjualan         float64 `json:"penjualan"`
	Pengeluaran       float64 `json:"pengeluaran"`
	TotalTransaksi    int64   `json:"total_transaksi"` // Ubah int menjadi int64
	ServerTime        string  `json:"server_time"` 
}