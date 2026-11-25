package model

// CustomerSummaryResponse: Untuk Screen 1 (Ringkasan)
type CustomerSummaryResponse struct {
	TotalPelanggan int64             `json:"total_pelanggan"`
	List           []CustomerAgregat `json:"list"`
}

type CustomerAgregat struct {
	Pelanggan
	TotalOrder   int64   `json:"total_order"`
	TotalNominal float64 `json:"total_nominal"`
}

// CustomerGrowthResponse: Untuk Screen 2 Tab Pertumbuhan
type CustomerGrowthResponse struct {
	TotalPelanggan            int64                    `json:"total_pelanggan"`
	TotalPria                 int64                    `json:"total_pria"`
	TotalWanita               int64                    `json:"total_wanita"`
	TotalTransactingCustomers int64                    `json:"total_transacting_customers"`
	TransactingPria           int64                    `json:"transacting_pria"`
	TransactingWanita         int64                    `json:"transacting_wanita"`
	TotalOrder                int64                    `json:"total_order"`
	TotalNominal              float64                  `json:"total_nominal"`
	ChartData                 []map[string]interface{} `json:"chart_data"`
	DetailTable               []GrowthDetail           `json:"detail_table"`
	NewCustomers              []GrowthCustomerDetail   `json:"new_customers"`
}

type GrowthDetail struct {
	Tanggal   string `json:"tanggal"`
	Perempuan int64  `json:"perempuan"`
	LakiLaki  int64  `json:"laki_laki"`
	Total     int64  `json:"total"`
}

type GrowthCustomerDetail struct {
	Tanggal      string `json:"tanggal"`
	Nama         string `json:"nama"`
	NoHP         string `json:"no_hp"`
	JenisKelamin string `json:"jenis_kelamin"`
}

// TopCustomerResponse: Untuk Screen 2 Tab Top Pelanggan
type TopCustomerResponse struct {
	Podium     []CustomerAgregat  `json:"podium"` // Rank 1-3
	Others     []CustomerAgregat  `json:"others"` // Rank 4++
	Summary    TopCustomerSummary `json:"summary"`
	Page       int                `json:"page"`
	Limit      int                `json:"limit"`
	Total      int64              `json:"total"`
	TotalPages int                `json:"total_pages"`
	HasMore    bool               `json:"has_more"`
}

type TopCustomerSummary struct {
	TotalCustomers int64   `json:"total_customers"`
	TotalOrder     int64   `json:"total_order"`
	TotalNominal   float64 `json:"total_nominal"`
}
