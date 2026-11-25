package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"gorm.io/gorm"
)

type AdminTransactionService struct {
	db *gorm.DB
}

func NewAdminTransactionService(db *gorm.DB) *AdminTransactionService {
	return &AdminTransactionService{db: db}
}

type GlobalTransactionFilter struct {
	Page      int
	Limit     int
	OutletID  string
	Status    string
	StartDate string
	EndDate   string
	Search    string
}

type PaginatedTransactions struct {
	Data       []model.Transaksi `json:"data"`
	Total      int64             `json:"total"`
	Page       int               `json:"page"`
	TotalPages int               `json:"total_pages"`
}

func (s *AdminTransactionService) ListTransactions(filter GlobalTransactionFilter) (*PaginatedTransactions, error) {
	var transaksis []model.Transaksi
	var total int64

	query := s.db.Model(&model.Transaksi{})

	if filter.OutletID != "" && filter.OutletID != "all" {
		query = query.Where("tr_outlet = ?", filter.OutletID)
	}

	if filter.Status != "" && filter.Status != "all" {
		query = query.Where("tr_status_order = ?", filter.Status)
	}

	if filter.StartDate != "" {
		query = query.Where("DATE(tr_created) >= ?", filter.StartDate)
	}
	if filter.EndDate != "" {
		query = query.Where("DATE(tr_created) <= ?", filter.EndDate)
	}

	if filter.Search != "" {
		searchLike := "%" + filter.Search + "%"
		query = query.Joins("LEFT JOIN ac_pelanggan p ON p.plg_id = ac_transaksi.tr_pelanggan").
			Where("ac_transaksi.tr_id LIKE ? OR p.plg_nama LIKE ?", searchLike, searchLike)
	}

	// Count total
	if err := query.Count(&total).Error; err != nil {
		return nil, err
	}

	// Pagination
	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 || limit > 100 {
		limit = 20
	}
	offset := (page - 1) * limit

	totalPages := int(total) / limit
	if int(total)%limit != 0 {
		totalPages++
	}

	// Fetch data
	err := query.Preload("Outlet").
		Preload("Pelanggan").
		Order("tr_created DESC").
		Limit(limit).
		Offset(offset).
		Find(&transaksis).Error

	if err != nil {
		return nil, err
	}

	return &PaginatedTransactions{
		Data:       transaksis,
		Total:      total,
		Page:       page,
		TotalPages: totalPages,
	}, nil
}
