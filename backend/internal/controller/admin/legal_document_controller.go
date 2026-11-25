package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type AdminLegalDocumentController struct {
	svc adminSvc.AdminLegalDocumentService
}

func NewAdminLegalDocumentController(svc adminSvc.AdminLegalDocumentService) *AdminLegalDocumentController {
	return &AdminLegalDocumentController{svc: svc}
}

func (ctrl *AdminLegalDocumentController) GetAll(c *gin.Context) {
	res, err := ctrl.svc.GetAll()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat dokumen legal")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminLegalDocumentController) GetByType(c *gin.Context) {
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

func (ctrl *AdminLegalDocumentController) Upsert(c *gin.Context) {
	var payload model.LegalDocument
	if err := c.ShouldBindJSON(&payload); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload tidak valid")
		return
	}
	res, err := ctrl.svc.Upsert(c.Param("type"), payload)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Dokumen legal berhasil disimpan", res)
}
