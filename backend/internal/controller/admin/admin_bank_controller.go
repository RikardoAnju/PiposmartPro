package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type AdminBankController struct {
	svc admin.AdminBankService
}

func NewAdminBankController(svc admin.AdminBankService) *AdminBankController {
	return &AdminBankController{svc: svc}
}

func (ctrl *AdminBankController) GetAll(c *gin.Context) {
	res, err := ctrl.svc.GetAll()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil data bank")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminBankController) Create(c *gin.Context) {
	var req model.BankAccount
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	res, err := ctrl.svc.Create(req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Berhasil menambah rekening", res)
}

func (ctrl *AdminBankController) Update(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	var req model.BankAccount
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	res, err := ctrl.svc.Update(uint(id), req)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Update berhasil", res)
}

func (ctrl *AdminBankController) ToggleStatus(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	if err := ctrl.svc.ToggleStatus(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status berhasil diubah", nil)
}

func (ctrl *AdminBankController) Delete(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	if err := ctrl.svc.Delete(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Rekening dihapus", nil)
}