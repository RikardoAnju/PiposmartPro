package admin

import (
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

type AccountDeletionController struct {
	svc adminSvc.AdminAccountDeletionService
}

func NewAccountDeletionController(svc adminSvc.AdminAccountDeletionService) *AccountDeletionController {
	return &AccountDeletionController{svc: svc}
}

func (ctrl *AccountDeletionController) List(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "200"))

	rows, err := ctrl.svc.List(adminSvc.AccountDeletionFilter{
		Search:    c.Query("search"),
		ActorType: c.Query("actor_type"),
		Limit:     limit,
	})
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data hapus akun: "+err.Error())
		return
	}

	utils.JSONResponse(c, http.StatusOK, "Account deletions", rows)
}
