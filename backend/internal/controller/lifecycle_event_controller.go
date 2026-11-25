package controller

import (
	"net/http"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"

	"github.com/gin-gonic/gin"
)

type LifecycleEventController struct {
	svc *service.LifecycleEventService
}

func NewLifecycleEventController(svc *service.LifecycleEventService) *LifecycleEventController {
	return &LifecycleEventController{svc: svc}
}

func (ctrl *LifecycleEventController) Track(c *gin.Context) {
	var req struct {
		EventID    string                 `json:"event_id" binding:"required"`
		EventName  string                 `json:"event_name" binding:"required"`
		OccurredAt *time.Time             `json:"occurred_at"`
		Metadata   map[string]interface{} `json:"metadata"`
	}
	if c.ShouldBindJSON(&req) != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Event lifecycle tidak valid")
		return
	}
	occurredAt := time.Now()
	if req.OccurredAt != nil {
		occurredAt = *req.OccurredAt
	}
	err := ctrl.svc.Track(model.LifecycleEvent{
		EventID: req.EventID, OutletID: c.GetString("outlet_id"),
		ActorID: c.GetString("actor_id"), ActorType: c.GetString("actor_type"),
		EventName: req.EventName, OccurredAt: occurredAt,
	}, req.Metadata)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusAccepted, "Event lifecycle diterima", nil)
}
