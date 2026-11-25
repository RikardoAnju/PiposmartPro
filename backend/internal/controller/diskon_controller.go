package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

func resolveDiskonJadwal(jadwalTipe, hari, tglMulai, tglAkhir string) (string, string, time.Time, time.Time, error) {
	jadwal := strings.TrimSpace(jadwalTipe)
	if jadwal == "" {
		jadwal = "rentang_tanggal"
	}
	if jadwal != "rentang_tanggal" && jadwal != "hari_berulang" {
		return "", "", time.Time{}, time.Time{}, errors.New("jadwal_tipe tidak valid")
	}

	if jadwal == "hari_berulang" {
		normHari, err := normalizeHari(hari)
		if err != nil {
			return "", "", time.Time{}, time.Time{}, err
		}
		now := time.Now()
		mulai := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.Local)
		akhir := mulai.AddDate(0, 0, 90)
		if t, e := time.Parse("2006-01-02", tglMulai); e == nil {
			mulai = t
		}
		if t, e := time.Parse("2006-01-02", tglAkhir); e == nil {
			akhir = t
		}
		return jadwal, normHari, mulai, akhir, nil
	}

	// rentang_tanggal
	tMulai, errM := time.Parse("2006-01-02", tglMulai)
	tAkhir, errA := time.Parse("2006-01-02", tglAkhir)
	if errM != nil || errA != nil {
		return "", "", time.Time{}, time.Time{}, errors.New("format tanggal salah (gunakan YYYY-MM-DD)")
	}
	return jadwal, "", tMulai, tAkhir, nil
}

func normalizeHari(hari string) (string, error) {
	seen := map[int]bool{}
	var days []int
	for _, part := range strings.Split(hari, ",") {
		p := strings.TrimSpace(part)
		if p == "" {
			continue
		}
		d, err := strconv.Atoi(p)
		if err != nil || d < 1 || d > 7 {
			return "", errors.New("hari tidak valid (harus 1-7)")
		}
		if !seen[d] {
			seen[d] = true
			days = append(days, d)
		}
	}
	if len(days) == 0 {
		return "", errors.New("pilih minimal satu hari untuk diskon berulang")
	}
	sort.Ints(days)
	parts := make([]string, len(days))
	for i, d := range days {
		parts[i] = strconv.Itoa(d)
	}
	return strings.Join(parts, ","), nil
}

type DiskonController struct {
	svc *service.DiskonService
}

func NewDiskonController(s *service.DiskonService) *DiskonController {
	return &DiskonController{svc: s}
}

func (ctrl *DiskonController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// DIUBAH: Langsung ambil sebagai string, tidak perlu ToUint()
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama         string  `json:"nama" binding:"required"`
		Nilai        float64 `json:"nilai" binding:"required,gt=0"`
		Tipe         string  `json:"tipe" binding:"required,oneof=persen nominal"`
		JadwalTipe   string  `json:"jadwal_tipe"`
		Hari         string  `json:"hari"`
		TanggalMulai string  `json:"tanggal_mulai"`
		TanggalAkhir string  `json:"tanggal_akhir"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid atau kurang lengkap")
		return
	}

	jadwal, hari, tMulai, tAkhir, jErr := resolveDiskonJadwal(req.JadwalTipe, req.Hari, req.TanggalMulai, req.TanggalAkhir)
	if jErr != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, jErr.Error())
		return
	}

	dis := model.Diskon{
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Nilai:          req.Nilai,
		Tipe:           req.Tipe,
		JadwalTipe:     jadwal,
		Hari:           hari,
		TanggalMulai:   tMulai,
		TanggalAkhir:   tAkhir,
		Status:         1,
		UserUpdate:     actorID, // Disimpan sebagai String
		UserUpdateType: actorType,
	}

	data, err := ctrl.svc.Create(dis)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("diskon:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Diskon berhasil ditambahkan", data)
}

func (ctrl *DiskonController) List(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("diskon:list:%s", outletID.(string))
	var data []model.Diskon
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data diskon (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.List(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 24*time.Hour)

	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil data diskon", data)
}

func (ctrl *DiskonController) Update(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	// DIUBAH: Langsung ambil sebagai string
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		Nama         string  `json:"nama" binding:"required"`
		Nilai        float64 `json:"nilai" binding:"required,gt=0"`
		Tipe         string  `json:"tipe" binding:"required,oneof=persen nominal"`
		JadwalTipe   string  `json:"jadwal_tipe"`
		Hari         string  `json:"hari"`
		TanggalMulai string  `json:"tanggal_mulai"`
		TanggalAkhir string  `json:"tanggal_akhir"`
		Status       int     `json:"status"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data update tidak valid")
		return
	}

	jadwal, hari, tMulai, tAkhir, jErr := resolveDiskonJadwal(req.JadwalTipe, req.Hari, req.TanggalMulai, req.TanggalAkhir)
	if jErr != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, jErr.Error())
		return
	}

	dis := model.Diskon{
		ID:             id,
		OutletID:       outletID.(string),
		Nama:           req.Nama,
		Nilai:          req.Nilai,
		Tipe:           req.Tipe,
		JadwalTipe:     jadwal,
		Hari:           hari,
		TanggalMulai:   tMulai,
		TanggalAkhir:   tAkhir,
		Status:         req.Status,
		UserUpdate:     actorID, // ID Pegawai String tersimpan utuh
		UserUpdateType: actorType,
	}

	if err := ctrl.svc.Update(dis); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("diskon:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Diskon berhasil diperbarui", nil)
}

func (ctrl *DiskonController) Delete(c *gin.Context) {
	id := c.Param("id")
	outletID, _ := c.Get("outlet_id")

	if err := ctrl.svc.Delete(id, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusConflict, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("diskon:list:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Diskon berhasil dihapus", nil)
}
