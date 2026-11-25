package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"

	"github.com/gin-gonic/gin"
)

type KategoriPengeluaranController struct {
	svc *service.KategoriPengeluaranService
}

func NewKategoriPengeluaranController(s *service.KategoriPengeluaranService) *KategoriPengeluaranController {
	return &KategoriPengeluaranController{svc: s}
}

func (ctrl *KategoriPengeluaranController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string, tidak perlu ToUint()
	actorID := c.MustGet("actor_id").(string)

	var req struct {
		Kategori string `json:"kategori" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nama kategori wajib diisi")
		return
	}

	kp, err := ctrl.svc.Create(model.KategoriPengeluaran{
		OutletID:   outletID.(string),
		Kategori:   req.Kategori,
		UserUpdate: actorID, // String ID Pegawai/Owner
	})
	
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	
	utils.JSONResponse(c, http.StatusCreated, "Kategori berhasil dibuat", kp)
}

func (ctrl *KategoriPengeluaranController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	results, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil daftar kategori", results)
}

func (ctrl *KategoriPengeluaranController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")
	// DIUBAH: Langsung ambil sebagai string
	actorID := c.MustGet("actor_id").(string)

	var req struct {
		Kategori string `json:"kategori" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	err := ctrl.svc.Update(id, outletID.(string), model.KategoriPengeluaran{
		Kategori:   req.Kategori,
		UserUpdate: actorID,
	})
	
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	
	utils.JSONResponse(c, http.StatusOK, "Kategori berhasil diperbarui", nil)
}

func (ctrl *KategoriPengeluaranController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Kategori berhasil dihapus", nil)
}