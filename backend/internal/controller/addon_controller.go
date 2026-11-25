package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

type AddonController struct {
	svc *service.AddonService
}

func NewAddonController(s *service.AddonService) *AddonController {
	return &AddonController{svc: s}
}

// ---------------------------------------------------------
// OWNER / TENANT ENDPOINTS (MOBILE APP)
// ---------------------------------------------------------

// GetKatalog menampilkan semua layanan add-on yang aktif
func (ctrl *AddonController) GetKatalog(c *gin.Context) {
	data, err := ctrl.svc.GetAvailableAddons()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memuat katalog fitur")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", data)
}

// PurchaseWithKoin menangani pembelian instan menggunakan saldo koin (Bulk Support)
func (ctrl *AddonController) PurchaseWithKoin(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)

	var req struct {
		AddonIDs  []string          `json:"addon_ids" binding:"required"`
		TargetIDs map[string]string `json:"target_ids"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload tidak valid")
		return
	}

	if err := ctrl.svc.PurchaseAddonWithKoin(outletID.(string), req.AddonIDs, req.TargetIDs, actorID); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Add-on berhasil diaktifkan!", nil)
}

// RequestActivation menangani order add-on via Transfer/Midtrans
func (ctrl *AddonController) RequestActivation(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	var req struct {
		AddonIDs    []string          `json:"addon_ids" binding:"required"`
		Metode      string            `json:"metode" binding:"required"`
		TargetIDs   map[string]string `json:"target_ids"`
		BankID      *uint             `json:"bank_id"`
		VoucherCode string            `json:"voucher_code"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Input data tidak valid")
		return
	}
	if strings.EqualFold(strings.TrimSpace(req.Metode), "MIDTRANS") {
		utils.ErrorResponse(c, http.StatusBadRequest, "Pembelian add-on hanya bisa dibayar memakai koin")
		return
	}

	res, err := ctrl.svc.CreateAddonOrder(outletID.(string), req.AddonIDs, req.Metode, req.TargetIDs, req.BankID, req.VoucherCode)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Pesanan berhasil dibuat.", res)
}

// UploadBukti menangani upload struk transfer manual (Retryable for FAILED status)
func (ctrl *AddonController) UploadBukti(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	taID := c.PostForm("ha_id")

	if taID == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Transaksi (ha_id) wajib diisi")
		return
	}

	file, err := c.FormFile("bukti")
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "File bukti transfer wajib diunggah")
		return
	}

	path, err := utils.SaveCompressedImage(file, utils.ImageUploadOptions{
		SubFolder: "bukti_addon",
		Prefix:    "addon_" + outletID.(string),
		MaxWidth:  1000,
		Quality:   75,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	
	if err := ctrl.svc.UploadBuktiTransferAddon(taID, outletID.(string), path); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Bukti transfer berhasil diunggah.", nil)
}

// ActivateOutlet menangani flow upgrade status outlet ke PRO
func (ctrl *AddonController) ActivateOutlet(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID := c.MustGet("actor_id").(string)

	var req struct {
		Metode      string `json:"metode" binding:"required"`
		BankID      *uint  `json:"bank_id"`
		VoucherCode string `json:"voucher_code"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Pilih metode pembayaran")
		return
	}

	res, err := ctrl.svc.ActivateOutlet(outletID.(string), actorID, req.Metode, req.BankID, req.VoucherCode)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	if m, ok := res.(map[string]string); ok && m["status"] == "INSTANT_SUCCESS" {
		utils.JSONResponse(c, http.StatusOK, "Outlet telah menjadi PRO permanen.", res)
		return
	}

	utils.JSONResponse(c, http.StatusCreated, "Pesanan aktivasi berhasil dibuat.", res)
}

// CancelOrder membatalkan tagihan pending oleh User (Final status CANCELED)
func (ctrl *AddonController) CancelOrder(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	var req struct {
		ID string `json:"ha_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Transaksi wajib diisi")
		return
	}

	if err := ctrl.svc.CancelOrder(req.ID, outletID.(string)); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Pesanan berhasil dibatalkan", nil)
}

// GetActiveFitur mengambil daftar fitur yang masa aktifnya masih berlaku
func (ctrl *AddonController) GetActiveFitur(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	res, err := ctrl.svc.GetActiveAddons(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Belum ada add-on aktif")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// GetPendingOrders menampilkan pesanan aktif (PENDING, PENDING_VALIDATION, FAILED)
func (ctrl *AddonController) GetPendingOrders(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	res, err := ctrl.svc.GetPendingOrders(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data pesanan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// GetAllHistory menampilkan riwayat final (SUCCESS, CANCELED)
func (ctrl *AddonController) GetAllHistory(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	res, err := ctrl.svc.GetAllTransactionHistory(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil riwayat")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// GetDetail menangani pencarian detail satu transaksi
func (ctrl *AddonController) GetDetail(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	taID := c.Param("id")

	res, err := ctrl.svc.GetTransactionDetail(outletID.(string), taID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", res)
}


func (ctrl *AddonController) ValidateVoucher(c *gin.Context) {
	code := c.Query("code")
	if code == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Kode voucher wajib diisi")
		return
	}

	outletID, _ := c.Get("outlet_id")
	outletIDStr, _ := outletID.(string)

	data, err := ctrl.svc.ValidateVoucher(code, outletIDStr)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Voucher valid!", data)
}

// ---------------------------------------------------------
// ADMIN PANEL ENDPOINTS
// ---------------------------------------------------------

// AdminApprove menangani validasi manual oleh Admin (Status -> SUCCESS)
func (ctrl *AddonController) AdminApprove(c *gin.Context) {
	var req struct {
		ID string `json:"ha_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Transaksi (ha_id) wajib diisi")
		return
	}

	actorID := c.MustGet("actor_id").(string)

	if err := ctrl.svc.ProcessApproval(req.ID, actorID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Transaksi add-on berhasil divalidasi!", nil)
}

// AdminCancel menangani penolakan bukti transfer oleh Admin (Status -> FAILED for re-upload)
func (ctrl *AddonController) AdminCancel(c *gin.Context) {
	var req struct {
		ID string `json:"ha_id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "ID Transaksi (ha_id) wajib diisi")
		return
	}

	actorID := c.MustGet("actor_id").(string)

	if err := ctrl.svc.AdminCancelOrder(req.ID, actorID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Bukti transfer add-on ditolak!", nil)
}

// AdminListTransactions menangani pengambilan semua transaksi oleh Admin
func (ctrl *AddonController) AdminListTransactions(c *gin.Context) {
	outletID := c.Query("outlet_id")
	status := c.Query("status")
	metode := c.Query("metode")
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")

	res, err := ctrl.svc.AdminListTransactions(outletID, status, metode, startDate, endDate)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data transaksi")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// AdminGetDetail menangani pengambilan detail transaksi oleh Admin
func (ctrl *AddonController) AdminGetDetail(c *gin.Context) {
	taID := c.Param("id")
	res, err := ctrl.svc.AdminGetDetail(taID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Data tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}
