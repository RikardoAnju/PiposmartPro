package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type TutorialController struct {
	svc admin.AdminTutorialService
}

func NewTutorialController(svc admin.AdminTutorialService) *TutorialController {
	return &TutorialController{svc: svc}
}

func (ctrl *TutorialController) List(c *gin.Context) {
	res, err := ctrl.svc.GetAll(c.Query("type"), c.Query("category"), false)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat tutorial")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}
