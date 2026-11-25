package controller

import (
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type LegalDocumentController struct {
	svc adminSvc.AdminLegalDocumentService
}

func NewLegalDocumentController(svc adminSvc.AdminLegalDocumentService) *LegalDocumentController {
	return &LegalDocumentController{svc: svc}
}

func (ctrl *LegalDocumentController) GetByType(c *gin.Context) {
	res, err := ctrl.svc.GetByType(c.Param("type"))
	if err != nil {
		status := http.StatusBadRequest
		if errors.Is(err, gorm.ErrRecordNotFound) {
			status = http.StatusNotFound
		}
		utils.ErrorResponse(c, status, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}
