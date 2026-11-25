package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/datatypes"
)

type PengeluaranController struct {
	svc *service.PengeluaranService
}

func NewPengeluaranController(s *service.PengeluaranService) *PengeluaranController {
	return &PengeluaranController{svc: s}
}

func (ctrl *PengeluaranController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	form, err := c.MultipartForm()
	if err != nil {
		utils.ErrorResponse(c, 400, "Format data harus multipart/form-data")
		return
	}

	kategoriID := c.PostForm("kategori_id")
	totalStr := c.PostForm("total")
	keterangan := c.PostForm("keterangan")
	tanggalStr := c.PostForm("tanggal")

	if kategoriID == "" || totalStr == "" || keterangan == "" {
		utils.ErrorResponse(c, 400, "Kategori, Total, dan Keterangan wajib diisi")
		return
	}

	total := utils.ToFloat64(totalStr)
	var tgl time.Time
	if tanggalStr != "" {
		tgl, _ = time.Parse("2006-01-02", tanggalStr)
	} else {
		tgl = time.Now()
	}

	// LOGIKA FOTO OPSIONAL & MAXIMAL 1
	var buktiPaths []string
	files := form.File["bukti"]
	if len(files) > 0 {
		file := files[0] // Hanya ambil file pertama
		path, err := utils.SaveUploadedFile(file, "pengeluaran")
		if err != nil {
			utils.ErrorResponse(c, 500, "Gagal upload file: "+err.Error())
			return
		}
		buktiPaths = append(buktiPaths, path)
	}

	buktiJSON, _ := json.Marshal(buktiPaths)

	p, err := ctrl.svc.Create(model.Pengeluaran{
		OutletID:       outletID.(string),
		KategoriID:     kategoriID,
		Total:          total,
		Keterangan:     keterangan,
		Tanggal:        tgl,
		Bukti:          datatypes.JSON(buktiJSON),
		UserUpdate:     actorID,
		UserUpdateType: actorType,
	})

	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Pengeluaran berhasil dicatat", p)
}

func (ctrl *PengeluaranController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var existing model.Pengeluaran
	if err := ctrl.svc.DB().Where("pg_id = ? AND pg_outlet = ?", id, outletID).First(&existing).Error; err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "data pengeluaran tidak ditemukan")
		return
	}
	if strings.ToLower(strings.TrimSpace(existing.SourceType)) == "payroll" {
		utils.ErrorResponse(
			c,
			http.StatusForbidden,
			"Pengeluaran dari Penggajian hanya bisa diubah dari menu Penggajian",
		)
		return
	}

	form, _ := c.MultipartForm()

	var bJSON datatypes.JSON
	if form != nil {
		files := form.File["bukti"]
		if len(files) > 0 {
			path, err := utils.SaveUploadedFile(files[0], "pengeluaran")
			if err != nil {
				utils.ErrorResponse(c, http.StatusBadRequest, "Gagal upload file: "+err.Error())
				return
			}
			encoded, _ := json.Marshal([]string{path})
			bJSON = datatypes.JSON(encoded)
		}
	}
	if len(bJSON) == 0 {
		bJSON = existing.Bukti
	}

	total := utils.ToFloat64(c.PostForm("total"))
	tgl, _ := time.Parse("2006-01-02", c.PostForm("tanggal"))

	p, err := ctrl.svc.Update(id, model.Pengeluaran{
		OutletID:       outletID.(string),
		KategoriID:     c.PostForm("kategori_id"),
		Total:          total,
		Keterangan:     c.PostForm("keterangan"),
		Tanggal:        tgl,
		Bukti:          bJSON,
		UserUpdate:     actorID,
		UserUpdateType: actorType, // Ditambahkan agar Service bisa memproses COALESCE dengan benar
	})

	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, 200, "Pengeluaran berhasil diperbarui", p)
}

func (ctrl *PengeluaranController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// Mendapatkan daftar pengeluaran yang sudah berisi UserUpdateNama & KategoriNama
	results, err := ctrl.svc.List(outletID.(string), c.Query("start"), c.Query("end"))

	if err != nil {
		utils.ErrorResponse(c, 500, "Gagal memuat daftar pengeluaran: "+err.Error())
		return
	}

	utils.JSONResponse(c, 200, "Daftar pengeluaran", results)
}

func (ctrl *PengeluaranController) Detail(c *gin.Context) {
	outletID := c.GetString("outlet_id")
	result, err := ctrl.svc.GetByID(c.Param("id"), outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Detail pengeluaran", result)
}

func (ctrl *PengeluaranController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	var existing model.Pengeluaran
	if err := ctrl.svc.DB().Where("pg_id = ? AND pg_outlet = ?", id, outletID).First(&existing).Error; err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "data tidak ditemukan")
		return
	}
	if strings.ToLower(strings.TrimSpace(existing.SourceType)) == "payroll" {
		utils.ErrorResponse(
			c,
			http.StatusForbidden,
			"Pengeluaran dari Penggajian tidak bisa dihapus dari menu Pengeluaran",
		)
		return
	}

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, 200, "Pengeluaran berhasil dihapus", nil)
}
