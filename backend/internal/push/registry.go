package push

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"log"
	"strings"
	"time"

	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type RegisterTokenInput struct {
	Token      string
	OutletID   string
	ActorID    string
	ActorType  string
	Platform   string
	AppVersion string
}

type TokenStatusSummary struct {
	CurrentTokenActive bool
	ActiveTokenCount   int64
}

func RegisterToken(db *gorm.DB, input RegisterTokenInput) error {
	token := strings.TrimSpace(input.Token)
	outletID := strings.TrimSpace(input.OutletID)
	actorID := strings.TrimSpace(input.ActorID)
	actorType := strings.TrimSpace(input.ActorType)
	if token == "" || outletID == "" {
		return nil
	}

	now := time.Now()
	record := model.PushToken{
		Token:      token,
		OutletID:   outletID,
		ActorID:    actorID,
		ActorType:  actorType,
		Platform:   strings.TrimSpace(input.Platform),
		AppVersion: strings.TrimSpace(input.AppVersion),
		IsActive:   true,
		LastSeenAt: now,
	}

	if err := db.Model(&model.PushToken{}).
		Where("pt_token = ? AND pt_outlet <> ?", token, outletID).
		Updates(map[string]interface{}{
			"pt_is_active":    false,
			"pt_updated":      now,
			"pt_last_seen_at": now,
		}).Error; err != nil {
		return err
	}

	if actorID != "" && actorType != "" {
		if err := db.Model(&model.PushToken{}).
			Where("pt_outlet = ? AND pt_actor_id = ? AND pt_actor_type = ? AND pt_token <> ?",
				outletID, actorID, actorType, token).
			Updates(map[string]interface{}{
				"pt_is_active":    false,
				"pt_updated":      now,
				"pt_last_seen_at": now,
			}).Error; err != nil {
			return err
		}
	}

	if err := db.Clauses(clause.OnConflict{
		Columns: []clause.Column{
			{Name: "pt_token"},
			{Name: "pt_outlet"},
		},
		DoUpdates: clause.Assignments(map[string]interface{}{
			"pt_actor_id":     record.ActorID,
			"pt_actor_type":   record.ActorType,
			"pt_platform":     record.Platform,
			"pt_app_version":  record.AppVersion,
			"pt_is_active":    true,
			"pt_last_seen_at": now,
			"pt_updated":      now,
		}),
	}).Create(&record).Error; err != nil {
		return err
	}

	log.Printf(
		"push-token: active token registered outlet=%s actor=%s/%s platform=%s app=%s",
		outletID,
		actorType,
		actorID,
		record.Platform,
		record.AppVersion,
	)

	return nil
}

func TokenStatusForOutlet(db *gorm.DB, outletID string, token string) (TokenStatusSummary, error) {
	outletID = strings.TrimSpace(outletID)
	token = strings.TrimSpace(token)

	summary := TokenStatusSummary{}
	if outletID == "" {
		return summary, nil
	}

	if err := db.Model(&model.PushToken{}).
		Where("pt_outlet = ? AND pt_is_active = ?", outletID, true).
		Count(&summary.ActiveTokenCount).Error; err != nil {
		return summary, err
	}

	if token == "" {
		return summary, nil
	}

	var currentCount int64
	if err := db.Model(&model.PushToken{}).
		Where("pt_outlet = ? AND pt_token = ? AND pt_is_active = ?", outletID, token, true).
		Count(&currentCount).Error; err != nil {
		return summary, err
	}
	summary.CurrentTokenActive = currentCount > 0

	return summary, nil
}

func DeactivateToken(db *gorm.DB, token string, outletID string) error {
	token = strings.TrimSpace(token)
	outletID = strings.TrimSpace(outletID)
	if token == "" || outletID == "" {
		return nil
	}

	return db.Model(&model.PushToken{}).
		Where("pt_token = ? AND pt_outlet = ?", token, outletID).
		Updates(map[string]interface{}{
			"pt_is_active":    false,
			"pt_updated":      time.Now(),
			"pt_last_seen_at": time.Now(),
		}).Error
}

func ActiveTokenRowsByOutletIDs(db *gorm.DB, outletIDs []string) ([]model.PushToken, error) {
	if len(outletIDs) == 0 {
		return nil, nil
	}

	var rows []model.PushToken
	err := db.
		Where("pt_is_active = ? AND pt_outlet IN ?", true, outletIDs).
		Order("pt_outlet ASC, pt_last_seen_at DESC").
		Find(&rows).Error
	if err != nil {
		return nil, err
	}

	return rows, nil
}

func ActiveTokensByOutletIDs(db *gorm.DB, outletIDs []string) ([]string, error) {
	if len(outletIDs) == 0 {
		return nil, nil
	}

	var rows []string
	err := db.Model(&model.PushToken{}).
		Distinct("pt_token").
		Where("pt_is_active = ? AND pt_outlet IN ?", true, outletIDs).
		Pluck("pt_token", &rows).Error
	if err != nil {
		return nil, err
	}

	return rows, nil
}

func HasTokenForOutlet(db *gorm.DB, outletID string) (bool, error) {
	outletID = strings.TrimSpace(outletID)
	if outletID == "" {
		return false, nil
	}

	var count int64
	err := db.Model(&model.PushToken{}).
		Where("pt_outlet = ? AND pt_is_active = ?", outletID, true).
		Count(&count).Error
	return count > 0, err
}
