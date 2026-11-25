package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type NobuFinanceController struct{ db *gorm.DB }

func NewNobuFinanceController(db *gorm.DB) *NobuFinanceController {
	return &NobuFinanceController{db: db}
}

func (c *NobuFinanceController) Payments(ctx *gin.Context) {
	var rows []model.NobuPaymentTransaction
	q := c.db.Order("npt_created DESC")
	if status := strings.TrimSpace(ctx.Query("status")); status != "" {
		q = q.Where("npt_internal_status = ?", status)
	}
	if err := q.Find(&rows).Error; err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, "Gagal mengambil payment Nobu")
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Payment Nobu berhasil diambil", rows)
}

// outletNames mengembalikan peta ot_id -> nama outlet untuk memperkaya respons.
func (c *NobuFinanceController) outletNames(ids []string) map[string]string {
	out := map[string]string{}
	if len(ids) == 0 {
		return out
	}
	var rows []model.Outlet
	c.db.Select("ot_id, ot_nama").Where("ot_id IN ?", ids).Find(&rows)
	for _, r := range rows {
		out[r.ID] = r.Nama
	}
	return out
}

type payableRow struct {
	model.OwnerPayable
	OutletName string `json:"outlet_name"`
}

func (c *NobuFinanceController) Payables(ctx *gin.Context) {
	var rows []model.OwnerPayable
	q := c.db.Order("op_created DESC")
	if status := strings.TrimSpace(ctx.Query("status")); status != "" {
		q = q.Where("op_status = ?", status)
	}
	if outlet := strings.TrimSpace(ctx.Query("outlet")); outlet != "" {
		q = q.Where("op_outlet_id = ?", outlet)
	}
	if err := q.Find(&rows).Error; err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, "Gagal mengambil payable owner")
		return
	}
	ids := make([]string, 0, len(rows))
	for _, r := range rows {
		ids = append(ids, r.OutletID)
	}
	names := c.outletNames(ids)
	enriched := make([]payableRow, 0, len(rows))
	for _, r := range rows {
		enriched = append(enriched, payableRow{OwnerPayable: r, OutletName: names[r.OutletID]})
	}
	utils.JSONResponse(ctx, http.StatusOK, "Payable owner berhasil diambil", enriched)
}

type settlementItemRow struct {
	PayableID  string  `json:"payable_id"`
	OrderID    string  `json:"order_id"`
	OutletID   string  `json:"outlet_id"`
	OutletName string  `json:"outlet_name"`
	Amount     float64 `json:"amount"`
}

type settlementRow struct {
	model.SettlementBatch
	ItemCount int                 `json:"item_count"`
	Items     []settlementItemRow `json:"items"`
}

// Settlements mengembalikan daftar batch settlement beserta itemnya, sehingga
// batch yang sudah dibuat tetap bisa dikonfirmasi/dilihat kapan saja (bukan
// hanya batch yang baru dibuat pada sesi berjalan).
func (c *NobuFinanceController) Settlements(ctx *gin.Context) {
	var batches []model.SettlementBatch
	q := c.db.Order("sb_created DESC")
	if status := strings.TrimSpace(ctx.Query("status")); status != "" {
		q = q.Where("sb_status = ?", status)
	}
	if err := q.Find(&batches).Error; err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, "Gagal mengambil settlement")
		return
	}
	batchIDs := make([]string, 0, len(batches))
	for _, b := range batches {
		batchIDs = append(batchIDs, b.ID)
	}
	var items []model.SettlementItem
	if len(batchIDs) > 0 {
		c.db.Where("si_batch_id IN ?", batchIDs).Find(&items)
	}
	// Ambil order_id per payable dan nama outlet untuk memperkaya item.
	payableIDs := make([]string, 0, len(items))
	outletIDs := make([]string, 0, len(items))
	for _, it := range items {
		payableIDs = append(payableIDs, it.PayableID)
		outletIDs = append(outletIDs, it.OutletID)
	}
	orderByPayable := map[string]string{}
	if len(payableIDs) > 0 {
		var payables []model.OwnerPayable
		c.db.Select("op_id, op_order_id").Where("op_id IN ?", payableIDs).Find(&payables)
		for _, p := range payables {
			orderByPayable[p.ID] = p.OrderID
		}
	}
	names := c.outletNames(outletIDs)
	itemsByBatch := map[string][]settlementItemRow{}
	for _, it := range items {
		itemsByBatch[it.BatchID] = append(itemsByBatch[it.BatchID], settlementItemRow{
			PayableID:  it.PayableID,
			OrderID:    orderByPayable[it.PayableID],
			OutletID:   it.OutletID,
			OutletName: names[it.OutletID],
			Amount:     it.Amount,
		})
	}
	rows := make([]settlementRow, 0, len(batches))
	for _, b := range batches {
		list := itemsByBatch[b.ID]
		rows = append(rows, settlementRow{SettlementBatch: b, ItemCount: len(list), Items: list})
	}
	utils.JSONResponse(ctx, http.StatusOK, "Settlement berhasil diambil", rows)
}

func (c *NobuFinanceController) Audits(ctx *gin.Context) {
	var rows []model.NobuCallbackAudit
	if err := c.db.Order("nca_created DESC").Limit(200).Find(&rows).Error; err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, "Gagal mengambil audit callback")
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Audit callback berhasil diambil", rows)
}

func (c *NobuFinanceController) Reconcile(ctx *gin.Context) {
	var summary struct {
		Payments          int64   `json:"payments"`
		Paid              int64   `json:"paid"`
		Pending           int64   `json:"pending"`
		Failed            int64   `json:"failed"`
		OpenPayables      int64   `json:"open_payables"`
		OpenPayableAmount float64 `json:"open_payable_amount"`
		ReceivedFunds     float64 `json:"received_funds"`
	}
	c.db.Model(&model.NobuPaymentTransaction{}).Count(&summary.Payments)
	c.db.Model(&model.NobuPaymentTransaction{}).Where("npt_internal_status = ?", "PAID").Count(&summary.Paid)
	c.db.Model(&model.NobuPaymentTransaction{}).Where("npt_internal_status = ?", "WAITING_PAYMENT").Count(&summary.Pending)
	c.db.Model(&model.NobuPaymentTransaction{}).Where("npt_internal_status = ?", "FAILED").Count(&summary.Failed)
	c.db.Model(&model.OwnerPayable{}).Where("op_status = ?", "OPEN").Count(&summary.OpenPayables)
	c.db.Model(&model.OwnerPayable{}).Where("op_status = ?", "OPEN").Select("COALESCE(SUM(op_net_amount),0)").Scan(&summary.OpenPayableAmount)
	c.db.Model(&model.NobuFundLedger{}).Where("nfl_status = ?", "RECEIVED").Select("COALESCE(SUM(nfl_net_amount),0)").Scan(&summary.ReceivedFunds)
	utils.JSONResponse(ctx, http.StatusOK, "Rekonsiliasi berhasil diambil", summary)
}

func (c *NobuFinanceController) CreateSettlement(ctx *gin.Context) {
	var req struct {
		PayableIDs []string `json:"payable_ids"`
		Note       string   `json:"note"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil || len(req.PayableIDs) == 0 {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "payable_ids wajib diisi")
		return
	}
	var payables []model.OwnerPayable
	if err := c.db.Where("op_id IN ? AND op_status = ?", req.PayableIDs, "OPEN").Find(&payables).Error; err != nil || len(payables) != len(req.PayableIDs) {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Sebagian payable tidak tersedia atau sudah diproses")
		return
	}
	var batch model.SettlementBatch
	err := c.db.Transaction(func(tx *gorm.DB) error {
		batch = model.SettlementBatch{ID: uuid.NewString(), Reference: "STL-" + time.Now().Format("20060102150405"), Status: "PENDING", AdminNote: &req.Note}
		for _, p := range payables {
			batch.TotalAmount += p.NetAmount
		}
		if err := tx.Create(&batch).Error; err != nil {
			return err
		}
		for _, p := range payables {
			if err := tx.Create(&model.SettlementItem{ID: uuid.NewString(), BatchID: batch.ID, PayableID: p.ID, OutletID: p.OutletID, Amount: p.NetAmount}).Error; err != nil {
				return err
			}
			if err := tx.Model(&p).Update("op_status", "RESERVED").Error; err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusCreated, "Settlement batch berhasil dibuat", batch)
}

func (c *NobuFinanceController) UpdateSettlement(ctx *gin.Context) {
	var req struct {
		Status   string `json:"status"`
		ProofURL string `json:"proof_url"`
		Note     string `json:"note"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data settlement tidak valid")
		return
	}
	status := strings.ToUpper(strings.TrimSpace(req.Status))
	if status != "PAID" && status != "FAILED" {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Status settlement harus PAID atau FAILED")
		return
	}
	err := c.db.Transaction(func(tx *gorm.DB) error {
		var batch model.SettlementBatch
		if err := tx.First(&batch, "sb_id = ?", ctx.Param("id")).Error; err != nil {
			return err
		}
		batch.Status = status
		batch.ProofURL = &req.ProofURL
		batch.AdminNote = &req.Note
		if err := tx.Save(&batch).Error; err != nil {
			return err
		}
		next := "SETTLED"
		if status == "FAILED" {
			next = "OPEN"
		}
		return tx.Model(&model.OwnerPayable{}).Where("op_id IN (SELECT si_payable_id FROM ac_settlement_items WHERE si_batch_id = ?)", batch.ID).Update("op_status", next).Error
	})
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Settlement berhasil diperbarui", nil)
}
