package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type IapController struct {
	svc *service.IapService
}

func NewIapController(svc *service.IapService) *IapController {
	return &IapController{svc: svc}
}

func (ctrl *IapController) GetIosProducts(c *gin.Context) {
	utils.JSONResponse(c, http.StatusOK, "Success", ctrl.svc.GetIosProducts())
}

func (ctrl *IapController) VerifyIosCoinTopup(c *gin.Context) {
	ctrl.verify(c, "COIN")
}

func (ctrl *IapController) VerifyIosOutletPro(c *gin.Context) {
	ctrl.verify(c, "OUTLET_PRO")
}

func (ctrl *IapController) verify(c *gin.Context, kind string) {
	actorIDStr := c.MustGet("actor_id").(string)
	ownerUserID, _ := strconv.ParseUint(actorIDStr, 10, 64)

	var req struct {
		ProductID             string `json:"product_id" binding:"required"`
		TransactionID         string `json:"transaction_id" binding:"required"`
		OriginalTransactionID string `json:"original_transaction_id"`
		ReceiptData           string `json:"receipt_data" binding:"required"`
		OutletID              string `json:"outlet_id" binding:"required"`
		EnvironmentHint       string `json:"environment_hint"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "payload verifikasi iOS tidak valid")
		return
	}

	input := service.VerifyIosPurchaseInput{
		OutletID:              req.OutletID,
		OwnerUserID:           uint(ownerUserID),
		ProductID:             req.ProductID,
		TransactionID:         req.TransactionID,
		OriginalTransactionID: req.OriginalTransactionID,
		ReceiptData:           req.ReceiptData,
		EnvironmentHint:       req.EnvironmentHint,
	}

	var (
		res interface{}
		err error
	)
	if kind == "COIN" {
		res, err = ctrl.svc.VerifyIosCoinTopup(input)
	} else {
		res, err = ctrl.svc.VerifyIosOutletPro(input)
	}
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Verifikasi pembelian iOS berhasil", res)
}
