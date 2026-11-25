package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type ReferralController struct {
	svc *service.ReferralService
}

func NewReferralController(svc *service.ReferralService) *ReferralController {
	return &ReferralController{svc: svc}
}

func (ctrl *ReferralController) GetSummary(c *gin.Context) {
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	res, err := ctrl.svc.GetSummary(uint(userID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data referral")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *ReferralController) GetRecruitedOwners(c *gin.Context) {
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	owners, err := ctrl.svc.GetRecruitedOwners(uint(userID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data owner yang direkrut")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", owners)
}

func (ctrl *ReferralController) GetTopReferralOwnerRanks(c *gin.Context) {
	limitStr := c.DefaultQuery("limit", "10")

	limit, err := strconv.Atoi(limitStr)
	if err != nil {
		limit = 10
	}

	res, err := ctrl.svc.GetTopReferralOwnerRanks(limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil ranking referral owner")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *ReferralController) ConvertToKoin(c *gin.Context) {
	var req struct {
		RewardIDs []uint `json:"reward_ids" binding:"required"`
		OutletID  string `json:"outlet_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data konversi tidak valid")
		return
	}

	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	res, err := ctrl.svc.ConvertBalanceToKoin(uint(userID), req.OutletID, req.RewardIDs)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Saldo referral berhasil dikonversi", res)
}

func (ctrl *ReferralController) CreatePayoutRequest(c *gin.Context) {
	var req struct {
		RewardIDs       []uint  `json:"reward_ids" binding:"required"`
		PayoutAccountID *uint   `json:"payout_account_id"`
		BankName        string  `json:"bank_name"`
		AccountName     string  `json:"account_name"`
		AccountNumber   string  `json:"account_number"`
		Note            *string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data payout tidak valid")
		return
	}

	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	res, err := ctrl.svc.CreatePayoutRequest(uint(userID), req.RewardIDs, req.PayoutAccountID, req.BankName, req.AccountName, req.AccountNumber, req.Note)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Permintaan payout berhasil dibuat", res)
}

func (ctrl *ReferralController) ListPayoutAccounts(c *gin.Context) {
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	res, err := ctrl.svc.ListPayoutAccounts(uint(userID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil rekening payout")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *ReferralController) CreatePayoutAccount(c *gin.Context) {
	var req struct {
		BankName      string `json:"bank_name" binding:"required"`
		AccountName   string `json:"account_name" binding:"required"`
		AccountNumber string `json:"account_number" binding:"required"`
		IsDefault     bool   `json:"is_default"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data rekening payout tidak valid")
		return
	}
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	res, err := ctrl.svc.CreatePayoutAccount(uint(userID), req.BankName, req.AccountName, req.AccountNumber, req.IsDefault)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Rekening payout berhasil ditambahkan", res)
}

func (ctrl *ReferralController) UpdatePayoutAccount(c *gin.Context) {
	accountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID rekening payout tidak valid")
		return
	}
	var req struct {
		BankName      string `json:"bank_name" binding:"required"`
		AccountName   string `json:"account_name" binding:"required"`
		AccountNumber string `json:"account_number" binding:"required"`
		IsDefault     bool   `json:"is_default"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data rekening payout tidak valid")
		return
	}
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	res, err := ctrl.svc.UpdatePayoutAccount(uint(userID), uint(accountID), req.BankName, req.AccountName, req.AccountNumber, req.IsDefault)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Rekening payout berhasil diperbarui", res)
}

func (ctrl *ReferralController) SetDefaultPayoutAccount(c *gin.Context) {
	accountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID rekening payout tidak valid")
		return
	}
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	if err := ctrl.svc.SetDefaultPayoutAccount(uint(userID), uint(accountID)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Rekening payout default berhasil diubah", nil)
}

func (ctrl *ReferralController) DeletePayoutAccount(c *gin.Context) {
	accountID, err := strconv.Atoi(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID rekening payout tidak valid")
		return
	}
	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	if err := ctrl.svc.DeletePayoutAccount(uint(userID), uint(accountID)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Rekening payout berhasil dihapus", nil)
}
func (ctrl *ReferralController) ApplyCode(c *gin.Context) {
	var req struct {
		Code string `json:"code" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Kode referral wajib diisi")
		return
	}

	userID, _ := strconv.Atoi(c.MustGet("actor_id").(string))
	err := ctrl.svc.ApplyReferralCode(uint(userID), req.Code)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Kode referral berhasil diterapkan", nil)
}
