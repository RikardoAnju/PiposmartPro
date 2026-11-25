package admin

import (
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type OTPLogController struct {
	svc adminSvc.AdminOTPLogService
}

func NewOTPLogController(svc adminSvc.AdminOTPLogService) *OTPLogController {
	return &OTPLogController{svc: svc}
}

func (ctrl *OTPLogController) List(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))

	rows, err := ctrl.svc.List(adminSvc.OTPLogFilter{
		Search:    c.Query("search"),
		Flow:      c.Query("flow"),
		Event:     c.Query("event"),
		StartDate: c.Query("start_date"),
		EndDate:   c.Query("end_date"),
		Limit:     limit,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil log OTP: "+err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "OTP logs", rows)
}
