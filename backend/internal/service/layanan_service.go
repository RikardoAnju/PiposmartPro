package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type LayananService struct {
	db *gorm.DB
}

func NewLayananService(db *gorm.DB) *LayananService {
	return &LayananService{db: db}
}

// PopularService = ranking layanan tersering se-outlet (dari data transaksi
// nyata semua kasir), dipakai untuk mengurutkan chip "Tambah Cepat" di app.
type PopularService struct {
	ProductID  string `json:"product_id"`
	OrderCount int    `json:"order_count"`
}

// GetPopularProductIDs mengembalikan layanan paling sering dipesan pada outlet,
// dihitung dari jumlah baris detail transaksi (exclude order 'Batal').
func (s *LayananService) GetPopularProductIDs(outletID string, limit int) ([]PopularService, error) {
	if limit <= 0 {
		limit = 12
	}
	var result []PopularService
	err := s.db.
		Table("ac_detail_transaksi AS d").
		Select("d.dtr_layanan AS product_id, COUNT(*) AS order_count").
		Joins("JOIN ac_transaksi t ON t.tr_id = d.dtr_transaksi").
		Where("t.tr_outlet = ? AND t.tr_status_order <> 'Batal' AND d.dtr_layanan <> ''", outletID).
		Group("d.dtr_layanan").
		Order("order_count DESC").
		Limit(limit).
		Scan(&result).Error
	return result, err
}

func normalizeServiceUnit(unit string) (string, error) {
	switch strings.ToLower(strings.TrimSpace(unit)) {
	case "kg", "kilogram", "kilo":
		return "kg", nil
	case "pcs", "piece", "pieces":
		return "pcs", nil
	case "m", "meter", "mtr", "m2", "m²":
		return "m", nil
	case "koin", "coin":
		return "koin", nil
	default:
		return "", fmt.Errorf("satuan %q tidak valid", unit)
	}
}

func sanitizeMinimalOrder(min *float64) (*float64, error) {
	if min == nil {
		return nil, nil
	}
	value := *min
	if value <= 0 {
		return nil, errors.New("minimal order harus lebih dari 0")
	}
	return &value, nil
}

func (s *LayananService) CreateLayanan(ly model.Layanan, actorID string, actorType string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		// 1. Generate ID Layanan (LN.OUTLETID.XX)
		ly.ID = utils.GenLayananID(tx, ly.OutletID)
		ly.UserUpdate = actorID // String ID
		ly.UserUpdateType = actorType

		// 2. Simpan Header
		if err := tx.Omit("Products").Create(&ly).Error; err != nil {
			return err
		}

		// 3. Simpan Detail Produk (JP.LAYANANID.XX)
		for i := range ly.Products {
			normalizedUnit, err := normalizeServiceUnit(ly.Products[i].Satuan)
			if err != nil {
				return err
			}
			minimalOrder, err := sanitizeMinimalOrder(ly.Products[i].MinimalOrder)
			if err != nil {
				return err
			}

			ly.Products[i].LayananID = ly.ID
			ly.Products[i].Satuan = normalizedUnit
			ly.Products[i].MinimalOrder = minimalOrder
			// Penomoran manual untuk menghindari deadlock dalam loop transaksi
			ly.Products[i].ID = fmt.Sprintf("JP.%s.%02d", ly.ID, i+1)
			ly.Products[i].UserUpdate = actorID
			ly.Products[i].UserUpdateType = actorType

			if err := tx.Create(&ly.Products[i]).Error; err != nil {
				return err
			}
		}
		return nil
	})
}

// CreateDefaultLayanans dipanggil otomatis saat registrasi outlet baru
func (s *LayananService) CreateDefaultLayanans(tx *gorm.DB, outletID string, ownerID string) error {
	// 1. Definisi Data Master untuk 3 Kategori Default
	defaultData := []struct {
		Nama   string
		Proses string
		Produk []struct {
			Nama      string
			Harga     float64
			Satuan    string
			Durasi    int
			Icon      string
			Prioritas int
		}
	}{
		{
			Nama:   "Cuci Kiloan",
			Proses: "Cuci,Kering,Lipat,Setrika",
			Produk: []struct {
				Nama      string
				Harga     float64
				Satuan    string
				Durasi    int
				Icon      string
				Prioritas int
			}{
				{"Cuci Kiloan Reguler", 6000, "Kg", 2, "assets/images/layanan/kaos.webp", 0},
				{"Cuci Kiloan Ekspres", 10000, "Kg", 1, "assets/images/layanan/express.webp", 20},
			},
		},
		{
			Nama:   "Bedcover",
			Proses: "Cuci,Kering",
			Produk: []struct {
				Nama      string
				Harga     float64
				Satuan    string
				Durasi    int
				Icon      string
				Prioritas int
			}{
				{"Bedcover Singel", 10000, "Pcs", 2, "assets/images/layanan/bed cover.webp", 0},
				{"Bedcover Double", 20000, "Pcs", 2, "assets/images/layanan/bed cover.webp", 0},
			},
		},
		{
			Nama:   "Karpet",
			Proses: "Cuci,Kering",
			Produk: []struct {
				Nama      string
				Harga     float64
				Satuan    string
				Durasi    int
				Icon      string
				Prioritas int
			}{
				{"Karpet Biasa", 6000, "M", 2, "assets/images/layanan/Karpet.webp", 0},
				{"Karpet Masjid", 12000, "M", 2, "assets/images/layanan/Karpet.webp", 0},
			},
		},
	}
	for _, category := range defaultData {

		layananID := utils.GenLayananID(tx, outletID)

		ly := model.Layanan{
			ID:             layananID,
			OutletID:       outletID,
			Nama:           category.Nama,
			Proses:         category.Proses,
			UserUpdate:     ownerID,
			UserUpdateType: "user",
		}

		if err := tx.Create(&ly).Error; err != nil {
			return fmt.Errorf("gagal insert layanan kategori %s: %v", category.Nama, err)
		}

		// 3. Loop Kedua untuk Insert Sub-Produk (JenisProduk)
		for i, pk := range category.Produk {
			p := model.JenisProduk{
				// Format ID: JP.[ID_LAYANAN].[SEQUENCE]
				ID:             fmt.Sprintf("JP.%s.%02d", layananID, i+1),
				LayananID:      layananID,
				Nama:           pk.Nama,
				Harga:          pk.Harga,
				Satuan:         strings.ToLower(pk.Satuan),
				Durasi:         pk.Durasi,
				DurasiSatuan:   "Hari",
				Icon:           pk.Icon,
				Prioritas:      pk.Prioritas,
				UserUpdate:     ownerID,
				UserUpdateType: "user",
			}

			if err := tx.Create(&p).Error; err != nil {
				return fmt.Errorf("gagal insert jenis produk %s: %v", pk.Nama, err)
			}
		}
	}

	return nil
}

func (s *LayananService) GetLayananByOutlet(outletID string) ([]model.Layanan, error) {
	var layanans []model.Layanan
	err := s.db.Preload("Products").Where("ly_outlet = ?", outletID).Find(&layanans).Error
	return layanans, err
}

func (s *LayananService) UpdateLayanan(ly model.Layanan, actorID string, actorType string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		// 1. Validasi Keberadaan Layanan Header
		var existingLayanan model.Layanan
		if err := tx.Where("ly_id = ? AND ly_outlet = ?", ly.ID, ly.OutletID).First(&existingLayanan).Error; err != nil {
			return errors.New("layanan tidak ditemukan")
		}

		// 2. Filter ID produk yang valid (sudah ada di DB) untuk proses Soft Delete
		var incomingIDs []string
		for _, p := range ly.Products {
			// Produk lama biasanya berawalan 'JP.'
			if p.ID != "" && strings.HasPrefix(p.ID, "JP.") {
				incomingIDs = append(incomingIDs, p.ID)
			}
		}

		// 3. Hapus produk yang tidak ada lagi di list kiriman Frontend
		if len(incomingIDs) > 0 {
			if err := tx.Where("jp_layanan = ? AND jp_id NOT IN ?", ly.ID, incomingIDs).Delete(&model.JenisProduk{}).Error; err != nil {
				return err
			}
		} else {
			// Jika semua produk lama dihapus
			if err := tx.Where("jp_layanan = ?", ly.ID).Delete(&model.JenisProduk{}).Error; err != nil {
				return err
			}
		}

		// 4. Update Header Layanan
		if err := tx.Model(&existingLayanan).Updates(map[string]interface{}{
			"ly_nama":            ly.Nama,
			"ly_proses":          ly.Proses,
			"ly_userupdate":      actorID,
			"ly_userupdate_type": actorType,
		}).Error; err != nil {
			return err
		}

		// 5. Loop Produk: Tentukan apakah Update atau Create
		for i, prod := range ly.Products {
			normalizedUnit, err := normalizeServiceUnit(prod.Satuan)
			if err != nil {
				return err
			}
			minimalOrder, err := sanitizeMinimalOrder(prod.MinimalOrder)
			if err != nil {
				return err
			}

			prod.LayananID = ly.ID
			prod.Satuan = normalizedUnit
			prod.MinimalOrder = minimalOrder
			prod.UserUpdate = actorID
			prod.UserUpdateType = actorType

			// LOGIKA PENENTUAN: Jika ID mengandung 'JP.' berarti Update, jika tidak berarti Produk Baru
			if prod.ID != "" && strings.HasPrefix(prod.ID, "JP.") {
				// PROSES UPDATE
				if err := tx.Model(&model.JenisProduk{}).Where("jp_id = ?", prod.ID).Updates(map[string]interface{}{
					"jp_nama":            prod.Nama,
					"jp_harga":           prod.Harga,
					"jp_satuan":          prod.Satuan,
					"jp_minimal_order":   prod.MinimalOrder,
					"jp_durasi":          prod.Durasi,
					"jp_durasi_satuan":   prod.DurasiSatuan,
					"jp_gambar":          prod.Icon,
					"jp_prioritas":       prod.Prioritas,
					"jp_userupdate":      actorID,
					"jp_userupdate_type": actorType,
				}).Error; err != nil {
					return err
				}
			} else {
				// PROSES INSERT PRODUK BARU
				// Generate ID resmi: JP.LNXXX.02 (menggunakan index agar urut)
				newID := fmt.Sprintf("JP.%s.%02d", ly.ID, i+1)

				// Cek apakah ID tersebut sudah pernah dipakai (menghindari duplikasi primary key)
				var count int64
				tx.Unscoped().Model(&model.JenisProduk{}).Where("jp_id = ?", newID).Count(&count)
				if count > 0 {
					// Jika bentrok, gunakan timestamp unik
					newID = fmt.Sprintf("JP.%s.%d", ly.ID, time.Now().UnixNano()/1e6)
				}

				prod.ID = newID
				if err := tx.Create(&prod).Error; err != nil {
					return err
				}
			}
		}

		return nil
	})
}

func (s *LayananService) DeleteLayanan(id string, outletID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var trxCount int64
		// Cek penggunaan produk di transaksi aktif
		tx.Table("ac_detail_transaksi").
			Joins("JOIN ac_jenis_produk ON ac_detail_transaksi.dtr_layanan = ac_jenis_produk.jp_id").
			Where("ac_jenis_produk.jp_layanan = ?", id).Count(&trxCount)

		if trxCount > 0 {
			return errors.New("layanan tidak bisa dihapus karena produknya sudah digunakan dalam transaksi")
		}

		tx.Where("jp_layanan = ?", id).Delete(&model.JenisProduk{})
		return tx.Where("ly_id = ? AND ly_outlet = ?", id, outletID).Delete(&model.Layanan{}).Error
	})
}
