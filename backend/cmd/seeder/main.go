package main

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"log"
	"os"
	"time"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	// 1. Konfigurasi Koneksi Database
	// Membaca DSN dari environment variable untuk fleksibilitas Docker
	dsn := os.Getenv("DB_DSN")
	if dsn == "" {
		// Fallback ke kredensial server jika environment tidak diatur
		dsn = "ayocuci_user:P26k8H>oS$k|@tcp(127.0.0.1:3306)/ayocuci_db?charset=utf8mb4&parseTime=True&loc=Local"
		// dsn = "ayocuci_user:P26k8H>oS$k|@tcp(76.13.19.62:3306)/ayocuci_db?charset=utf8mb4&parseTime=True&loc=Local"
	}

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("❌ Gagal koneksi database:", err)
	}

	fmt.Println("--------------------------------------------")
	fmt.Println("🚀 AYOCUCI DATABASE SEEDER (ONLY)")
	fmt.Println("--------------------------------------------")
	
	// Langsung eksekusi seeding data
	seedData(db)
}

// Helper untuk pointer string karena field model banyak yang menggunakan pointer
func stringPtr(s string) *string {
	return &s
}

func seedData(db *gorm.DB) {
	statuses := []string{"Antrian", "Proses", "Siap Ambil", "Selesai", "Batal"}
	outletID := "1.001"
	actorID := "1"
	actorType := "user"

	fmt.Printf("\n🚀 Memulai Seeding 505 Data untuk Outlet %s...\n", outletID)

	for _, status := range statuses {
		fmt.Printf("⏳ Seeding status [%s]: ", status)
		for i := 1; i <= 101; i++ {
			err := db.Transaction(func(tx *gorm.DB) error {
				// Variasi waktu agar testing pagination (limit 20) terlihat nyata di UI
				now := time.Now().Add(time.Duration(-i) * time.Hour) 
				
				// 1. Header Transaksi (ac_transaksi)
				trx := model.Transaksi{
					ID:               utils.GenTransaksiID(tx, outletID),
					OutletID:         outletID,
					PelangganID:      "PL.12.001.202602001",
					// ParfumID:         stringPtr("PF.1.001.03"),
					// DiskonID:         stringPtr("DIS.1.001.02.002"),
					TotalKotor:       50000,
					PotonganDiskon:   5000,
					Total:            45000,
					StatusOrder:      status,
					StatusPembayaran: "Lunas",
					CreatedAt:        now,
					UserUpdate:       &actorID,
					UserUpdateType:   &actorType,
				}
				if err := tx.Create(&trx).Error; err != nil { return err }

				// 2. Detail Transaksi (ac_detail_transaksi)
				// Digunakan untuk kalkulasi tr_estimate di Aggregated Query
				est := now.Add(48 * time.Hour)
				detail := model.DetailTransaksi{
					ID:          fmt.Sprintf("DTRX/%s/001", trx.ID),
					TransaksiID: trx.ID,
					ProductID:   "JP.LN.12.001.01.01",
					NamaLayanan: "Cuci Kering (Seeder Mode)",
					Harga:       45000,
					Qty:         1,
					Subtotal:    45000,
					ReadyAt:     &est,
				}
				if err := tx.Create(&detail).Error; err != nil { return err }

				// 3. Item Checklist (ac_item_transaksi)
				item := model.ItemTransaksi{
					ID:          fmt.Sprintf("ITRX/%s/001", trx.ID),
					TransaksiID: trx.ID,
					ItemID:      "IT.12.001.01",
					Qty:         5,
				}
				if err := tx.Create(&item).Error; err != nil { return err }

				// 4. Pembayaran (ac_dp_transaksi)
				payment := model.DPTransaksi{
					ID:                 utils.GenDPTrxID(tx, trx.ID),
					TransaksiID:        trx.ID,
					MetodePembayaranID: "MP.12.001.02",
					JumlahDP:           45000,
					JumlahSisa:         0,
					TanggalDP:          now,
					UserUpdate:         actorID,
				}
				if err := tx.Create(&payment).Error; err != nil { return err }

				return nil
			})

			if err != nil {
				fmt.Printf("\n❌ Gagal pada data ke-%d: %v", i, err)
				return
			}
			
			if i % 20 == 0 { fmt.Print(".") } // Indikator progress setiap 1 halaman UI
		}
		fmt.Println(" OK")
	}
	fmt.Println("\n✅ SEMUA DATA BERHASIL DIMASUKKAN!")
}