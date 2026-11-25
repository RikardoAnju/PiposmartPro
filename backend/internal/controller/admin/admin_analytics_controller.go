package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	adminSvc "github.com/RikardoAnju/PiposmartPro/internal/service/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type AdminAnalyticsController struct {
	svc *adminSvc.AdminAnalyticsService
}

func NewAdminAnalyticsController(svc *adminSvc.AdminAnalyticsService) *AdminAnalyticsController {
	return &AdminAnalyticsController{svc: svc}
}

func parseDays(c *gin.Context, defaultDays int) int {
	days, err := strconv.Atoi(c.DefaultQuery("days", strconv.Itoa(defaultDays)))
	if err != nil || days < 1 || days > 365 {
		return defaultDays
	}
	return days
}

func parseAnalyticsRange(c *gin.Context, defaultDays int) (adminSvc.AnalyticsDateRange, error) {
	startDate := c.Query("start_date")
	endDate := c.Query("end_date")
	now := time.Now()

	if startDate != "" || endDate != "" {
		if startDate == "" {
			startDate = endDate
		}
		if endDate == "" {
			endDate = startDate
		}

		start, err := time.ParseInLocation("2006-01-02", startDate, now.Location())
		if err != nil {
			return adminSvc.AnalyticsDateRange{}, err
		}

		end, err := time.ParseInLocation("2006-01-02", endDate, now.Location())
		if err != nil {
			return adminSvc.AnalyticsDateRange{}, err
		}

		return adminSvc.NewAnalyticsDateRange(start, end), nil
	}

	days := parseDays(c, defaultDays)
	end := now
	start := now.AddDate(0, 0, -(days - 1))
	return adminSvc.NewAnalyticsDateRange(start, end), nil
}

func analyticsCacheKey(prefix string, dateRange adminSvc.AnalyticsDateRange) string {
	return fmt.Sprintf("admin:analytics:%s:%s:%s", prefix, dateRange.StartSQL(), dateRange.EndSQL())
}

// GET /admin/analytics/revenue?days=30
func (ctrl *AdminAnalyticsController) GetRevenue(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("revenue:v1", dateRange)
	var cached adminSvc.RevenueSummary
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Revenue stream", cached)
		return
	}

	data, err := ctrl.svc.GetRevenueStream(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data revenue: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 45*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Revenue stream", data)
}

// GET /admin/analytics/growth?days=30
func (ctrl *AdminAnalyticsController) GetGrowth(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("growth:v1", dateRange)
	var cached adminSvc.GrowthSummary
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Growth metrics", cached)
		return
	}

	data, err := ctrl.svc.GetGrowthMetrics(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data growth: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 45*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Growth metrics", data)
}

// GET /admin/analytics/geography
func (ctrl *AdminAnalyticsController) GetGeography(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("geography:v1", dateRange)
	var cached adminSvc.GeoSummary
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Geographic breakdown", cached)
		return
	}

	data, err := ctrl.svc.GetGeographicBreakdown(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data geografis: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 60*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Geographic breakdown", data)
}

// GET /admin/analytics/activity?days=30
func (ctrl *AdminAnalyticsController) GetActivity(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("activity:v1", dateRange)
	var cached adminSvc.ActivitySummary
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Platform activity", cached)
		return
	}

	data, err := ctrl.svc.GetPlatformActivity(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data activity: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 30*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Platform activity", data)
}

// GET /admin/analytics/referral?days=30
func (ctrl *AdminAnalyticsController) GetReferral(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("referral:v1", dateRange)
	var cached adminSvc.ReferralSummary
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Referral economy", cached)
		return
	}

	data, err := ctrl.svc.GetReferralEconomy(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data referral: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 45*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Referral economy", data)
}

// GET /admin/analytics/referral-topup-details?days=30
func (ctrl *AdminAnalyticsController) GetReferralTopupDetails(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("referral-topup-details:v1", dateRange)
	var cached []adminSvc.TopupExportRow
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Referral topup details", cached)
		return
	}

	data, err := ctrl.svc.GetReferralTopupDetails(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data detail top up: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 45*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Referral topup details", data)
}

// GET /admin/analytics/inactive-owners?days=30
func (ctrl *AdminAnalyticsController) GetInactiveOwners(c *gin.Context) {
	dateRange, err := parseAnalyticsRange(c, 30)
	if err != nil {
		utils.ErrorResponse(c, http.StatusBadRequest, "Format tanggal tidak valid. Gunakan YYYY-MM-DD")
		return
	}

	cacheKey := analyticsCacheKey("inactive-owners:v1", dateRange)
	var cached adminSvc.InactiveOwnerSummary
	if database.GetCache(cacheKey, &cached) {
		utils.JSONResponse(c, http.StatusOK, "Inactive owners", cached)
		return
	}

	data, err := ctrl.svc.GetInactiveOwners(dateRange)
	if err != nil {
		utils.ErrorResponse(c, http.StatusInternalServerError, "Gagal mengambil data inactive owners: "+err.Error())
		return
	}
	database.SetCache(cacheKey, data, 45*time.Second)
	utils.JSONResponse(c, http.StatusOK, "Inactive owners", data)
}
