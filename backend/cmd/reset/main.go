package main

import (
	"fmt"
	"log"
	"os"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func main() {
	// 1. Konfigurasi Koneksi Database
	dsn := os.Getenv("DB_DSN")
	if dsn == "" {
		dsn = "ayocuci_user:P26k8H>oS$k|@tcp(127.0.0.1:3306)/ayocuci_db?charset=utf8mb4&parseTime=True&loc=Local"
	}

	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatal("❌ Gagal koneksi database:", err)
	}

	fmt.Println("--------------------------------------------")
	fmt.Println("⚠️  AYOCUCI DATABASE RESET TOOL")
	fmt.Println("--------------------------------------------")
	
	resetData(db)
	
}

func resetData(db *gorm.DB) {
	fmt.Println("\n⏳ Sedang membersihkan tabel transaksi...")


	tables := []string{
		"ac_log_transaksi",
		"ac_dp_transaksi",
		"ac_item_transaksi",
		"ac_detail_transaksi",
		"ac_transaksi",
	}

	for _, table := range tables {
		err := db.Exec(fmt.Sprintf("DELETE FROM %s", table)).Error
		if err != nil {
			fmt.Printf("❌ Gagal menghapus tabel %s: %v\n", table, err)
		} else {
			fmt.Printf("✅ Tabel %s berhasil dikosongkan.\n", table)
		}
	}

	fmt.Println("\n✨ DATABASE TRANSAKSI SEKARANG BERSIH!")
}