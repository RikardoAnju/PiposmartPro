package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AdminFeatureRequestController struct {
	svc *service.FeatureRequestService
}

func NewAdminFeatureRequestController(svc *service.FeatureRequestService) *AdminFeatureRequestController {
	return &AdminFeatureRequestController{svc: svc}
}

func (ctrl *AdminFeatureRequestController) List(c *gin.Context) {
	items, err := ctrl.svc.List("", "", c.Query("status"), c.DefaultQuery("sort", "popular"), c.Query("search"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil usulan fitur")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", items)
}

func (ctrl *AdminFeatureRequestController) UpdateStatus(c *gin.Context) {
	var input struct {
		Status    string `json:"status" binding:"required"`
		AdminNote string `json:"admin_note"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Status wajib dipilih")
		return
	}
	if err := ctrl.svc.UpdateStatus(c.Param("id"), input.Status, input.AdminNote); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status usulan berhasil diperbarui", nil)
}
