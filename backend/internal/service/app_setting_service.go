package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"time"

	"gorm.io/gorm"
)

type AppSettingService interface {
	GetSettings() (*model.AppSetting, error)
	UpdateSettings(settings *model.AppSetting) (*model.AppSetting, error)
	SeedDefaults() error
}

type appSettingService struct {
	db *gorm.DB
}

func NewAppSettingService(db *gorm.DB) AppSettingService {
	return &appSettingService{db: db}
}

func (s *appSettingService) SeedDefaults() error {
	setting := model.AppSetting{ID: 1}
	return s.db.Where(model.AppSetting{ID: 1}).FirstOrCreate(&setting).Error
}

func (s *appSettingService) GetSettings() (*model.AppSetting, error) {
	cacheKey := "app:settings"
	var setting model.AppSetting

	if database.GetCache(cacheKey, &setting) {
		return &setting, nil
	}

	err := s.db.First(&setting, 1).Error // Always ID 1
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			if createErr := s.SeedDefaults(); createErr != nil {
				return nil, createErr
			}
			setting = model.AppSetting{ID: 1}
			database.SetCache(cacheKey, setting, 24*time.Hour)
			return &setting, nil
		}
		return nil, err
	}

	database.SetCache(cacheKey, setting, 24*time.Hour)
	return &setting, nil
}

func (s *appSettingService) UpdateSettings(req *model.AppSetting) (*model.AppSetting, error) {
	var setting model.AppSetting
	err := s.db.First(&setting, 1).Error
	if err != nil && err != gorm.ErrRecordNotFound {
		return nil, err
	}

	setting.WhatsappNumber = req.WhatsappNumber
	setting.InstagramUsername = req.InstagramUsername
	setting.FacebookUsername = req.FacebookUsername
	setting.Email = req.Email
	setting.TiktokUsername = req.TiktokUsername
	setting.WebsiteUrl = req.WebsiteUrl
	setting.PlaystoreUrl = req.PlaystoreUrl
	setting.AppstoreUrl = req.AppstoreUrl
	setting.AppVersion = req.AppVersion
	setting.MinimumSupportedVersion = req.MinimumSupportedVersion
	setting.AppVersionIOS = req.AppVersionIOS
	setting.MinimumSupportedVersionIOS = req.MinimumSupportedVersionIOS

	if err == gorm.ErrRecordNotFound {
		setting.ID = 1
		err = s.db.Create(&setting).Error
	} else {
		err = s.db.Save(&setting).Error
	}

	if err != nil {
		return nil, err
	}

	// Invalidate Cache
	database.InvalidateCache("app:settings")

	return &setting, nil
}
