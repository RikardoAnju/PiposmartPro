package controller

import (
	"github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"github.com/gin-gonic/gin"
	"net/http"
	"strconv"
)

type AttendanceController struct{ svc *service.AttendanceService }

func NewAttendanceController(s *service.AttendanceService) *AttendanceController {
	return &AttendanceController{svc: s}
}
func (c *AttendanceController) GetConfiguration(ctx *gin.Context) {
	outlet, _ := ctx.Get("outlet_id")
	data, err := c.svc.Get(outlet.(string))
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusInternalServerError, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Berhasil mengambil konfigurasi absensi", data)
}
func (c *AttendanceController) SaveConfiguration(ctx *gin.Context) {
	outlet, _ := ctx.Get("outlet_id")
	var input service.AttendanceConfigInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data absensi tidak valid")
		return
	}
	data, err := c.svc.Save(outlet.(string), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Konfigurasi absensi berhasil disimpan", data)
}

func (c *AttendanceController) CheckIn(ctx *gin.Context) {
	if ctx.GetString("actor_type") != "pegawai" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya pegawai yang dapat melakukan absen")
		return
	}
	var input service.AttendanceLocationInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Lokasi absensi tidak valid")
		return
	}
	record, err := c.svc.CheckIn(ctx.GetString("outlet_id"), ctx.GetString("actor_id"), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Absen masuk berhasil", record)
}

func (c *AttendanceController) CheckOut(ctx *gin.Context) {
	if ctx.GetString("actor_type") != "pegawai" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya pegawai yang dapat melakukan absen")
		return
	}
	var input service.AttendanceLocationInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Lokasi absensi tidak valid")
		return
	}
	record, err := c.svc.CheckOut(ctx.GetString("outlet_id"), ctx.GetString("actor_id"), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Absen pulang berhasil", record)
}

func (c *AttendanceController) RequestLeave(ctx *gin.Context) {
	if ctx.GetString("actor_type") != "pegawai" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya pegawai yang dapat mengajukan izin")
		return
	}
	var input service.AttendanceLeaveInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data izin tidak valid")
		return
	}
	leave, err := c.svc.RequestLeave(ctx.GetString("outlet_id"), ctx.GetString("actor_id"), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusCreated, "Pengajuan izin berhasil dikirim ke owner", leave)
}

func (c *AttendanceController) RequestOvertime(ctx *gin.Context) {
	if ctx.GetString("actor_type") != "pegawai" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya pegawai yang dapat mengajukan lembur")
		return
	}
	var input service.AttendanceOvertimeInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data lembur tidak valid")
		return
	}
	o, err := c.svc.RequestOvertime(ctx.GetString("outlet_id"), ctx.GetString("actor_id"), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusCreated, "Pengajuan lembur berhasil dikirim", o)
}

func (c *AttendanceController) OvertimeRequests(ctx *gin.Context) {
	t := ctx.GetString("actor_type")
	if t != "pegawai" && t != "user" && t != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Akses lembur ditolak")
		return
	}
	employeeID := ""
	if t == "pegawai" {
		employeeID = ctx.GetString("actor_id")
	}
	limit, _ := strconv.Atoi(ctx.Query("limit"))
	offset, _ := strconv.Atoi(ctx.Query("offset"))
	rows, more, err := c.svc.OvertimeRequests(ctx.GetString("outlet_id"), employeeID, ctx.Query("status"), limit, offset)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	if limit > 0 {
		utils.JSONResponse(ctx, http.StatusOK, "Data lembur berhasil diambil", gin.H{"requests": rows, "has_more": more})
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Data lembur berhasil diambil", rows)
}

func (c *AttendanceController) DecideOvertime(ctx *gin.Context) {
	t := ctx.GetString("actor_type")
	if t != "user" && t != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya owner yang dapat memproses lembur")
		return
	}
	var input service.AttendanceOvertimeDecisionInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data keputusan lembur tidak valid")
		return
	}
	o, err := c.svc.DecideOvertime(ctx.GetString("outlet_id"), ctx.Param("id"), ctx.GetString("actor_id"), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Keputusan lembur berhasil disimpan", o)
}

func (c *AttendanceController) LeaveRequests(ctx *gin.Context) {
	actorType := ctx.GetString("actor_type")
	if actorType != "pegawai" && actorType != "user" && actorType != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Akses riwayat izin ditolak")
		return
	}
	employeeID := ""
	if actorType == "pegawai" {
		employeeID = ctx.GetString("actor_id")
	}
	limit, _ := strconv.Atoi(ctx.Query("limit"))
	offset, _ := strconv.Atoi(ctx.Query("offset"))
	requests, hasMore, err := c.svc.LeaveRequests(ctx.GetString("outlet_id"), employeeID, ctx.Query("month"), limit, offset)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	if limit > 0 {
		utils.JSONResponse(ctx, http.StatusOK, "Data izin berhasil diambil", gin.H{"requests": requests, "has_more": hasMore})
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Data izin berhasil diambil", requests)
}

func (c *AttendanceController) UpdateLeaveStatus(ctx *gin.Context) {
	if t := ctx.GetString("actor_type"); t != "user" && t != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya owner yang dapat memproses izin")
		return
	}
	var input service.AttendanceLeaveDecisionInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data keputusan izin tidak valid")
		return
	}
	leave, err := c.svc.UpdateLeaveStatus(
		ctx.GetString("outlet_id"),
		ctx.Param("id"),
		ctx.GetString("actor_id"),
		input,
	)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Keputusan izin berhasil disimpan", leave)
}

func (c *AttendanceController) Records(ctx *gin.Context) {
	actorType := ctx.GetString("actor_type")
	if actorType != "pegawai" && actorType != "user" && actorType != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Akses riwayat absensi ditolak")
		return
	}
	employeeID := ""
	if actorType == "pegawai" {
		employeeID = ctx.GetString("actor_id")
	}
	limit, _ := strconv.Atoi(ctx.Query("limit"))
	offset, _ := strconv.Atoi(ctx.Query("offset"))
	records, hasMore, err := c.svc.Records(ctx.GetString("outlet_id"), ctx.Query("date"), ctx.Query("month"), employeeID, limit, offset)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	if limit > 0 {
		utils.JSONResponse(ctx, http.StatusOK, "Data absensi berhasil diambil", gin.H{"records": records, "has_more": hasMore})
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Data absensi berhasil diambil", records)
}

func (c *AttendanceController) Holidays(ctx *gin.Context) {
	actorType := ctx.GetString("actor_type")
	if actorType != "pegawai" && actorType != "user" && actorType != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Akses hari libur ditolak")
		return
	}
	holidays, err := c.svc.Holidays(ctx.GetString("outlet_id"))
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Data hari libur berhasil diambil", holidays)
}

func (c *AttendanceController) AddHoliday(ctx *gin.Context) {
	if t := ctx.GetString("actor_type"); t != "user" && t != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya owner yang dapat mengatur hari libur")
		return
	}
	var input service.AttendanceHolidayInput
	if err := ctx.ShouldBindJSON(&input); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, "Data hari libur tidak valid")
		return
	}
	holiday, err := c.svc.AddHoliday(ctx.GetString("outlet_id"), input)
	if err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusCreated, "Hari libur ditambahkan", holiday)
}

func (c *AttendanceController) DeleteHoliday(ctx *gin.Context) {
	if t := ctx.GetString("actor_type"); t != "user" && t != "admin" {
		utils.ErrorResponse(ctx, http.StatusForbidden, "Hanya owner yang dapat mengatur hari libur")
		return
	}
	if err := c.svc.DeleteHoliday(ctx.GetString("outlet_id"), ctx.Param("id")); err != nil {
		utils.ErrorResponse(ctx, http.StatusBadRequest, err.Error())
		return
	}
	utils.JSONResponse(ctx, http.StatusOK, "Hari libur dihapus", nil)
}
