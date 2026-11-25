package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type ReportController struct {
	svc *service.ReportService
}

func NewReportController(s *service.ReportService) *ReportController {
	return &ReportController{svc: s}
}

func (ctrl *ReportController) GetTransactionReport(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	start, end := c.Query("start_date"), c.Query("end_date")
	// App mengirim `status_order`; jaga kompatibilitas lama dengan `status`.
	status := c.Query("status_order")
	if status == "" {
		status = c.Query("status")
	}
	statusPembayaran := c.Query("status_pembayaran")
	search := c.Query("search")
	customerID := c.Query("customer_id")

	if start == "" || end == "" {
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

	report, err := ctrl.svc.GetAllTransactionReport(outletID, start+" 00:00:00", end+" 23:59:59", status, statusPembayaran, search, customerID, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// Endpoint: GET /report/transactions/summary
func (ctrl *ReportController) GetOperationalSummary(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	start, end := c.Query("start_date"), c.Query("end_date")

	report, err := ctrl.svc.GetOperationalSummary(outletID, start+" 00:00:00", end+" 23:59:59")
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

func (ctrl *ReportController) GetServiceReport(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	start := c.Query("start_date")
	end := c.Query("end_date")

	if start == "" || end == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}

	report, err := ctrl.svc.GetServiceReport(outletID, start+" 00:00:00", end+" 23:59:59", page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}
