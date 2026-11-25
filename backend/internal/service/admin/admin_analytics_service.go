package admin

import (
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

const analyticsDateLayout = "2006-01-02"
const analyticsMaxDays = 365

var analyticsDateSequenceSQL = buildAnalyticsDateSequenceSQL(analyticsMaxDays)

type AdminAnalyticsService struct {
	db *gorm.DB
}

type AnalyticsDateRange struct {
	Start time.Time
	End   time.Time
}

func NewAdminAnalyticsService(db *gorm.DB) *AdminAnalyticsService {
	return &AdminAnalyticsService{db: db}
}

func NewAnalyticsDateRange(start, end time.Time) AnalyticsDateRange {
	start = normalizeAnalyticsDate(start)
	end = normalizeAnalyticsDate(end)
	if end.Before(start) {
		start, end = end, start
	}
	return AnalyticsDateRange{Start: start, End: end}
}

func normalizeAnalyticsDate(value time.Time) time.Time {
	year, month, day := value.Date()
	return time.Date(year, month, day, 0, 0, 0, 0, value.Location())
}

func (r AnalyticsDateRange) Days() int {
	return int(r.End.Sub(r.Start).Hours()/24) + 1
}

func (r AnalyticsDateRange) StartSQL() string {
	return r.Start.Format(analyticsDateLayout)
}

func (r AnalyticsDateRange) EndSQL() string {
	return r.End.Format(analyticsDateLayout)
}

func buildAnalyticsDateSequenceSQL(maxDays int) string {
	parts := make([]string, maxDays)
	for i := 0; i < maxDays; i++ {
		parts[i] = fmt.Sprintf("SELECT %d AS seq", i)
	}
	return strings.Join(parts, " UNION ")
}

func analyticsDateSeriesSubquery() string {
	return fmt.Sprintf(`
		SELECT DATE(DATE_ADD(?, INTERVAL seq DAY)) AS date
		FROM (%s) n
		WHERE seq < ?`, analyticsDateSequenceSQL)
}

// ────────────────────────────────────────────────────────────
// 1. REVENUE STREAM
// ────────────────────────────────────────────────────────────

type RevenuePoint struct {
	Date         string  `json:"date" gorm:"column:date"`
	TopupRevenue float64 `json:"topup_revenue" gorm:"column:topup_revenue"`
	AddonRevenue float64 `json:"addon_revenue" gorm:"column:addon_revenue"`
	TotalRevenue float64 `json:"total_revenue" gorm:"column:total_revenue"`
}

type RevenueSummary struct {
	TotalRevenue    float64        `json:"total_revenue"`
	TopupRevenue    float64        `json:"topup_revenue"`
	AddonRevenue    float64        `json:"addon_revenue"`
	AvgDailyRevenue float64        `json:"avg_daily_revenue"`
	Series          []RevenuePoint `json:"series"`

	// Retensi (all-time, tidak tergantung rentang tanggal): pembagian outlet
	// yang pernah top up SUKSES menjadi pelanggan baru (tepat 1x) vs repeat
	// (>=2x). RepeatRate = repeat / total outlet berbayar.
	PaidOutlets       int     `json:"paid_outlets"`
	NewPaidOutlets    int     `json:"new_paid_outlets"`
	RepeatPaidOutlets int     `json:"repeat_paid_outlets"`
	RepeatRate        float64 `json:"repeat_rate"`
}

func (s *AdminAnalyticsService) GetRevenueStream(dateRange AnalyticsDateRange) (RevenueSummary, error) {
	var series []RevenuePoint

	query := fmt.Sprintf(`
		SELECT
			dates.date,
			COALESCE(t.topup_revenue, 0) AS topup_revenue,
			COALESCE(a.addon_revenue, 0) AS addon_revenue,
			COALESCE(t.topup_revenue, 0) + COALESCE(a.addon_revenue, 0) AS total_revenue
		FROM (%s) dates
		LEFT JOIN (
			SELECT DATE(tk_created) AS d, SUM(tk_total) AS topup_revenue
			FROM ac_top_koin
			WHERE tk_status IN ('success', 'completed')
			  AND DATE(tk_created) BETWEEN ? AND ?
			GROUP BY DATE(tk_created)
		) t ON t.d = dates.date
		LEFT JOIN (
			SELECT DATE(ha_created) AS d, SUM(ha_total) AS addon_revenue
			FROM ac_transaksi_addons
			WHERE ha_status = 'SUCCESS'
			  AND DATE(ha_created) BETWEEN ? AND ?
			GROUP BY DATE(ha_created)
		) a ON a.d = dates.date
		ORDER BY dates.date ASC`, analyticsDateSeriesSubquery())

	err := s.db.Raw(
		query,
		dateRange.StartSQL(), dateRange.Days(),
		dateRange.StartSQL(), dateRange.EndSQL(),
		dateRange.StartSQL(), dateRange.EndSQL(),
	).Scan(&series).Error
	if err != nil {
		return RevenueSummary{}, err
	}

	var totalTopup, totalAddon float64
	for _, point := range series {
		totalTopup += point.TopupRevenue
		totalAddon += point.AddonRevenue
	}

	total := totalTopup + totalAddon
	avg := 0.0
	if dateRange.Days() > 0 {
		avg = total / float64(dateRange.Days())
	}

	// Metrik retensi all-time: outlet berbayar dibagi baru (1x) vs repeat (>=2x).
	var retensi struct {
		PaidOutlets int `gorm:"column:paid_outlets"`
		NewPaid     int `gorm:"column:new_paid"`
		RepeatPaid  int `gorm:"column:repeat_paid"`
	}
	s.db.Raw(`
		SELECT
			COUNT(*) AS paid_outlets,
			SUM(CASE WHEN c = 1 THEN 1 ELSE 0 END) AS new_paid,
			SUM(CASE WHEN c >= 2 THEN 1 ELSE 0 END) AS repeat_paid
		FROM (
			SELECT tk_outlet, COUNT(*) AS c
			FROM ac_top_koin
			WHERE tk_status IN ('success', 'completed')
			GROUP BY tk_outlet
		) x`).Scan(&retensi)

	repeatRate := 0.0
	if retensi.PaidOutlets > 0 {
		repeatRate = float64(retensi.RepeatPaid) / float64(retensi.PaidOutlets)
	}

	return RevenueSummary{
		TotalRevenue:      total,
		TopupRevenue:      totalTopup,
		AddonRevenue:      totalAddon,
		AvgDailyRevenue:   avg,
		Series:            series,
		PaidOutlets:       retensi.PaidOutlets,
		NewPaidOutlets:    retensi.NewPaid,
		RepeatPaidOutlets: retensi.RepeatPaid,
		RepeatRate:        repeatRate,
	}, nil
}

// ────────────────────────────────────────────────────────────
// 2. GROWTH METRICS
// ────────────────────────────────────────────────────────────

type GrowthPoint struct {
	Date           string `json:"date" gorm:"column:date"`
	NewOwners      int    `json:"new_owners" gorm:"column:new_owners"`
	OrganicOwners  int    `json:"organic_owners" gorm:"column:organic_owners"`
	ReferralOwners int    `json:"referral_owners" gorm:"column:referral_owners"`
	NewOutlets     int    `json:"new_outlets" gorm:"column:new_outlets"`
}

type GrowthSummary struct {
	TotalNewOwners      int           `json:"total_new_owners"`
	TotalOrganicOwners  int           `json:"total_organic_owners"`
	TotalReferralOwners int           `json:"total_referral_owners"`
	TotalNewOutlets     int           `json:"total_new_outlets"`
	RecentNewOwners     int           `json:"recent_new_owners"`
	TrialOutlets        int           `json:"trial_outlets"`
	ProOutlets          int           `json:"pro_outlets"`
	ExpiredOutlets      int           `json:"expired_outlets"`
	ConversionRate      float64       `json:"conversion_rate"`
	Series              []GrowthPoint `json:"series"`
}

func (s *AdminAnalyticsService) GetGrowthMetrics(dateRange AnalyticsDateRange) (GrowthSummary, error) {
	var series []GrowthPoint

	query := fmt.Sprintf(`
		SELECT
			dates.date,
			COALESCE(u.new_owners, 0) AS new_owners,
			COALESCE(u.organic_owners, 0) AS organic_owners,
			COALESCE(u.referral_owners, 0) AS referral_owners,
			COALESCE(o.new_outlets, 0) AS new_outlets
		FROM (%s) dates
		LEFT JOIN (
			SELECT
				DATE(usr_created) AS d,
				COUNT(*) AS new_owners,
				SUM(CASE WHEN usr_referred_by IS NULL THEN 1 ELSE 0 END) AS organic_owners,
				SUM(CASE WHEN usr_referred_by IS NOT NULL THEN 1 ELSE 0 END) AS referral_owners
			FROM ac_user
			WHERE DATE(usr_created) BETWEEN ? AND ?
			GROUP BY DATE(usr_created)
		) u ON u.d = dates.date
		LEFT JOIN (
			SELECT DATE(ot_created) AS d, COUNT(*) AS new_outlets
			FROM ac_outlet
			WHERE DATE(ot_created) BETWEEN ? AND ?
			GROUP BY DATE(ot_created)
		) o ON o.d = dates.date
		ORDER BY dates.date ASC`, analyticsDateSeriesSubquery())

	err := s.db.Raw(
		query,
		dateRange.StartSQL(), dateRange.Days(),
		dateRange.StartSQL(), dateRange.EndSQL(),
		dateRange.StartSQL(), dateRange.EndSQL(),
	).Scan(&series).Error
	if err != nil {
		return GrowthSummary{}, err
	}

	var totalOwners, totalOrganic, totalReferral, totalOutlets int
	for _, point := range series {
		totalOwners += point.NewOwners
		totalOrganic += point.OrganicOwners
		totalReferral += point.ReferralOwners
		totalOutlets += point.NewOutlets
	}

	var trialCount, proCount, expiredCount int64
	s.db.Raw(`SELECT
		SUM(CASE WHEN ot_activated_at IS NOT NULL THEN 1 ELSE 0 END) as pro,
		SUM(CASE WHEN ot_activated_at IS NULL AND ot_trial_at > NOW() THEN 1 ELSE 0 END) as trial,
		SUM(CASE WHEN ot_activated_at IS NULL AND ot_trial_at <= NOW() THEN 1 ELSE 0 END) as expired
		FROM ac_outlet`).Row().Scan(&proCount, &trialCount, &expiredCount)

	totalSubscriptionOutlets := proCount + trialCount + expiredCount
	conversionRate := 0.0
	if totalSubscriptionOutlets > 0 {
		conversionRate = float64(proCount) / float64(totalSubscriptionOutlets) * 100
	}

	var recentNewOwners int64
	s.db.Raw(`
		SELECT COUNT(*)
		FROM ac_user
		WHERE DATE(usr_created) BETWEEN GREATEST(?, DATE_SUB(?, INTERVAL 2 DAY)) AND ?`,
		dateRange.StartSQL(), dateRange.EndSQL(), dateRange.EndSQL(),
	).Scan(&recentNewOwners)

	return GrowthSummary{
		TotalNewOwners:      totalOwners,
		TotalOrganicOwners:  totalOrganic,
		TotalReferralOwners: totalReferral,
		TotalNewOutlets:     totalOutlets,
		RecentNewOwners:     int(recentNewOwners),
		TrialOutlets:        int(trialCount),
		ProOutlets:          int(proCount),
		ExpiredOutlets:      int(expiredCount),
		ConversionRate:      conversionRate,
		Series:              series,
	}, nil
}

// ────────────────────────────────────────────────────────────
// 3. GEOGRAPHIC BREAKDOWN
// ────────────────────────────────────────────────────────────

type GeoPoint struct {
	Name       string  `json:"name" gorm:"column:name"`
	Count      int     `json:"count" gorm:"column:count"`
	Percentage float64 `json:"percentage" gorm:"column:percentage"`
}

type GeoSummary struct {
	TopProvinsi  []GeoPoint `json:"top_provinsi"`
	TopKota      []GeoPoint `json:"top_kota"`
	TotalOutlets int        `json:"total_outlets"`
}

var provinsiNames = map[string]string{
	"11": "Aceh", "12": "Sumatera Utara", "13": "Sumatera Barat",
	"14": "Riau", "15": "Jambi", "16": "Sumatera Selatan",
	"17": "Bengkulu", "18": "Lampung", "19": "Kep. Bangka Belitung",
	"21": "Kep. Riau", "31": "DKI Jakarta", "32": "Jawa Barat",
	"33": "Jawa Tengah", "34": "DI Yogyakarta", "35": "Jawa Timur",
	"36": "Banten", "51": "Bali", "52": "Nusa Tenggara Barat",
	"53": "Nusa Tenggara Timur", "61": "Kalimantan Barat", "62": "Kalimantan Tengah",
	"63": "Kalimantan Selatan", "64": "Kalimantan Timur", "65": "Kalimantan Utara",
	"71": "Sulawesi Utara", "72": "Sulawesi Tengah", "73": "Sulawesi Selatan",
	"74": "Sulawesi Tenggara", "75": "Gorontalo", "76": "Sulawesi Barat",
	"81": "Maluku", "82": "Maluku Utara", "91": "Papua Barat", "94": "Papua",
}

func resolveProvinsiName(code string) string {
	if name, ok := provinsiNames[code]; ok {
		return name
	}
	if len(code) >= 2 {
		if name, ok := provinsiNames[code[:2]]; ok {
			return name
		}
	}
	if code == "" || code == "Tidak Diketahui" {
		return "Tidak Diketahui"
	}
	return code
}

func (s *AdminAnalyticsService) GetGeographicBreakdown(dateRange AnalyticsDateRange) (GeoSummary, error) {
	var topProvinsiRaw []GeoPoint
	var topKota []GeoPoint
	var totalOutlets int64

	s.db.Raw(`SELECT COUNT(*) FROM ac_outlet WHERE DATE(ot_created) BETWEEN ? AND ?`, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&totalOutlets)
	if totalOutlets == 0 {
		return GeoSummary{
			TopProvinsi:  []GeoPoint{},
			TopKota:      []GeoPoint{},
			TotalOutlets: 0,
		}, nil
	}

	s.db.Raw(`
		SELECT
			COALESCE(ot_provinsi, '') AS name,
			COUNT(*) AS count,
			ROUND(COUNT(*) * 100.0 / ?, 1) AS percentage
		FROM ac_outlet
		WHERE DATE(ot_created) BETWEEN ? AND ?
		GROUP BY ot_provinsi
		ORDER BY count DESC
		LIMIT 15`, totalOutlets, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&topProvinsiRaw)

	topProvinsi := make([]GeoPoint, 0, len(topProvinsiRaw))
	for _, point := range topProvinsiRaw {
		topProvinsi = append(topProvinsi, GeoPoint{
			Name:       resolveProvinsiName(point.Name),
			Count:      point.Count,
			Percentage: point.Percentage,
		})
	}

	s.db.Raw(`
		SELECT
			COALESCE(ot_kota, 'Tidak Diketahui') AS name,
			COUNT(*) AS count,
			ROUND(COUNT(*) * 100.0 / ?, 1) AS percentage
		FROM ac_outlet
		WHERE DATE(ot_created) BETWEEN ? AND ?
		GROUP BY ot_kota
		ORDER BY count DESC
		LIMIT 10`, totalOutlets, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&topKota)

	return GeoSummary{
		TopProvinsi:  topProvinsi,
		TopKota:      topKota,
		TotalOutlets: int(totalOutlets),
	}, nil
}

// ────────────────────────────────────────────────────────────
// 4. PLATFORM ACTIVITY
// ────────────────────────────────────────────────────────────

type ActivityPoint struct {
	Date          string  `json:"date" gorm:"column:date"`
	ActiveOutlets int     `json:"active_outlets" gorm:"column:active_outlets"`
	TotalOrders   int     `json:"total_orders" gorm:"column:total_orders"`
	GMV           float64 `json:"gmv" gorm:"column:gmv"`
}

type ActivitySummary struct {
	TodayActiveOutlets int             `json:"today_active_outlets"`
	TodayOrders        int             `json:"today_orders"`
	TodayGMV           float64         `json:"today_gmv"`
	TotalWorkforce     int             `json:"total_workforce"`
	TotalCustomers     int             `json:"total_customers"`
	AvgOrdersPerOutlet float64         `json:"avg_orders_per_outlet"`
	Series             []ActivityPoint `json:"series"`
}

func (s *AdminAnalyticsService) GetPlatformActivity(dateRange AnalyticsDateRange) (ActivitySummary, error) {
	var series []ActivityPoint

	query := fmt.Sprintf(`
		SELECT
			dates.date,
			COALESCE(act.active_outlets, 0) AS active_outlets,
			COALESCE(act.total_orders, 0) AS total_orders,
			COALESCE(act.gmv, 0) AS gmv
		FROM (%s) dates
		LEFT JOIN (
			SELECT
				DATE(tr_created) AS d,
				COUNT(DISTINCT tr_outlet) AS active_outlets,
				COUNT(*) AS total_orders,
				SUM(tr_total) AS gmv
			FROM ac_transaksi
			WHERE DATE(tr_created) BETWEEN ? AND ?
			GROUP BY DATE(tr_created)
		) act ON act.d = dates.date
		ORDER BY dates.date ASC`, analyticsDateSeriesSubquery())

	err := s.db.Raw(
		query,
		dateRange.StartSQL(), dateRange.Days(),
		dateRange.StartSQL(), dateRange.EndSQL(),
	).Scan(&series).Error
	if err != nil {
		return ActivitySummary{}, err
	}

	var periodActiveOutlets int64
	var periodOrders int64
	var periodGMV float64
	s.db.Raw(`SELECT COUNT(DISTINCT tr_outlet) FROM ac_transaksi WHERE DATE(tr_created) = ?`, dateRange.EndSQL()).Scan(&periodActiveOutlets)
	s.db.Raw(`SELECT COUNT(*) FROM ac_transaksi WHERE DATE(tr_created) = ?`, dateRange.EndSQL()).Scan(&periodOrders)
	s.db.Raw(`SELECT COALESCE(SUM(tr_total), 0) FROM ac_transaksi WHERE DATE(tr_created) = ?`, dateRange.EndSQL()).Scan(&periodGMV)

	var totalWorkforce int64
	var totalCustomers int64
	s.db.Raw(`SELECT COUNT(*) FROM ac_pegawai WHERE pg_status = 1`).Scan(&totalWorkforce)
	s.db.Raw(`SELECT COUNT(DISTINCT pl_id) FROM ac_pelanggan`).Scan(&totalCustomers)

	avgOrders := 0.0
	if periodActiveOutlets > 0 {
		avgOrders = float64(periodOrders) / float64(periodActiveOutlets)
	}

	return ActivitySummary{
		TodayActiveOutlets: int(periodActiveOutlets),
		TodayOrders:        int(periodOrders),
		TodayGMV:           periodGMV,
		TotalWorkforce:     int(totalWorkforce),
		TotalCustomers:     int(totalCustomers),
		AvgOrdersPerOutlet: avgOrders,
		Series:             series,
	}, nil
}

// ────────────────────────────────────────────────────────────
// 5. REFERRAL ECONOMY
// ────────────────────────────────────────────────────────────

type TopReferrer struct {
	Name        string `json:"name" gorm:"column:name"`
	Email       string `json:"email" gorm:"column:email"`
	Recruits    int    `json:"recruits" gorm:"column:recruits"`
	TotalReward int    `json:"total_reward" gorm:"column:total_reward"`
}

type ReferralSummary struct {
	TotalRewardDistributed  int           `json:"total_reward_distributed"`
	TotalReferralUsers      int           `json:"total_referral_users"`
	PendingPayouts          int           `json:"pending_payouts"`
	PendingPayoutAmount     int           `json:"pending_payout_amount"`
	ReferralTopupRevenue    int           `json:"referral_topup_revenue"`
	ReferralTopupOwners     int           `json:"referral_topup_owners"`
	NonReferralTopupRevenue int           `json:"non_referral_topup_revenue"`
	NonReferralTopupOwners  int           `json:"non_referral_topup_owners"`
	TotalTopupRevenue       int           `json:"total_topup_revenue"`
	TopReferrers            []TopReferrer `json:"top_referrers"`
}

func (s *AdminAnalyticsService) GetReferralEconomy(dateRange AnalyticsDateRange) (ReferralSummary, error) {
	var totalReward int64
	var totalReferralUsers int64
	var pendingPayouts int64
	var pendingAmount int64
	var topReferrers []TopReferrer
	var topupBreakdown struct {
		ReferralRevenue    float64 `gorm:"column:referral_revenue"`
		ReferralOwners     int64   `gorm:"column:referral_owners"`
		NonReferralRevenue float64 `gorm:"column:non_referral_revenue"`
		NonReferralOwners  int64   `gorm:"column:non_referral_owners"`
		TotalRevenue       float64 `gorm:"column:total_revenue"`
	}

	s.db.Raw(`
		SELECT COALESCE(SUM(rr_reward_amount), 0)
		FROM ac_referral_rewards
		WHERE DATE(rr_created) BETWEEN ? AND ?`, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&totalReward)

	s.db.Raw(`
		SELECT COUNT(*)
		FROM ac_user
		WHERE usr_referred_by IS NOT NULL
		  AND DATE(usr_created) BETWEEN ? AND ?`, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&totalReferralUsers)

	s.db.Raw(`
		SELECT COUNT(*), COALESCE(SUM(rp_amount), 0)
		FROM ac_referral_payout_requests
		WHERE rp_status = 'pending'
		  AND DATE(rp_created) BETWEEN ? AND ?`, dateRange.StartSQL(), dateRange.EndSQL()).Row().Scan(&pendingPayouts, &pendingAmount)

	if err := s.db.Raw(`
		SELECT
			COALESCE(SUM(CASE WHEN u.usr_referred_by IS NOT NULL THEN t.tk_total ELSE 0 END), 0) as referral_revenue,
			COUNT(DISTINCT CASE WHEN u.usr_referred_by IS NOT NULL THEN u.usr_id END) as referral_owners,
			COALESCE(SUM(CASE WHEN u.usr_referred_by IS NULL THEN t.tk_total ELSE 0 END), 0) as non_referral_revenue,
			COUNT(DISTINCT CASE WHEN u.usr_referred_by IS NULL THEN u.usr_id END) as non_referral_owners,
			COALESCE(SUM(t.tk_total), 0) as total_revenue
		FROM ac_top_koin t
		JOIN ac_outlet o ON t.tk_outlet = o.ot_id
		JOIN ac_user u ON o.ot_user = u.usr_id
		WHERE t.tk_status IN ('success', 'completed')
		  AND DATE(t.tk_created) BETWEEN ? AND ?`, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&topupBreakdown).Error; err != nil {
		return ReferralSummary{}, err
	}

	s.db.Raw(`
		SELECT
			u.usr_nama AS name,
			u.usr_email AS email,
			COALESCE(rc.recruits, 0) AS recruits,
			COALESCE(rr.total_reward, 0) AS total_reward
		FROM ac_user u
		LEFT JOIN (
			SELECT usr_referred_by AS referrer_id, COUNT(*) AS recruits
			FROM ac_user
			WHERE usr_referred_by IS NOT NULL
			  AND DATE(usr_created) BETWEEN ? AND ?
			GROUP BY usr_referred_by
		) rc ON rc.referrer_id = u.usr_id
		LEFT JOIN (
			SELECT rr_referrer_user AS referrer_id, SUM(rr_reward_amount) AS total_reward
			FROM ac_referral_rewards
			WHERE DATE(rr_created) BETWEEN ? AND ?
			GROUP BY rr_referrer_user
		) rr ON rr.referrer_id = u.usr_id
		WHERE COALESCE(rc.recruits, 0) > 0 OR COALESCE(rr.total_reward, 0) > 0
		ORDER BY recruits DESC, total_reward DESC
		LIMIT 10`,
		dateRange.StartSQL(), dateRange.EndSQL(),
		dateRange.StartSQL(), dateRange.EndSQL(),
	).Scan(&topReferrers)

	return ReferralSummary{
		TotalRewardDistributed:  int(totalReward),
		TotalReferralUsers:      int(totalReferralUsers),
		PendingPayouts:          int(pendingPayouts),
		PendingPayoutAmount:     int(pendingAmount),
		ReferralTopupRevenue:    int(topupBreakdown.ReferralRevenue),
		ReferralTopupOwners:     int(topupBreakdown.ReferralOwners),
		NonReferralTopupRevenue: int(topupBreakdown.NonReferralRevenue),
		NonReferralTopupOwners:  int(topupBreakdown.NonReferralOwners),
		TotalTopupRevenue:       int(topupBreakdown.TotalRevenue),
		TopReferrers:            topReferrers,
	}, nil
}

type TopupExportRow struct {
	Category         string  `json:"category" gorm:"column:category"`
	OwnerCode        string  `json:"owner_code" gorm:"column:owner_code"`
	OwnerName        string  `json:"owner_name" gorm:"column:owner_name"`
	TotalOutlets     int     `json:"total_outlets" gorm:"column:total_outlets"`
	RegistrationDate string  `json:"registration_date" gorm:"column:registration_date"`
	TotalTopup       float64 `json:"total_topup" gorm:"column:total_topup"`
	AvgTopup         float64 `json:"avg_topup" gorm:"column:avg_topup"`
	ReferrerName     *string `json:"referrer_name" gorm:"column:referrer_name"`
	ReferrerCode     *string `json:"referrer_code" gorm:"column:referrer_code"`
	ReferralCode     *string `json:"referral_code" gorm:"column:referral_code"`
}

func (s *AdminAnalyticsService) GetReferralTopupDetails(dateRange AnalyticsDateRange) ([]TopupExportRow, error) {
	var results []TopupExportRow

	query := `
		SELECT
			CASE WHEN u.usr_referred_by IS NOT NULL THEN 'Referral' ELSE 'Non Referral' END as category,
			CAST(u.usr_id AS CHAR) as owner_code,
			u.usr_nama as owner_name,
			(SELECT COUNT(*) FROM ac_outlet o2 WHERE o2.ot_user = u.usr_id) as total_outlets,
			DATE_FORMAT(u.usr_created, '%Y-%m-%d') as registration_date,
			SUM(t.tk_total) as total_topup,
			AVG(t.tk_total) as avg_topup,
			ref.usr_nama as referrer_name,
			CAST(ref.usr_id AS CHAR) as referrer_code,
			u.usr_referral_code as referral_code
		FROM ac_top_koin t
		JOIN ac_outlet o ON t.tk_outlet = o.ot_id
		JOIN ac_user u ON o.ot_user = u.usr_id
		LEFT JOIN ac_user ref ON u.usr_referred_by = ref.usr_id
		WHERE t.tk_status IN ('success', 'completed')
		  AND DATE(t.tk_created) BETWEEN ? AND ?
		GROUP BY u.usr_id, u.usr_nama, u.usr_created, ref.usr_nama, ref.usr_id, u.usr_referral_code
		ORDER BY category DESC, total_topup DESC`

	err := s.db.Raw(query, dateRange.StartSQL(), dateRange.EndSQL()).Scan(&results).Error
	if err != nil {
		return nil, err
	}

	return results, nil
}

// ────────────────────────────────────────────────────────────
// 6. INACTIVE OWNERS
// ────────────────────────────────────────────────────────────

type InactiveOwner struct {
	ID                  string  `json:"id" gorm:"column:id"`
	Name                string  `json:"name" gorm:"column:name"`
	Email               string  `json:"email" gorm:"column:email"`
	TotalOutlets        int     `json:"total_outlets" gorm:"column:total_outlets"`
	LastTransactionDate *string `json:"last_transaction_date" gorm:"column:last_transaction_date"`
}

type InactiveOwnerSummary struct {
	Days   int             `json:"days"`
	Total  int             `json:"total"`
	Owners []InactiveOwner `json:"owners"`
}

func (s *AdminAnalyticsService) GetInactiveOwners(dateRange AnalyticsDateRange) (InactiveOwnerSummary, error) {
	var owners []InactiveOwner

	query := `
		SELECT
			u.usr_id as id,
			u.usr_nama as name,
			u.usr_email as email,
			COUNT(DISTINCT o.ot_id) as total_outlets,
			MAX(t.tr_created) as last_transaction_date
		FROM ac_user u
		LEFT JOIN ac_outlet o ON o.ot_user = u.usr_id
		LEFT JOIN ac_transaksi t ON t.tr_outlet = o.ot_id AND DATE(t.tr_created) <= ?
		GROUP BY u.usr_id, u.usr_nama, u.usr_email
		HAVING (MAX(t.tr_created) IS NULL OR DATE(MAX(t.tr_created)) < ?)
		ORDER BY last_transaction_date ASC
		LIMIT 100`

	err := s.db.Raw(query, dateRange.EndSQL(), dateRange.StartSQL()).Scan(&owners).Error
	if err != nil {
		return InactiveOwnerSummary{}, err
	}

	return InactiveOwnerSummary{
		Days:   dateRange.Days(),
		Total:  len(owners),
		Owners: owners,
	}, nil
}
