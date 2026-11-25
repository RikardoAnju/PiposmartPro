package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strconv"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type OutletService struct {
	db         *gorm.DB
	roleSvc    *RoleService
	parfumSvc  *ParfumService
	layananSvc *LayananService
	katExpSvc  *KategoriPengeluaranService
	paySvc     *MetodePembayaranService
	itemSvc    *ItemService
}

func NewOutletService(
	db *gorm.DB,
	role *RoleService,
	parfum *ParfumService,
	layanan *LayananService,
	katExp *KategoriPengeluaranService,
	pay *MetodePembayaranService,
	item *ItemService,
) *OutletService {
	return &OutletService{
		db:         db,
		roleSvc:    role,
		parfumSvc:  parfum,
		layananSvc: layanan,
		katExpSvc:  katExp,
		paySvc:     pay,
		itemSvc:    item,
	}
}

func (s *OutletService) Create(p model.Outlet) (model.Outlet, error) {
	err := s.db.Transaction(func(tx *gorm.DB) error {
		now := time.Now()
		ownerIDStr := strconv.FormatUint(uint64(p.UserID), 10)
		var existingOutlets int64
		var cfgBase model.EconomyConfig
		seedBonusKoin := 20

		if err := tx.Model(&model.Outlet{}).Where("ot_user = ?", p.UserID).Count(&existingOutlets).Error; err != nil {
			return fmt.Errorf("gagal mengecek outlet user: %v", err)
		}

		isAdditionalOutlet := existingOutlets > 0
		if err := tx.Where("cfg_key = ?", "bonus_koin_new_user").First(&cfgBase).Error; err == nil {
			if parsed, errParse := strconv.Atoi(cfgBase.Value); errParse == nil && parsed > 0 {
				seedBonusKoin = parsed
			}
		}

		// 1. Setup ID Outlet & Saldo Koin
		p.ID = utils.GenOutletID(tx, p.UserID)
		if isAdditionalOutlet {
			p.Koin = 0
		} else {
			p.Koin = seedBonusKoin // Bonus pendaftaran outlet pertama mengikuti economy config
		}
		p.IsMetodePembayaran = 1
		p.IsFiturDiskon = 1

		// 2. LOGIK TRIAL & LIMITASI
		p.MaxPegawaiBase = 2 // Slot pegawai gratis tetap 2
		if isAdditionalOutlet {
			// Outlet tambahan tidak langsung PRO; trial-nya habis agar wajib aktivasi.
			p.TrialExpiresAt = now
			p.ActivatedAt = nil
		} else {
			p.TrialExpiresAt = now.AddDate(0, 0, 31) // Masa trial 30 hari (+1 hari toleransi)
			p.ActivatedAt = nil                      // Status permanent: Belum (Null)
		}

		// 3. Simpan entitas Outlet
		if err := tx.Create(&p).Error; err != nil {
			return fmt.Errorf("gagal simpan outlet: %v", err)
		}

		// 4. Simpan Riwayat Mutasi Koin Awal hanya untuk outlet pertama
		if !isAdditionalOutlet {
			historyKoin := model.HistoryKoin{
				ID:             utils.GenHistoryKoinID(tx, p.ID),
				OutletID:       p.ID,
				JenisTransaksi: "masuk",
				Keterangan:     "Bonus pendaftaran outlet baru",
				Status:         1,
				Jumlah:         seedBonusKoin,
				CreatedAt:      now,
				UserUpdate:     ownerIDStr,
			}
			if err := tx.Create(&historyKoin).Error; err != nil {
				return fmt.Errorf("gagal mencatat riwayat koin: %v", err)
			}
		}

		// 5. KIRIM NOTIFIKASI SELAMAT DATANG
		if err := s.createOutletWelcomeNotification(tx, p.ID, isAdditionalOutlet, now); err != nil {
			return err
		}

		// 6. BOOTSTRAP DATA DEFAULT (Seeder)
		if err := s.roleSvc.CreateDefaultRoles(tx, p.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat role default: %v", err)
		}
		if err := s.parfumSvc.CreateDefaultParfums(tx, p.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat parfum default: %v", err)
		}
		if err := s.layananSvc.CreateDefaultLayanans(tx, p.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat layanan default: %v", err)
		}
		if err := s.katExpSvc.CreateDefaultCategories(tx, p.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat kategori pengeluaran default: %v", err)
		}
		if err := s.paySvc.CreateDefaultMethods(tx, p.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat metode pembayaran default: %v", err)
		}
		if err := s.itemSvc.CreateDefaultItems(tx, p.ID, ownerIDStr); err != nil {
			return fmt.Errorf("gagal membuat item default: %v", err)
		}

		return nil
	})

	return p, err
}

func (s *OutletService) createOutletWelcomeNotification(tx *gorm.DB, outletID string, isAdditionalOutlet bool, now time.Time) error {
	nmID := uuid.New().String()
	judulNotif := utils.CleanNotificationText("Outlet Siap Digunakan", "Notifikasi AyoCuci")
	pesanNotif := utils.CleanNotificationText(
		"Outlet kamu sudah aktif. Lengkapi layanan, metode pembayaran, dan data pelanggan untuk mulai bertransaksi.",
		"Outlet kamu sudah aktif. Lengkapi data outlet untuk mulai bertransaksi.",
	)

	if !isAdditionalOutlet {
		pesanNotif = utils.CleanNotificationText(
			"Outlet kamu sudah aktif dengan akses trial 30 hari. Lengkapi layanan, metode pembayaran, dan data pelanggan untuk mulai bertransaksi.",
			"Outlet kamu sudah aktif. Lengkapi data outlet untuk mulai bertransaksi.",
		)
	} else {
		judulNotif = utils.CleanNotificationText("Outlet Tambahan Siap", "Notifikasi AyoCuci")
		pesanNotif = utils.CleanNotificationText(
			"Outlet tambahan sudah dibuat. Lakukan aktivasi PRO dan top up koin sebelum mulai transaksi.",
			"Outlet tambahan sudah dibuat. Lakukan aktivasi dan top up dulu sebelum transaksi.",
		)
	}

	if err := tx.Exec(`INSERT INTO ac_notif_master (nm_id, nm_kategori, nm_judul, nm_pesan, nm_userupdate, nm_created) 
            VALUES (?, 'SISTEM', ?, ?, 'SYSTEM', ?)`,
		nmID, judulNotif, pesanNotif, now.Format("2006-01-02 15:04:05")).Error; err != nil {
		return fmt.Errorf("gagal membuat master notifikasi: %v", err)
	}

	if err := tx.Exec(`INSERT INTO ac_notif_receiver (nr_nm_id, nr_outlet, nr_status) VALUES (?, ?, 0)`,
		nmID, outletID).Error; err != nil {
		return fmt.Errorf("gagal mapping penerima notifikasi: %v", err)
	}

	return nil
}

func (s *OutletService) GetUserOutlets(userID uint) ([]model.Outlet, error) {
	var outlets []model.Outlet
	err := s.db.Where("ot_user = ?", userID).Order("ot_created ASC").Find(&outlets).Error
	return outlets, err
}

func (s *OutletService) GetEmployeeOutlets(employeeID string) ([]model.Outlet, error) {
	var employee model.Pegawai
	if err := s.db.Where("pg_id = ? AND pg_status = 1 AND pg_deleted_at IS NULL", employeeID).First(&employee).Error; err != nil {
		return nil, errors.New("pegawai tidak ditemukan atau tidak aktif")
	}
	if !employee.AllOutletAccess {
		var outlets []model.Outlet
		err := s.db.Where("ot_id = ? AND ot_status = 1", employee.OutletID).Find(&outlets).Error
		return outlets, err
	}
	var primary model.Outlet
	if err := s.db.Where("ot_id = ?", employee.OutletID).First(&primary).Error; err != nil {
		return nil, errors.New("outlet utama pegawai tidak ditemukan")
	}
	var outlets []model.Outlet
	err := s.db.Where("ot_user = ? AND ot_status = 1", primary.UserID).Order("ot_created ASC").Find(&outlets).Error
	return outlets, err
}

func (s *OutletService) VerifyEmployeeAccess(employeeID, outletID string) (model.Pegawai, bool, error) {
	var employee model.Pegawai
	if err := s.db.Where("pg_id = ? AND pg_status = 1 AND pg_deleted_at IS NULL", employeeID).First(&employee).Error; err != nil {
		return employee, false, err
	}
	if outletID == employee.OutletID {
		return employee, true, nil
	}
	if !employee.AllOutletAccess {
		return employee, false, nil
	}
	var count int64
	err := s.db.Table("ac_outlet target").
		Joins("JOIN ac_outlet primary_outlet ON primary_outlet.ot_id = ?", employee.OutletID).
		Where("target.ot_id = ? AND target.ot_user = primary_outlet.ot_user AND target.ot_status = 1", outletID).
		Count(&count).Error
	return employee, count > 0, err
}

func (s *OutletService) UpdateEmployeeLastOutlet(employeeID, outletID string) error {
	return s.db.Model(&model.Pegawai{}).Where("pg_id = ?", employeeID).Update("pg_last_outlet", outletID).Error
}

func (s *OutletService) GetProfile(outletID string) (model.Outlet, error) {
	var outlet model.Outlet
	err := s.db.Where("ot_id = ?", outletID).First(&outlet).Error
	return outlet, err
}

func (s *OutletService) UpdateProfile(outletID string, updates map[string]interface{}) (model.Outlet, error) {
	var outlet model.Outlet
	if err := s.db.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return outlet, errors.New("outlet tidak ditemukan")
	}

	// Proteksi: Jangan izinkan update field sistem Addon & Trial via profil biasa
	delete(updates, "ot_trial_at")
	delete(updates, "ot_activated_at")
	delete(updates, "ot_max_pegawai_base")

	// Cek apakah ada perubahan nama
	oldName := outlet.Nama
	newName, hasNewName := updates["ot_nama"].(string)

	if err := s.db.Model(&outlet).Updates(updates).Error; err != nil {
		return outlet, err
	}

	// Jika update berhasil dan nama benar-benar berubah, catat ke history
	if hasNewName && newName != oldName && newName != "" {
		changedBy, _ := updates["ot_userupdate"].(string)
		changedByType, _ := updates["ot_userupdate_type"].(string)

		var changedByPtr *string
		if changedBy != "" {
			changedByPtr = &changedBy
		}
		var changedByTypePtr *string
		if changedByType != "" {
			changedByTypePtr = &changedByType
		}

		history := model.OutletHistoryNama{
			OutletID:      outletID,
			OldName:       oldName,
			NewName:       newName,
			ChangedBy:     changedByPtr,
			ChangedByType: changedByTypePtr,
		}
		// Abaikan error saat mencatat history agar tidak menggagalkan update profil utama
		s.db.Create(&history)
	}

	// Re-fetch data terbaru
	s.db.Where("ot_id = ?", outletID).First(&outlet)
	return outlet, nil
}

func (s *OutletService) VerifyOwner(userID uint, outletID string) (bool, error) {
	var count int64
	err := s.db.Model(&model.Outlet{}).
		Where("ot_id = ? AND ot_user = ?", outletID, userID).
		Count(&count).Error
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

func (s *OutletService) UpdateLastOutlet(userID uint, outletID string) error {
	return s.db.Table("ac_user").
		Where("usr_id = ?", userID).
		Update("usr_last_outlet", outletID).Error
}
