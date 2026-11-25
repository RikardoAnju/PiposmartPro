package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"errors"
	"strings"

	"time"

	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type PegawaiService struct {
	db *gorm.DB
}

func NewPegawaiService(db *gorm.DB) *PegawaiService {
	return &PegawaiService{db: db}
}

func (s *PegawaiService) Create(p model.Pegawai, actorID string) (model.Pegawai, error) {
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// 1. Ambil data Outlet untuk cek kuota base.
		// Lock baris outlet (FOR UPDATE) supaya create pegawai untuk outlet yang
		// sama diserialisasi — mencegah race melewati batas MaxPegawaiBase.
		var outlet model.Outlet
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).
			Where("ot_id = ?", p.OutletID).First(&outlet).Error; err != nil {
			return errors.New("outlet tidak ditemukan")
		}

		// 2. Hitung jumlah pegawai tipe 'base' yang MEMEGANG slot (semua base
		// yang belum dihapus — aktif maupun non-aktif). Base non-aktif tetap
		// memegang slotnya, sehingga menonaktifkan base TIDAK membebaskan slot
		// untuk base baru. Ini mencegah bug jumlah base melebihi kuota
		// (mis. deactivate 1 base lalu create → malah jadi 3 base-type).
		var baseStaffCount int64
		tx.Model(&model.Pegawai{}).Where("pg_outlet = ? AND pg_type = ? AND pg_deleted_at IS NULL", p.OutletID, "base").Count(&baseStaffCount)

		// 3. LOGIKA KUOTA & FLAGGING TYPE (Independen per Pegawai)
		if baseStaffCount < int64(outlet.MaxPegawaiBase) {
			p.Type = "base"
			p.ActiveUntil = nil // Base staff aktif selamanya (selama status=1)
		} else {
			// Pegawai ke-3 dst masuk kategori addon
			p.Type = "addon"

			// Jika owner mau create, dia harus beli addon dulu.
			// Disini kita default statusnya non-aktif (0) jika ActiveUntil kosong
			if p.ActiveUntil == nil || p.ActiveUntil.Before(time.Now()) {
				p.Status = 0
				// Kita tetep izinkan simpan data, tapi status non-aktif (suruh owner bayar di UI)
			}
		}

		// 4. Validasi Keunikan (abaikan pegawai yang sudah dihapus).
		// Email wajib → selalu dicek. No HP opsional → hanya dicek bila diisi,
		// supaya beberapa pegawai tanpa No HP tidak saling menolak.
		var emailCount int64
		tx.Model(&model.Pegawai{}).
			Where("pg_outlet = ? AND pg_email = ? AND pg_deleted_at IS NULL", p.OutletID, p.Email).
			Count(&emailCount)
		if emailCount > 0 {
			return errors.New("email sudah digunakan di outlet ini")
		}
		if strings.TrimSpace(p.NoHP) != "" {
			var phoneCount int64
			tx.Model(&model.Pegawai{}).
				Where("pg_outlet = ? AND pg_nohp = ? AND pg_deleted_at IS NULL", p.OutletID, p.NoHP).
				Count(&phoneCount)
			if phoneCount > 0 {
				return errors.New("nomor HP sudah digunakan di outlet ini")
			}
		}

		// 5. Validasi Role
		var roleCount int64
		tx.Model(&model.Role{}).Where("rl_id = ? AND rl_outlet = ?", p.RoleID, p.OutletID).Count(&roleCount)
		if roleCount == 0 {
			return errors.New("role tidak valid")
		}

		// 6. Set ID & Hash Password
		p.ID = utils.GenPegawaiID(tx, p.OutletID)
		if p.Password == nil || *p.Password == "" {
			return errors.New("password wajib diisi")
		}
		hashed, err := bcrypt.GenerateFromPassword([]byte(*p.Password), bcrypt.DefaultCost)
		if err != nil {
			return errors.New("gagal mengamankan password")
		}
		passStr := string(hashed)
		p.Password = &passStr

		// 7. Simpan Data
		// Simpan status yang sudah diputuskan oleh logika kuota. Field model punya
		// default database 1, sehingga GORM dapat mengganti zero-value menjadi 1
		// saat create jika tidak dipaksa kembali secara eksplisit.
		desiredStatus := p.Status
		if err := tx.Create(&p).Error; err != nil {
			return normalizePegawaiDBError(err)
		}
		if err := tx.Model(&model.Pegawai{}).
			Where("pg_id = ?", p.ID).
			UpdateColumn("pg_status", desiredStatus).Error; err != nil {
			return err
		}
		p.Status = desiredStatus
		_ = s.recordPegawaiHistory(tx, p, "created", actorID, "pegawai")
		return nil
	})

	return p, err
}

func normalizePegawaiDBError(err error) error {
	if err == nil {
		return nil
	}

	msg := strings.ToLower(err.Error())
	if strings.Contains(msg, "duplicate entry") {
		if strings.Contains(msg, "pg_email") {
			return errors.New("email login sudah digunakan. Gunakan email lain")
		}
		if strings.Contains(msg, "pg_nohp") || strings.Contains(msg, "nohp") {
			return errors.New("nomor HP sudah digunakan. Gunakan nomor lain")
		}
		return errors.New("data pegawai sudah pernah terdaftar")
	}

	return err
}

func (s *PegawaiService) List(outletID string) ([]model.Pegawai, error) {
	var pegawai []model.Pegawai
	err := s.db.Preload("Role").Where("pg_outlet = ? AND pg_deleted_at IS NULL", outletID).Find(&pegawai).Error
	return pegawai, err
}

func (s *PegawaiService) GetByID(id string) (model.Pegawai, error) {
	var pegawai model.Pegawai
	err := s.db.Preload("Role").Where("pg_id = ?", id).First(&pegawai).Error
	return pegawai, err
}

func (s *PegawaiService) UpdatePartial(id string, outletID string, updates map[string]interface{}, rawPassword string, actorID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var existing model.Pegawai
		if err := tx.Where("pg_id = ? AND pg_outlet = ? AND pg_deleted_at IS NULL", id, outletID).First(&existing).Error; err != nil {
			return errors.New("pegawai tidak ditemukan")
		}

		// VALIDASI AKTIVASI (Jika mengubah status ke Aktif)
		newStatus, statusOk := updates["pg_status"]
		if statusOk && (newStatus == 1 || newStatus == "1") && existing.Status != 1 {
			// Jika addon, cek masa berlaku
			if existing.Type == "addon" {
				if existing.ActiveUntil == nil || existing.ActiveUntil.Before(time.Now()) {
					return errors.New("tidak bisa mengaktifkan pegawai. Masa aktif addon pegawai ini telah habis")
				}
			} else {
				// Jika base, pastikan kuota base tidak over-capacity (misal ada case ganti type)
				var baseActiveCount int64
				tx.Model(&model.Pegawai{}).Where("pg_outlet = ? AND pg_type = ? AND pg_status = 1", outletID, "base").Count(&baseActiveCount)

				var outlet model.Outlet
				tx.Where("ot_id = ?", outletID).First(&outlet)

				if baseActiveCount >= int64(outlet.MaxPegawaiBase) {
					return errors.New("kuota pegawai gratis sudah penuh. Silakan ubah pegawai lain menjadi non-aktif terlebih dahulu")
				}
			}
		}

		if rawPassword != "" {
			hashed, err := bcrypt.GenerateFromPassword([]byte(rawPassword), bcrypt.DefaultCost)
			if err != nil {
				return errors.New("gagal mengamankan password")
			}
			updates["pg_password"] = string(hashed)
		}

		// Menonaktifkan akun harus sekaligus mencabut seluruh token yang sudah
		// diterbitkan. Login berikutnya tetap ditahan oleh pg_status.
		if statusOk && (newStatus == 0 || newStatus == "0") && existing.Status == 1 {
			updates["pg_token_version"] = gorm.Expr("pg_token_version + 1")
		}
		if access, ok := updates["pg_all_outlet_access"]; ok {
			updates["pg_token_version"] = gorm.Expr("pg_token_version + 1")
			if enabled, isBool := access.(bool); isBool && !enabled {
				updates["pg_last_outlet"] = nil
			}
		}

		if err := tx.Model(&existing).Updates(updates).Error; err != nil {
			return normalizePegawaiDBError(err)
		}

		var updated model.Pegawai
		if err := tx.Where("pg_id = ?", id).First(&updated).Error; err == nil {
			_ = s.recordPegawaiHistory(tx, updated, "updated", actorID, "pegawai")
		}
		return nil
	})
}

// Fungsi Perpanjangan Addon Pegawai (Dipanggil oleh AddonService setelah payment success)
func (s *PegawaiService) ExtendAddon(pegawaiID string, months int) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var p model.Pegawai
		if err := tx.Where("pg_id = ? AND pg_deleted_at IS NULL", pegawaiID).First(&p).Error; err != nil {
			return err
		}

		now := time.Now()
		var newExpiry time.Time

		// Jika sudah punya ActiveUntil dan belum expired, tambahkan dari tgl tersebut
		if p.ActiveUntil != nil && p.ActiveUntil.After(now) {
			newExpiry = p.ActiveUntil.AddDate(0, months, 0)
		} else {
			// Jika baru atau sudah expired, tambahkan dari hari ini
			newExpiry = now.AddDate(0, months, 0)
		}

		return tx.Model(&p).Updates(map[string]interface{}{
			"pg_active_until": newExpiry,
			"pg_status":       1, // Otomatis aktifkan kembali
		}).Error
	})
}

// Check Expired Addons (Bisa dijalankan via Cron Job)
func (s *PegawaiService) CheckExpiredAddons() error {
	// Non-aktifkan semua pegawai addon yang masa aktifnya lewat hari ini
	return s.db.Model(&model.Pegawai{}).
		Where("pg_type = ? AND pg_status = 1 AND pg_active_until < ? AND pg_deleted_at IS NULL", "addon", time.Now()).
		Update("pg_status", 0).Error
}

func (s *PegawaiService) Delete(id string, outletID string, actorID string) error {
	if id == actorID {
		return errors.New("tidak dapat menghapus diri sendiri")
	}
	return s.db.Transaction(func(tx *gorm.DB) error {
		var pegawai model.Pegawai
		if err := tx.Where("pg_id = ? AND pg_outlet = ? AND pg_deleted_at IS NULL", id, outletID).First(&pegawai).Error; err != nil {
			return errors.New("pegawai tidak ditemukan")
		}

		now := time.Now()
		pegawai.Status = 0
		pegawai.DeletedAt = &now
		pegawai.TokenVersion = pegawai.TokenVersion + 1
		if err := tx.Model(&pegawai).Updates(map[string]any{
			"pg_status":        0,
			"pg_deleted_at":    &now,
			"pg_token_version": gorm.Expr("pg_token_version + 1"),
		}).Error; err != nil {
			return err
		}

		return s.recordPegawaiHistory(tx, pegawai, "deleted", actorID, "pegawai")
	})
}

func (s *PegawaiService) ForceLogout(id string, outletID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var pegawai model.Pegawai
		if err := tx.Where("pg_id = ? AND pg_outlet = ? AND pg_deleted_at IS NULL", id, outletID).First(&pegawai).Error; err != nil {
			return errors.New("pegawai tidak ditemukan")
		}

		return tx.Model(&pegawai).Update("pg_token_version", gorm.Expr("pg_token_version + 1")).Error
	})
}

func (s *PegawaiService) recordPegawaiHistory(tx *gorm.DB, p model.Pegawai, action string, actorID string, actorType string) error {
	snapshot := map[string]any{
		"id":            p.ID,
		"outlet_id":     p.OutletID,
		"role_id":       p.RoleID,
		"nama":          p.Nama,
		"email":         p.Email,
		"nohp":          p.NoHP,
		"tanggal_lahir": p.TanggalLahir,
		"status":        p.Status,
		"type":          p.Type,
		"active_until":  p.ActiveUntil,
		"deleted_at":    p.DeletedAt,
		"token_version": p.TokenVersion,
		"created_at":    p.CreatedAt,
		"updated_at":    p.UpdatedAt,
	}
	payload, err := json.Marshal(snapshot)
	if err != nil {
		return err
	}

	history := model.PegawaiHistory{
		ID:        utils.GenNotifID(),
		OutletID:  p.OutletID,
		PegawaiID: p.ID,
		Action:    action,
		Snapshot:  string(payload),
	}
	if strings.TrimSpace(actorID) != "" {
		history.ActorID = &actorID
	}
	if strings.TrimSpace(actorType) != "" {
		history.ActorType = &actorType
	}
	return tx.Create(&history).Error
}
