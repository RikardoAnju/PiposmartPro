package model

import "time"

// QueueDTO digunakan untuk menampilkan list data ringkas pada tab antrian/status.
// Didesain ringan (tanpa preload berat) untuk performa maksimal.
type QueueDTO struct {
	// Tag gorm:"column:..." harus sesuai dengan alias di SELECT raw query
	ID               string    `json:"tr_id" gorm:"column:tr_id"`
	Invoice          string    `json:"tr_invoice" gorm:"column:tr_invoice"`
	PelangganNama    string    `json:"pelanggan_nama" gorm:"column:pelanggan_nama"`
	Total            float64   `json:"tr_total" gorm:"column:tr_total"`
	StatusPembayaran string    `json:"tr_status_pembayaran" gorm:"column:tr_status_pembayaran"`
	StatusOrder      string    `json:"tr_status_order" gorm:"column:tr_status_order"`
	TglMasuk         time.Time `json:"tr_created" gorm:"column:tr_created"`
	TglEstimasi      time.Time `json:"tr_estimate" gorm:"column:tr_estimate"`
}

// AggregatedQueueResponse adalah struktur pembungkus untuk optimasi 1 hit API dapat semua tab.
// Digunakan oleh StatusService.GetFullQueueAggregated.
type AggregatedQueueResponse struct {
	Antrian   []QueueDTO `json:"Antrian"`
	Proses    []QueueDTO `json:"Proses"`
	SiapAmbil []QueueDTO `json:"Siap Ambil"`
	Selesai   []QueueDTO `json:"Selesai"`
	Batal     []QueueDTO `json:"Batal"`
}