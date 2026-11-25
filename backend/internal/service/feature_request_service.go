package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"errors"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type FeatureRequestService struct{ db *gorm.DB }

type FeatureRequestItem struct {
	model.FeatureRequest
	VoteCount   int64                            `json:"vote_count"`
	HasVoted    bool                             `json:"has_voted"`
	IsMine      bool                             `json:"is_mine"`
	Attachments []model.FeatureRequestAttachment `json:"attachments"`
}

func NewFeatureRequestService(db *gorm.DB) *FeatureRequestService {
	return &FeatureRequestService{db: db}
}

func (s *FeatureRequestService) List(actorID, actorType, status, sortBy, search string) ([]FeatureRequestItem, error) {
	var requests []model.FeatureRequest
	query := s.db.Model(&model.FeatureRequest{})
	if status = strings.TrimSpace(strings.ToUpper(status)); status != "" && status != "ALL" {
		query = query.Where("fr_status = ?", status)
	}
	if search = strings.TrimSpace(search); search != "" {
		like := "%" + search + "%"
		query = query.Where("fr_title LIKE ? OR fr_description LIKE ? OR fr_creator_name LIKE ?", like, like, like)
	}
	if sortBy == "newest" {
		query = query.Order("fr_created_at DESC")
	} else {
		query = query.Order("(SELECT COUNT(*) FROM ac_feature_request_votes WHERE frv_request_id = ac_feature_requests.fr_id) DESC").Order("fr_created_at DESC")
	}
	if err := query.Find(&requests).Error; err != nil {
		return nil, err
	}

	items := make([]FeatureRequestItem, 0, len(requests))
	for _, request := range requests {
		var count int64
		s.db.Model(&model.FeatureRequestVote{}).Where("frv_request_id = ?", request.ID).Count(&count)
		var ownCount int64
		if actorID != "" {
			s.db.Model(&model.FeatureRequestVote{}).Where("frv_request_id = ? AND frv_voter_id = ? AND frv_voter_type = ?", request.ID, actorID, actorType).Count(&ownCount)
		}
		var attachments []model.FeatureRequestAttachment
		s.db.Where("fra_request_id = ?", request.ID).Order("fra_created_at ASC").Find(&attachments)
		items = append(items, FeatureRequestItem{FeatureRequest: request, VoteCount: count, HasVoted: ownCount > 0, IsMine: actorID != "" && request.CreatorID == actorID && request.CreatorType == actorType, Attachments: attachments})
	}
	return items, nil
}

func (s *FeatureRequestService) Create(actorID, actorType, outletID, title, description string) (*FeatureRequestItem, error) {
	title, description = strings.TrimSpace(title), strings.TrimSpace(description)
	if len([]rune(title)) < 5 || len([]rune(title)) > 120 {
		return nil, errors.New("judul harus 5–120 karakter")
	}
	if len([]rune(description)) < 10 || len([]rune(description)) > 1500 {
		return nil, errors.New("penjelasan harus 10–1500 karakter")
	}
	creatorName := "Pengguna AyoCuci"
	if outletID != "" {
		var outlet model.Outlet
		if err := s.db.Select("ot_nama").Where("ot_id = ?", outletID).First(&outlet).Error; err == nil && strings.TrimSpace(outlet.Nama) != "" {
			creatorName = outlet.Nama
		}
	}
	request := model.FeatureRequest{ID: uuid.NewString(), OutletID: outletID, CreatorID: actorID, CreatorType: actorType, CreatorName: creatorName, Title: title, Description: description, Status: model.FeatureRequestStatusSubmitted}
	if err := s.db.Create(&request).Error; err != nil {
		return nil, err
	}
	return &FeatureRequestItem{FeatureRequest: request, IsMine: true, Attachments: []model.FeatureRequestAttachment{}}, nil
}

func (s *FeatureRequestService) Get(id, actorID, actorType string) (*FeatureRequestItem, error) {
	var request model.FeatureRequest
	if err := s.db.First(&request, "fr_id = ?", id).Error; err != nil {
		return nil, errors.New("usulan fitur tidak ditemukan")
	}
	items, err := s.List(actorID, actorType, "ALL", "newest", "")
	if err != nil {
		return nil, err
	}
	for i := range items {
		if items[i].ID == id {
			return &items[i], nil
		}
	}
	return nil, errors.New("usulan fitur tidak ditemukan")
}

func (s *FeatureRequestService) Update(id, actorID, actorType, title, description string) error {
	var request model.FeatureRequest
	if err := s.db.First(&request, "fr_id = ?", id).Error; err != nil {
		return errors.New("usulan fitur tidak ditemukan")
	}
	if request.CreatorID != actorID || request.CreatorType != actorType {
		return errors.New("hanya pembuat usulan yang dapat mengedit")
	}
	if request.Status != model.FeatureRequestStatusSubmitted {
		return errors.New("usulan hanya dapat diedit selama masih berstatus Diajukan")
	}
	title, description = strings.TrimSpace(title), strings.TrimSpace(description)
	if len([]rune(title)) < 5 || len([]rune(title)) > 120 {
		return errors.New("judul harus 5–120 karakter")
	}
	if len([]rune(description)) < 10 || len([]rune(description)) > 1500 {
		return errors.New("penjelasan harus 10–1500 karakter")
	}
	return s.db.Model(&request).Updates(map[string]interface{}{"fr_title": title, "fr_description": description}).Error
}

func (s *FeatureRequestService) AddAttachment(requestID, actorID, actorType, fileURL string) (*model.FeatureRequestAttachment, error) {
	var request model.FeatureRequest
	if err := s.db.First(&request, "fr_id = ?", requestID).Error; err != nil {
		return nil, errors.New("usulan fitur tidak ditemukan")
	}
	if request.CreatorID != actorID || request.CreatorType != actorType {
		return nil, errors.New("hanya pembuat usulan yang dapat menambah lampiran")
	}
	if request.Status != model.FeatureRequestStatusSubmitted {
		return nil, errors.New("lampiran hanya dapat diubah selama status Diajukan")
	}
	var count int64
	s.db.Model(&model.FeatureRequestAttachment{}).Where("fra_request_id = ?", requestID).Count(&count)
	if count >= 3 {
		return nil, errors.New("maksimal 3 lampiran per usulan")
	}
	attachment := model.FeatureRequestAttachment{ID: uuid.NewString(), FeatureRequestID: requestID, FileURL: fileURL}
	if err := s.db.Create(&attachment).Error; err != nil {
		return nil, err
	}
	return &attachment, nil
}

func (s *FeatureRequestService) DeleteAttachment(requestID, attachmentID, actorID, actorType string) error {
	var request model.FeatureRequest
	if err := s.db.First(&request, "fr_id = ?", requestID).Error; err != nil {
		return errors.New("usulan fitur tidak ditemukan")
	}
	if request.CreatorID != actorID || request.CreatorType != actorType {
		return errors.New("hanya pembuat usulan yang dapat menghapus lampiran")
	}
	if request.Status != model.FeatureRequestStatusSubmitted {
		return errors.New("lampiran hanya dapat diubah selama status Diajukan")
	}
	result := s.db.Where("fra_id = ? AND fra_request_id = ?", attachmentID, requestID).Delete(&model.FeatureRequestAttachment{})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("lampiran tidak ditemukan")
	}
	return nil
}

func (s *FeatureRequestService) ToggleVote(requestID, actorID, actorType string) (bool, int64, error) {
	var request model.FeatureRequest
	if err := s.db.Select("fr_id").First(&request, "fr_id = ?", requestID).Error; err != nil {
		return false, 0, errors.New("usulan fitur tidak ditemukan")
	}
	voted := false
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var vote model.FeatureRequestVote
		err := tx.Where("frv_request_id = ? AND frv_voter_id = ? AND frv_voter_type = ?", requestID, actorID, actorType).First(&vote).Error
		if err == nil {
			return tx.Delete(&vote).Error
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}
		voted = true
		return tx.Create(&model.FeatureRequestVote{ID: uuid.NewString(), FeatureRequestID: requestID, VoterID: actorID, VoterType: actorType}).Error
	})
	if err != nil {
		return false, 0, err
	}
	var count int64
	s.db.Model(&model.FeatureRequestVote{}).Where("frv_request_id = ?", requestID).Count(&count)
	return voted, count, nil
}

func (s *FeatureRequestService) UpdateStatus(id, status, note string) error {
	status = strings.ToUpper(strings.TrimSpace(status))
	valid := map[string]bool{model.FeatureRequestStatusSubmitted: true, model.FeatureRequestStatusUnderReview: true, model.FeatureRequestStatusInProgress: true, model.FeatureRequestStatusCompleted: true, model.FeatureRequestStatusNotPlanned: true}
	if !valid[status] {
		return errors.New("status usulan tidak valid")
	}
	now := time.Now()
	result := s.db.Model(&model.FeatureRequest{}).Where("fr_id = ?", id).Updates(map[string]interface{}{"fr_status": status, "fr_admin_note": strings.TrimSpace(note), "fr_status_updated_at": now})
	if result.Error != nil {
		return result.Error
	}
	if result.RowsAffected == 0 {
		return errors.New("usulan fitur tidak ditemukan")
	}
	return nil
}
