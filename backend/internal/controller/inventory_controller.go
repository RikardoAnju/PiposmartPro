package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"github.com/gin-gonic/gin"
	"net/http"
)

type InventoryController struct{ svc *service.InventoryService }

func NewInventoryController(s *service.InventoryService) *InventoryController {
	return &InventoryController{svc: s}
}
func inventoryOutlet(c *gin.Context) string { return c.MustGet("outlet_id").(string) }
func inventoryActor(c *gin.Context) (string, string) {
	return c.MustGet("actor_id").(string), c.MustGet("actor_type").(string)
}
func (ctrl *InventoryController) Overview(c *gin.Context) {
	data, err := ctrl.svc.Overview(inventoryOutlet(c), c.Query("q"), c.Query("status"))
	if err != nil {
		utils.ErrorResponse(c, 500, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Berhasil mengambil ringkasan inventory", data)
}
func (ctrl *InventoryController) ListItems(c *gin.Context) {
	data, err := ctrl.svc.ListItems(inventoryOutlet(c), c.Query("q"), c.Query("status"))
	if err != nil {
		utils.ErrorResponse(c, 500, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Berhasil mengambil barang inventory", data)
}
func (ctrl *InventoryController) CreateItem(c *gin.Context) {
	var req model.InventoryItem
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, 400, "Data barang tidak valid")
		return
	}
	req.OutletID = inventoryOutlet(c)
	actor, kind := inventoryActor(c)
	data, err := ctrl.svc.CreateItem(req, actor, kind)
	if err != nil {
		utils.ErrorResponse(c, 400, err.Error())
		return
	}
	utils.JSONResponse(c, 201, "Barang inventory berhasil ditambahkan", data)
}
func (ctrl *InventoryController) AdjustStock(c *gin.Context) {
	var req struct {
		Type     string  `json:"type" binding:"required"`
		Quantity float64 `json:"quantity" binding:"required"`
		Note     string  `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, 400, "Data penyesuaian tidak valid")
		return
	}
	actor, kind := inventoryActor(c)
	data, err := ctrl.svc.AdjustStock(inventoryOutlet(c), c.Param("id"), req.Type, req.Quantity, req.Note, actor, kind)
	if err != nil {
		utils.ErrorResponse(c, 400, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Stok berhasil diperbarui", data)
}
func (ctrl *InventoryController) ListCategories(c *gin.Context) {
	data, err := ctrl.svc.ListCategories(inventoryOutlet(c))
	if err != nil {
		utils.ErrorResponse(c, 500, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Berhasil mengambil kategori inventory", data)
}
func (ctrl *InventoryController) CreateCategory(c *gin.Context) {
	var req struct {
		Name    string `json:"name" binding:"required"`
		IconKey string `json:"icon_key"`
	}
	if c.ShouldBindJSON(&req) != nil {
		utils.ErrorResponse(c, 400, "Nama kategori wajib diisi")
		return
	}
	data, err := ctrl.svc.CreateCategory(inventoryOutlet(c), req.Name, req.IconKey)
	if err != nil {
		utils.ErrorResponse(c, 400, err.Error())
		return
	}
	utils.JSONResponse(c, 201, "Kategori berhasil ditambahkan", data)
}
func (ctrl *InventoryController) UpdateCategory(c *gin.Context) {
	var req struct {
		Name    string `json:"name" binding:"required"`
		IconKey string `json:"icon_key"`
	}
	if c.ShouldBindJSON(&req) != nil {
		utils.ErrorResponse(c, 400, "Nama kategori wajib diisi")
		return
	}
	if err := ctrl.svc.UpdateCategory(inventoryOutlet(c), c.Param("id"), req.Name, req.IconKey); err != nil {
		utils.ErrorResponse(c, 400, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Kategori berhasil diperbarui", nil)
}
func (ctrl *InventoryController) DeleteCategory(c *gin.Context) {
	if err := ctrl.svc.DeleteCategory(inventoryOutlet(c), c.Param("id")); err != nil {
		utils.ErrorResponse(c, 400, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Kategori berhasil dihapus", nil)
}
func (ctrl *InventoryController) GetSetting(c *gin.Context) {
	data, err := ctrl.svc.GetSetting(inventoryOutlet(c))
	if err != nil {
		utils.ErrorResponse(c, 500, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Berhasil mengambil pengaturan inventory", data)
}
func (ctrl *InventoryController) SaveSetting(c *gin.Context) {
	var req model.InventorySetting
	if c.ShouldBindJSON(&req) != nil {
		utils.ErrorResponse(c, 400, "Data pengaturan tidak valid")
		return
	}
	req.OutletID = inventoryOutlet(c)
	if err := ctrl.svc.SaveSetting(req); err != nil {
		utils.ErrorResponse(c, 400, err.Error())
		return
	}
	utils.JSONResponse(c, 200, "Pengaturan inventory berhasil disimpan", nil)
}
