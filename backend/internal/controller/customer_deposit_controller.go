package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"github.com/gin-gonic/gin"
	"net/http"
	"strconv"
	"time"
)

type CustomerDepositController struct {
	svc *service.CustomerDepositService
}

func NewCustomerDepositController(s *service.CustomerDepositService) *CustomerDepositController {
	return &CustomerDepositController{svc: s}
}
func (c *CustomerDepositController) GetBalance(ctx *gin.Context) {
	outlet := ctx.MustGet("outlet_id").(string)
	v, e := c.svc.Balance(ctx.Param("id"), outlet)
	if e != nil {
		utils.ErrorResponse(ctx, 500, e.Error())
		return
	}
	utils.JSONResponse(ctx, 200, "Saldo deposit", v)
}
func (c *CustomerDepositController) GetLedger(ctx *gin.Context) {
	outlet := ctx.MustGet("outlet_id").(string)
	// Pertahankan bentuk response lama untuk versi aplikasi yang belum
	// mengirim filter/pagination.
	if ctx.Request.URL.RawQuery == "" {
		v, err := c.svc.Ledger(ctx.Param("id"), outlet)
		if err != nil {
			utils.ErrorResponse(ctx, 500, err.Error())
			return
		}
		utils.JSONResponse(ctx, 200, "Riwayat deposit", v)
		return
	}
	page, _ := strconv.Atoi(ctx.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "30"))
	if limit > 100 {
		limit = 100
	}
	startDate := ctx.Query("start_date")
	endDate := ctx.Query("end_date")
	if (startDate != "" && !validISODate(startDate)) || (endDate != "" && !validISODate(endDate)) {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Format tanggal harus YYYY-MM-DD")
		return
	}
	v, e := c.svc.LedgerPage(ctx.Param("id"), outlet, startDate, endDate, page, limit)
	if e != nil {
		utils.ErrorResponse(ctx, 500, e.Error())
		return
	}
	utils.JSONResponse(ctx, 200, "Riwayat deposit", v)
}

func validISODate(value string) bool {
	_, err := time.Parse("2006-01-02", value)
	return err == nil
}
func (c *CustomerDepositController) GetLedgerEntry(ctx *gin.Context) {
	outlet := ctx.MustGet("outlet_id").(string)
	v, e := c.svc.LedgerEntry(ctx.Param("id"), ctx.Param("entryId"), outlet)
	if e != nil {
		utils.ErrorResponse(ctx, http.StatusNotFound, "Mutasi deposit tidak ditemukan")
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Detail mutasi deposit", v)
}
func (c *CustomerDepositController) TopUp(ctx *gin.Context) {
	var req struct {
		DepositType     string   `json:"deposit_type" binding:"required"`
		Value           float64  `json:"value" binding:"required"`
		TotalPaid       float64  `json:"total_paid"`
		DiscountAmount  *float64 `json:"discount_amount"`
		PaymentMethodID string   `json:"payment_method_id"`
		RequestID       string   `json:"request_id"`
		Note            string   `json:"note"`
	}
	if ctx.ShouldBindJSON(&req) != nil {
		utils.ErrorResponse(ctx, 400, "Data top up tidak valid")
		return
	}
	discount := 0.0
	if req.DiscountAmount != nil {
		discount = *req.DiscountAmount
	} else if req.DepositType == "RUPIAH" && req.TotalPaid < req.Value {
		// Kompatibilitas aplikasi lama: selisih yang sebelumnya tidak memiliki
		// nama dicatat sebagai diskon program deposit.
		discount = req.Value - req.TotalPaid
	}
	a, e := c.svc.TopUp(ctx.Param("id"), ctx.MustGet("outlet_id").(string), ctx.MustGet("actor_id").(string), ctx.GetString("actor_type"), req.RequestID, req.DepositType, req.PaymentMethodID, req.Note, req.Value, req.TotalPaid, discount)
	if e != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, e.Error())
		return
	}
	utils.JSONResponse(ctx, 201, "Top up deposit berhasil", a)
}

func (c *CustomerDepositController) AdjustTopUp(ctx *gin.Context) {
	actorType := ctx.GetString("actor_type")
	if actorType != "user" && actorType != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya owner atau admin yang dapat menyetujui koreksi deposit")
		return
	}
	var req struct {
		Kind            string  `json:"kind" binding:"required,oneof=CORRECTION REFUND"`
		Value           float64 `json:"value"`
		TotalPaid       float64 `json:"total_paid"`
		PaymentMethodID string  `json:"payment_method_id"`
		Note            string  `json:"note" binding:"required"`
		RequestID       string  `json:"request_id" binding:"required"`
		ExpectedValue   float64 `json:"expected_value"`
		ExpectedPaid    float64 `json:"expected_paid"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data koreksi deposit tidak lengkap")
		return
	}
	result, err := c.svc.AdjustTopUp(ctx.Param("id"), ctx.MustGet("outlet_id").(string), ctx.Param("topupId"), ctx.MustGet("actor_id").(string), actorType, req.RequestID, req.Kind, req.PaymentMethodID, req.Note, req.Value, req.TotalPaid, req.ExpectedValue, req.ExpectedPaid)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusCreated, "Penyesuaian deposit berhasil", result)
}

func (c *CustomerDepositController) GetAdjustmentState(ctx *gin.Context) {
	result, err := c.svc.AdjustmentState(ctx.Param("id"), ctx.MustGet("outlet_id").(string), ctx.Param("topupId"))
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusNotFound, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Status koreksi top up", result)
}
