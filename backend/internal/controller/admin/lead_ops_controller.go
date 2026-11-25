package admin

import (
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type LeadOpsController struct {
	svc adminSvc.LeadOpsService
}

func NewLeadOpsController(svc adminSvc.LeadOpsService) *LeadOpsController {
	return &LeadOpsController{svc: svc}
}

func (ctrl *LeadOpsController) GetSummary(c *gin.Context) {
	data, err := ctrl.svc.GetSummary()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil ringkasan lead")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) GetMySummary(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.GetMySummary(actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil ringkasan personal lead ops")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) ListAdmins(c *gin.Context) {
	data, err := ctrl.svc.ListAdminOptions()
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil daftar admin")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) GetMe(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.GetActorProfile(actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil profil lead ops")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) ImportLeads(c *gin.Context) {
	var req struct {
		Source string                       `json:"source" binding:"required"`
		Items  []adminSvc.LeadOpsImportItem `json:"items" binding:"required,min=1"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload import tidak valid: "+err.Error())
		return
	}

	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.ImportLeads(req.Source, req.Items, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Lead berhasil diimport", data)
}

func (ctrl *LeadOpsController) ListLeads(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	data, err := ctrl.svc.ListLeads(adminSvc.LeadOpsListFilter{
		Search:     c.Query("search"),
		Status:     c.Query("status"),
		Division:   c.Query("division"),
		AssigneeID: c.Query("assignee_id"),
		Limit:      limit,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data lead")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) ListMyLeads(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	data, err := ctrl.svc.ListMyLeads(adminSvc.LeadOpsListFilter{
		Search:   c.Query("search"),
		Status:   c.Query("status"),
		Division: c.Query("division"),
		Limit:    limit,
	}, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil lead milik saya")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) GetLeadDetail(c *gin.Context) {
	data, err := ctrl.svc.GetLeadDetail(c.Param("id"))
	if err != nil {
		utils.ErrorResponse(c, http.StatusNotFound, "Lead tidak ditemukan")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) AssignLead(c *gin.Context) {
	var req adminSvc.LeadOpsAssignInput
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload assignment tidak valid")
		return
	}

	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.AssignLead(c.Param("id"), req, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Lead berhasil dibagikan", data)
}

func (ctrl *LeadOpsController) ReassignLead(c *gin.Context) {
	var req adminSvc.LeadOpsAssignInput
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload reassign tidak valid")
		return
	}

	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.ReassignLead(c.Param("id"), req, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Lead berhasil dipindahkan", data)
}

func (ctrl *LeadOpsController) ReleaseLead(c *gin.Context) {
	var req struct {
		Note string `json:"note"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload release tidak valid")
		return
	}

	actorID := c.MustGet("actor_id").(string)
	if err := ctrl.svc.ReleaseLead(c.Param("id"), actorID, req.Note); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Lead berhasil dilepas", gin.H{"released": true})
}

func (ctrl *LeadOpsController) AddFollowUp(c *gin.Context) {
	var req adminSvc.LeadOpsFollowUpInput
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload follow-up tidak valid")
		return
	}

	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.AddFollowUp(c.Param("id"), req, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Follow-up berhasil dicatat", data)
}

func (ctrl *LeadOpsController) UpsertOpportunity(c *gin.Context) {
	var req adminSvc.LeadOpsOpportunityInput
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Payload opportunity tidak valid")
		return
	}

	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.UpsertOpportunity(c.Param("id"), req, actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Opportunity berhasil diperbarui", data)
}

func (ctrl *LeadOpsController) ListAssignments(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	data, err := ctrl.svc.ListAssignments(limit)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil ledger assignment")
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Berhasil", data)
}

func (ctrl *LeadOpsController) SeedSampleData(c *gin.Context) {
	actorID := c.MustGet("actor_id").(string)
	data, err := ctrl.svc.SeedSampleData(actorID)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusCreated, "Sample data berhasil dibuat", data)
}
