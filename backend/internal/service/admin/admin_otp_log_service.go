package admin

import (
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type OTPLogRow struct {
	ID        uint      `json:"id" gorm:"column:ol_id"`
	Phone     string    `json:"phone" gorm:"column:ol_phone"`
	Email     *string   `json:"email" gorm:"column:ol_email"`
	Flow      string    `json:"flow" gorm:"column:ol_flow"`
	Event     string    `json:"event" gorm:"column:ol_event"`
	Provider  string    `json:"provider" gorm:"column:ol_provider"`
	OTPCode   *string   `json:"otp_code" gorm:"column:ol_otp_code"`
	Message   string    `json:"message" gorm:"column:ol_message"`
	CreatedAt time.Time `json:"created_at" gorm:"column:ol_created"`
}

type OTPLogFilter struct {
	Search   string
	Flow     string
	Event    string
	StartDate string
	EndDate   string
	Limit    int
}

type AdminOTPLogService interface {
	List(filter OTPLogFilter) ([]OTPLogRow, error)
}

type adminOTPLogService struct {
	db *gorm.DB
}

func NewAdminOTPLogService(db *gorm.DB) AdminOTPLogService {
	return &adminOTPLogService{db: db}
}

func normalizeLikeQuery(value string) string {
	value = strings.TrimSpace(value)
	if value == "" {
		return ""
	}
	return "%" + strings.ToLower(value) + "%"
}

func (s *adminOTPLogService) List(filter OTPLogFilter) ([]OTPLogRow, error) {
	var rows []OTPLogRow
	limit := filter.Limit
	if limit <= 0 || limit > 500 {
		limit = 200
	}

	query := `
		SELECT
			ol_id,
			ol_phone,
			ol_email,
			ol_flow,
			ol_event,
			ol_provider,
			ol_otp_code,
			ol_message,
			ol_created
		FROM ac_otp_request_logs
		WHERE 1=1
	`
	args := make([]interface{}, 0, 8)

	if q := normalizeLikeQuery(filter.Search); q != "" {
		query += `
			AND (
				LOWER(ol_phone) LIKE ? OR
				LOWER(COALESCE(ol_email, '')) LIKE ? OR
				LOWER(ol_flow) LIKE ? OR
				LOWER(ol_event) LIKE ? OR
				LOWER(COALESCE(ol_message, '')) LIKE ?
			)`
		args = append(args, q, q, q, q, q)
	}

	if flow := strings.TrimSpace(filter.Flow); flow != "" && strings.ToLower(flow) != "all" {
		query += " AND ol_flow = ?"
		args = append(args, strings.ToLower(flow))
	}

	if event := strings.TrimSpace(filter.Event); event != "" && strings.ToLower(event) != "all" {
		query += " AND ol_event = ?"
		args = append(args, strings.ToLower(event))
	}

	if filter.StartDate != "" {
		query += " AND DATE(ol_created) >= ?"
		args = append(args, filter.StartDate)
	}

	if filter.EndDate != "" {
		query += " AND DATE(ol_created) <= ?"
		args = append(args, filter.EndDate)
	}

	query += " ORDER BY ol_created DESC LIMIT ?"
	args = append(args, limit)

	if err := s.db.Raw(query, args...).Scan(&rows).Error; err != nil {
		return nil, fmt.Errorf("failed to list otp logs: %w", err)
	}

	return rows, nil
}
