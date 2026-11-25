package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type NotaController struct {
	svc *service.NotaService
}

func NewNotaController(svc *service.NotaService) *NotaController {
	return &NotaController{svc: svc}
}

func (ctrl *NotaController) GetSetting(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)

	result, err := ctrl.svc.GetSetting(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", result)
}

func (ctrl *NotaController) UpdateSetting(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	current, err := ctrl.svc.GetSetting(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	var payload model.NotaSettingUpdateRequest
	if err := c.ShouldBindJSON(&payload); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	payload.ApplyTo(&current)
	current.OutletID = outletID
	current.UserUpdate = actorID
	current.UserUpdateType = actorType

	if err := ctrl.svc.UpdateSetting(current); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memperbarui pengaturan nota")
		return
	}

	updated, err := ctrl.svc.GetSetting(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Pengaturan nota berhasil disimpan", updated)
}

func (ctrl *NotaController) UploadLogo(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	file, err := c.FormFile("logo")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "File logo nota wajib diunggah")
		return
	}

	logoPath, err := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
		SubFolder: "nota",
		Prefix:    "nota_" + outletID,
		MaxWidth:  600,
		Quality:   80,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	if err := ctrl.svc.UpdateLogo(outletID, logoPath, actorID, actorType); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyimpan logo nota")
		return
	}

	updated, err := ctrl.svc.GetSetting(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Logo nota berhasil diunggah", updated)
}

func (ctrl *NotaController) DeleteLogo(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	if err := ctrl.svc.DeleteLogo(outletID, actorID, actorType); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menghapus logo nota")
		return
	}

	updated, err := ctrl.svc.GetSetting(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Logo nota berhasil dihapus", updated)
}
