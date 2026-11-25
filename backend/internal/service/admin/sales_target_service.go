package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"math"
	"sort"
	"strings"
	"time"

	"gorm.io/gorm"
)

// AdminSalesTargetService menghitung "peluang closing" (lead score) untuk
// outlet yang BELUM pernah top up sukses, murni dari sinyal pemakaian live
// (jumlah transaksi, recency, sisa koin, momentum, plan). Read-only.
type AdminSalesTargetService struct {
	db *gorm.DB
}

func NewAdminSalesTargetService(db *gorm.DB) *AdminSalesTargetService {
	return &AdminSalesTargetService{db: db}
}

// baris mentah hasil query gabungan sinyal per outlet.
type salesTargetRow struct {
	OutletID    string     `json:"outlet_id"`
	OutletName  string     `json:"outlet_name"`
	OwnerID     int64      `json:"owner_id"`
	OwnerName   string     `json:"owner_name"`
	OwnerPhone  string     `json:"owner_phone"`
	OutletPhone string     `json:"outlet_phone"`
	LeadSource  string     `json:"lead_source"`
	City        string     `json:"city"`
	Plan        string     `json:"plan"`
	Koin        int        `json:"koin"`
	CreatedAt   *time.Time `json:"created_at"`
	TotalTx     int        `json:"total_tx"`
	Omzet       float64    `json:"omzet"`
	LastTxAt    *time.Time `json:"last_tx_at"`
	TxCount7d   int        `json:"tx_count_7d"`
	TxCount30d  int        `json:"tx_count_30d"`
}

// SalesTarget adalah baris hasil akhir yang dikirim ke admin panel.
type SalesTarget struct {
	salesTargetRow
	DaysSinceLastTx *int     `json:"days_since_last_tx"`
	Score           int      `json:"score"`
	Tier            string   `json:"tier"` // hot | warm | cold
	Reasons         []string `json:"reasons"`
	DataFlag        string   `json:"data_flag,omitempty"`
	// Status tindak-lanjut sales
	ContactStatus string     `json:"contact_status"`
	ContactNote   string     `json:"contact_note,omitempty"`
	ContactBy     string     `json:"contact_by,omitempty"`
	ContactAt     *time.Time `json:"contact_at,omitempty"`
}

// SalesTargetFilter menampung query params.
type SalesTargetFilter struct {
	Tier       string // hot|warm|cold|"" (semua)
	Channel    string // lead_source
	Search     string // nama outlet/owner
	OnlyActive bool   // hanya yang sudah transaksi (default true di controller)
	Limit      int
}

func (s *AdminSalesTargetService) GetSalesTargets(f SalesTargetFilter) (map[string]interface{}, error) {
	query := `
		SELECT
			o.ot_id                                   AS outlet_id,
			o.ot_nama                                 AS outlet_name,
			o.ot_user                                 AS owner_id,
			u.usr_nama                                AS owner_name,
			COALESCE(u.usr_nohp, '')                  AS owner_phone,
			COALESCE(o.ot_nohp, '')                   AS outlet_phone,
			COALESCE(u.usr_lead_source, '')           AS lead_source,
			COALESCE(o.ot_kota, '')                   AS city,
			CASE WHEN o.ot_activated_at IS NOT NULL THEN 'PRO' ELSE 'FREE' END AS plan,
			o.ot_koin                                 AS koin,
			o.ot_created                              AS created_at,
			COALESCE(tx.total_tx, 0)                  AS total_tx,
			COALESCE(tx.omzet, 0)                     AS omzet,
			tx.last_tx_at                             AS last_tx_at,
			COALESCE(tx.tx_count_7d, 0)               AS tx_count_7d,
			COALESCE(tx.tx_count_30d, 0)              AS tx_count_30d
		FROM ac_outlet o
		JOIN ac_user u ON u.usr_id = o.ot_user
		LEFT JOIN (
			SELECT
				tr_outlet,
				COUNT(*) AS total_tx,
				COALESCE(SUM(CASE WHEN tr_status_order <> 'Batal' THEN tr_total ELSE 0 END), 0) AS omzet,
				MAX(tr_created) AS last_tx_at,
				SUM(CASE WHEN tr_created >= NOW() - INTERVAL 7 DAY THEN 1 ELSE 0 END) AS tx_count_7d,
				SUM(CASE WHEN tr_created >= NOW() - INTERVAL 30 DAY THEN 1 ELSE 0 END) AS tx_count_30d
			FROM ac_transaksi
			GROUP BY tr_outlet
		) tx ON tx.tr_outlet = o.ot_id
		WHERE o.ot_id NOT IN (
			SELECT DISTINCT tk_outlet FROM ac_top_koin WHERE tk_status IN ('success','completed')
		)
	`

	var rows []salesTargetRow
	if err := s.db.Raw(query).Scan(&rows).Error; err != nil {
		return nil, err
	}

	// Ambil status kontak yang tersimpan, index by outlet.
	var statuses []model.SalesLeadStatus
	s.db.Find(&statuses)
	statusMap := make(map[string]model.SalesLeadStatus, len(statuses))
	for _, st := range statuses {
		statusMap[st.OutletID] = st
	}

	now := time.Now()
	targets := make([]SalesTarget, 0, len(rows))
	for _, r := range rows {
		t := SalesTarget{salesTargetRow: r}

		if r.LastTxAt != nil {
			d := int(math.Floor(now.Sub(*r.LastTxAt).Hours() / 24))
			if d < 0 {
				d = 0
			}
			t.DaysSinceLastTx = &d
		}

		t.Score, t.Tier, t.Reasons, t.DataFlag = scoreTarget(r, t.DaysSinceLastTx)

		if st, ok := statusMap[r.OutletID]; ok {
			t.ContactStatus = st.Status
			t.ContactNote = st.Note
			t.ContactBy = st.ByName
			at := st.UpdatedAt
			t.ContactAt = &at
		} else {
			t.ContactStatus = "baru"
		}

		targets = append(targets, t)
	}

	// Filter di memori (dataset kecil: outlet belum-topup).
	filtered := make([]SalesTarget, 0, len(targets))
	for _, t := range targets {
		if f.OnlyActive && t.TotalTx == 0 {
			continue
		}
		if f.Tier != "" && t.Tier != f.Tier {
			continue
		}
		if f.Channel != "" && !strings.EqualFold(t.LeadSource, f.Channel) {
			continue
		}
		if f.Search != "" {
			q := strings.ToLower(f.Search)
			if !strings.Contains(strings.ToLower(t.OutletName), q) &&
				!strings.Contains(strings.ToLower(t.OwnerName), q) {
				continue
			}
		}
		filtered = append(filtered, t)
	}

	// Urutkan: skor tertinggi dulu, lalu omzet.
	sort.SliceStable(filtered, func(i, j int) bool {
		if filtered[i].Score != filtered[j].Score {
			return filtered[i].Score > filtered[j].Score
		}
		return filtered[i].Omzet > filtered[j].Omzet
	})

	// Ringkasan tier dihitung dari hasil terfilter (kecuali filter tier itu sendiri).
	summarySrc := targets
	if f.OnlyActive || f.Channel != "" || f.Search != "" {
		summarySrc = make([]SalesTarget, 0, len(targets))
		for _, t := range targets {
			if f.OnlyActive && t.TotalTx == 0 {
				continue
			}
			if f.Channel != "" && !strings.EqualFold(t.LeadSource, f.Channel) {
				continue
			}
			if f.Search != "" {
				q := strings.ToLower(f.Search)
				if !strings.Contains(strings.ToLower(t.OutletName), q) &&
					!strings.Contains(strings.ToLower(t.OwnerName), q) {
					continue
				}
			}
			summarySrc = append(summarySrc, t)
		}
	}
	var hot, warm, cold int
	for _, t := range summarySrc {
		switch t.Tier {
		case "hot":
			hot++
		case "warm":
			warm++
		default:
			cold++
		}
	}

	if f.Limit > 0 && len(filtered) > f.Limit {
		filtered = filtered[:f.Limit]
	}

	return map[string]interface{}{
		"summary": map[string]interface{}{
			"total": len(summarySrc),
			"hot":   hot,
			"warm":  warm,
			"cold":  cold,
		},
		"data": filtered,
	}, nil
}

// scoreTarget menghitung skor 0-100 + tier + alasan untuk outlet belum-topup.
// Bobot: aktivitas 30, urgensi koin 25, recency 20, momentum 15, plan PRO 10.
func scoreTarget(r salesTargetRow, daysSince *int) (int, string, []string, string) {
	reasons := []string{}
	dataFlag := ""
	score := 0.0

	// 1. Aktivitas transaksi (maks 30) — makin sering pakai, makin serius.
	act := float64(r.TotalTx)
	if act > 20 {
		act = 20
	}
	score += act / 20.0 * 30.0
	if r.TotalTx > 0 {
		reasons = append(reasons, plural(r.TotalTx, "transaksi"))
	}

	// 2. Urgensi koin (maks 25) — hanya relevan bila outlet aktif.
	if r.TotalTx > 0 {
		switch {
		case r.Koin <= 5:
			score += 25
			reasons = append(reasons, "koin kritis (sisa "+itoa(r.Koin)+")")
		case r.Koin <= 10:
			score += 18
			reasons = append(reasons, "koin menipis (sisa "+itoa(r.Koin)+")")
		case r.Koin <= 15:
			score += 10
			reasons = append(reasons, "koin mulai menipis (sisa "+itoa(r.Koin)+")")
		default:
			score += 3
		}
	}

	// 3. Recency (maks 20).
	if daysSince != nil {
		d := *daysSince
		switch {
		case d <= 2:
			score += 20
			reasons = append(reasons, "aktif "+recencyLabel(d))
		case d <= 5:
			score += 14
			reasons = append(reasons, "aktif "+recencyLabel(d))
		case d <= 10:
			score += 7
		case d <= 20:
			score += 3
		default:
			reasons = append(reasons, "diam "+itoa(d)+" hari (perlu reaktivasi)")
		}
	}

	// 4. Momentum 7 hari (maks 15).
	switch {
	case r.TxCount7d >= 3:
		score += 15
		reasons = append(reasons, "momentum kuat ("+itoa(r.TxCount7d)+" trx/7hr)")
	case r.TxCount7d >= 1:
		score += 8
	}

	// 5. Plan PRO (10) — sudah bayar aktivasi = lebih berkomitmen.
	if r.Plan == "PRO" {
		score += 10
		reasons = append(reasons, "sudah PRO")
	}

	// Penalti kualitas data: transaksi ada tapi omzet 0 (kemungkinan salah input).
	if r.TotalTx > 0 && r.Omzet == 0 {
		score -= 5
		dataFlag = "omzet_nol"
	}
	// Penalti anomali omzet ekstrem (kemungkinan salah input nominal).
	if r.TotalTx > 0 && r.Omzet/float64(r.TotalTx) > 5000000 {
		dataFlag = "omzet_janggal"
	}

	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	final := int(math.Round(score))

	tier := "cold"
	if final >= 70 {
		tier = "hot"
	} else if final >= 40 {
		tier = "warm"
	}

	return final, tier, reasons, dataFlag
}

func recencyLabel(d int) string {
	switch d {
	case 0:
		return "hari ini"
	case 1:
		return "kemarin"
	default:
		return itoa(d) + " hari lalu"
	}
}

func plural(n int, unit string) string {
	return itoa(n) + " " + unit
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	buf := [20]byte{}
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		buf[i] = '-'
	}
	return string(buf[i:])
}

// SetContactStatus meng-upsert status tindak-lanjut sales untuk sebuah outlet.
// Nama admin di-resolve dari actor_id agar tercatat siapa yang menindaklanjuti.
func (s *AdminSalesTargetService) SetContactStatus(outletID, status, note, byID string) error {
	byName := ""
	if byID != "" {
		var adm model.Admin
		if err := s.db.Select("adm_nama").Where("adm_id = ?", byID).First(&adm).Error; err == nil {
			byName = adm.Nama
		}
	}
	rec := model.SalesLeadStatus{
		OutletID: outletID,
		Status:   status,
		Note:     note,
		ByID:     byID,
		ByName:   byName,
	}
	return s.db.Save(&rec).Error
}
