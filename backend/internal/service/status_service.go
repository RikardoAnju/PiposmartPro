package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type StatusService struct {
	db *gorm.DB
}

func NewStatusService(db *gorm.DB) *StatusService {
	return &StatusService{db: db}
}

// GetQueueCount: Menghitung jumlah per badge tab
func (s *StatusService) GetQueueCount(outletID string, startDate, endDate string) (map[string]int64, error) {
	counts := make(map[string]int64)
	statuses := []string{"Antrian", "Proses", "Siap Ambil", "Selesai", "Batal"}

	for _, status := range statuses {
		var count int64
		query := s.db.Table("ac_transaksi").Where("tr_outlet = ? AND tr_status_order = ?", outletID, status)

		if startDate != "" && endDate != "" {
			query = query.Where("tr_created >= ? AND tr_created <= ?", startDate+" 00:00:00", endDate+" 23:59:59")
		}

		query.Count(&count)
		counts[status] = count
	}
	return counts, nil
}

// GetQueueByStatusPaged: Query list per status dengan filter tanggal dan pengurutan
func (s *StatusService) GetQueueByStatusPaged(outletID string, status string, page int, pageSize int, startDate, endDate string, sort string) ([]model.QueueDTO, error) {
	results := []model.QueueDTO{}
	offset := (page - 1) * pageSize

	orderClause := "max_priority DESC, t.tr_created ASC"
	if sort == "newest" {
		orderClause = "max_priority DESC, t.tr_created DESC"
	}

	query := s.db.Table("ac_transaksi t").
		Select(`
            t.tr_id, 
            t.tr_id as tr_invoice, 
            p.pl_nama as pelanggan_nama, 
            t.tr_total as tr_total, -- PERBAIKAN: Gunakan tr_total (nilai bersih + rounding) bukannya tr_total_kotor
            t.tr_status_pembayaran, 
            t.tr_status_order, 
            t.tr_created,
            COALESCE(t.tr_estimate, MAX(d.dtr_ready_at)) as tr_estimate,
            COALESCE(MAX(jp.jp_prioritas), 0) as max_priority`).
		Joins("LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id").
		Joins("LEFT JOIN ac_detail_transaksi d ON d.dtr_transaksi = t.tr_id").
		Joins("LEFT JOIN ac_jenis_produk jp ON d.dtr_layanan = jp.jp_id").
		Joins("LEFT JOIN ac_layanan ly ON jp.jp_layanan = ly.ly_id").
		Where("t.tr_outlet = ? AND t.tr_status_order = ?", outletID, status).
		Group("t.tr_id, p.pl_nama, t.tr_total, t.tr_status_pembayaran, t.tr_status_order, t.tr_created, t.tr_estimate")
		// Catatan: Pastikan semua field Non-Aggregated masuk ke Group By untuk kompatibilitas SQL (terutama PostgreSQL/MySQL strict mode)

	if startDate != "" && endDate != "" {
		query = query.Where("t.tr_created >= ? AND t.tr_created <= ?", startDate+" 00:00:00", endDate+" 23:59:59")
	}

	err := query.Order(orderClause).Limit(pageSize).Offset(offset).Scan(&results).Error
	return results, err
}

// GetFullQueueAggregated: Ambil semua status sekaligus secara paralel
func (s *StatusService) GetFullQueueAggregated(outletID, startDate, endDate string, sort string) (map[string][]model.QueueDTO, error) {
	statuses := []string{"Antrian", "Proses", "Siap Ambil", "Selesai", "Batal"}
	aggregated := make(map[string][]model.QueueDTO)

	type result struct {
		status string
		data   []model.QueueDTO
	}
	resChan := make(chan result, len(statuses))

	for _, status := range statuses {
		go func(st string) {
			data, err := s.GetQueueByStatusPaged(outletID, st, 1, 20, startDate, endDate, sort)
			if err != nil {
				resChan <- result{status: st, data: []model.QueueDTO{}}
			} else {
				resChan <- result{status: st, data: data}
			}
		}(status)
	}

	for i := 0; i < len(statuses); i++ {
		res := <-resChan
		aggregated[res.status] = res.data
	}

	return aggregated, nil
}

// UpdateStatusBulk: Update status massal dengan dukungan alasan pembatalan.
// Parameter alasan diisi saat newStatus == "Batal", kosong untuk status lainnya.
// UpdateStatusBulk: Update status massal dengan dukungan alasan pembatalan.
func (s *StatusService) UpdateStatusBulk(ids []string, outletID, newStatus, actorID, actorType string, alasan string) error {
	// Fetch OldValue dulu sebelum update
	oldStatusMap := make(map[string]string)
	rows, err := s.db.Table("ac_transaksi").
		Select("tr_id, tr_status_order").
		Where("tr_id IN ? AND tr_outlet = ?", ids, outletID).
		Rows()
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var trID, trStatus string
			rows.Scan(&trID, &trStatus)
			oldStatusMap[trID] = trStatus
		}
	}

	err = s.db.Transaction(func(tx *gorm.DB) error {
		res := tx.Table("ac_transaksi").
			Where("tr_id IN ? AND tr_outlet = ?", ids, outletID).
			Updates(map[string]interface{}{
				"tr_status_order":    newStatus,
				"tr_userupdate":      actorID,
				"tr_userupdate_type": actorType,
				"tr_lastupdate":      time.Now(),
			})
		if res.Error != nil {
			return res.Error
		}

		for _, id := range ids {
			if newStatus == "Batal" {
				if err := s.refundDepositForTransaction(tx, id, outletID, actorID); err != nil {
					return err
				}
			}
			oldStatus := oldStatusMap[id]
			var oldStatusPtr *string
			if oldStatus != "" {
				oldStatusPtr = &oldStatus
			}

			log := model.LogTransaksi{
				ID:          utils.GenLogTrxID(tx, id),
				TransaksiID: id,
				Scope:       "header",
				Field:       "status_order", // konsisten dengan log "Nota Dibuat"
				OldValue:    oldStatusPtr,   // ✅ isi OldValue
				NewValue:    &newStatus,
				ActorID:     actorID,
				ActorType:   actorType,
			}
			if err := tx.Create(&log).Error; err != nil {
				return err // ✅ handle error, jangan silent fail
			}

			if newStatus == "Batal" && alasan != "" {
				alasanCopy := alasan
				alasanLog := model.LogTransaksi{
					ID:          utils.GenLogTrxID(tx, id),
					TransaksiID: id,
					Scope:       "header",
					Field:       "alasan_batal",
					OldValue:    nil,
					NewValue:    &alasanCopy,
					ActorID:     actorID,
					ActorType:   actorType,
				}
				if err := tx.Create(&alasanLog).Error; err != nil {
					return err
				}
			}
		}
		return nil
	})

	if err == nil {
		utils.AppHub.BroadcastToOutlet(outletID, gin.H{
			"type":    "ORDER_UPDATED",
			"message": fmt.Sprintf("%d pesanan diupdate ke status %s", len(ids), newStatus),
			"payload": gin.H{
				"ids":    ids,
				"status": newStatus,
			},
		})
	}

	return err
}

// refundDepositForTransaction mengembalikan pemakaian deposit saat order
// dibatalkan. Pengecekan ledger membuat retry/status update idempotent.
func (s *StatusService) refundDepositForTransaction(tx *gorm.DB, trxID, outletID, actorID string) error {
	var usages []model.CustomerDepositLedger
	if err := tx.Where("cdl_reference = ? AND cdl_entry_type = ? AND cdl_outlet = ?", trxID, "USAGE", outletID).Find(&usages).Error; err != nil {
		return err
	}
	for _, usage := range usages {
		var existing int64
		if err := tx.Model(&model.CustomerDepositLedger{}).
			Where("cdl_reference = ? AND cdl_entry_type IN ? AND cdl_type = ?", trxID, []string{"USAGE_REVERSAL", "REFUND"}, usage.DepositType).
			Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 {
			continue
		}

		var account model.CustomerDepositAccount
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&account, "cda_id = ?", usage.AccountID).Error; err != nil {
			return err
		}
		before := account.BalanceRupiah
		if usage.DepositType == "KG" {
			before = account.BalanceKg
			account.BalanceKg += usage.Amount
		} else {
			account.BalanceRupiah += usage.Amount
		}
		if err := tx.Save(&account).Error; err != nil {
			return err
		}
		after := account.BalanceRupiah
		if usage.DepositType == "KG" {
			after = account.BalanceKg
		}
		if err := tx.Create(&model.CustomerDepositLedger{
			ID: uuid.New().String(), AccountID: account.ID, CustomerID: usage.CustomerID,
			OutletID: usage.OutletID, EntryType: "USAGE_REVERSAL", DepositType: usage.DepositType,
			Amount: usage.Amount, BalanceBefore: before, BalanceAfter: after,
			ReferenceID: trxID, Note: "Pengembalian deposit karena transaksi dibatalkan", CreatedBy: actorID,
		}).Error; err != nil {
			return err
		}
	}
	return nil
}
func (s *StatusService) SearchQueue(outletID string, query string) ([]model.QueueDTO, error) {
	results := []model.QueueDTO{}
	normalizedQuery := strings.TrimSpace(query)

	baseSQL := `
		SELECT t.tr_id, t.tr_id as tr_invoice, p.pl_nama as pelanggan_nama,
			t.tr_total, t.tr_status_pembayaran, t.tr_status_order, t.tr_created,
			COALESCE(t.tr_estimate, (SELECT MAX(dtr_ready_at) FROM ac_detail_transaksi WHERE dtr_transaksi = t.tr_id)) as tr_estimate
		FROM ac_transaksi t
		LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
		WHERE t.tr_outlet = ?`

	args := []interface{}{outletID}

	if strings.HasPrefix(strings.ToUpper(normalizedQuery), "TRX/") {
		baseSQL += ` AND t.tr_id = ?`
		args = append(args, normalizedQuery)
	} else {
		searchTerm := "%" + normalizedQuery + "%"
		baseSQL += ` AND (p.pl_nama LIKE ? OR t.tr_id LIKE ?)`
		args = append(args, searchTerm, searchTerm)
	}

	baseSQL += ` ORDER BY t.tr_created DESC LIMIT 50`

	err := s.db.Raw(baseSQL, args...).Scan(&results).Error
	return results, err
}
