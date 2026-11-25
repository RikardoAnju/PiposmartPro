package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"github.com/gin-gonic/gin"
	"net/http"
	"strconv"
	"strings"
	"time"
)

type OutletController struct {
	svc *service.OutletService
}

func NewOutletController(s *service.OutletService) *OutletController {
	return &OutletController{svc: s}
}

func (ctrl *OutletController) List(c *gin.Context) {
	actorType := c.GetString("actor_type")
	userIDStr := c.MustGet("actor_id").(string)
	if actorType == "pegawai" {
		data, err := ctrl.svc.GetEmployeeOutlets(userIDStr)
		if err != nil {
			utils.ErrorResponse(c, http.StatusForbidden, err.Error())
			return
		}
		utils.JSONResponse(c, http.StatusOK, "Success", data)
		return
	}
	userID, _ := strconv.ParseUint(userIDStr, 10, 32)

	data, err := ctrl.svc.GetUserOutlets(uint(userID))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil daftar outlet")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", data)
}

func (ctrl *OutletController) Create(c *gin.Context) {
	userIDStr := c.MustGet("actor_id").(string)
	userID, _ := strconv.ParseUint(userIDStr, 10, 32)
	actorType := c.MustGet("actor_type").(string)
	if actorType != "user" {
		utils.ErrorResponse(c, http.StatusForbidden, "Hanya owner yang dapat menambah outlet")
		return
	}

	var input struct {
		Nama            string `json:"nama" binding:"required"`
		NoHP            string `json:"no_hp"`
		Alamat          string `json:"alamat"`
		Provinsi        string `json:"provinsi"`
		Kota            string `json:"kota"`
		Kecamatan       string `json:"kecamatan"`
		TipeLokasiUsaha string `json:"tipe_lokasi_usaha"`
		ModalUsaha      string `json:"modal_usaha"`
		JumlahKaryawan  string `json:"jumlah_karyawan"`
		JumlahMesin     string `json:"jumlah_mesin"`
		TanggalBerjalan string `json:"tanggal_berjalan"`
		Timezone        string `json:"timezone"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Nama outlet wajib diisi")
		return
	}

	newOutlet := model.Outlet{
		UserID:          uint(userID),
		Nama:            input.Nama,
		NoHP:            &input.NoHP,
		Alamat:          &input.Alamat,
		Provinsi:        &input.Provinsi,
		Kota:            &input.Kota,
		Kecamatan:       &input.Kecamatan,
		TipeLokasiUsaha: &input.TipeLokasiUsaha,
		ModalUsaha:      &input.ModalUsaha,
		JumlahKaryawan:  &input.JumlahKaryawan,
		JumlahMesin:     &input.JumlahMesin,
		TanggalBerjalan: func() *string {
			if input.TanggalBerjalan == "" {
				return nil
			}
			s := input.TanggalBerjalan
			return &s
		}(),
		Timezone:       input.Timezone,
		Status:         1,
		UserUpdate:     &userIDStr,
		UserUpdateType: &actorType,
	}

	data, err := ctrl.svc.Create(newOutlet)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Outlet baru berhasil dibuat", data)
}

func (ctrl *OutletController) GetProfile(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")

	// 1. Try Cache
	cacheKey := fmt.Sprintf("outlet:profile:%s", outletID.(string))
	var data model.Outlet
	if database.GetCache(cacheKey, &data) {
		utils.JSONResponse(c, http.StatusOK, "Success (Cached)", data)
		return
	}

	// 2. Try DB
	data, err := ctrl.svc.GetProfile(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Profil tidak ditemukan")
		return
	}

	// 3. Save Cache
	database.SetCache(cacheKey, data, 24*time.Hour)

	utils.JSONResponse(c, http.StatusOK, "Success", data)
}

func (ctrl *OutletController) UpdateProfile(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	if actorType == "pegawai" {
		utils.ErrorResponse(c, http.StatusForbidden, "Hanya owner/admin yang dapat mengubah profil outlet")
		return
	}

	updates := make(map[string]interface{})

	// Map fields (Sama seperti sebelumnya)
	if nama := c.PostForm("nama"); nama != "" {
		updates["ot_nama"] = nama
	}
	if nohp := c.PostForm("no_hp"); nohp != "" {
		updates["ot_nohp"] = nohp
	}
	if alamat := c.PostForm("alamat"); alamat != "" {
		updates["ot_alamat"] = alamat
	}
	if provinsi := c.PostForm("provinsi"); provinsi != "" {
		updates["ot_provinsi"] = provinsi
	}
	if kota := c.PostForm("kota"); kota != "" {
		updates["ot_kota"] = kota
	}
	if kecamatan := c.PostForm("kecamatan"); kecamatan != "" {
		updates["ot_kecamatan"] = kecamatan
	}
	if latitude := strings.TrimSpace(c.PostForm("latitude")); latitude != "" {
		value, err := strconv.ParseFloat(latitude, 64)
		if err != nil || value < -90 || value > 90 {
			utils.ErrorResponse(c, http.StatusBadRequest, "Latitude lokasi outlet tidak valid")
			return
		}
		updates["ot_latitude"] = value
	}
	if longitude := strings.TrimSpace(c.PostForm("longitude")); longitude != "" {
		value, err := strconv.ParseFloat(longitude, 64)
		if err != nil || value < -180 || value > 180 {
			utils.ErrorResponse(c, http.StatusBadRequest, "Longitude lokasi outlet tidak valid")
			return
		}
		updates["ot_longitude"] = value
	}
	if radius := strings.TrimSpace(c.PostForm("location_radius_meters")); radius != "" {
		value, err := strconv.Atoi(radius)
		if err == nil && value == 0 {
			value = 5
		}
		if err != nil || value < 1 || value > 1000 {
			utils.ErrorResponse(c, http.StatusBadRequest, "Radius absensi harus antara 1 sampai 1000 meter")
			return
		}
		updates["ot_location_radius_meters"] = value
	}
	if tipeLokasi := c.PostForm("tipe_lokasi_usaha"); tipeLokasi != "" {
		updates["ot_tipe_lokasi_usaha"] = tipeLokasi
	}
	if modal := c.PostForm("modal_usaha"); modal != "" {
		updates["ot_modal_usaha"] = modal
	}
	if karyawan := c.PostForm("jumlah_karyawan"); karyawan != "" {
		updates["ot_jumlah_karyawan"] = karyawan
	}
	if mesin := c.PostForm("jumlah_mesin"); mesin != "" {
		updates["ot_jumlah_mesin"] = mesin
	}
	if tanggal := c.PostForm("tanggal_berjalan"); tanggal != "" {
		updates["ot_tanggal_berjalan"] = tanggal
	}
	if skip := c.PostForm("skip_proses"); skip != "" {
		updates["ot_skip_proses"] = skip
	}
	if metode := c.PostForm("metode_pembayaran"); metode != "" {
		updates["ot_metode_pembayaran"] = metode
	}
	if diskon := c.PostForm("fitur_diskon"); diskon != "" {
		updates["ot_fitur_diskon"] = diskon
	}
	if timezone := c.PostForm("timezone"); timezone != "" {
		updates["ot_timezone"] = timezone
	}

	updates["ot_userupdate"] = actorID
	updates["ot_userupdate_type"] = actorType

	// 🚀 LOGIC UPLOAD GAMBAR DENGAN COMPRESS
	file, err := c.FormFile("gambar")
	if err == nil {
		imagePath, saveErr := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
			SubFolder: "outlets",
			Prefix:    outletID.(string),
			MaxWidth:  500,
			Quality:   80,
		})
		if saveErr != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, saveErr.Error())
			return
		}
		updates["ot_gambar"] = imagePath
	}

	updatedData, err := ctrl.svc.UpdateProfile(outletID.(string), updates)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate cache
	database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Profil outlet berhasil diperbarui", updatedData)
}

func (ctrl *OutletController) Switch(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)
	packageID := c.MustGet("package_id").(uint)

	var input struct {
		OutletID string `json:"outlet_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Outlet ID wajib diisi")
		return
	}

	userID, _ := strconv.ParseUint(actorID, 10, 32)
	var employee model.Pegawai
	if actorType == "pegawai" {
		var allowed bool
		var err error
		employee, allowed, err = ctrl.svc.VerifyEmployeeAccess(actorID, input.OutletID)
		if err != nil || !allowed {
			utils.ErrorResponse(c, http.StatusForbidden, "Anda tidak memiliki akses ke outlet ini")
			return
		}
	} else {
		isOwner, err := ctrl.svc.VerifyOwner(uint(userID), input.OutletID)
		if err != nil || !isOwner {
			utils.ErrorResponse(c, http.StatusForbidden, "Anda tidak memiliki akses ke outlet ini")
			return
		}
	}

	profile, errProfile := ctrl.svc.GetProfile(input.OutletID)
	if errProfile == nil && profile.Status != 1 {
		utils.ErrorResponse(c, http.StatusForbidden, "Outlet sedang dinonaktifkan")
		return
	}

	// --- TAMBAHKAN LOGIKA INI ---
	// Update usr_last_outlet di database agar sinkron saat login ulang
	if actorType == "user" {
		err := ctrl.svc.UpdateLastOutlet(uint(userID), input.OutletID)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal sinkronisasi outlet di database")
			return
		}
	} else if actorType == "pegawai" {
		if err := ctrl.svc.UpdateEmployeeLastOutlet(actorID, input.OutletID); err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal menyimpan outlet aktif")
			return
		}
	}
	// ----------------------------

	roleID := c.MustGet("role_id").(string)
	permissions := c.MustGet("role_permissions").(string)

	newClaims := middleware.Claims{
		ActorID:      actorID,
		ActorType:    actorType,
		OutletID:     input.OutletID,
		RoleID:       roleID,
		Permissions:  permissions,
		PackageID:    packageID,
		TokenVersion: employee.TokenVersion,
	}

	newToken, err := utils.GenerateToken(newClaims)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memperbarui sesi")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Berhasil pindah outlet", gin.H{
		"token": newToken,
	})
}
