package model

// FinanceSummary untuk card di bagian atas dashboard
type FinanceSummary struct {
	TotalOmset      float64 `json:"total_omset"`
	OmsetTrend      float64 `json:"omset_trend"`
	TotalIncome     float64 `json:"total_income"`
	IncomeTrend     float64 `json:"income_trend"`
	TotalExpense    float64 `json:"total_expense"`
	ExpenseTrend    float64 `json:"expense_trend"`
	ProfitLoss      float64 `json:"profit_loss"`
	ProfitLossTrend float64 `json:"profit_loss_trend"`
	TotalTransaksi  int64   `json:"total_transaksi"`
	TransaksiTrend  float64 `json:"transaksi_trend"`
	PesananDiambil  int64   `json:"pesanan_diambil"`
	PesananTrend    float64 `json:"pesanan_trend"`
}

// DailyChartData untuk data grafik line chart
type DailyChartData struct {
	Date       string  `json:"date"`
	Omset      float64 `json:"omset"`
	Income     float64 `json:"income"`
	Expense    float64 `json:"expense"`
	TotalOrder int64   `json:"total_order"`
}

// FinanceReportResponse wrap semua data untuk satu kali hit API
type FinanceReportResponse struct {
	Summary   FinanceSummary   `json:"summary"`
	ChartData []DailyChartData `json:"chart_data"`
}