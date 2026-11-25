package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/base64"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type NotaPublicController struct {
	svc     *service.TransaksiService
	notaSvc *service.NotaService
}

func NewNotaPublicController(svc *service.TransaksiService, notaSvc *service.NotaService) *NotaPublicController {
	return &NotaPublicController{svc: svc, notaSvc: notaSvc}
}

// decodeID — decode base64url ke raw transaction ID
func decodeNotaID(encodedId string) (string, error) {
	// Tambah padding jika kurang
	padded := encodedId
	switch len(padded) % 4 {
	case 2:
		padded += "=="
	case 3:
		padded += "="
	}
	decoded, err := base64.URLEncoding.DecodeString(padded)
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(decoded)), nil
}

func (ctrl *NotaPublicController) ServeNotaPage(c *gin.Context) {

    c.File("./internal/templates/nota_digital.html")
}


func (ctrl *NotaPublicController) GetNotaJSON(c *gin.Context) {
	encodedId := c.Param("encodedId")

	rawID, err := decodeNotaID(encodedId)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID nota tidak valid")
		return
	}

	trx, err := ctrl.svc.GetByIDPublic(rawID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Nota tidak ditemukan")
		return
	}

	notaConfig, _ := ctrl.notaSvc.GetSetting(trx.OutletID)

	utils.JSONResponse(c, http.StatusOK, "Success", gin.H{
		"transaction": trx,
		"nota_config": notaConfig,
	})
}