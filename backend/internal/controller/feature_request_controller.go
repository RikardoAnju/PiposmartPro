package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type FeatureRequestController struct {
	svc *service.FeatureRequestService
}

func NewFeatureRequestController(svc *service.FeatureRequestService) *FeatureRequestController {
	return &FeatureRequestController{svc: svc}
}

func featureActor(c *gin.Context) (string, string, string) {
	id, _ := c.Get("actor_id")
	kind, _ := c.Get("actor_type")
	outlet, _ := c.Get("outlet_id")
	return id.(string), kind.(string), outlet.(string)
}

func (ctrl *FeatureRequestController) List(c *gin.Context) {
	id, kind, _ := featureActor(c)
	items, err := ctrl.svc.List(id, kind, c.Query("status"), c.DefaultQuery("sort", "popular"), c.Query("search"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil usulan fitur")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", items)
}

func (ctrl *FeatureRequestController) Get(c *gin.Context) {
	id, kind, _ := featureActor(c)
	item, err := ctrl.svc.Get(c.Param("id"), id, kind)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", item)
}

func (ctrl *FeatureRequestController) Create(c *gin.Context) {
	var input struct {
		Title       string `json:"title" binding:"required"`
		Description string `json:"description" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Judul dan penjelasan wajib diisi")
		return
	}
	id, kind, outlet := featureActor(c)
	item, err := ctrl.svc.Create(id, kind, outlet, input.Title, input.Description)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Usulan fitur berhasil dikirim", item)
}

func (ctrl *FeatureRequestController) ToggleVote(c *gin.Context) {
	id, kind, _ := featureActor(c)
	voted, count, err := ctrl.svc.ToggleVote(c.Param("id"), id, kind)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Vote berhasil diperbarui", gin.H{"has_voted": voted, "vote_count": count})
}

func (ctrl *FeatureRequestController) Update(c *gin.Context) {
	var input struct {
		Title       string `json:"title" binding:"required"`
		Description string `json:"description" binding:"required"`
	}
	if err := c.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Judul dan penjelasan wajib diisi")
		return
	}
	id, kind, _ := featureActor(c)
	if err := ctrl.svc.Update(c.Param("id"), id, kind, input.Title, input.Description); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Usulan fitur berhasil diperbarui", nil)
}

func (ctrl *FeatureRequestController) UploadAttachment(c *gin.Context) {
	id, kind, _ := featureActor(c)
	item, lookupErr := ctrl.svc.Get(c.Param("id"), id, kind)
	if lookupErr != nil || !item.IsMine {
		utils.ErrorResponse(c, http.StatusForbidden, "Hanya pembuat usulan yang dapat menambah lampiran")
		return
	}
	if item.Status != "SUBMITTED" || len(item.Attachments) >= 3 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Lampiran hanya dapat ditambah saat status Diajukan, maksimal 3 gambar")
		return
	}
	file, err := c.FormFile("attachment")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Gambar lampiran wajib dipilih")
		return
	}
	if file.Size > 5*1024*1024 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Ukuran gambar maksimal 5 MB")
		return
	}
	path, err := utils.SaveUploadedFile(file, "feature-requests")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Gagal memproses lampiran: "+err.Error())
		return
	}
	attachment, err := ctrl.svc.AddAttachment(c.Param("id"), id, kind, path)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Lampiran berhasil ditambahkan", attachment)
}

func (ctrl *FeatureRequestController) DeleteAttachment(c *gin.Context) {
	id, kind, _ := featureActor(c)
	if err := ctrl.svc.DeleteAttachment(c.Param("id"), c.Param("attachmentId"), id, kind); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Lampiran berhasil dihapus", nil)
}
