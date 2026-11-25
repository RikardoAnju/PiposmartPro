package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type FinanceController struct {
	svc *service.FinanceService
}

func NewFinanceController(s *service.FinanceService) *FinanceController {
	return &FinanceController{svc: s}
}

func (ctrl *FinanceController) getOutletLocation(outletID string) *time.Location {
	// Untuk controller, lebih baik service yang menghandle logic timezone.
	// Tapi karena kita ingin default date di controller, kita perlu hitung di sini atau minta service.
	// Kita buat helper internal saja biar cepat.
	return ctrl.svc.GetOutletLocation(outletID)
}

// =============================================================================
// DASHBOARD & OMSET METHODS
// =============================================================================

// GetDashboardSummary: Untuk kartu ringkasan (Harian/Range terpilih)
func (ctrl *FinanceController) GetDashboardSummary(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	// Default ke hari ini jika kosong
	if startDate == "" || endDate == "" {
		loc := ctrl.getOutletLocation(outletID)
		now := time.Now().In(loc).Format("2006-01-02")
		startDate, endDate = now, now
	}

	summary, err := ctrl.svc.GetFinanceSummary(outletID, startDate+" 00:00:00", endDate+" 23:59:59")
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", summary)
}

// GetDashboardChart: Untuk data grafik (Default 30 hari terakhir)
func (ctrl *FinanceController) GetDashboardChart(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)

	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	var start string
	var end string

	if startDate != "" && endDate != "" {
		start = startDate + " 00:00:00"
		end = endDate + " 23:59:59"
	} else {
		// Default 30 hari ke belakang dari hari ini bila range tidak dikirim.
		loc := ctrl.getOutletLocation(outletID)
		nowLocal := time.Now().In(loc)
		end = nowLocal.Format("2006-01-02") + " 23:59:59"
		start = nowLocal.AddDate(0, 0, -30).Format("2006-01-02") + " 00:00:00"
	}

	chartData, err := ctrl.svc.GetFinanceChart(outletID, start, end)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", chartData)
}

func (ctrl *FinanceController) GetOmsetReport(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate, statusBayar := c.Query("start_date"), c.Query("end_date"), c.Query("status_pembayaran")
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	page, limit := reportPagination(c, 20)
	report, err := ctrl.svc.GetOmsetReport(outletID, startDate+" 00:00:00", endDate+" 23:59:59", statusBayar, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

func (ctrl *FinanceController) GetOmsetDetail(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	date, statusBayar := c.Query("date"), c.Query("status_pembayaran")
	if date == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Tanggal (date) harus diisi")
		return
	}

	pageStr := c.DefaultQuery("page", "1")
	limitStr := c.DefaultQuery("limit", "20")
	page, _ := strconv.Atoi(pageStr)
	limit, _ := strconv.Atoi(limitStr)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}

	report, err := ctrl.svc.GetOmsetDetail(outletID, date, statusBayar, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// =============================================================================
// EXPENSE (PENGELUARAN) METHODS
// =============================================================================

func (ctrl *FinanceController) GetExpenseAnalisa(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	page, limit := reportPagination(c, 20)
	report, err := ctrl.svc.GetExpenseAnalisa(outletID, startDate+" 00:00:00", endDate+" 23:59:59", page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

func reportPagination(c *gin.Context, defaultLimit int) (int, int) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", strconv.Itoa(defaultLimit)))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = defaultLimit
	}
	return page, limit
}

func (ctrl *FinanceController) GetExpenseByCategory(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	report, err := ctrl.svc.GetExpenseByCategory(outletID, startDate+" 00:00:00", endDate+" 23:59:59")
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

func (ctrl *FinanceController) GetExpenseDetail(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	kategoriID := c.Query("kategori_id")
	fullStart, fullEnd := "", ""
	if startDate != "" && endDate != "" {
		fullStart, fullEnd = startDate+" 00:00:00", endDate+" 23:59:59"
	}

	pageStr := c.DefaultQuery("page", "1")
	limitStr := c.DefaultQuery("limit", "20")
	page, _ := strconv.Atoi(pageStr)
	limit, _ := strconv.Atoi(limitStr)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}

	report, err := ctrl.svc.GetExpenseDetail(outletID, fullStart, fullEnd, kategoriID, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// =============================================================================
// INCOME (PENDAPATAN) METHODS
// =============================================================================

func (ctrl *FinanceController) GetIncomeReport(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	metodeID := c.Query("metode_pembayaran_id")
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	page, limit := reportPagination(c, 20)
	report, err := ctrl.svc.GetIncomeReport(outletID, startDate+" 00:00:00", endDate+" 23:59:59", metodeID, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

func (ctrl *FinanceController) GetIncomeMethods(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	methods, err := ctrl.svc.GetIncomeActiveMethods(outletID, startDate+" 00:00:00", endDate+" 23:59:59")
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", methods)
}

func (ctrl *FinanceController) GetIncomeDetail(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	metodeNama := c.Query("metode_nama")

	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}

	pageStr := c.DefaultQuery("page", "1")
	limitStr := c.DefaultQuery("limit", "20")
	page, _ := strconv.Atoi(pageStr)
	limit, _ := strconv.Atoi(limitStr)
	if page < 1 {
		page = 1
	}
	if limit < 1 {
		limit = 20
	}

	report, err := ctrl.svc.GetIncomeDetail(outletID, startDate+" 00:00:00", endDate+" 23:59:59", metodeNama, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// =============================================================================
// PIUTANG & LABA RUGI METHODS
// =============================================================================

func (ctrl *FinanceController) GetPiutangReport(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	search := c.Query("search")
	status := c.Query("status")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	report, err := ctrl.svc.GetPiutangReport(outletID, startDate+" 00:00:00", endDate+" 23:59:59", search, status, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

func (ctrl *FinanceController) GetProfitLossReport(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}
	report, err := ctrl.svc.GetProfitLossReport(outletID, startDate+" 00:00:00", endDate+" 23:59:59")
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// GetProfitLossDetailMetode: Detail akumulasi harian per metode di Laba/Rugi
func (ctrl *FinanceController) GetProfitLossDetailMetode(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	metodeID := c.Query("metode_id")
	if startDate == "" || endDate == "" || metodeID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Parameter tidak lengkap")
		return
	}
	report, err := ctrl.svc.GetProfitLossDetailMetode(outletID, startDate+" 00:00:00", endDate+" 23:59:59", metodeID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// GetProfitLossDetailPengeluaran: Detail akumulasi harian per kategori di Laba/Rugi
func (ctrl *FinanceController) GetProfitLossDetailPengeluaran(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate, endDate := c.Query("start_date"), c.Query("end_date")
	kategoriID := c.Query("kategori_id")
	if startDate == "" || endDate == "" || kategoriID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Parameter tidak lengkap")
		return
	}
	report, err := ctrl.svc.GetProfitLossDetailPengeluaran(outletID, startDate+" 00:00:00", endDate+" 23:59:59", kategoriID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", report)
}
