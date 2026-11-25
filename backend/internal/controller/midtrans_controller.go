package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type MidtransController struct {
	svc *service.MidtransService
}

func NewMidtransController(svc *service.MidtransService) *MidtransController {
	return &MidtransController{svc: svc}
}

func (ctrl *MidtransController) HandleNotification(c *gin.Context) {
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid payload")
		return
	}

	// Kirim ke dispatcher service
	err := ctrl.svc.ProcessNotification(payload)
	if err != nil {
		// Kita log errornya tapi tetap beri 200 ke midtrans agar tidak dikirim ulang terus menerus
		// atau bisa 500 jika ingin midtrans mencoba retry (tergantung kebutuhan)
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok", "message": "Notification processed"})
}