package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type DashboardController struct {
	svc *service.DashboardService
}

func NewDashboardController(s *service.DashboardService) *DashboardController {
	return &DashboardController{svc: s}
}

func (ctrl *DashboardController) GetSummary(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	data, err := ctrl.svc.GetSummary(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat data dashboard")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Statistik Outlet Hari Ini", data)
}