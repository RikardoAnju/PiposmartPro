package model

import "time"

type IncomeDetailRow struct {
	ID                    string    `json:"id"`
	SourceType            string    `json:"source_type"`
	TransactionID         string    `json:"transaction_id"`
	TanggalPembayaran     time.Time `json:"tanggal_pembayaran"`
	NominalBayar          float64   `json:"nominal_bayar"`
	TotalAkhir            float64   `json:"total_akhir"`
	StatusPembayaranAkhir string    `json:"status_pembayaran_akhir"`
	PelangganNama         string    `json:"pelanggan_nama"`
	CustomerID            string    `json:"customer_id"`
	MetodeNama            string    `json:"metode_nama"`
	MetodeKategori        string    `json:"metode_kategori"`
	DepositType           string    `json:"deposit_type"`
	ReferenceID           string    `json:"reference_id"`
	BalanceAfter          float64   `json:"balance_after"`
	CreatedBy             string    `json:"created_by"`
	CreatedByName         string    `json:"created_by_name"`
	TanggalTransaksi      time.Time `json:"tanggal_transaksi"`
	PaymentIndex          int       `json:"payment_index"`
	PaymentType           string    `json:"payment_type"` // "DP", "Pelunasan", or "Lunas"
}
