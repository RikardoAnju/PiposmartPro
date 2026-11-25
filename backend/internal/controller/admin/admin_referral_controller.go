package admin

import (
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AdminReferralController struct {
	svc adminSvc.AdminReferralService
}

func NewAdminReferralController(svc adminSvc.AdminReferralService) *AdminReferralController {
	return &AdminReferralController{svc: svc}
}

func (ctrl *AdminReferralController) GetDashboard(c *gin.Context) {
	res, err := ctrl.svc.GetDashboard()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil ringkasan referral")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminReferralController) ListPayouts(c *gin.Context) {
	res, err := ctrl.svc.ListPayouts(c.DefaultQuery("status", "all"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil daftar payout referral")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminReferralController) ListRewards(c *gin.Context) {
	typeFilter := c.DefaultQuery("type", "all")
	res, err := ctrl.svc.ListRewards(typeFilter)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil riwayat reward referral")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminReferralController) UpdatePayoutStatus(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Status    string  `json:"status" binding:"required"`
		AdminNote *string `json:"admin_note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input update payout tidak valid")
		return
	}
	if err := ctrl.svc.UpdatePayoutStatus(id, req.Status, req.AdminNote); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status payout referral berhasil diperbarui", nil)
}

func (ctrl *AdminReferralController) GetConfig(c *gin.Context) {
	cfg, err := ctrl.svc.GetConfig()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil konfigurasi referral")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", cfg)
}

func (ctrl *AdminReferralController) UpdateConfig(c *gin.Context) {
	var req struct {
		Key   string `json:"key" binding:"required"`
		Value string `json:"value" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input konfigurasi tidak valid")
		return
	}
	if err := ctrl.svc.UpdateConfig(req.Key, req.Value); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Konfigurasi referral berhasil diperbarui", nil)
}
