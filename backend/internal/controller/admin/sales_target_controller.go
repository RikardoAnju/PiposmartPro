package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type AdminSalesTargetController struct {
	svc *admin.AdminSalesTargetService
}

func NewAdminSalesTargetController(s *admin.AdminSalesTargetService) *AdminSalesTargetController {
	return &AdminSalesTargetController{svc: s}
}

// GET /admin/sales-targets
// Query: tier, channel, search, only_active(=true default), limit
func (ctrl *AdminSalesTargetController) List(c *gin.Context) {
	onlyActive := true
	if v := c.Query("only_active"); v == "false" || v == "0" {
		onlyActive = false
	}
	limit := 0
	if v := c.Query("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			limit = n
		}
	}

	f := admin.SalesTargetFilter{
		Tier:       c.Query("tier"),
		Channel:    c.Query("channel"),
		Search:     c.Query("search"),
		OnlyActive: onlyActive,
		Limit:      limit,
	}

	data, err := ctrl.svc.GetSalesTargets(f)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghitung target sales: "+err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", data)
}

// PATCH /admin/sales-targets/:id/contact
// Body: { status, note }
func (ctrl *AdminSalesTargetController) SetContact(c *gin.Context) {
	outletID := c.Param("id")
	var body struct {
		Status string `json:"status"`
		Note   string `json:"note"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Body tidak valid")
		return
	}
	if body.Status == "" {
		body.Status = "dihubungi"
	}

	actorID, _ := c.Get("actor_id")
	byID, _ := actorID.(string)

	if err := ctrl.svc.SetContactStatus(outletID, body.Status, body.Note, byID); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyimpan status: "+err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status tersimpan", gin.H{"outlet_id": outletID, "status": body.Status})
}
