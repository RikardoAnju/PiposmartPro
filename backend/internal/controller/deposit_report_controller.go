package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type DepositReportController struct{ svc *service.DepositReportService }

func NewDepositReportController(svc *service.DepositReportService) *DepositReportController {
	return &DepositReportController{svc: svc}
}

func (c *DepositReportController) GetReport(ctx *gin.Context) {
	outletID := ctx.MustGet("outlet_id").(string)
	start, end := ctx.Query("start_date"), ctx.Query("end_date")
	if start == "" || end == "" {
		loc := time.Local
		today := time.Now().In(loc).Format("2006-01-02")
		start, end = today, today
	}
	page, _ := strconv.Atoi(ctx.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(ctx.DefaultQuery("limit", "20"))
	data, err := c.svc.GetReport(
		outletID,
		start+" 00:00:00",
		end+" 23:59:59",
		ctx.Query("activity_type"),
		ctx.Query("deposit_type"),
		ctx.Query("customer_id"),
		page,
		limit,
	)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Laporan deposit", data)
}

func (c *DepositReportController) GetAnalytics(ctx *gin.Context) {
	outletID := ctx.MustGet("outlet_id").(string)
	start, end := ctx.Query("start_date"), ctx.Query("end_date")
	if (start == "") != (end == "") {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Rentang tanggal harus diisi lengkap")
		return
	}
	if start != "" {
		start += " 00:00:00"
		end += " 23:59:59"
	}
	data, err := c.svc.GetAnalytics(
		outletID,
		ctx.Query("customer_id"),
		start,
		end,
	)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Analitik deposit", data)
}
