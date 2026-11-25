package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

type AdminContentController struct {
	svc admin.AdminContentService
}

func NewAdminContentController(svc admin.AdminContentService) *AdminContentController {
	return &AdminContentController{svc: svc}
}

func (ctrl *AdminContentController) GetAll(c *gin.Context) {
	res, err := ctrl.svc.GetAll(c.Query("category"), true)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal ambil konten")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminContentController) GetByID(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	res, err := ctrl.svc.GetByID(uint(id))
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Konten tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *AdminContentController) Create(c *gin.Context) {
	data, ok := bindContentForm(c, true)
	if !ok {
		return
	}
	res, err := ctrl.svc.Create(data)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Konten berhasil dibuat", res)
}

func (ctrl *AdminContentController) Update(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	data, ok := bindContentForm(c, false)
	if !ok {
		return
	}
	res, err := ctrl.svc.Update(uint(id), data)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Konten berhasil diupdate", res)
}

func (ctrl *AdminContentController) ToggleStatus(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	if err := ctrl.svc.ToggleStatus(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Status berhasil diubah", nil)
}

func (ctrl *AdminContentController) Delete(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))
	if err := ctrl.svc.Delete(uint(id)); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Konten berhasil dihapus", nil)
}

func bindContentForm(c *gin.Context, imageRequired bool) (model.ContentBanner, bool) {
	var data model.ContentBanner
	data.Category = c.PostForm("category")
	data.Title = c.PostForm("title")
	data.Summary = c.PostForm("summary")
	data.Body = c.PostForm("body")
	// Kode voucher opsional — hanya relevan untuk kategori PROMO. Di-trim &
	// di-uppercase agar konsisten dengan kode voucher pada umumnya.
	data.VoucherCode = strings.ToUpper(strings.TrimSpace(c.PostForm("voucher_code")))
	if publishedAt := c.PostForm("published_at"); publishedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, publishedAt); err == nil {
			data.PublishedAt = parsed
		}
	}

	file, err := c.FormFile("image")
	if err == nil && file != nil {
		contentType := file.Header.Get("Content-Type")
		if !strings.HasPrefix(contentType, "image/") {
			utils.ErrorResponse(c, http.StatusBadRequest, "File harus berupa gambar")
			return data, false
		}
		if file.Size > 5<<20 {
			utils.ErrorResponse(c, http.StatusBadRequest, "Ukuran gambar maksimal 5MB")
			return data, false
		}
		path, err := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
			SubFolder: "content",
			Prefix:    "content",
			MaxWidth:  1280,
			Quality:   78,
		})
		if err != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
			return data, false
		}
		data.ImageURL = path
	} else if imageRequired {
		utils.ErrorResponse(c, http.StatusBadRequest, "Gambar wajib diisi")
		return data, false
	}

	if data.Category == "" || data.Title == "" || data.Body == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak lengkap")
		return data, false
	}
	return data, true
}
