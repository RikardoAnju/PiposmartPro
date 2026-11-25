package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"errors"
	"time"

	"gorm.io/gorm"
)

var allowedNotifEvents = map[string]struct{}{
	"opened":              {},
	"navigation_success":  {},
	"navigation_fallback": {},
	"navigation_denied":   {},
}

type NotifService struct {
	db *gorm.DB
}

func NewNotifService(db *gorm.DB) *NotifService {
	return &NotifService{db: db}
}

// List mengambil semua notifikasi untuk outlet tertentu (Normalized)
func (s *NotifService) List(outletID, actorID, actorType string) ([]model.NotifReceiver, error) {
	var results []model.NotifReceiver

	// Preload Master untuk mengambil Judul, Pesan, dan Kategori
	err := s.db.Preload("Master").
		Where("nr_outlet = ? AND (nr_recipient_actor_id = '' OR nr_recipient_actor_id IS NULL OR (nr_recipient_actor_id = ? AND nr_recipient_actor_type = ?))", outletID, actorID, actorType).
		Order("nr_id DESC"). // Notif terbaru di atas
		Limit(100).
		Find(&results).Error

	return results, err
}

// MarkAsRead menandai satu notifikasi tertentu sebagai sudah dibaca
func (s *NotifService) MarkAsRead(id uint, outletID, actorID, actorType string) error {
	now := time.Now()
	result := s.db.Model(&model.NotifReceiver{}).
		Where("nr_id = ? AND nr_outlet = ? AND (nr_recipient_actor_id = '' OR nr_recipient_actor_id IS NULL OR (nr_recipient_actor_id = ? AND nr_recipient_actor_type = ?))", id, outletID, actorID, actorType).
		Updates(map[string]interface{}{
			"nr_status":  1,
			"nr_read_at": &now,
		})

	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("notifikasi tidak ditemukan")
	}
	return nil
}

func (s *NotifService) MarkManyAsRead(ids []uint, outletID, actorID, actorType string) error {
	if len(ids) == 0 {
		return errors.New("tidak ada notifikasi dipilih")
	}

	now := time.Now()
	return s.db.Model(&model.NotifReceiver{}).
		Where("nr_id IN ? AND nr_outlet = ? AND (nr_recipient_actor_id = '' OR nr_recipient_actor_id IS NULL OR (nr_recipient_actor_id = ? AND nr_recipient_actor_type = ?))", ids, outletID, actorID, actorType).
		Updates(map[string]interface{}{
			"nr_status":  1,
			"nr_read_at": &now,
		}).Error
}

// MarkAllAsRead menandai semua notif unread di outlet tersebut sebagai dibaca
func (s *NotifService) MarkAllAsRead(outletID, actorID, actorType string) error {
	now := time.Now()
	return s.db.Model(&model.NotifReceiver{}).
		Where("nr_outlet = ? AND nr_status = 0 AND (nr_recipient_actor_id = '' OR nr_recipient_actor_id IS NULL OR (nr_recipient_actor_id = ? AND nr_recipient_actor_type = ?))", outletID, actorID, actorType).
		Updates(map[string]interface{}{
			"nr_status":  1,
			"nr_read_at": &now,
		}).Error
}

func (s *NotifService) DeleteMany(ids []uint, outletID, actorID, actorType string) error {
	if len(ids) == 0 {
		return errors.New("tidak ada notifikasi dipilih")
	}

	return s.db.Where("nr_id IN ? AND nr_outlet = ? AND (nr_recipient_actor_id = '' OR nr_recipient_actor_id IS NULL OR (nr_recipient_actor_id = ? AND nr_recipient_actor_type = ?))", ids, outletID, actorID, actorType).
		Delete(&model.NotifReceiver{}).Error
}

// GetUnreadCount menghitung jumlah notif yang belum dibaca (untuk badge di Flutter)
func (s *NotifService) GetUnreadCount(outletID, actorID, actorType string) (int64, error) {
	var count int64
	err := s.db.Model(&model.NotifReceiver{}).
		Where("nr_outlet = ? AND nr_status = 0 AND (nr_recipient_actor_id = '' OR nr_recipient_actor_id IS NULL OR (nr_recipient_actor_id = ? AND nr_recipient_actor_type = ?))", outletID, actorID, actorType).
		Count(&count).Error
	return count, err
}

func (s *NotifService) RecordEvent(event model.NotifEvent) error {
	if _, allowed := allowedNotifEvents[event.EventType]; !allowed {
		return errors.New("event notifikasi tidak valid")
	}
	var count int64
	if err := s.db.Model(&model.NotifReceiver{}).
		Where("nr_nm_id = ? AND nr_outlet = ?", event.MasterID, event.OutletID).
		Count(&count).Error; err != nil {
		return err
	}
	if count == 0 {
		return errors.New("notifikasi tidak ditemukan")
	}
	return s.db.Create(&event).Error
}
