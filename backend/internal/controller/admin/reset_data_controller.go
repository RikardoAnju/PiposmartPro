package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
)

type ResetDataController struct {
	svc admin.ResetDataService
}

func NewResetDataController(svc admin.ResetDataService) *ResetDataController {
	return &ResetDataController{svc: svc}
}

// ResetOutletData resets all operational data for an outlet
func (ctrl *ResetDataController) ResetOutletData(c *gin.Context) {
	outletID := c.Param("id")

	var req struct {
		ResetType        string `json:"reset_type" binding:"required,oneof=full transactions_only customers_only"`
		Reason           string `json:"reason" binding:"required,oneof=trial_to_production data_cleanup customer_request other"`
		ConfirmationCode string `json:"confirmation_code" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request: "+err.Error())
		return
	}

	// Validate confirmation code (must be provided to prevent accidental resets)
	if strings.TrimSpace(req.ConfirmationCode) == "" {
		utils.ErrorResponse(c, http.StatusBadRequest, "Confirmation code is required")
		return
	}

	// Get actor info from JWT token
	actorID, _ := c.Get("actor_id")
	actorIDStr := ""
	if actorID != nil {
		actorIDStr = actorID.(string)
	}

	// Perform reset
	backup, err := ctrl.svc.ResetOutletData(outletID, req.ResetType, req.Reason, actorIDStr)
	if err != nil {
		if strings.Contains(err.Error(), "outlet not found") {
			utils.ErrorResponse(c, http.StatusNotFound, "Outlet tidak ditemukan")
			return
		}
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal reset data: "+err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Data reset berhasil", gin.H{
		"backup_id":  backup.ID,
		"reset_type": backup.ResetType,
		"reason":     backup.Reason,
		"deleted_records": gin.H{
			"orders":                 backup.DeletedStats.Orders,
			"customers":              backup.DeletedStats.Customers,
			"expenses":               backup.DeletedStats.Expenses,
			"detail_transaksi":       backup.DeletedStats.DetailTransaksi,
			"dp_transaksi":           backup.DeletedStats.DPTransaksi,
			"item_transaksi":         backup.DeletedStats.ItemTransaksi,
			"log_transaksi":          backup.DeletedStats.LogTransaksi,
			"history_koin":           backup.DeletedStats.HistoryKoin,
			"topup_koin":             backup.DeletedStats.TopupKoin,
			"diskon":                 backup.DeletedStats.Diskon,
			"addon_transaksi":        backup.DeletedStats.AddonTransaksi,
			"addon_detail_transaksi": backup.DeletedStats.AddonDetailTransaksi,
			"addon_history":          backup.DeletedStats.AddonHistory,
			"pegawai":                backup.DeletedStats.Pegawai,
			"roles":                  backup.DeletedStats.Roles,
			"layanan":                backup.DeletedStats.Layanan,
			"jenis_produk":           backup.DeletedStats.JenisProduk,
			"parfums":                backup.DeletedStats.Parfums,
			"items":                  backup.DeletedStats.Items,
			"metode_pembayaran":      backup.DeletedStats.MetodePembayaran,
			"kategori_pengeluaran":   backup.DeletedStats.KategoriPengeluaran,
			"notifications":          backup.DeletedStats.Notifications,
		},
		"reset_at": backup.ResetAt,
	})
}

// GetResetHistory retrieves reset history for an outlet
func (ctrl *ResetDataController) GetResetHistory(c *gin.Context) {
	outletID := c.Param("id")

	// Optional limit query parameter (default 10)
	limit := 10
	if limitStr := c.Query("limit"); limitStr != "" {
		// Validate limit is numeric (simple validation)
		for i := 0; i < len(limitStr); i++ {
			if limitStr[i] < '0' || limitStr[i] > '9' {
				utils.ErrorResponse(c, http.StatusBadRequest, "Invalid limit parameter")
				return
			}
		}
		if parsed, err := strconv.Atoi(limitStr); err == nil && parsed > 0 {
			limit = parsed
		}
	}

	history, err := ctrl.svc.GetResetHistory(outletID, limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil riwayat reset")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", gin.H{
		"total": len(history),
		"data":  history,
	})
}

// GetResetDetail retrieves details of a specific reset operation
func (ctrl *ResetDataController) GetResetDetail(c *gin.Context) {
	resetID := c.Param("reset_id")

	backup, err := ctrl.svc.GetResetDetail(resetID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Reset backup tidak ditemukan")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", backup)
}
