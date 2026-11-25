package admin

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type AccountDeletionRow struct {
	ID           uint      `json:"id" gorm:"column:ad_id"`
	ActorID      string    `json:"actor_id" gorm:"column:ad_actor_id"`
	ActorType    string    `json:"actor_type" gorm:"column:ad_actor_type"`
	ActorName    *string   `json:"actor_name" gorm:"column:actor_name"`
	ActorEmail   *string   `json:"actor_email" gorm:"column:actor_email"`
	ActorPhone   *string   `json:"actor_phone" gorm:"column:actor_phone"`
	Reason       string    `json:"reason" gorm:"column:ad_reason"`
	ReasonDetail *string   `json:"reason_detail" gorm:"column:ad_reason_detail"`
	SnapshotRaw  *string   `json:"-" gorm:"column:ad_snapshot"`
	Snapshot     any       `json:"snapshot,omitempty" gorm:"-"`
	CreatedAt    time.Time `json:"created_at" gorm:"column:ad_created"`
}

type AccountDeletionFilter struct {
	Search    string
	ActorType string
	Limit     int
}

type AdminAccountDeletionService interface {
	List(filter AccountDeletionFilter) ([]AccountDeletionRow, error)
}

type adminAccountDeletionService struct {
	db *gorm.DB
}

func NewAdminAccountDeletionService(db *gorm.DB) AdminAccountDeletionService {
	return &adminAccountDeletionService{db: db}
}

func normalizeDeletionQuery(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	return "%" + strings.ToLower(value) + "%"
}

func (s *adminAccountDeletionService) List(filter AccountDeletionFilter) ([]AccountDeletionRow, error) {
	var rows []AccountDeletionRow
	limit := filter.Limit
	if limit <= 0 || limit > 500 {
		limit = 200
	}

	query := `
		SELECT
			ad.id AS ad_id,
			ad.ad_actor_id,
			ad.ad_actor_type,
			COALESCE(NULLIF(ad.ad_actor_name, ''), u.usr_nama, pg.pg_nama, a.adm_nama) AS actor_name,
			COALESCE(NULLIF(ad.ad_actor_email, ''), u.usr_email, pg.pg_email, a.adm_email) AS actor_email,
			COALESCE(NULLIF(ad.ad_actor_phone, ''), u.usr_nohp, pg.pg_nohp, '') AS actor_phone,
			ad.ad_reason,
			ad.ad_reason_detail,
			ad.ad_snapshot,
			ad.ad_created
		FROM account_deletions ad
		LEFT JOIN ac_user u
			ON ad.ad_actor_type COLLATE utf8mb4_unicode_ci = 'user'
			AND CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci =
				ad.ad_actor_id COLLATE utf8mb4_unicode_ci
		LEFT JOIN ac_pegawai pg
			ON ad.ad_actor_type COLLATE utf8mb4_unicode_ci = 'pegawai'
			AND pg.pg_id COLLATE utf8mb4_unicode_ci =
				ad.ad_actor_id COLLATE utf8mb4_unicode_ci
		LEFT JOIN ac_admin a
			ON ad.ad_actor_type COLLATE utf8mb4_unicode_ci = 'admin'
			AND a.adm_id COLLATE utf8mb4_unicode_ci =
				ad.ad_actor_id COLLATE utf8mb4_unicode_ci
		WHERE 1=1
	`
	args := make([]interface{}, 0, 6)

	if q := normalizeDeletionQuery(filter.Search); q != "" {
		query += `
			AND (
				LOWER(ad.ad_actor_id) LIKE ? OR
				LOWER(ad.ad_actor_type) LIKE ? OR
				LOWER(ad.ad_reason) LIKE ? OR
				LOWER(COALESCE(ad.ad_reason_detail, '')) LIKE ? OR
				LOWER(COALESCE(NULLIF(ad.ad_actor_name, ''), u.usr_nama, pg.pg_nama, a.adm_nama, '')) LIKE ? OR
				LOWER(COALESCE(NULLIF(ad.ad_actor_email, ''), u.usr_email, pg.pg_email, a.adm_email, '')) LIKE ? OR
				LOWER(COALESCE(NULLIF(ad.ad_actor_phone, ''), u.usr_nohp, pg.pg_nohp, '')) LIKE ?
			)`
		args = append(args, q, q, q, q, q, q, q)
	}

	if actorType := strings.TrimSpace(filter.ActorType); actorType != "" && strings.ToLower(actorType) != "all" {
		query += " AND ad.ad_actor_type COLLATE utf8mb4_unicode_ci = ?"
		args = append(args, strings.ToLower(actorType))
	}

	query += " ORDER BY ad.ad_created DESC LIMIT ?"
	args = append(args, limit)

	if err := s.db.Raw(query, args...).Scan(&rows).Error; err != nil {
		return nil, fmt.Errorf("failed to list account deletions: %w", err)
	}
	for i := range rows {
		if rows[i].ActorName == nil || strings.TrimSpace(*rows[i].ActorName) == "" {
			fallbackName := strings.Title(strings.TrimSpace(rows[i].ActorType))
			if fallbackName == "" {
				fallbackName = "Akun"
			}
			actorID := strings.TrimSpace(rows[i].ActorID)
			if actorID != "" {
				fallbackName = fmt.Sprintf("%s #%s", fallbackName, actorID)
			}
			rows[i].ActorName = &fallbackName
		}
		if rows[i].ActorEmail == nil {
			empty := ""
			rows[i].ActorEmail = &empty
		}
		if rows[i].ActorPhone == nil {
			empty := ""
			rows[i].ActorPhone = &empty
		}
		if rows[i].SnapshotRaw == nil || strings.TrimSpace(*rows[i].SnapshotRaw) == "" {
			continue
		}
		var snapshot map[string]any
		if err := json.Unmarshal([]byte(*rows[i].SnapshotRaw), &snapshot); err == nil {
			rows[i].Snapshot = snapshot
		}
	}
	return rows, nil
}
