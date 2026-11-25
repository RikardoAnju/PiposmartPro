package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type CustomerReportController struct {
	svc *service.CustomerReportService
}

func NewCustomerReportController(s *service.CustomerReportService) *CustomerReportController {
	return &CustomerReportController{svc: s}
}

// GetCustomerSummary: Screen "Ringkasan Pelanggan" (Directory dengan Search)
func (ctrl *CustomerReportController) GetCustomerSummary(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	search := c.Query("search")

	report, err := ctrl.svc.GetCustomerSummary(outletID, search)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// GetCustomerGrowth: Screen "Laporan Pelanggan" - Tab Pertumbuhan
func (ctrl *CustomerReportController) GetCustomerGrowth(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}

	report, err := ctrl.svc.GetCustomerGrowth(outletID, startDate+" 00:00:00", endDate+" 23:59:59")
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}

// GetTopCustomers: Screen "Laporan Pelanggan" - Tab Top Pelanggan (Podium)
func (ctrl *CustomerReportController) GetTopCustomers(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	jenisKelamin := c.Query("jenis_kelamin")
	activityStatus := c.DefaultQuery("activity_status", "active")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "15"))
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 15
	}

	if startDate == "" || endDate == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Range tanggal harus diisi")
		return
	}

	report, err := ctrl.svc.GetTopCustomers(outletID, startDate+" 00:00:00", endDate+" 23:59:59", jenisKelamin, activityStatus, page, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", report)
}
