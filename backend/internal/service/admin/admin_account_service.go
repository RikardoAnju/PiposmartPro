package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"gorm.io/gorm"
)

// AdminAccountService handles CRUD untuk akun admin dan role admin
type AdminAccountService interface {
	// Admin Accounts
	ListAdmins() ([]model.Admin, error)
	CreateAdmin(nama, email, password string, roleID *string) (model.Admin, error)
	UpdateAdmin(id string, nama, email, password string, roleID *string) (model.Admin, error)
	DeleteAdmin(id string) error
	AssignRole(adminID string, roleID *string) error

	// Admin Roles
	ListRoles() ([]model.AdminRole, error)
	CreateRole(nama string, permissions json.RawMessage, createdBy string) (model.AdminRole, error)
	UpdateRole(id string, nama string, permissions json.RawMessage) error
	DeleteRole(id string) error
}

type adminAccountService struct {
	db *gorm.DB
}

func NewAdminAccountService(db *gorm.DB) AdminAccountService {
	return &adminAccountService{db}
}

// =====================================
// ADMIN ACCOUNTS
// =====================================

func (s *adminAccountService) ListAdmins() ([]model.Admin, error) {
	var admins []model.Admin
	err := s.db.Preload("Role").
		Where("adm_is_master = ?", false). // Sembunyikan master admin dari list
		Order("adm_created DESC").
		Find(&admins).Error
	return admins, err
}

func (s *adminAccountService) CreateAdmin(nama, email, password string, roleID *string) (model.Admin, error) {
	// Cek apakah email sudah terdaftar
	var count int64
	s.db.Model(&model.Admin{}).Where("adm_email = ?", email).Count(&count)
	if count > 0 {
		return model.Admin{}, errors.New("email sudah terdaftar sebagai admin")
	}

	// Hash password
	hashed, err := utils.HashPassword(password)
	if err != nil {
		return model.Admin{}, errors.New("gagal memproses password")
	}

	// Generate ID (format: ADM.xxxxxx)
	var lastAdmin model.Admin
	newID := "ADM.000002"
	if err := s.db.Order("adm_id DESC").Where("adm_id != ?", "ADM.000001").First(&lastAdmin).Error; err == nil {
		// Parse angka dari ID terakhir dan increment
		var num int
		fmt.Sscanf(lastAdmin.ID, "ADM.%06d", &num)
		newID = fmt.Sprintf("ADM.%06d", num+1)
	}

	admin := model.Admin{
		ID:       newID,
		Nama:     nama,
		Email:    email,
		Password: hashed,
		RoleID:   roleID,
		IsMaster: false,
	}

	if err := s.db.Create(&admin).Error; err != nil {
		return model.Admin{}, errors.New("gagal membuat akun admin: " + err.Error())
	}

	// Preload role untuk response
	if admin.RoleID != nil {
		s.db.Preload("Role").First(&admin, "adm_id = ?", admin.ID)
	}

	return admin, nil
}

func (s *adminAccountService) UpdateAdmin(id string, nama, email, password string, roleID *string) (model.Admin, error) {
	if id == "ADM.000001" {
		return model.Admin{}, errors.New("tidak dapat mengedit Master Admin")
	}

	// Ambil admin yang akan diedit
	var admin model.Admin
	if err := s.db.Where("adm_id = ? AND adm_is_master = ?", id, false).First(&admin).Error; err != nil {
		return model.Admin{}, errors.New("admin tidak ditemukan")
	}

	// Cek apakah email baru sudah terdaftar untuk admin lain
	var count int64
	s.db.Model(&model.Admin{}).Where("adm_email = ? AND adm_id != ?", email, id).Count(&count)
	if count > 0 {
		return model.Admin{}, errors.New("email sudah terdaftar sebagai admin lain")
	}

	// Update fields
	admin.Nama = nama
	admin.Email = email
	admin.RoleID = roleID

	// Hash password jika diisi
	if password != "" {
		if len(password) < 6 {
			return model.Admin{}, errors.New("password minimal 6 karakter")
		}
		hashed, err := utils.HashPassword(password)
		if err != nil {
			return model.Admin{}, errors.New("gagal memproses password")
		}
		admin.Password = hashed
	}

	if err := s.db.Save(&admin).Error; err != nil {
		return model.Admin{}, errors.New("gagal memperbarui akun admin: " + err.Error())
	}

	// Preload role
	if admin.RoleID != nil {
		s.db.Preload("Role").First(&admin, "adm_id = ?", admin.ID)
	} else {
		admin.Role = nil
	}

	return admin, nil
}

func (s *adminAccountService) DeleteAdmin(id string) error {
	if id == "ADM.000001" {
		return errors.New("tidak dapat menghapus Master Admin")
	}
	result := s.db.Where("adm_id = ? AND adm_is_master = ?", id, false).Delete(&model.Admin{})
	if result.RowsAffected == 0 {
		return errors.New("admin tidak ditemukan atau tidak dapat dihapus")
	}
	return result.Error
}

func (s *adminAccountService) AssignRole(adminID string, roleID *string) error {
	if adminID == "ADM.000001" {
		return errors.New("tidak dapat mengubah role Master Admin")
	}
	return s.db.Model(&model.Admin{}).
		Where("adm_id = ? AND adm_is_master = ?", adminID, false).
		Update("adm_role", roleID).Error
}

// =====================================
// ADMIN ROLES
// =====================================

func (s *adminAccountService) ListRoles() ([]model.AdminRole, error) {
	var roles []model.AdminRole
	err := s.db.Order("ar_created DESC").Find(&roles).Error
	return roles, err
}

func (s *adminAccountService) CreateRole(nama string, permissions json.RawMessage, createdBy string) (model.AdminRole, error) {
	// Generate ID dari nama + timestamp
	id := fmt.Sprintf("AR-%d", time.Now().UnixNano())

	role := model.AdminRole{
		ID:          id,
		Nama:        nama,
		Permissions: permissions,
		CreatedBy:   createdBy,
	}

	if err := s.db.Create(&role).Error; err != nil {
		return model.AdminRole{}, errors.New("gagal membuat role: " + err.Error())
	}

	return role, nil
}

func (s *adminAccountService) UpdateRole(id string, nama string, permissions json.RawMessage) error {
	return s.db.Model(&model.AdminRole{}).Where("ar_id = ?", id).Updates(map[string]interface{}{
		"ar_nama":        nama,
		"ar_permissions": string(permissions),
	}).Error
}

func (s *adminAccountService) DeleteRole(id string) error {
	// Cek apakah role masih dipakai oleh admin manapun
	var count int64
	s.db.Model(&model.Admin{}).Where("adm_role = ?", id).Count(&count)
	if count > 0 {
		return errors.New("role masih digunakan oleh akun admin, tidak dapat dihapus")
	}

	result := s.db.Where("ar_id = ?", id).Delete(&model.AdminRole{})
	if result.RowsAffected == 0 {
		return errors.New("role tidak ditemukan")
	}
	return result.Error
}
