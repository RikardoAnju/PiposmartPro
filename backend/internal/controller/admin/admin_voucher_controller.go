package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AdminVoucherController struct {
	svc admin.AdminVoucherService
}

func NewAdminVoucherController(svc admin.AdminVoucherService) *AdminVoucherController {
	return &AdminVoucherController{svc}
}

func (ctrl *AdminVoucherController) Create(c *gin.Context) {
	var v model.Voucher
	if err := c.ShouldBindJSON(&v); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	v.UserUpdate = c.MustGet("actor_id").(string)

	if err := ctrl.svc.CreateVoucher(v); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Voucher created", nil)
}

func (ctrl *AdminVoucherController) List(c *gin.Context) {
	res, err := ctrl.svc.GetVouchers()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil data")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminVoucherController) ToggleStatus(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Status int `json:"status"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid status")
		return
	}

	if err := ctrl.svc.UpdateVoucherStatus(id, req.Status); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal update status")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status updated", nil)
}

func (ctrl *AdminVoucherController) Update(c *gin.Context) {
	id := c.Param("id")
	var v model.Voucher
	if err := c.ShouldBindJSON(&v); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	v.UserUpdate = c.MustGet("actor_id").(string)

	if err := ctrl.svc.UpdateVoucher(id, v); err != nil {
		status := http.StatusInternalServerError
		if err.Error() == "jumlah voucher harus lebih dari 0" {
			status = http.StatusBadRequest
		}
		utils.ErrorResponse(c, status, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Voucher updated", nil)
}

func (ctrl *AdminVoucherController) Delete(c *gin.Context) {
	id := c.Param("id")
	if err := ctrl.svc.DeleteVoucher(id); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghapus voucher")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Voucher deleted", nil)
}
