package controller

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type AIAnalystController struct {
	svc    *service.AIAnalystService
	initErr error
}

func NewAIAnalystController(svc *service.AIAnalystService, initErr error) *AIAnalystController {
	return &AIAnalystController{svc: svc, initErr: initErr}
}

func (ctrl *AIAnalystController) Ask(c *gin.Context) {
	if ctrl.svc == nil {
		msg := "Fitur AI Analyst belum aktif."
		if ctrl.initErr != nil {
			msg = "AI Analyst belum siap: " + ctrl.initErr.Error()
		}
		utils.ErrorResponse(c, http.StatusServiceUnavailable, msg)
		return
	}

	var req struct {
		SessionID string `json:"session_id"`
		Message   string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Pesan wajib diisi")
		return
	}
	if strings.TrimSpace(req.SessionID) == "" {
		req.SessionID = uuid.NewString()
	}

	res, err := ctrl.svc.Ask(req.SessionID, req.Message)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadGateway, err.Error())
		return
	}
	utils.JSONResponse(c, http.StatusOK, "Success", res)
}

// AskStream: jawaban streaming via Server-Sent Events.
func (ctrl *AIAnalystController) AskStream(c *gin.Context) {
	if ctrl.svc == nil {
		utils.ErrorResponse(c, http.StatusServiceUnavailable, "Fitur AI Analyst belum aktif.")
		return
	}
	var req struct {
		SessionID string `json:"session_id"`
		Message   string `json:"message" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Pesan wajib diisi")
		return
	}
	if strings.TrimSpace(req.SessionID) == "" {
		req.SessionID = uuid.NewString()
	}

	c.Writer.Header().Set("Content-Type", "text/event-stream")
	c.Writer.Header().Set("Cache-Control", "no-cache")
	c.Writer.Header().Set("Connection", "keep-alive")
	c.Writer.Header().Set("X-Accel-Buffering", "no")
	flusher, _ := c.Writer.(http.Flusher)

	emit := func(evt string, payload map[string]any) {
		b, _ := json.Marshal(payload)
		c.Writer.WriteString("event: " + evt + "\ndata: " + string(b) + "\n\n")
		if flusher != nil {
			flusher.Flush()
		}
	}
	emit("session", map[string]any{"session_id": req.SessionID})
	ctrl.svc.AskStream(req.SessionID, req.Message, emit)
}
