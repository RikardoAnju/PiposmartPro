package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"github.com/gin-gonic/gin"
	"net/http"
	"strings"
)

type KoinController struct {
	koinSvc    *service.KoinService
	economySvc adminSvc.AdminEconomyService
	addonSvc   *service.AddonService // Untuk dispatch notifikasi midtrans ke AddonService jika bukan transaksi koin
}

func NewKoinController(s *service.KoinService, es adminSvc.AdminEconomyService, a *service.AddonService) *KoinController {
	return &KoinController{
		koinSvc:    s,
		economySvc: es,
		addonSvc:   a,
	}
}
func (ctrl *KoinController) GetAllTopups(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	res, err := ctrl.koinSvc.GetAllTopupsByOutlet(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil semua riwayat tagihan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// RegenerateSnapURL: Mekanisme fixing jika link midtrans expired/hilang
func (ctrl *KoinController) RegenerateSnapURL(c *gin.Context) {
	topupID := c.Param("id")
	outletID := c.MustGet("outlet_id").(string)

	if topupID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Tagihan tidak valid")
		return
	}

	newSnapURL, err := ctrl.koinSvc.RegenerateSnapURL(topupID, outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Link pembayaran baru berhasil dibuat", gin.H{
		"snap_url": newSnapURL,
	})
}

// GetEconomyConfig: Ambil config (price_per_coin, dll)
func (ctrl *KoinController) GetEconomyConfig(c *gin.Context) {
	configs, err := ctrl.economySvc.GetConfigs()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil konfigurasi ekonomi")
		return
	}
	result := make(map[string]string)
	for _, cfg := range configs {
		result[cfg.Key] = cfg.Value
	}
	utils.JSONResponse(c, http.StatusOK, "Success", result)
}

func (ctrl *KoinController) GetHistory(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	res, err := ctrl.koinSvc.GetHistory(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil riwayat koin")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *KoinController) GetActiveTopups(c *gin.Context) {
	outletID := c.MustGet("outlet_id").(string)
	res, err := ctrl.koinSvc.GetActiveTopups(outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data tagihan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// CheckVoucher: Digunakan Flutter untuk validasi kode & dapetin nominal diskon sebelum checkout
func (ctrl *KoinController) CheckVoucher(c *gin.Context) {
	code := c.Query("code")
	jumlahKoin := utils.StringToInt(c.Query("jumlah"))

	if code == "" || jumlahKoin <= 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Kode voucher dan jumlah koin valid harus diisi")
		return
	}

	priceCfg := ctrl.economySvc.GetConfigValue("price_per_coin")
	basePrice := utils.StringToFloat64(priceCfg)
	if basePrice <= 0 {
		basePrice = 200
	}

	res, potongan, err := ctrl.koinSvc.ValidateVoucherWithCalculation(code, jumlahKoin, basePrice)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Voucher Valid", gin.H{
		"voucher":          res,
		"nominal_potongan": potongan,
		"estimasi_total":   (float64(jumlahKoin) * basePrice) - potongan,
	})
}

func (ctrl *KoinController) CancelTopup(c *gin.Context) {
	var req struct {
		TopupID string `json:"topup_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Tagihan wajib diisi")
		return
	}

	outletID := c.MustGet("outlet_id").(string)

	err := ctrl.koinSvc.CancelTopupByUser(req.TopupID, outletID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Tagihan berhasil dibatalkan", nil)
}

// RequestTopup UPDATED: Support BankID untuk transfer manual
func (ctrl *KoinController) RequestTopup(c *gin.Context) {
	var req struct {
		JumlahKoin   int     `json:"jumlah_koin" binding:"required"`
		NominalBayar float64 `json:"nominal_bayar" binding:"required"`
		MetodeBayar  string  `json:"metode_bayar" binding:"required"` // midtrans / transfer
		BankID       *uint   `json:"bank_id"`                         // Diisi jika transfer manual
		KodeVoucher  *string `json:"kode_voucher"`
		KodeUnik     int     `json:"kode_unik"` // 3 digit dari frontend untuk transfer manual
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data input tidak valid")
		return
	}

	outletID := c.MustGet("outlet_id").(string)
	userID := c.MustGet("actor_id").(string)

	res, snapURL, err := ctrl.koinSvc.CreateTopup(
		outletID,
		req.JumlahKoin,
		req.NominalBayar,
		req.MetodeBayar,
		req.BankID,
		req.KodeVoucher,
		req.KodeUnik,
		userID,
	)

	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Topup Berhasil Dibuat", gin.H{
		"topup_data": res,
		"snap_url":   snapURL,
	})
}

// UploadBuktiTransfer: Endpoint untuk upload foto struk transfer manual
func (ctrl *KoinController) UploadBuktiTransfer(c *gin.Context) {
	topupID := c.PostForm("topup_id")
	if topupID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Topup ID wajib diisi")
		return
	}

	file, err := c.FormFile("bukti")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "File bukti transfer tidak ditemukan")
		return
	}

	imageURL, err := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
		SubFolder: "bukti_transfer",
		Prefix:    "tf_" + topupID,
		MaxWidth:  800,
		Quality:   75,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	if err := ctrl.koinSvc.SubmitBuktiTransfer(topupID, imageURL); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal update data bukti transfer")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Bukti transfer berhasil diunggah", gin.H{
		"image_url": imageURL,
	})
}

// internal/controller/koin_controller.go

func (ctrl *KoinController) HandleMidtransNotification(c *gin.Context) {
	var payload map[string]interface{}
	if err := c.ShouldBindJSON(&payload); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload tidak valid")
		return
	}

	orderID, _ := payload["order_id"].(string)

	// --- SMART DISPATCHER LOGIC ---

	// 1. Jika ini transaksi TOPUP KOIN (Biasanya lo kasih prefix TK- atau sesuai generator lo)
	// Asumsi: Topup Koin ID lo diawali huruf atau format tertentu yang beda dari UUID Addon
	if strings.HasPrefix(orderID, "TK-") {
		err := ctrl.koinSvc.ProcessMidtransNotification(payload)
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
			return
		}
	} else {
		// 2. Jika bukan Koin, berarti ini ADDON atau AKTIVASI OUTLET (Format UUID)
		// Kita panggil AddonService untuk proses
		err := ctrl.addonSvc.ProcessMidtransNotification(payload) // Lo perlu inject addonSvc ke KoinController
		if err != nil {
			utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{"status": "ok"})
}
func (ctrl *KoinController) GetPackages(c *gin.Context) {
	// svc di sini adalah admin.AdminEconomyService yang di-inject ke controller
	res, err := ctrl.economySvc.GetKoinPackages()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat paket")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *KoinController) AdminListAllPemasukan(c *gin.Context) {
	outletID := c.Query("outlet_id")
	status := c.Query("status")
	metode := c.Query("metode")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	res, err := ctrl.koinSvc.AdminListAllPemasukan(outletID, status, metode, startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil seluruh data pemasukan koin")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *KoinController) AdminListTopups(c *gin.Context) {
	outletID := c.Query("outlet_id")
	status := c.Query("status")
	metode := c.Query("metode")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	res, err := ctrl.koinSvc.AdminListTopups(outletID, status, metode, startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data topup")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

func (ctrl *KoinController) AdminCoinLedger(c *gin.Context) {
	outletID := c.Query("outlet_id")
	jenis := c.Query("jenis")
	sourceType := c.Query("source_type")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	search := c.Query("search")

	res, err := ctrl.koinSvc.AdminCoinLedger(outletID, jenis, sourceType, startDate, endDate, search)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil ledger koin")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// AdminGetTopupDetail: GET /api/v1/admin/topup-koin/:id
func (ctrl *KoinController) AdminGetTopupDetail(c *gin.Context) {
	topupID := c.Param("id")
	res, err := ctrl.koinSvc.AdminGetTopupDetail(topupID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Data tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// AdminCancelMidtrans: PATCH /api/v1/admin/topup-koin/cancel-midtrans
func (ctrl *KoinController) AdminCancelMidtrans(c *gin.Context) {
	var req struct {
		TopupID string `json:"topup_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	adminID := c.MustGet("actor_id").(string)
	err := ctrl.koinSvc.AdminCancelMidtrans(req.TopupID, adminID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Transaksi Midtrans berhasil dibatalkan secara paksa", nil)
}

// AdminConfirmTopup: PATCH /api/v1/admin/topups/confirm
func (ctrl *KoinController) AdminConfirmTopup(c *gin.Context) {
	var req struct {
		TopupID string `json:"topup_id" binding:"required"`
		Status  string `json:"status" binding:"required"` // success / failed
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}

	adminID := c.MustGet("actor_id").(string)
	err := ctrl.koinSvc.AdminConfirmPayment(req.TopupID, req.Status, adminID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Pembayaran berhasil dikonfirmasi", nil)
}

func (ctrl *KoinController) AdminInjectCoin(c *gin.Context) {
	outletID := c.Param("id")
	if outletID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Outlet wajib diisi")
		return
	}

	jumlahKoin := utils.StringToInt(c.PostForm("jumlah_koin"))
	alasan := c.PostForm("alasan")
	metodeBayar := c.PostForm("metode_bayar")
	if metodeBayar != "transfer" && metodeBayar != "bonus" {
		metodeBayar = "transfer"
	}

	if jumlahKoin <= 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "Jumlah koin harus lebih dari 0")
		return
	}
	if strings.TrimSpace(alasan) == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Alasan penambahan koin wajib diisi")
		return
	}

	var buktiPath *string
	file, err := c.FormFile("bukti")
	if err == nil && file != nil {
		imageURL, errUpload := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
			SubFolder: "bukti_transfer",
			Prefix:    "tf_inj_" + outletID + "_",
			MaxWidth:  800,
			Quality:   75,
		})
		if errUpload != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Gagal mengunggah bukti transfer: "+errUpload.Error())
			return
		}
		buktiPath = &imageURL
	}

	adminID := c.MustGet("actor_id").(string)
	errSvc := ctrl.koinSvc.AdminInjectCoin(outletID, jumlahKoin, alasan, metodeBayar, buktiPath, adminID)
	if errSvc != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, errSvc.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Koin berhasil ditambahkan ke outlet", nil)
}


