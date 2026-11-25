package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"errors"

	"gorm.io/gorm"
)

type AdminBankService interface {
	GetAll() ([]model.BankAccount, error)
	Create(bank model.BankAccount) (model.BankAccount, error)
	Update(id uint, bank model.BankAccount) (model.BankAccount, error)
	Delete(id uint) error
	ToggleStatus(id uint) error
}

type adminBankService struct {
	db *gorm.DB
}

func NewAdminBankService(db *gorm.DB) AdminBankService {
	return &adminBankService{db: db}
}

func (s *adminBankService) GetAll() ([]model.BankAccount, error) {
	var banks []model.BankAccount
	err := s.db.Order("id DESC").Find(&banks).Error
	return banks, err
}

func (s *adminBankService) Create(bank model.BankAccount) (model.BankAccount, error) {
	err := s.db.Create(&bank).Error
	return bank, err
}

func (s *adminBankService) Update(id uint, data model.BankAccount) (model.BankAccount, error) {
	var bank model.BankAccount
	if err := s.db.First(&bank, id).Error; err != nil {
		return bank, errors.New("rekening tidak ditemukan")
	}

	err := s.db.Model(&bank).Updates(model.BankAccount{
		BankName:      data.BankName,
		AccountName:   data.AccountName,
		AccountNumber: data.AccountNumber,
	}).Error

	return bank, err
}

func (s *adminBankService) ToggleStatus(id uint) error {
	return s.db.Model(&model.BankAccount{}).Where("id = ?", id).
		Update("is_active", gorm.Expr("NOT is_active")).Error
}

func (s *adminBankService) Delete(id uint) error {
	return s.db.Delete(&model.BankAccount{}, id).Error
}