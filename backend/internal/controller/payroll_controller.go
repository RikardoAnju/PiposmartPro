package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"net/http"

	"github.com/gin-gonic/gin"
)

type PayrollController struct {
	svc *service.PayrollService
}

func (ctrl *PayrollController) MarkBulkPaid(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")
	var ids []string
	if err := json.Unmarshal([]byte(c.PostForm("item_ids")), &ids); err != nil || len(ids) == 0 {
		utils.ErrorResponse(c, http.StatusBadRequest, "item_ids tidak valid")
		return
	}
	paidBy, _ := actorID.(string)
	paidByType, _ := actorType.(string)
	if paidByType == "" {
		paidByType = "user"
	}
	data, err := ctrl.svc.MarkBulkPaid(outletID.(string), ids, c.PostForm("payment_method"), paidBy, paidByType)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Payroll berhasil dibayar", data)
}

func NewPayrollController(svc *service.PayrollService) *PayrollController {
	return &PayrollController{svc: svc}
}

func (ctrl *PayrollController) GetPendingEmployees(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	rows, err := ctrl.svc.GetPendingEmployees(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil kandidat penggajian", rows)
}

func (ctrl *PayrollController) SaveSalaryConfig(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	pegawaiID := c.Param("pegawai_id")
	var body map[string]any
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}
	cfg, err := ctrl.svc.SaveConfig(outletID.(string), pegawaiID, body)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Pengaturan gaji berhasil disimpan", cfg)
}

func (ctrl *PayrollController) GetConfigs(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	rows, err := ctrl.svc.GetConfigs(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil konfigurasi gaji", rows)
}

func (ctrl *PayrollController) GetActive(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	summary, err := ctrl.svc.ListActive(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil payroll aktif", summary)
}

func (ctrl *PayrollController) GetHistory(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	rows, err := ctrl.svc.ListHistory(outletID.(string))
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil riwayat payroll", rows)
}

func (ctrl *PayrollController) GetItemDetail(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	itemID := c.Param("id")
	row, err := ctrl.svc.GetItemDetail(outletID.(string), itemID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil mengambil detail payroll", row)
}

func (ctrl *PayrollController) UpdateItemComponents(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	itemID := c.Param("id")
	var body map[string]any
	if err := c.ShouldBindJSON(&body); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Data tidak valid")
		return
	}
	row, err := ctrl.svc.UpdateItemComponents(outletID.(string), itemID, body)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Komponen payroll berhasil disimpan", row)
}

func (ctrl *PayrollController) DeleteItem(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	itemID := c.Param("id")
	if err := ctrl.svc.DeleteItem(outletID.(string), itemID); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Item payroll berhasil dihapus", nil)
}

func (ctrl *PayrollController) MarkPaid(c *gin.Context) {
	outletID, _ := c.Get("outlet_id")
	itemID := c.Param("id")
	actorID, _ := c.Get("actor_id")
	actorType, _ := c.Get("actor_type")
	paymentMethod := c.PostForm("payment_method")

	buktiPath := ""
	if fileHeader, err := c.FormFile("bukti"); err == nil && fileHeader != nil {
		path, upErr := utils.SaveUploadedFile(fileHeader, "payroll")
		if upErr != nil {
			utils.ErrorResponse(c, http.StatusBadRequest, "Gagal mengunggah bukti struk")
			return
		}
		buktiPath = path
	}

	paidBy := ""
	if v, ok := actorID.(string); ok {
		paidBy = v
	}
	paidByType := "user"
	if v, ok := actorType.(string); ok && v != "" {
		paidByType = v
	}
	data, err := ctrl.svc.MarkPaid(outletID.(string), itemID, paymentMethod, paidBy, paidByType, buktiPath)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Payroll berhasil dibayar", data)
}
