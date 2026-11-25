package model

// TransactionReportResponse: Untuk Screen "Semua Data Transaksi"
type TransactionReportResponse struct {
	Header struct {
		TotalTransaksi  int64   `json:"total_transaksi"`
		TotalPendapatan float64 `json:"total_pendapatan"`
		Trend           string  `json:"trend"` // Misal: "+12%"
	} `json:"header"`
	List []Transaksi `json:"list"`
}

// OperationalSummaryResponse: Untuk Bottom Sheet "Ringkasan" di Screen 1
type OperationalSummaryResponse struct {
	BelumDiambil int64 `json:"belum_diambil"`
	SudahDiambil int64 `json:"sudah_diambil"`
	Selesai      int64 `json:"selesai"`
}

// ServiceReportResponse: Untuk Screen "Transaksi Per Layanan"
type ServiceReportResponse struct {
	Header struct {
		TotalLayanan  int64              `json:"total_layanan"`
		TotalPesanan  int64              `json:"total_pesanan"`
		TotalQuantity map[string]float64 `json:"total_quantity"`
		TotalHarga    float64            `json:"total_harga"`
	} `json:"header"`
	List       []ServiceBreakdown `json:"list"`
	Page       int                `json:"page"`
	Limit      int                `json:"limit"`
	Total      int                `json:"total"`
	TotalPages int                `json:"total_pages"`
	HasMore    bool               `json:"has_more"`
}

type ServiceBreakdown struct {
	ID           string  `json:"id"`
	NamaLayanan  string  `json:"nama_layanan"`  // Nama produk (Bedcover Double)
	NamaKategori string  `json:"nama_kategori"` // Nama induk layanan (Satuan/Kiloan)
	TotalPesanan int64   `json:"total_pesanan"`
	Qty          float64 `json:"qty"`
	Satuan       string  `json:"satuan"`
	TotalHarga   float64 `json:"total_harga"`
}
