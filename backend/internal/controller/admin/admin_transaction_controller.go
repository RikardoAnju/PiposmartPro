package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type AdminTransactionController struct {
	svc *admin.AdminTransactionService
}

func NewAdminTransactionController(svc *admin.AdminTransactionService) *AdminTransactionController {
	return &AdminTransactionController{svc: svc}
}

func (ctrl *AdminTransactionController) ListTransactions(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	outletID := c.Query("outlet")
	status := c.Query("status")
	startDate := c.Query("start")
	endDate := c.Query("end")
	search := c.Query("search")

	filter := admin.GlobalTransactionFilter{
		Page:      page,
		Limit:     limit,
		OutletID:  outletID,
		Status:    status,
		StartDate: startDate,
		EndDate:   endDate,
		Search:    search,
	}

	result, err := ctrl.svc.ListTransactions(filter)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data transaksi")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil riwayat transaksi", result)
}
