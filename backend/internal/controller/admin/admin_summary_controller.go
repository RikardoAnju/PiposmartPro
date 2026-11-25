package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AdminSummaryController struct {
	svc *admin.AdminSummaryService
}

func NewAdminSummaryController(s *admin.AdminSummaryService) *AdminSummaryController {
	return &AdminSummaryController{svc: s}
}

func (ctrl *AdminSummaryController) GetDashboard(c *gin.Context) {
	data, err := ctrl.svc.GetPlatformOverview()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil statistik platform")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", data)
}