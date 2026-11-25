package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type ContentController struct {
	svc admin.AdminContentService
}

func NewContentController(svc admin.AdminContentService) *ContentController {
	return &ContentController{svc: svc}
}

func (ctrl *ContentController) List(c *gin.Context) {
	res, err := ctrl.svc.GetAll(c.Query("category"), false)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat konten")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}
