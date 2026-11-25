package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"errors"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type AdminContentService interface {
	GetAll(category string, includeInactive bool) ([]model.ContentBanner, error)
	GetByID(id uint) (model.ContentBanner, error)
	Create(data model.ContentBanner) (model.ContentBanner, error)
	Update(id uint, data model.ContentBanner) (model.ContentBanner, error)
	ToggleStatus(id uint) error
	Delete(id uint) error
}

type adminContentService struct {
	db *gorm.DB
}

func NewAdminContentService(db *gorm.DB) AdminContentService {
	return &adminContentService{db: db}
}

func (s *adminContentService) GetByID(id uint) (model.ContentBanner, error) {
	var item model.ContentBanner
	err := s.db.First(&item, id).Error
	return item, err
}

func (s *adminContentService) GetAll(category string, includeInactive bool) ([]model.ContentBanner, error) {
	cacheKey := fmt.Sprintf("content:banners:%s:%v", strings.ToLower(category), includeInactive)
	var items []model.ContentBanner

	// 1. Try Cache
	if database.GetCache(cacheKey, &items) {
		return items, nil
	}

	// 2. Cache Miss: Fetch from DB
	q := s.db.Order("published_at DESC, id DESC")
	if category != "" {
		q = q.Where("category = ?", strings.ToUpper(category))
	}
	if !includeInactive {
		q = q.Where("is_active = ?", true)
	}
	err := q.Find(&items).Error

	// 3. Store in Cache (30 min TTL)
	if err == nil {
		database.SetCache(cacheKey, items, 30*time.Minute)
	}

	return items, err
}

func (s *adminContentService) Create(data model.ContentBanner) (model.ContentBanner, error) {
	data.Category = strings.ToUpper(data.Category)
	if data.Category != "PROMO" && data.Category != "INFORMASI" {
		return data, errors.New("kategori harus PROMO atau INFORMASI")
	}
	if data.PublishedAt.IsZero() {
		data.PublishedAt = time.Now()
	}
	if data.ImageURL == "" {
		return data, errors.New("gambar wajib diisi")
	}
	if err := s.db.Create(&data).Error; err != nil {
		return data, err
	}

	// Invalidate Cache
	database.ClearCacheByPattern("content:banners:*")

	return data, nil
}

func (s *adminContentService) Update(id uint, data model.ContentBanner) (model.ContentBanner, error) {
	var item model.ContentBanner
	if err := s.db.First(&item, id).Error; err != nil {
		return item, errors.New("konten tidak ditemukan")
	}
	updates := map[string]interface{}{
		"category":     strings.ToUpper(data.Category),
		"title":        data.Title,
		"summary":      data.Summary,
		"body":         data.Body,
		"voucher_code": data.VoucherCode,
		"published_at": data.PublishedAt,
	}
	if data.ImageURL != "" {
		updates["image_url"] = data.ImageURL
	}
	if t, ok := updates["published_at"].(time.Time); ok && t.IsZero() {
		delete(updates, "published_at")
	}
	if err := s.db.Model(&item).Updates(updates).Error; err != nil {
		return item, err
	}

	// Invalidate Cache
	database.ClearCacheByPattern("content:banners:*")

	return item, nil
}

func (s *adminContentService) ToggleStatus(id uint) error {
	err := s.db.Model(&model.ContentBanner{}).Where("id = ?", id).
		Update("is_active", gorm.Expr("NOT is_active")).Error

	if err == nil {
		database.ClearCacheByPattern("content:banners:*")
	}
	return err
}

func (s *adminContentService) Delete(id uint) error {
	err := s.db.Delete(&model.ContentBanner{}, id).Error
	if err == nil {
		database.ClearCacheByPattern("content:banners:*")
	}
	return err
}
