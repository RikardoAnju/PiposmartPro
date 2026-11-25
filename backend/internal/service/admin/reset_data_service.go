package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	baseService "github.com/RikardoAnju/PiposmartPro/internal/service"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type ResetDataService interface {
	ResetOutletData(outletID, resetType, reason, actorID string) (*model.ResetBackup, error)
	GetResetHistory(outletID string, limit int) ([]model.ResetBackup, error)
	GetResetDetail(resetID string) (*model.ResetBackup, error)
}

type resetDataService struct {
	db         *gorm.DB
	roleSvc    *baseService.RoleService
	parfumSvc  *baseService.ParfumService
	layananSvc *baseService.LayananService
	katExpSvc  *baseService.KategoriPengeluaranService
	paySvc     *baseService.MetodePembayaranService
	itemSvc    *baseService.ItemService
	koinSvc    *baseService.KoinService
}

func NewResetDataService(
	db *gorm.DB,
	roleSvc *baseService.RoleService,
	parfumSvc *baseService.ParfumService,
	layananSvc *baseService.LayananService,
	katExpSvc *baseService.KategoriPengeluaranService,
	paySvc *baseService.MetodePembayaranService,
	itemSvc *baseService.ItemService,
	koinSvc *baseService.KoinService,
) ResetDataService {
	return &resetDataService{
		db:         db,
		roleSvc:    roleSvc,
		parfumSvc:  parfumSvc,
		layananSvc: layananSvc,
		katExpSvc:  katExpSvc,
		paySvc:     paySvc,
		itemSvc:    itemSvc,
		koinSvc:    koinSvc,
	}
}

// ResetOutletData resets outlet operational state while keeping outlet metadata intact.
// full              => factory reset: wipe outlet operational data, reset license/koin state, and reseed default master data
// transactions_only => only transaction trees
// customers_only    => only customers
func (s *resetDataService) ResetOutletData(outletID, resetType, reason, actorID string) (*model.ResetBackup, error) {
	var outlet model.Outlet
	if err := s.db.First(&outlet, "ot_id = ?", outletID).Error; err != nil {
		return nil, fmt.Errorf("outlet not found: %w", err)
	}

	backupID := uuid.New().String()
	backup := &model.ResetBackup{
		ID:           backupID,
		OutletID:     outletID,
		ResetType:    resetType,
		Reason:       reason,
		ActorID:      actorID,
		ActorType:    "admin",
		DeletedStats: model.DeletedStats{},
	}

	tx := s.db.Begin()
	if err := tx.Error; err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}

	backupData, stats, err := s.createBackupSnapshot(tx, &outlet, resetType)
	if err != nil {
		_ = tx.Rollback().Error
		return nil, fmt.Errorf("failed to create backup: %w", err)
	}
	backup.BackupData = backupData
	backup.DeletedStats = stats

	if err := s.performReset(tx, &outlet, resetType, actorID); err != nil {
		if txErr := tx.Rollback().Error; txErr != nil {
			return nil, fmt.Errorf("failed to rollback: %w", txErr)
		}
		return nil, fmt.Errorf("failed to delete data: %w", err)
	}

	if err := tx.Create(backup).Error; err != nil {
		_ = tx.Rollback().Error
		return nil, fmt.Errorf("failed to save backup record: %w", err)
	}

	if err := tx.Commit().Error; err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	s.invalidateResetCaches(outletID)
	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "ORDER_UPDATED",
		"message": "Data outlet berhasil direset. Daftar transaksi diperbarui.",
		"payload": map[string]interface{}{
			"outlet_id":  outletID,
			"reset_type": resetType,
			"reason":     reason,
		},
	})
	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "OUTLET_UPDATED",
		"message": "Profil outlet diperbarui setelah reset data.",
		"payload": map[string]interface{}{
			"outlet_id":  outletID,
			"reset_type": resetType,
		},
	})

	return backup, nil
}

func (s *resetDataService) invalidateResetCaches(outletID string) {
	keys := []string{
		fmt.Sprintf("outlet:profile:%s", outletID),
		fmt.Sprintf("summary:dashboard:%s", outletID),
		fmt.Sprintf("pelanggan:list:v2:%s", outletID),
		fmt.Sprintf("items:list:%s", outletID),
		fmt.Sprintf("layanan:list:%s", outletID),
		fmt.Sprintf("parfum:list:%s", outletID),
		fmt.Sprintf("payment:list:v2:%s", outletID),
		fmt.Sprintf("diskon:list:%s", outletID),
		fmt.Sprintf("notif:list:%s", outletID),
		fmt.Sprintf("notif:unread:%s", outletID),
	}
	database.InvalidateCache(keys...)
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
}

func (s *resetDataService) createBackupSnapshot(tx *gorm.DB, outlet *model.Outlet, resetType string) ([]byte, model.DeletedStats, error) {
	stats := model.DeletedStats{}
	snapshot := map[string]interface{}{}

	type outletSnapshot struct {
		ID               string     `json:"ot_id"`
		Nama             string     `json:"ot_nama"`
		Koin             int        `json:"ot_koin"`
		Status           int        `json:"ot_status"`
		ActivatedAt      *time.Time `json:"ot_activated_at"`
		TrialExpiresAt   time.Time  `json:"ot_trial_at"`
		MaxPegawaiBase   int        `json:"ot_max_pegawai_base"`
		SkipProses       int        `json:"ot_skip_proses"`
		IsMetodeBayar    int        `json:"ot_metode_pembayaran"`
		IsFiturDiskon    int        `json:"ot_fitur_diskon"`
		Timezone         string     `json:"ot_timezone"`
		UserID           uint       `json:"ot_user"`
		MetadataConsumed bool       `json:"metadata_unchanged"`
	}

	snapshot["outlet"] = outletSnapshot{
		ID:             outlet.ID,
		Nama:           outlet.Nama,
		Koin:           outlet.Koin,
		Status:         outlet.Status,
		ActivatedAt:    outlet.ActivatedAt,
		TrialExpiresAt: outlet.TrialExpiresAt,
		MaxPegawaiBase: outlet.MaxPegawaiBase,
		SkipProses:     outlet.SkipProses,
		IsMetodeBayar:  outlet.IsMetodePembayaran,
		IsFiturDiskon:  outlet.IsFiturDiskon,
		Timezone:       outlet.Timezone,
		UserID:         outlet.UserID,
	}

	// Count records that will be removed. Full reset includes all outlet-owned operational data.
	if resetType == "full" || resetType == "transactions_only" {
		tx.Table("ac_transaksi").Where("tr_outlet = ?", outlet.ID).Count(&stats.Orders)
		tx.Table("ac_detail_transaksi dt").
			Joins("JOIN ac_transaksi t ON t.tr_id = dt.dtr_transaksi").
			Where("t.tr_outlet = ?", outlet.ID).
			Count(&stats.DetailTransaksi)
		tx.Table("ac_item_transaksi it").
			Joins("JOIN ac_transaksi t ON t.tr_id = it.itr_transaksi").
			Where("t.tr_outlet = ?", outlet.ID).
			Count(&stats.ItemTransaksi)
		tx.Table("ac_dp_transaksi dp").
			Joins("JOIN ac_transaksi t ON t.tr_id = dp.dptr_transaksi").
			Where("t.tr_outlet = ?", outlet.ID).
			Count(&stats.DPTransaksi)
		tx.Table("ac_log_transaksi lt").
			Joins("JOIN ac_transaksi t ON t.tr_id = lt.lr_transaksi").
			Where("t.tr_outlet = ?", outlet.ID).
			Count(&stats.LogTransaksi)

		tx.Table("ac_transaksi_addons").Where("ha_outlet = ?", outlet.ID).Count(&stats.AddonTransaksi)
		tx.Table("ac_detail_transaksi_addons dt").
			Joins("JOIN ac_transaksi_addons t ON t.ha_id = dt.dha_transaksi").
			Where("t.ha_outlet = ?", outlet.ID).
			Count(&stats.AddonDetailTransaksi)
		tx.Table("ac_history_addons").Where("ha_outlet = ?", outlet.ID).Count(&stats.AddonHistory)
	}

	if resetType == "full" || resetType == "customers_only" {
		tx.Table("ac_pelanggan").Where("pl_outlet = ?", outlet.ID).Count(&stats.Customers)
	}

	if resetType == "full" {
		tx.Table("ac_pengeluaran").Where("pg_outlet = ?", outlet.ID).Count(&stats.Expenses)
		tx.Table("ac_history_koin").Where("hk_outlet = ?", outlet.ID).Count(&stats.HistoryKoin)
		tx.Table("ac_top_koin").Where("tk_outlet = ?", outlet.ID).Count(&stats.TopupKoin)
		tx.Table("ac_diskon").Where("dis_outlet = ?", outlet.ID).Count(&stats.Diskon)
		tx.Table("ac_pegawai").Where("pg_outlet = ?", outlet.ID).Count(&stats.Pegawai)
		tx.Table("ac_role").Where("rl_outlet = ?", outlet.ID).Count(&stats.Roles)
		tx.Table("ac_layanan").Where("ly_outlet = ?", outlet.ID).Count(&stats.Layanan)
		tx.Table("ac_jenis_produk jp").
			Joins("JOIN ac_layanan l ON jp.jp_layanan = l.ly_id").
			Where("l.ly_outlet = ?", outlet.ID).
			Count(&stats.JenisProduk)
		tx.Table("ac_parfum").Where("pf_outlet = ?", outlet.ID).Count(&stats.Parfums)
		tx.Table("ac_item").Where("it_outlet = ?", outlet.ID).Count(&stats.Items)
		tx.Table("ac_metode_pembayaran").Where("mp_outlet = ?", outlet.ID).Count(&stats.MetodePembayaran)
		tx.Table("ac_kategori_pengeluaran").Where("kp_outlet = ?", outlet.ID).Count(&stats.KategoriPengeluaran)
		tx.Table("ac_notif_receiver").Where("nr_outlet = ?", outlet.ID).Count(&stats.Notifications)
	}

	stats.HistoryDiskon = 0
	stats.DPOutlet = 0

	snapshot["timestamp"] = time.Now()
	snapshot["outlet_id"] = outlet.ID
	snapshot["reset_type"] = resetType
	snapshot["stats"] = stats
	snapshot["recovery_notes"] = "Snapshot berisi ringkasan data yang akan dihapus. Reset full juga akan me-reset outlet ke state awal dan men-seed ulang master data default."

	backupJSON, err := json.Marshal(snapshot)
	if err != nil {
		return nil, stats, fmt.Errorf("failed to marshal backup: %w", err)
	}

	return backupJSON, stats, nil
}

func (s *resetDataService) performReset(tx *gorm.DB, outlet *model.Outlet, resetType, actorID string) error {
	switch resetType {
	case "transactions_only":
		return s.deleteTransactionTrees(tx, outlet.ID)
	case "customers_only":
		return tx.Where("pl_outlet = ?", outlet.ID).Delete(&model.Pelanggan{}).Error
	case "full":
		if err := s.deleteTransactionTrees(tx, outlet.ID); err != nil {
			return err
		}
		if err := tx.Where("pl_outlet = ?", outlet.ID).Delete(&model.Pelanggan{}).Error; err != nil {
			return fmt.Errorf("failed to delete pelanggan: %w", err)
		}
		if err := tx.Where("pg_outlet = ?", outlet.ID).Delete(&model.Pengeluaran{}).Error; err != nil {
			return fmt.Errorf("failed to delete pengeluaran: %w", err)
		}
		if err := tx.Where("hk_outlet = ?", outlet.ID).Delete(&model.HistoryKoin{}).Error; err != nil {
			return fmt.Errorf("failed to delete history koin: %w", err)
		}
		if err := tx.Where("tk_outlet = ?", outlet.ID).Delete(&model.TopupKoin{}).Error; err != nil {
			return fmt.Errorf("failed to delete topup koin: %w", err)
		}
		if err := tx.Where("dis_outlet = ?", outlet.ID).Delete(&model.Diskon{}).Error; err != nil {
			return fmt.Errorf("failed to delete diskon: %w", err)
		}
		if err := tx.Where("nr_outlet = ?", outlet.ID).Delete(&model.NotifReceiver{}).Error; err != nil {
			return fmt.Errorf("failed to delete notification receiver: %w", err)
		}
		if err := tx.Where("pg_outlet = ?", outlet.ID).Delete(&model.Pegawai{}).Error; err != nil {
			return fmt.Errorf("failed to delete pegawai: %w", err)
		}
		if err := tx.Unscoped().Where("jp_layanan IN (SELECT ly_id FROM ac_layanan WHERE ly_outlet = ?)", outlet.ID).Delete(&model.JenisProduk{}).Error; err != nil {
			return fmt.Errorf("failed to delete jenis produk: %w", err)
		}
		if err := tx.Where("ly_outlet = ?", outlet.ID).Delete(&model.Layanan{}).Error; err != nil {
			return fmt.Errorf("failed to delete layanan: %w", err)
		}
		if err := tx.Where("it_outlet = ?", outlet.ID).Delete(&model.Item{}).Error; err != nil {
			return fmt.Errorf("failed to delete item: %w", err)
		}
		if err := tx.Where("pf_outlet = ?", outlet.ID).Delete(&model.Parfum{}).Error; err != nil {
			return fmt.Errorf("failed to delete parfum: %w", err)
		}
		if err := tx.Where("mp_outlet = ?", outlet.ID).Delete(&model.MetodePembayaran{}).Error; err != nil {
			return fmt.Errorf("failed to delete metode pembayaran: %w", err)
		}
		if err := tx.Where("kp_outlet = ?", outlet.ID).Delete(&model.KategoriPengeluaran{}).Error; err != nil {
			return fmt.Errorf("failed to delete kategori pengeluaran: %w", err)
		}
		if err := tx.Where("rl_outlet = ?", outlet.ID).Delete(&model.Role{}).Error; err != nil {
			return fmt.Errorf("failed to delete role: %w", err)
		}

		return s.resetOutletStateAndSeed(tx, outlet, actorID)
	default:
		return fmt.Errorf("unsupported reset type: %s", resetType)
	}
}

func (s *resetDataService) deleteTransactionTrees(tx *gorm.DB, outletID string) error {
	// Child records first, then transaction headers.
	if err := tx.Exec(`
		DELETE dt FROM ac_detail_transaksi dt
		JOIN ac_transaksi t ON t.tr_id = dt.dtr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("failed to delete detail transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE it FROM ac_item_transaksi it
		JOIN ac_transaksi t ON t.tr_id = it.itr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("failed to delete item transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE dp FROM ac_dp_transaksi dp
		JOIN ac_transaksi t ON t.tr_id = dp.dptr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("failed to delete dp transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE lt FROM ac_log_transaksi lt
		JOIN ac_transaksi t ON t.tr_id = lt.lr_transaksi
		WHERE t.tr_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("failed to delete log transaksi: %w", err)
	}

	if err := tx.Where("tr_outlet = ?", outletID).Delete(&model.Transaksi{}).Error; err != nil {
		return fmt.Errorf("failed to delete transaksi: %w", err)
	}

	if err := tx.Exec(`
		DELETE dt FROM ac_detail_transaksi_addons dt
		JOIN ac_transaksi_addons t ON t.ha_id = dt.dha_transaksi
		WHERE t.ha_outlet = ?`, outletID).Error; err != nil {
		return fmt.Errorf("failed to delete detail transaksi addons: %w", err)
	}

	if err := tx.Where("ha_outlet = ?", outletID).Delete(&model.TransaksiAddon{}).Error; err != nil {
		return fmt.Errorf("failed to delete transaksi addons: %w", err)
	}

	return tx.Where("ha_outlet = ?", outletID).Delete(&model.HistoryAddon{}).Error
}

func (s *resetDataService) resetOutletStateAndSeed(tx *gorm.DB, outlet *model.Outlet, actorID string) error {
	ownerID := fmt.Sprintf("%d", outlet.UserID)
	operatorID := actorID
	if operatorID == "" {
		operatorID = ownerID
	}

	bonusKoin := 20
	var cfg model.EconomyConfig
	if err := tx.Where("cfg_key = ?", "bonus_koin_new_user").First(&cfg).Error; err == nil {
		var parsed int
		if _, scanErr := fmt.Sscanf(cfg.Value, "%d", &parsed); scanErr == nil && parsed > 0 {
			bonusKoin = parsed
		}
	}

	now := time.Now()
	if err := tx.Model(&model.Outlet{}).
		Where("ot_id = ?", outlet.ID).
		Updates(map[string]interface{}{
			"ot_koin":              bonusKoin,
			"ot_status":            1,
			"ot_activated_at":      nil,
			"ot_trial_at":          now.AddDate(0, 0, 31),
			"ot_max_pegawai_base":  2,
			"ot_skip_proses":       0,
			"ot_metode_pembayaran": 1,
			"ot_fitur_diskon":      1,
		}).Error; err != nil {
		return fmt.Errorf("failed to reset outlet state: %w", err)
	}

	if bonusKoin > 0 && s.koinSvc != nil {
		ket := fmt.Sprintf("Bonus pendaftaran outlet baru (+%d) setelah reset", bonusKoin)
		if err := s.koinSvc.AddHistoryKoin(tx, outlet.ID, "masuk", bonusKoin, ket, operatorID); err != nil {
			return fmt.Errorf("failed to create initial coin history: %w", err)
		}
	}

	if s.roleSvc == nil || s.parfumSvc == nil || s.layananSvc == nil || s.katExpSvc == nil || s.paySvc == nil || s.itemSvc == nil {
		return fmt.Errorf("reset service dependencies are not initialized")
	}

	if err := s.roleSvc.CreateDefaultRoles(tx, outlet.ID, ownerID); err != nil {
		return fmt.Errorf("failed to seed default roles: %w", err)
	}
	if err := s.parfumSvc.CreateDefaultParfums(tx, outlet.ID, ownerID); err != nil {
		return fmt.Errorf("failed to seed default parfums: %w", err)
	}
	if err := s.layananSvc.CreateDefaultLayanans(tx, outlet.ID, ownerID); err != nil {
		return fmt.Errorf("failed to seed default layanan: %w", err)
	}
	if err := s.katExpSvc.CreateDefaultCategories(tx, outlet.ID, ownerID); err != nil {
		return fmt.Errorf("failed to seed default kategori pengeluaran: %w", err)
	}
	if err := s.paySvc.CreateDefaultMethods(tx, outlet.ID, ownerID); err != nil {
		return fmt.Errorf("failed to seed default metode pembayaran: %w", err)
	}
	if err := s.itemSvc.CreateDefaultItems(tx, outlet.ID, ownerID); err != nil {
		return fmt.Errorf("failed to seed default items: %w", err)
	}

	return nil
}

// GetResetHistory retrieves recent reset operations for an outlet
func (s *resetDataService) GetResetHistory(outletID string, limit int) ([]model.ResetBackup, error) {
	var history []model.ResetBackup
	if limit <= 0 {
		limit = 10
	}

	if err := s.db.Where("rb_outlet = ?", outletID).
		Order("rb_created DESC").
		Limit(limit).
		Find(&history).Error; err != nil {
		return nil, fmt.Errorf("failed to fetch reset history: %w", err)
	}

	return history, nil
}

// GetResetDetail retrieves a specific reset operation
func (s *resetDataService) GetResetDetail(resetID string) (*model.ResetBackup, error) {
	var backup model.ResetBackup
	if err := s.db.First(&backup, "rb_id = ?", resetID).Error; err != nil {
		return nil, fmt.Errorf("reset backup not found: %w", err)
	}

	return &backup, nil
}
