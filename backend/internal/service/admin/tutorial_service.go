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

type AdminTutorialService interface {
	GetAll(tutorialType string, category string, includeInactive bool) ([]model.Tutorial, error)
	GetByID(id uint) (model.Tutorial, error)
	Create(data model.Tutorial) (model.Tutorial, error)
	Update(id uint, data model.Tutorial) (model.Tutorial, error)
	ToggleStatus(id uint) error
	Delete(id uint) error
}

type adminTutorialService struct {
	db *gorm.DB
}

var validTutorialTypes = map[string]bool{
	"VIDEO": true,
	"GUIDE": true,
	"FAQ":   true,
}

var validTutorialCategories = map[string]bool{
	"TRANSAKSI": true,
	"LAPORAN":   true,
	"PELANGGAN": true,
	"OUTLET":    true,
	"PRINTER":   true,
	"KOIN":      true,
	"REFERRAL":  true,
}

func NewAdminTutorialService(db *gorm.DB) AdminTutorialService {
	return &adminTutorialService{db: db}
}

func (s *adminTutorialService) GetByID(id uint) (model.Tutorial, error) {
	var item model.Tutorial
	err := s.db.First(&item, id).Error
	return item, err
}

func (s *adminTutorialService) GetAll(tutorialType string, category string, includeInactive bool) ([]model.Tutorial, error) {
	normalizedType := normalizeTutorialType(tutorialType)
	normalizedCategory := normalizeTutorialCategory(category)
	cacheKey := fmt.Sprintf("tutorials:%s:%s:%v", normalizedType, normalizedCategory, includeInactive)
	var items []model.Tutorial

	if database.GetCache(cacheKey, &items) {
		return items, nil
	}

	q := s.db.Order("sort_order ASC, id DESC")
	if normalizedType != "" {
		q = q.Where("type = ?", normalizedType)
	}
	if normalizedCategory != "" {
		q = q.Where("category = ?", normalizedCategory)
	}
	if !includeInactive {
		q = q.Where("is_active = ?", true)
	}

	err := q.Find(&items).Error
	if err == nil {
		database.SetCache(cacheKey, items, 30*time.Minute)
	}
	return items, err
}

func (s *adminTutorialService) Create(data model.Tutorial) (model.Tutorial, error) {
	if err := validateTutorial(&data); err != nil {
		return data, err
	}
	if err := s.db.Create(&data).Error; err != nil {
		return data, err
	}
	database.ClearCacheByPattern("tutorials:*")
	return data, nil
}

func (s *adminTutorialService) Update(id uint, data model.Tutorial) (model.Tutorial, error) {
	var item model.Tutorial
	if err := s.db.First(&item, id).Error; err != nil {
		return item, errors.New("tutorial tidak ditemukan")
	}
	if err := validateTutorial(&data); err != nil {
		return item, err
	}

	updates := map[string]interface{}{
		"type":       data.Type,
		"category":   data.Category,
		"title":      data.Title,
		"summary":    data.Summary,
		"body":       data.Body,
		"video_url":  data.VideoURL,
		"youtube_id": data.YoutubeID,
		"pdf_url":    data.PdfURL,
		"duration":   data.Duration,
		"sort_order": data.SortOrder,
	}

	if err := s.db.Model(&item).Updates(updates).Error; err != nil {
		return item, err
	}
	database.ClearCacheByPattern("tutorials:*")
	return item, nil
}

func (s *adminTutorialService) ToggleStatus(id uint) error {
	err := s.db.Model(&model.Tutorial{}).Where("id = ?", id).
		Update("is_active", gorm.Expr("NOT is_active")).Error
	if err == nil {
		database.ClearCacheByPattern("tutorials:*")
	}
	return err
}

func (s *adminTutorialService) Delete(id uint) error {
	err := s.db.Delete(&model.Tutorial{}, id).Error
	if err == nil {
		database.ClearCacheByPattern("tutorials:*")
	}
	return err
}

func validateTutorial(data *model.Tutorial) error {
	data.Type = normalizeTutorialType(data.Type)
	data.Category = normalizeTutorialCategory(data.Category)
	data.Title = strings.TrimSpace(data.Title)
	data.Summary = strings.TrimSpace(data.Summary)
	data.Body = strings.TrimSpace(data.Body)
	data.VideoURL = strings.TrimSpace(data.VideoURL)
	data.YoutubeID = strings.TrimSpace(data.YoutubeID)
	data.PdfURL = strings.TrimSpace(data.PdfURL)
	data.Duration = strings.TrimSpace(data.Duration)

	if !validTutorialTypes[data.Type] {
		return errors.New("tipe tutorial harus VIDEO, GUIDE, atau FAQ")
	}
	if !validTutorialCategories[data.Category] {
		return errors.New("kategori tutorial tidak valid")
	}
	if data.Title == "" {
		return errors.New("judul tutorial wajib diisi")
	}

	switch data.Type {
	case "VIDEO":
		if data.VideoURL == "" && data.YoutubeID == "" {
			return errors.New("video wajib punya YouTube ID atau URL video")
		}
	case "GUIDE":
		if data.PdfURL == "" && data.Body == "" {
			return errors.New("panduan wajib punya URL PDF atau deskripsi")
		}
	case "FAQ":
		if data.Body == "" {
			return errors.New("FAQ wajib punya jawaban")
		}
	}

	return nil
}

func normalizeTutorialType(value string) string {
	return strings.ToUpper(strings.TrimSpace(value))
}

func normalizeTutorialCategory(value string) string {
	return strings.ToUpper(strings.TrimSpace(value))
}
