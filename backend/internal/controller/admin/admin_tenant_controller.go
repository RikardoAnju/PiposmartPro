package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type AdminTenantController struct {
	svc *admin.AdminTenantService
}

func NewAdminTenantController(s *admin.AdminTenantService) *AdminTenantController {
	return &AdminTenantController{svc: s}
}

func parsePagination(c *gin.Context, defaultLimit int) (int, int) {
	page, err := strconv.Atoi(c.DefaultQuery("page", "1"))
	if err != nil || page < 1 {
		page = 1
	}

	limit, err := strconv.Atoi(c.DefaultQuery("limit", strconv.Itoa(defaultLimit)))
	if err != nil || limit < 1 {
		limit = defaultLimit
	}
	if limit > 100 {
		limit = 100
	}

	return page, limit
}

func (ctrl *AdminTenantController) ListTenants(c *gin.Context) {
	txStart, txEnd := c.Query("tx_start"), c.Query("tx_end")
	for _, value := range []string{txStart, txEnd} {
		if value != "" {
			if _, err := time.Parse("2006-01-02", value); err != nil {
				utils.ErrorResponse(c, http.StatusBadRequest, "Format periode transaksi tidak valid. Gunakan YYYY-MM-DD")
				return
			}
		}
	}
	if txStart != "" && txEnd != "" && txStart > txEnd {
		utils.ErrorResponse(c, http.StatusBadRequest, "Tanggal awal transaksi tidak boleh setelah tanggal akhir")
		return
	}

	data, err := ctrl.svc.GetAllTenants(txStart, txEnd)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data tenant")
		return
	}

	page, limit := parsePagination(c, 25)
	total := len(data)
	start := (page - 1) * limit
	if start > total {
		start = total
	}
	end := start + limit
	if end > total {
		end = total
	}

	if c.Query("paginated") != "1" {
		utils.JSONResponse(c, http.StatusOK, "Success", data)
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Success", gin.H{
		"items": data[start:end],
		"pagination": gin.H{
			"page":  page,
			"limit": limit,
			"total": total,
		},
	})
}

func (ctrl *AdminTenantController) UpdateStatus(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Status int `json:"status"` // 1: Aktif, 0: Suspend
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := ctrl.svc.UpdateTenantStatus(id, req.Status); err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal memperbarui status tenant")
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Status tenant berhasil diperbarui", nil)
}

func (ctrl *AdminTenantController) DeleteTenant(c *gin.Context) {
	id := c.Param("id")
	if err := ctrl.svc.DeleteTenant(id); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Outlet berhasil dihapus", nil)
}

func (ctrl *AdminTenantController) GetDetail(c *gin.Context) {
	id := c.Param("id")
	data, err := ctrl.svc.GetTenantDetail(id)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Tenant tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", data)
}

func (ctrl *AdminTenantController) GetNameHistory(c *gin.Context) {
	id := c.Param("id")
	data, err := ctrl.svc.GetNameHistory(id)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil riwayat perubahan nama")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", data)
}
