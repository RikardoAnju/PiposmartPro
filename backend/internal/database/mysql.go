package database

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"encoding/json"
	"fmt"
	"strings"

	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

func InitDB(dsn string) (*gorm.DB, error) {
	db, err := gorm.Open(mysql.Open(dsn), &gorm.Config{
		DisableForeignKeyConstraintWhenMigrating: true,
	})
	if err != nil {
		return nil, err
	}

	// Force Session Timezone ke WIB (+07:00) agar NOW() dan filter tanggal sinkron
	sqlDB, _ := db.DB()
	sqlDB.Exec("SET time_zone = '+07:00'")

	fmt.Println("🚀 Running Auto Migration...")
	// Paksa setiap tabel baru dibuat dengan collation utf8mb4_unicode_ci,
	// menyamai tabel-tabel lama. Tanpa ini, AutoMigrate memakai default
	// database (di MySQL 8/9 = utf8mb4_0900_ai_ci) sehingga tabel baru beda
	// collation → JOIN lintas-tabel gagal "Illegal mix of collations".
	migrator := db.Set(
		"gorm:table_options",
		"ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
	)
	err = migrator.AutoMigrate(
		&model.User{},
		&model.Outlet{},
		&model.OutletHistoryNama{}, // Riwayat perubahan nama outlet
		&model.Role{},
		&model.DataMigration{},
		&model.Pegawai{},
		&model.PegawaiHistory{},
		&model.SalaryConfig{},
		&model.AttendanceConfiguration{},
		&model.AttendanceRecord{},
		&model.AttendanceOvertime{},
		&model.AttendanceLeave{},
		&model.AttendanceHoliday{},
		&model.PayrollPeriod{},
		&model.PayrollItem{},
		&model.PayrollItemComponent{},
		&model.PayrollPayment{},
		&model.PayrollItemSnapshot{},
		&model.Pelanggan{},
		&model.CustomerDepositAccount{},
		&model.CustomerDepositTopup{},
		&model.CustomerDepositAdjustment{},
		&model.CustomerDepositLedger{},
		&model.Parfum{},
		&model.Diskon{},
		&model.MetodePembayaran{},
		&model.Item{},
		&model.KategoriPengeluaran{}, // Ditambahkan jika sebelumnya tertinggal
		&model.Pengeluaran{},

		// --- SISTEM ADD-ON & AKTIVASI (FULL UPDATE) ---
		&model.Addon{},                // Tabel ac_addons (Katalog)
		&model.TransaksiAddon{},       // Tabel ac_transaksi_addons (Header)
		&model.DetailTransaksiAddon{}, // Tabel ac_detail_transaksi_addons (Item Belanja)
		&model.HistoryAddon{},         // Tabel ac_history_addons (Akses Fitur)

		// --- SISTEM TOPUP KOIN ---
		&model.Voucher{},
		&model.TopupKoin{},
		&model.HistoryKoin{},
		&model.StoreTransaction{},

		// --- SISTEM NOTIFIKASI (NORMALIZED) ---
		&model.NotifMaster{},   // Tabel ac_notif_master
		&model.NotifReceiver{}, // Tabel ac_notif_receiver
		&model.NotifEvent{},
		&model.NotifTemplate{},
		&model.LifecycleEvent{},
		&model.LifecycleAutomationRun{},
		&model.LifecycleAutomationRule{},
		&model.PushToken{},

		// --- LAYANAN & PRODUK ---
		&model.Layanan{},
		&model.JenisProduk{},

		// --- INVENTORY SYSTEM ---
		&model.InventoryCategory{},       // Tabel ac_inventory_category
		&model.InventoryItem{},           // Tabel ac_inventory_item
		&model.InventoryStockMovement{},  // Tabel ac_inventory_stock_movement
		&model.InventorySetting{},        // Tabel ac_inventory_setting

		// --- TRANSAKSI ---
		&model.Transaksi{},
		&model.DetailTransaksi{},
		&model.ItemTransaksi{},
		&model.DPTransaksi{},
		&model.LogTransaksi{},
		&model.NobuPaymentTransaction{},
		&model.NobuProviderEvent{},
		&model.NobuCallbackToken{},
		&model.NobuCallbackAudit{},
		&model.OwnerPayable{},
		&model.NobuFundLedger{},
		&model.SettlementBatch{},
		&model.SettlementItem{},
		&model.ReconciliationRecord{},
		&model.NotaSetting{},
		&model.OTPRequestLog{},
		&model.EmailDispatchLog{},
		&model.EconomyConfig{},
		&model.AdminRole{}, // Harus sebelum Admin karena Admin punya FK ke AdminRole
		&model.Admin{},
		&model.BankAccount{},
		&model.KoinPackage{},
		&model.ContentBanner{},
		&model.Tutorial{},
		&model.LegalDocument{},
		&model.ReferralReward{},
		&model.ReferralPayoutItem{},
		&model.ReferralWalletHistory{},
		&model.ReferralPayoutRequest{},
		&model.ReferralPayoutAccount{},
		&model.AccountDeletion{},
		&model.AppSetting{},
		&model.SalesLeadStatus{}, // Status tindak-lanjut sales (halaman Target Sales)
		&model.ResetBackup{},     // Track outlet data resets
		&model.LeadOpsSource{},
		&model.LeadOpsLead{},
		&model.LeadOpsAssignment{},
		&model.LeadOpsFollowUp{},
		&model.LeadOpsStatusHistory{},
		&model.LeadOpsOpportunity{},
		&model.FeatureRequest{},
		&model.FeatureRequestVote{},
		&model.FeatureRequestAttachment{},
	)

	if err != nil {
		fmt.Printf("❌ Auto Migration Failed: %v\n", err)
		return nil, err
	}

	if err := disableDeleteOnExistingDefaultRoles(db); err != nil {
		return nil, fmt.Errorf("migrate default role permissions: %w", err)
	}

	fmt.Println("✅ Auto Migration Successful!")
	// REFUND lama dipakai untuk dua arti. Mutasi dengan referensi transaksi
	// sebenarnya hanya membatalkan pemakaian saldo, bukan mengembalikan uang
	// top-up. Pisahkan tipenya agar laporan tidak menghitung refund dua kali.
	if err := db.Exec(`UPDATE ac_customer_deposit_ledger l
		JOIN ac_transaksi tr ON tr.tr_id = l.cdl_reference
		LEFT JOIN ac_customer_deposit_adjustments a ON a.caj_id = l.cdl_reference
		SET l.cdl_entry_type = 'USAGE_REVERSAL'
		WHERE l.cdl_entry_type = 'REFUND' AND a.caj_id IS NULL`).Error; err != nil {
		return nil, fmt.Errorf("migrate deposit usage reversals: %w", err)
	}
	// Financial reports keep corrections in the original top-up period because
	// they fix a recording error rather than move cash today. Refunds stay on
	// their actual date because money is returned on that date. Audit rows and
	// ledger timestamps remain untouched.
	if err := db.Exec(`CREATE OR REPLACE VIEW ac_customer_deposit_cash_events AS
		SELECT cdt_id, cdt_outlet, cdt_customer, cdt_type, cdt_value,
			cdt_total_paid, cdt_discount, cdt_payment_method, cdt_created_by, cdt_created,
			'TOP_UP' AS cdt_event_type
		FROM ac_customer_deposit_topups
		UNION ALL
		SELECT a.caj_id, a.caj_outlet, a.caj_customer, a.caj_type, a.caj_cash_delta,
			a.caj_cash_delta,
			CASE WHEN a.caj_kind = 'CORRECTION' AND UPPER(a.caj_type) = 'RUPIAH'
				THEN a.caj_value_delta - a.caj_cash_delta ELSE 0 END,
			CASE WHEN a.caj_kind = 'CORRECTION' THEN t.cdt_payment_method ELSE a.caj_payment_method END,
			a.caj_created_by,
			CASE WHEN a.caj_kind = 'CORRECTION' THEN t.cdt_created ELSE a.caj_created END,
			a.caj_kind
		FROM ac_customer_deposit_adjustments a
		JOIN ac_customer_deposit_topups t ON t.cdt_id = a.caj_topup`).Error; err != nil {
		return nil, fmt.Errorf("create deposit cash events view: %w", err)
	}

	// Payroll tables sempat dibuat dengan panjang ID yang terlalu pendek di
	// iterasi awal. Paksa lebarkan kolom ID agar UUID payroll/config bisa
	// tersimpan tanpa error "Data too long".
	_ = db.Migrator().AlterColumn(&model.SalaryConfig{}, "ID")
	_ = db.Migrator().AlterColumn(&model.SalaryConfig{}, "PegawaiID")
	_ = db.Migrator().AlterColumn(&model.PayrollPeriod{}, "ID")
	_ = db.Migrator().AlterColumn(&model.PayrollItem{}, "ID")
	_ = db.Migrator().AlterColumn(&model.PayrollItem{}, "PeriodID")
	_ = db.Migrator().AlterColumn(&model.PayrollItem{}, "PegawaiID")
	_ = db.Migrator().AlterColumn(&model.PayrollItemComponent{}, "ID")
	_ = db.Migrator().AlterColumn(&model.PayrollItemComponent{}, "ItemID")
	_ = db.Migrator().AlterColumn(&model.PayrollPayment{}, "ID")
	_ = db.Migrator().AlterColumn(&model.PayrollPayment{}, "PeriodID")

	// --- PATCH: Pastikan master admin selalu punya adm_is_master = true ---
	// Handles kasus database lama yang sudah punya admin tapi belum ada kolom is_master
	db.Model(&model.Admin{}).Where("adm_id = ? AND adm_is_master = ?", "ADM.000001", false).
		Update("adm_is_master", true)

	// --- AUTO SEED ADMIN (If Empty) ---
	var adminCount int64
	db.Model(&model.Admin{}).Count(&adminCount)
	if adminCount == 0 {
		fmt.Println("🌱 Seeding Default Admin Account...")
		hashedPassword, _ := utils.HashPassword("admin123")
		admin := model.Admin{
			ID:       "ADM.000001",
			Nama:     "Super Admin",
			Email:    "admin@com",
			Password: hashedPassword,
			IsMaster: true, // Super Admin punya akses penuh ke semua fitur
		}
		if err := db.Create(&admin).Error; err != nil {
			fmt.Printf("❌ Failed to seed Admin: %v\n", err)
		} else {
			fmt.Println("✅ Default Admin Seeded: admin@com / admin123")
		}
	}

	ensureAdminRolePermissionCompat(db)

	return db, nil
}

const disableDefaultRoleDeleteMigration = "20261005_disable_default_role_delete_v1"

func disableDeleteOnExistingDefaultRoles(db *gorm.DB) error {
	return db.Transaction(func(tx *gorm.DB) error {
		var count int64
		if err := tx.Model(&model.DataMigration{}).
			Where("dm_key = ?", disableDefaultRoleDeleteMigration).
			Count(&count).Error; err != nil {
			return err
		}
		if count > 0 {
			return nil
		}

		var roles []model.Role
		if err := tx.Where("LOWER(TRIM(rl_nama)) IN ?", []string{"admin", "kasir"}).Find(&roles).Error; err != nil {
			return err
		}

		for _, role := range roles {
			permissions, changed := permissionsWithoutDelete(role.Permission)
			if !changed {
				continue
			}
			encoded, err := json.Marshal(permissions)
			if err != nil {
				return err
			}
			if err := tx.Model(&model.Role{}).
				Where("rl_id = ?", role.ID).
				Update("rl_permission", string(encoded)).Error; err != nil {
				return err
			}
			// Permission tersimpan di JWT pegawai. Cabut token lama agar akses
			// delete yang sudah terbit tidak tetap berlaku sampai token kedaluwarsa.
			if err := tx.Model(&model.Pegawai{}).
				Where("pg_role = ? AND pg_deleted_at IS NULL", role.ID).
				Update("pg_token_version", gorm.Expr("pg_token_version + 1")).Error; err != nil {
				return err
			}
		}

		return tx.Create(&model.DataMigration{Key: disableDefaultRoleDeleteMigration}).Error
	})
}

func permissionsWithoutDelete(raw json.RawMessage) (map[string][]string, bool) {
	permissions := map[string][]string{}
	if err := json.Unmarshal(raw, &permissions); err != nil {
		return permissions, false
	}

	changed := false
	for module, actions := range permissions {
		next := make([]string, 0, len(actions))
		for _, action := range actions {
			switch action {
			case "delete":
				changed = true
			case "all":
				next = append(next, safeActionsForModule(module)...)
				changed = true
			default:
				next = append(next, action)
			}
		}
		permissions[module] = uniqueStrings(next)
	}
	return permissions, changed
}

func safeActionsForModule(module string) []string {
	switch module {
	case "transaksi":
		return []string{"create", "read", "update", "update_status", "update_delivery_fee"}
	case "laporan":
		return []string{
			"read_home_summary", "read_daily_summary", "read_omset",
			"read_pengeluaran", "read_pendapatan", "read_profit_loss",
			"read_transaction", "read_service_summary", "read_customer", "read_debt",
		}
	case "outlet":
		return []string{"read"}
	default:
		return []string{"create", "read", "update"}
	}
}

func uniqueStrings(values []string) []string {
	seen := make(map[string]struct{}, len(values))
	result := make([]string, 0, len(values))
	for _, value := range values {
		if _, exists := seen[value]; exists {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}
	return result
}

func ensureAdminRolePermissionCompat(db *gorm.DB) {
	type roleRow struct {
		ID          string
		Nama        string
		Permissions string
	}

	var roles []roleRow
	if err := db.Table("ac_admin_role").Select("ar_id as id, ar_nama as nama, ar_permissions as permissions").Find(&roles).Error; err != nil {
		fmt.Printf("⚠️ unable to scan admin roles for permission compat: %v\n", err)
		return
	}

	for _, role := range roles {
		if strings.TrimSpace(role.Permissions) == "" {
			continue
		}

		var perms map[string][]string
		if err := json.Unmarshal([]byte(role.Permissions), &perms); err != nil {
			continue
		}

		changed := false
		switch {
		case strings.Contains(strings.ToLower(role.Nama), "growth"), strings.Contains(strings.ToLower(role.Nama), "marketing"):
			changed = mergePermission(&perms, "lead-ops", []string{"read", "create", "update", "export"}) || changed
		case strings.Contains(strings.ToLower(role.Nama), "admin"), strings.Contains(strings.ToLower(role.Nama), "ops"):
			changed = mergePermission(&perms, "lead-ops", []string{"read", "create", "update", "export"}) || changed
		}

		if !changed {
			continue
		}

		next, err := json.Marshal(perms)
		if err != nil {
			continue
		}

		if err := db.Table("ac_admin_role").
			Where("ar_id = ?", role.ID).
			Update("ar_permissions", string(next)).Error; err != nil {
			fmt.Printf("⚠️ unable to update compat permissions for role %s: %v\n", role.Nama, err)
		}
	}
}

func mergePermission(perms *map[string][]string, module string, actions []string) bool {
	if *perms == nil {
		*perms = map[string][]string{}
	}
	current, ok := (*perms)[module]
	if !ok {
		(*perms)[module] = actions
		return true
	}

	set := map[string]struct{}{}
	for _, a := range current {
		set[a] = struct{}{}
	}

	changed := false
	for _, a := range actions {
		if _, exists := set[a]; !exists {
			current = append(current, a)
			changed = true
		}
	}
	(*perms)[module] = current
	return changed
}
