package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"io"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type NobuController struct{ svc *service.NobuPaymentService }

func NewNobuController(svc *service.NobuPaymentService) *NobuController {
	return &NobuController{svc: svc}
}

func (c *NobuController) GenerateQR(ctx *gin.Context) {
	var req struct {
		OrderID string `json:"order_id" binding:"required"`
	}
	if err := ctx.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "order_id wajib diisi")
		return
	}
	result, err := c.svc.GenerateQR(req.OrderID, ctx.ClientIP())
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "QRIS berhasil dibuat", result)
}

func (c *NobuController) QRStatus(ctx *gin.Context) {
	orderID := strings.TrimSpace(ctx.Query("order_id"))
	if orderID == "" {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "order_id wajib diisi")
		return
	}
	result, err := c.svc.GetQRStatus(orderID)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusNotFound, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Status QRIS berhasil diambil", result)
}

func (c *NobuController) AccessTokenB2B(ctx *gin.Context) {
	var req service.B2BTokenRequest
	if err := ctx.ShouldBindJSON(&req); err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"responseCode": "4007300", "responseMessage": "Invalid request"})
		return
	}
	result, err := c.svc.IssueCallbackToken(req, ctx.Request.Header)
	if err != nil {
		ctx.JSON(http.StatusUnauthorized, gin.H{"responseCode": "4017300", "responseMessage": "Unauthorized"})
		return
	}
	ctx.JSON(http.StatusOK, result)
}

func (c *NobuController) Notify(ctx *gin.Context) {
	raw, err := io.ReadAll(io.LimitReader(ctx.Request.Body, 2<<20))
	if err != nil {
		ctx.JSON(http.StatusBadRequest, gin.H{"responseCode": "4005200", "responseMessage": "Invalid request"})
		return
	}
	if err = c.svc.ProcessNotify(raw, ctx.Request.Header); err != nil {
		c.svc.RecordCallbackAudit(raw, ctx.Request.Header, false, c.svc.ValidateCallbackToken(ctx.GetHeader("Authorization")), "REJECTED", err)
		message := err.Error()
		if strings.Contains(message, "signature") || strings.Contains(message, "header callback") || strings.Contains(message, "NOBU_CLIENT_SECRET") {
			ctx.JSON(http.StatusUnauthorized, gin.H{"responseCode": "4015200", "responseMessage": message})
			return
		}
		// Valid Nobu notifications are acknowledged to avoid retry storms; the event is retained for review.
		ctx.JSON(http.StatusOK, gin.H{"responseCode": "2005200", "responseMessage": "Request has been processed successfully"})
		return
	}
	c.svc.RecordCallbackAudit(raw, ctx.Request.Header, true, true, "PROCESSED", nil)
	ctx.JSON(http.StatusOK, gin.H{"responseCode": "2005200", "responseMessage": "Request has been processed successfully", "additionalInfo": gin.H{}})
}
