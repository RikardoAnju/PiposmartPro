package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/middleware"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type TransaksiController struct {
	svc     *service.TransaksiService
	notaSvc *service.NotaService
}

func NewTransaksiController(s *service.TransaksiService, n *service.NotaService) *TransaksiController {
	return &TransaksiController{
		svc:     s,
		notaSvc: n,
	}
}

func (ctrl *TransaksiController) Create(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		PelangganID        string  `json:"pelanggan_id" binding:"required"`
		ParfumID           *string `json:"parfum_id"`
		DiskonID           *string `json:"diskon_id"`
		MetodePembayaranID string  `json:"metode_pembayaran_id"`
		StatusPembayaran   string  `json:"status_pembayaran"`
		DPAmount           float64 `json:"dp_amount"`
		RoundingMode       string  `json:"rounding_mode"` // "none", "ceil", "floor", "round"
		Catatan            string  `json:"catatan"`
		JemputAlamat       string  `json:"jemput_alamat"`
		JemputBiaya        float64 `json:"jemput_biaya"`
		AntarAlamat        string  `json:"antar_alamat"`
		AntarBiaya         float64 `json:"antar_biaya"`
		Details            []struct {
			ProductID string  `json:"product_id" binding:"required"`
			Qty       float64 `json:"qty" binding:"required"`
		} `json:"details" binding:"required"`
		Items []struct {
			ItemID      string `json:"item_id" binding:"required"`
			ServiceName string `json:"service_name"`
			Qty         int    `json:"qty" binding:"required"`
			Keterangan  string `json:"keterangan"`
		} `json:"items"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input tidak valid: "+err.Error())
		return
	}

	if req.StatusPembayaran == "Lunas" && req.MetodePembayaranID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Transaksi Lunas wajib memilih metode pembayaran")
		return
	}

	trx := model.Transaksi{
		OutletID:         outletID.(string),
		PelangganID:      req.PelangganID,
		ParfumID:         req.ParfumID,
		DiskonID:         req.DiskonID,
		StatusPembayaran: req.StatusPembayaran,
		Catatan:          &req.Catatan,
		UserUpdate:       &actorID,
		UserUpdateType:   &actorType,
	}

	if req.JemputAlamat != "" {
		trx.JemputAlamat = &req.JemputAlamat
		trx.JemputBiaya = &req.JemputBiaya
	}
	if req.AntarAlamat != "" {
		trx.AntarAlamat = &req.AntarAlamat
		trx.AntarBiaya = &req.AntarBiaya
	}

	var details []model.DetailTransaksi
	for _, d := range req.Details {
		details = append(details, model.DetailTransaksi{ProductID: d.ProductID, Qty: d.Qty})
	}

	var items []model.ItemTransaksi
	for _, it := range req.Items {
		items = append(items, model.ItemTransaksi{
			ItemID:         it.ItemID,
			ServiceName:    it.ServiceName,
			Qty:            it.Qty,
			Keterangan:     &it.Keterangan,
			UserUpdate:     actorID,
			UserUpdateType: actorType,
		})
	}

	// Mengirim RoundingMode ke Service untuk kalkulasi final
	result, err := ctrl.svc.Create(trx, details, items, req.DPAmount, req.MetodePembayaranID, req.RoundingMode)
	if err != nil {
		status := http.StatusInternalServerError
		msg := "Gagal proses transaksi: " + err.Error()
		if strings.Contains(strings.ToLower(err.Error()), "trial outlet sudah habis") ||
			strings.Contains(strings.ToLower(err.Error()), "outlet tidak ditemukan") {
			status = http.StatusBadRequest
		}
		utils.ErrorResponse(c, status, msg)
		return
	}

	notaConfig, _ := ctrl.notaSvc.GetSetting(outletID.(string))

	// Invalidate Cache (Aggressive Pattern Clearing)
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:summary:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:chart:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:profit_loss:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:expense:analisa:%s:*", outletID.(string)))

	database.InvalidateCache(
		fmt.Sprintf("summary:dashboard:%s", outletID.(string)),
	)
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID.(string)))
	// Refresh daftar pelanggan agar "last_transaction_at" (fitur pelanggan
	// terakhir dilayani) langsung ikut terbarui.
	database.InvalidateCache(fmt.Sprintf("pelanggan:list:v2:%s", outletID.(string)))
	// Refresh ranking layanan tersering (fitur "Tambah Cepat").
	database.InvalidateCache(fmt.Sprintf("layanan:popular:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusCreated, "Transaksi Berhasil", gin.H{
		"transaction": result,
		"nota_config": notaConfig,
	})
}

func (ctrl *TransaksiController) GetAll(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	res, err := ctrl.svc.GetAll(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, 404, "Transaksi tidak ditemukan")
		return
	}
	utils.JSONResponse(c, 200, "Success", res)
}

func (ctrl *TransaksiController) GetByID(c *gin.Context) {
	id := c.Query("id")
	outletID, _ := c.Get("outlet_id")
	res, err := ctrl.svc.GetByID(id, outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, 404, "Transaksi tidak ditemukan")
		return
	}
	utils.JSONResponse(c, 200, "Success", res)
}
func (ctrl *TransaksiController) UpdateStatus(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		IDs    []string `json:"ids" binding:"required"`
		Status string   `json:"status" binding:"required"`
		Alasan string   `json:"alasan"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	if err := ctrl.svc.UpdateStatus(req.IDs, req.Status, actorID, actorType, req.Alasan); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate Cache
	outletID, _ := c.Get("outlet_id")
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:summary:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:chart:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:profit_loss:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:expense:analisa:%s:*", outletID.(string)))

	database.InvalidateCache(
		fmt.Sprintf("summary:dashboard:%s", outletID.(string)),
	)
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Status berhasil diperbarui", nil)
}
func (ctrl *TransaksiController) ProcessPayment(c *gin.Context) {
	trxID := c.Query("id")

	var req struct {
		Amount   float64 `json:"amount" binding:"required"`
		MethodID string  `json:"method_id" binding:"required"`

		JemputAlamat *string  `json:"jemput_alamat"`
		JemputBiaya  *float64 `json:"jemput_biaya"`

		AntarAlamat *string  `json:"antar_alamat"`
		AntarBiaya  *float64 `json:"antar_biaya"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, 400, "Data tidak lengkap")
		return
	}

	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	if err := ctrl.svc.ProcessPayment(
		trxID,
		req.Amount,
		req.MethodID,
		req.JemputAlamat,
		req.JemputBiaya,
		req.AntarAlamat,
		req.AntarBiaya,
		actorID,
		actorType,
	); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	outletID, _ := c.Get("outlet_id")

	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:summary:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:chart:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:profit_loss:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:expense:analisa:%s:*", outletID.(string)))

	database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID.(string)))

	utils.JSONResponse(c, 200, "Pembayaran Berhasil", nil)
}

func (ctrl *TransaksiController) Update(c *gin.Context) {
	id := c.Query("id")
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)
	actorType := c.MustGet("actor_type").(string)

	var req struct {
		ParfumID     *string  `json:"parfum_id"`
		DiskonID     *string  `json:"diskon_id"`
		Catatan      *string  `json:"catatan"`
		RoundingMode string   `json:"rounding_mode"` // Menambahkan support rounding_mode di update
		JemputAlamat *string  `json:"jemput_alamat"`
		JemputBiaya  *float64 `json:"jemput_biaya"`
		AntarAlamat  *string  `json:"antar_alamat"`
		AntarBiaya   *float64 `json:"antar_biaya"`
		Details      []struct {
			ProductID string  `json:"product_id"`
			Qty       float64 `json:"qty"`
		} `json:"details"`
		Items []struct {
			ItemID      string `json:"item_id"`
			ServiceName string `json:"service_name"`
			Qty         int    `json:"qty"`
			Keterangan  string `json:"keterangan"`
		} `json:"items"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data payload tidak valid")
		return
	}

	canUpdateDeliveryFee := actorType == "user"
	if !canUpdateDeliveryFee {
		if permData, exists := c.Get("role_permissions"); exists && permData != nil {
			var permString string
			switch v := permData.(type) {
			case string:
				permString = v
			case []byte:
				permString = string(v)
			}
			canUpdateDeliveryFee = middleware.HasPermission(
				permString,
				"transaksi",
				"update_delivery_fee",
			)
		}
	}

	var details []model.DetailTransaksi
	for _, d := range req.Details {
		details = append(details, model.DetailTransaksi{ProductID: d.ProductID, Qty: d.Qty})
	}

	var items []model.ItemTransaksi
	for _, it := range req.Items {
		items = append(items, model.ItemTransaksi{
			ItemID:         it.ItemID,
			ServiceName:    it.ServiceName,
			Qty:            it.Qty,
			Keterangan:     &it.Keterangan,
			UserUpdate:     actorID,
			UserUpdateType: actorType,
		})
	}

	// Pastikan service Update lo juga siap menerima roundingMode jika diperlukan
	// Untuk sekarang kita teruskan field yang ada sesuai struktur model lo
	res, err := ctrl.svc.Update(id, model.Transaksi{
		OutletID:     outletID.(string),
		ParfumID:     req.ParfumID,
		DiskonID:     req.DiskonID,
		Catatan:      req.Catatan,
		JemputAlamat: req.JemputAlamat,
		JemputBiaya:  req.JemputBiaya,
		AntarAlamat:  req.AntarAlamat,
		AntarBiaya:   req.AntarBiaya,
	}, details, items, actorID, actorType, canUpdateDeliveryFee)

	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	// Invalidate Cache
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:summary:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:chart:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:profit_loss:%s:*", outletID.(string)))
	database.ClearCacheByPattern(fmt.Sprintf("finance:expense:analisa:%s:*", outletID.(string)))

	database.InvalidateCache(
		fmt.Sprintf("summary:dashboard:%s", outletID.(string)),
	)
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID.(string)))

	utils.JSONResponse(c, http.StatusOK, "Nota berhasil diperbarui", res)
}
