package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type SummaryController struct {
	svc *service.SummaryService
}

func NewSummaryController(s *service.SummaryService) *SummaryController {
	return &SummaryController{svc: s}
}

// Handler Dashboard (Lama)
func (ctrl *SummaryController) GetHomeSummary(c *gin.Context) {
	outletID, exists := c.Get("outlet_id")
	if !exists {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Outlet tidak teridentifikasi")
		return
	}

	data, err := ctrl.svc.GetDashboardSummary(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memproses data dashboard")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", data)
}

// HANDLER BARU: Untuk Modul Ringkasan Layanan
func (ctrl *SummaryController) GetAggregatedSummary(c *gin.Context) {
	outletID, exists := c.Get("outlet_id")
	if !exists {
		utils.ErrorResponse(c, http.StatusUnauthorized, "Outlet ID tidak ditemukan")
		return
	}

	data, err := ctrl.svc.GetAggregatedSummary(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memproses data ringkasan")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", data)
}