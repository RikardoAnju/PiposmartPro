package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"net/http"

	"github.com/gin-gonic/gin"
)

type AdminCustomerController struct {
	svc admin.AdminCustomerService
}

func NewAdminCustomerController(svc admin.AdminCustomerService) *AdminCustomerController {
	return &AdminCustomerController{svc}
}

func (ctrl *AdminCustomerController) ListCustomers(c *gin.Context) {
	outletID := c.Query("outlet_id") // Ambil filter dari query params
	customers, err := ctrl.svc.GetAllCustomers(outletID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"status": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": true, "data": customers})
}