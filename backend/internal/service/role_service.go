package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json" // Digunakan untuk konversi tipe
	"errors"
	"fmt"

	"gorm.io/gorm"
)

type RoleService struct {
	db *gorm.DB
}

func NewRoleService(db *gorm.DB) *RoleService {
	return &RoleService{db: db}
}

func (s *RoleService) Create(role model.Role) (model.Role, error) {
	// 1. Validasi: Cek apakah nama role sudah ada di outlet ini
	var count int64
	s.db.Model(&model.Role{}).Where("rl_outlet = ? AND rl_nama = ?", role.OutletID, role.Nama).Count(&count)
	if count > 0 {
		return role, errors.New("nama role sudah digunakan di outlet ini")
	}

	// 2. Generate ID menggunakan generator
	role.ID = utils.GenRoleID(s.db, role.OutletID)
	err := s.db.Create(&role).Error
	return role, err
}

// CreateDefaultRoles: Otomatis dipanggil saat pendaftaran outlet baru
func (s *RoleService) CreateDefaultRoles(tx *gorm.DB, outletID string, ownerID string) error {
	defaults := []struct {
		Nama  string
		Perms map[string][]string
	}{
		{
			Nama: "Admin",
			Perms: map[string][]string{
				"transaksi":   {"create", "read", "update", "update_status", "update_delivery_fee"},
				"pelanggan":   {"create", "read", "update"},
				"pengeluaran": {"create", "read", "update"},
				"item":        {"create", "read", "update"},
				"parfum":      {"create", "read", "update"},
				"layanan":     {"create", "read", "update"},
				"diskon":      {"create", "read", "update"},
				"pembayaran":  {"create", "read", "update"},
				"pegawai":     {"create", "read", "update"},
				"laporan":     defaultReportPermissions(),
			},
		},
		{
			Nama: "Kasir",
			Perms: map[string][]string{
				"transaksi":   {"create", "read", "update_status"},
				"pelanggan":   {"create", "read", "update"},
				"pengeluaran": {"create", "read"},
				"item":        {"read"},
				"parfum":      {"read"},
				"layanan":     {"read"},
				"diskon":      {"read"},
				"laporan":     defaultReportPermissions(),
			},
		},
		{
			Nama: "Investor",
			Perms: map[string][]string{
				"transaksi":   {"read"},
				"pengeluaran": {"read"},
				"laporan":     defaultReportPermissions(),
				"outlet":      {"read"},
			},
		},
	}

	for _, d := range defaults {
		permissionJSON, err := json.Marshal(d.Perms)
		if err != nil {
			return fmt.Errorf("gagal menyiapkan permission role %s: %v", d.Nama, err)
		}
		role := model.Role{
			ID:       utils.GenRoleID(tx, outletID),
			OutletID: outletID,
			Nama:     d.Nama,
			// KONVERSI: Mengubah string JSON mentah menjadi json.RawMessage
			Permission:     permissionJSON,
			UserUpdate:     ownerID,
			UserUpdateType: "user",
		}

		if err := tx.Create(&role).Error; err != nil {
			return fmt.Errorf("gagal insert role %s: %v", d.Nama, err)
		}
	}

	return nil
}

func defaultReportPermissions() []string {
	return []string{
		"read_home_summary",
		"read_daily_summary",
		"read_omset",
		"read_pengeluaran",
		"read_pendapatan",
		"read_profit_loss",
		"read_transaction",
		"read_service_summary",
		"read_customer",
		"read_debt",
	}
}

func (s *RoleService) List(outletID string) ([]model.Role, error) {
	var roles []model.Role
	err := s.db.Where("rl_outlet = ?", outletID).Order("rl_id ASC").Find(&roles).Error
	return roles, err
}

func (s *RoleService) Update(role model.Role) error {
	// 1. Validasi Keberadaan
	var count int64
	s.db.Model(&model.Role{}).Where("rl_id = ? AND rl_outlet = ?", role.ID, role.OutletID).Count(&count)
	if count == 0 {
		return errors.New("role tidak ditemukan atau akses ditolak")
	}

	// 2. Validasi Duplikasi Nama
	var dupCount int64
	s.db.Model(&model.Role{}).Where("rl_outlet = ? AND rl_nama = ? AND rl_id != ?", role.OutletID, role.Nama, role.ID).Count(&dupCount)
	if dupCount > 0 {
		return errors.New("nama role sudah digunakan oleh role lain")
	}

	// 3. Update role dan cabut token pegawai yang masih membawa permission lama.
	return s.db.Transaction(func(tx *gorm.DB) error {
		if err := tx.Model(&model.Role{}).
			Where("rl_id = ? AND rl_outlet = ?", role.ID, role.OutletID).
			Updates(map[string]interface{}{
				"rl_nama":            role.Nama,
				"rl_permission":      role.Permission,
				"rl_userupdate":      role.UserUpdate,
				"rl_userupdate_type": role.UserUpdateType,
			}).Error; err != nil {
			return err
		}

		return tx.Model(&model.Pegawai{}).
			Where("pg_role = ? AND pg_deleted_at IS NULL", role.ID).
			Update("pg_token_version", gorm.Expr("pg_token_version + 1")).Error
	})
}

func (s *RoleService) Delete(id string, outletID string) error {
	var roleCount int64
	s.db.Model(&model.Role{}).Where("rl_id = ? AND rl_outlet = ?", id, outletID).Count(&roleCount)
	if roleCount == 0 {
		return errors.New("role tidak ditemukan")
	}

	// Cek apakah masih ada pegawai yang memakai role ini
	var pgCount int64
	s.db.Table("ac_pegawai").Where("pg_role = ? AND pg_outlet = ?", id, outletID).Count(&pgCount)
	if pgCount > 0 {
		return errors.New("role tidak bisa dihapus karena masih digunakan oleh pegawai")
	}

	return s.db.Where("rl_id = ? AND rl_outlet = ?", id, outletID).Delete(&model.Role{}).Error
}
