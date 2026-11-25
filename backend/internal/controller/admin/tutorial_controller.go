package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type AdminTutorialController struct {
	svc admin.AdminTutorialService
}

func NewAdminTutorialController(svc admin.AdminTutorialService) *AdminTutorialController {
	return &AdminTutorialController{svc: svc}
}

func (ctrl *AdminTutorialController) GetAll(c *gin.Context) {
	res, err := ctrl.svc.GetAll(c.Query("type"), c.Query("category"), true)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil tutorial")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminTutorialController) GetByID(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	res, err := ctrl.svc.GetByID(uint(id))
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Tutorial tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminTutorialController) Create(c *gin.Context) {
	var data model.Tutorial
	if err := c.ShouldBindJSON(&data); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload tutorial tidak valid")
		return
	}
	res, err := ctrl.svc.Create(data)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Tutorial berhasil dibuat", res)
}

func (ctrl *AdminTutorialController) Update(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	var data model.Tutorial
	if err := c.ShouldBindJSON(&data); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload tutorial tidak valid")
		return
	}
	res, err := ctrl.svc.Update(uint(id), data)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Tutorial berhasil diupdate", res)
}

func (ctrl *AdminTutorialController) ToggleStatus(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	if err := ctrl.svc.ToggleStatus(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status berhasil diubah", nil)
}

func (ctrl *AdminTutorialController) Delete(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	if err := ctrl.svc.Delete(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Tutorial berhasil dihapus", nil)
}
