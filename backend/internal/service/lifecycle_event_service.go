package service

import (
	"encoding/json"
	"errors"
	"strings"
	"time"

	"github.com/RikardoAnju/PiposmartPro/internal/model"

	"gorm.io/datatypes"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var allowedLifecycleEvents = map[string]struct{}{
	"app_opened":         {},
	"coin_topup_viewed":  {},
	"pro_viewed":         {},
	"addon_store_viewed": {},
	"report_viewed":      {},
}

type LifecycleEventService struct{ db *gorm.DB }

func NewLifecycleEventService(db *gorm.DB) *LifecycleEventService {
	return &LifecycleEventService{db: db}
}

func (s *LifecycleEventService) Track(event model.LifecycleEvent, metadata map[string]interface{}) error {
	event.EventName = strings.ToLower(strings.TrimSpace(event.EventName))
	if _, allowed := allowedLifecycleEvents[event.EventName]; !allowed {
		return errors.New("event lifecycle tidak didukung")
	}
	if strings.TrimSpace(event.EventID) == "" || strings.TrimSpace(event.OutletID) == "" {
		return errors.New("event_id dan outlet wajib diisi")
	}
	if event.OccurredAt.IsZero() || event.OccurredAt.After(time.Now().Add(5*time.Minute)) {
		event.OccurredAt = time.Now()
	}
	encoded, err := json.Marshal(metadata)
	if err != nil {
		return err
	}
	event.Metadata = datatypes.JSON(encoded)
	return s.db.Clauses(clause.OnConflict{DoNothing: true}).Create(&event).Error
}
