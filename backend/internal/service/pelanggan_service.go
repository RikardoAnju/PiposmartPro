package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"strconv"
	"strings"
	"time"

	"gorm.io/gorm"
)

type PelangganService struct {
	db *gorm.DB
}

// PelangganListItem = data pelanggan + kapan terakhir bertransaksi (untuk fitur
// "pelanggan terakhir dilayani" di app). LastTransactionAt bisa null bila
// pelanggan belum pernah bertransaksi.
type PelangganListItem struct {
	model.Pelanggan
	LastTransactionAt *time.Time `gorm:"column:last_transaction_at" json:"last_transaction_at"`
	LastTransactionID *string    `gorm:"column:last_transaction_id" json:"last_transaction_id"`
	DepositRupiah     float64    `gorm:"column:deposit_rupiah" json:"deposit_rupiah"`
	DepositKg         float64    `gorm:"column:deposit_kg" json:"deposit_kg"`
}

type BulkImportCustomerInput struct {
	Nama         string
	NoHP         string
	Alamat       string
	JenisKelamin string
}

type BulkImportCustomerResult struct {
	Index     int              `json:"index"`
	Nama      string           `json:"nama"`
	NoHP      string           `json:"no_hp"`
	Status    string           `json:"status"`
	Reason    string           `json:"reason,omitempty"`
	Pelanggan *model.Pelanggan `json:"pelanggan,omitempty"`
}

type BulkImportCustomerResponse struct {
	SuccessCount int                        `json:"success_count"`
	SkippedCount int                        `json:"skipped_count"`
	FailedCount  int                        `json:"failed_count"`
	Results      []BulkImportCustomerResult `json:"results"`
}

type BulkDeleteCustomerResult struct {
	ID     string `json:"id"`
	Nama   string `json:"nama,omitempty"`
	Status string `json:"status"`
	Reason string `json:"reason,omitempty"`
}

type BulkDeleteCustomerResponse struct {
	SuccessCount int                        `json:"success_count"`
	FailedCount  int                        `json:"failed_count"`
	Results      []BulkDeleteCustomerResult `json:"results"`
}

func NewPelangganService(db *gorm.DB) *PelangganService {
	return &PelangganService{db: db}
}

func (s *PelangganService) Create(pl model.Pelanggan) (model.Pelanggan, error) {
	// 1. Validasi: Cek apakah No HP sudah terdaftar di outlet ini
	if pl.NoHP != "" {
		var count int64
		s.db.Model(&model.Pelanggan{}).Where("pl_nohp = ? AND pl_outlet = ?", pl.NoHP, pl.OutletID).Count(&count)
		if count > 0 {
			return pl, errors.New("nomor HP sudah terdaftar sebagai pelanggan di outlet ini")
		}
	}

	// 2. Generate ID (PL.OUTLETID.YYYYMMXXX) menggunakan generator pusat
	pl.ID = utils.GenPelangganID(s.db, pl.OutletID)

	// 3. Generate pl_kode (5 digit terakhir No HP)
	if len(pl.NoHP) >= 5 {
		pl.Kode = pl.NoHP[len(pl.NoHP)-5:]
	} else {
		pl.Kode = pl.ID
		if len(pl.Kode) > 5 {
			pl.Kode = pl.Kode[len(pl.Kode)-5:]
		}
	}

	err := s.db.Create(&pl).Error
	return pl, err
}

func (s *PelangganService) List(outletID string) ([]PelangganListItem, error) {
	var pelanggan []PelangganListItem
	// LEFT JOIN subquery MAX(tr_created) per pelanggan (exclude order batal) agar
	// tiap pelanggan membawa tanggal transaksi terakhirnya.
	err := s.db.
		Table("ac_pelanggan AS p").
		Select(`p.*, t.last_trx AS last_transaction_at, t.last_id AS last_transaction_id,
			COALESCE(d.cda_balance_rupiah, 0) AS deposit_rupiah,
			COALESCE(d.cda_balance_kg, 0) AS deposit_kg`).
		Joins(`LEFT JOIN (
			SELECT tr_pelanggan,
			       MAX(tr_created) AS last_trx,
			       SUBSTRING_INDEX(GROUP_CONCAT(tr_id ORDER BY tr_created DESC), ',', 1) AS last_id
			FROM ac_transaksi
			WHERE tr_outlet = ? AND tr_status_order <> 'Batal'
			GROUP BY tr_pelanggan
		) t ON t.tr_pelanggan = p.pl_id`, outletID).
		Joins("LEFT JOIN ac_customer_deposit_accounts d ON d.cda_customer = p.pl_id AND d.cda_outlet = p.pl_outlet").
		Where("p.pl_outlet = ?", outletID).
		Order("p.pl_nama ASC").
		Scan(&pelanggan).Error
	return pelanggan, err
}

func (s *PelangganService) GetByID(id string, outletID string) (model.Pelanggan, error) {
	var pl model.Pelanggan
	err := s.db.Where("pl_id = ? AND pl_outlet = ?", id, outletID).First(&pl).Error
	return pl, err
}

func (s *PelangganService) Update(pl model.Pelanggan) error {
	// 1. Validasi keberadaan data
	var count int64
	s.db.Model(&model.Pelanggan{}).Where("pl_id = ? AND pl_outlet = ?", pl.ID, pl.OutletID).Count(&count)
	if count == 0 {
		return errors.New("data pelanggan tidak ditemukan")
	}

	// 2. Cek duplikasi No HP jika No HP diubah (terbatas pada outlet yang sama)
	if pl.NoHP != "" {
		var duplicateCount int64
		s.db.Model(&model.Pelanggan{}).Where("pl_nohp = ? AND pl_outlet = ? AND pl_id != ?", pl.NoHP, pl.OutletID, pl.ID).Count(&duplicateCount)
		if duplicateCount > 0 {
			return errors.New("nomor HP ini sudah digunakan oleh pelanggan lain di outlet ini")
		}
	}

	// 3. Update Kode jika nomor HP berubah
	if len(pl.NoHP) >= 5 {
		pl.Kode = pl.NoHP[len(pl.NoHP)-5:]
	} else {
		pl.Kode = pl.ID
		if len(pl.Kode) > 5 {
			pl.Kode = pl.Kode[len(pl.Kode)-5:]
		}
	}

	// DIUBAH: Gunakan map interface agar field UserUpdate (String) terupdate dengan benar
	return s.db.Model(&model.Pelanggan{}).
		Where("pl_id = ? AND pl_outlet = ?", pl.ID, pl.OutletID).
		Updates(map[string]interface{}{
			"pl_nama":            pl.Nama,
			"pl_nohp":            pl.NoHP,
			"pl_alamat":          pl.Alamat,
			"pl_jenis_kelamin":   pl.JenisKelamin,
			"pl_tanggal_lahir":   pl.TanggalLahir,
			"pl_kode":            pl.Kode,
			"pl_userupdate":      pl.UserUpdate, // ID String tersimpan di sini
			"pl_userupdate_type": pl.UserUpdateType,
		}).Error
}

func (s *PelangganService) Delete(id string, outletID string) error {
	var count int64
	s.db.Model(&model.Pelanggan{}).Where("pl_id = ? AND pl_outlet = ?", id, outletID).Count(&count)
	if count == 0 {
		return errors.New("pelanggan tidak ditemukan")
	}

	var trxCount int64
	s.db.Table("ac_transaksi").Where("tr_pelanggan = ?", id).Count(&trxCount)
	if trxCount > 0 {
		return errors.New("pelanggan tidak bisa dihapus karena memiliki riwayat transaksi")
	}

	return s.db.Where("pl_id = ? AND pl_outlet = ?", id, outletID).Delete(&model.Pelanggan{}).Error
}

func (s *PelangganService) BulkImport(
	outletID string,
	actorID string,
	actorType string,
	items []BulkImportCustomerInput,
) (BulkImportCustomerResponse, error) {
	result := BulkImportCustomerResponse{
		Results: make([]BulkImportCustomerResult, 0, len(items)),
	}

	seenPhones := make(map[string]int)

	for idx, item := range items {
		nama := strings.TrimSpace(item.Nama)
		noHP := strings.TrimSpace(item.NoHP)
		alamat := strings.TrimSpace(item.Alamat)
		jenisKelamin := strings.TrimSpace(strings.ToUpper(item.JenisKelamin))

		row := BulkImportCustomerResult{
			Index: idx,
			Nama:  nama,
			NoHP:  noHP,
		}

		if nama == "" {
			row.Status = "failed"
			row.Reason = "nama wajib diisi"
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}

		if noHP == "" {
			row.Status = "failed"
			row.Reason = "nomor WhatsApp wajib diisi"
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}

		if jenisKelamin != "" && jenisKelamin != "L" && jenisKelamin != "P" {
			row.Status = "failed"
			row.Reason = "jenis kelamin harus kosong, L, atau P"
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}

		if firstIndex, exists := seenPhones[noHP]; exists {
			row.Status = "skipped"
			row.Reason = "duplikat di batch import"
			row.Index = idx
			row.Reason = row.Reason + " (baris " + strconv.Itoa(firstIndex+1) + ")"
			result.SkippedCount++
			result.Results = append(result.Results, row)
			continue
		}
		seenPhones[noHP] = idx

		var existingCount int64
		s.db.Model(&model.Pelanggan{}).
			Where("pl_nohp = ? AND pl_outlet = ?", noHP, outletID).
			Count(&existingCount)
		if existingCount > 0 {
			row.Status = "skipped"
			row.Reason = "nomor WhatsApp sudah terdaftar"
			result.SkippedCount++
			result.Results = append(result.Results, row)
			continue
		}

		pelanggan := model.Pelanggan{
			ID:             utils.GenPelangganID(s.db, outletID),
			OutletID:       outletID,
			Nama:           nama,
			NoHP:           noHP,
			Alamat:         alamat,
			JenisKelamin:   jenisKelamin,
			UserUpdate:     actorID,
			UserUpdateType: actorType,
		}
		if len(pelanggan.NoHP) >= 5 {
			pelanggan.Kode = pelanggan.NoHP[len(pelanggan.NoHP)-5:]
		} else {
			pelanggan.Kode = pelanggan.NoHP
		}

		if err := s.db.Create(&pelanggan).Error; err != nil {
			row.Status = "failed"
			row.Reason = err.Error()
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}

		row.Status = "created"
		row.Pelanggan = &pelanggan
		result.SuccessCount++
		result.Results = append(result.Results, row)
	}

	return result, nil
}

func (s *PelangganService) BulkDelete(
	outletID string,
	ids []string,
) (BulkDeleteCustomerResponse, error) {
	result := BulkDeleteCustomerResponse{
		Results: make([]BulkDeleteCustomerResult, 0, len(ids)),
	}

	seenIDs := make(map[string]struct{}, len(ids))
	for _, rawID := range ids {
		id := strings.TrimSpace(rawID)
		if id == "" {
			continue
		}
		if _, exists := seenIDs[id]; exists {
			continue
		}
		seenIDs[id] = struct{}{}

		row := BulkDeleteCustomerResult{ID: id}

		var pelanggan model.Pelanggan
		if err := s.db.Where("pl_id = ? AND pl_outlet = ?", id, outletID).First(&pelanggan).Error; err != nil {
			row.Status = "failed"
			row.Reason = "pelanggan tidak ditemukan"
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}
		row.Nama = pelanggan.Nama

		var trxCount int64
		s.db.Table("ac_transaksi").Where("tr_pelanggan = ?", id).Count(&trxCount)
		if trxCount > 0 {
			row.Status = "failed"
			row.Reason = "pelanggan memiliki riwayat transaksi"
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}

		if err := s.db.Where("pl_id = ? AND pl_outlet = ?", id, outletID).Delete(&model.Pelanggan{}).Error; err != nil {
			row.Status = "failed"
			row.Reason = err.Error()
			result.FailedCount++
			result.Results = append(result.Results, row)
			continue
		}

		row.Status = "deleted"
		result.SuccessCount++
		result.Results = append(result.Results, row)
	}

	return result, nil
}
