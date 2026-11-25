package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type LocationController struct {
	locService *service.LocationService
}

func NewLocationController(s *service.LocationService) *LocationController {
	return &LocationController{locService: s}
}

func (ctrl *LocationController) GetProvinces(c *gin.Context) {
	data, err := ctrl.locService.GetProvinces()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil provinsi")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LocationController) GetCities(c *gin.Context) {
	provinceID := c.Query("province_id")
	data, err := ctrl.locService.GetCities(provinceID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil kota")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LocationController) GetDistricts(c *gin.Context) {
	cityID := c.Query("city_id")
	if cityID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "city_id diperlukan")
		return
	}
	data, err := ctrl.locService.GetDistricts(cityID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil kecamatan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}