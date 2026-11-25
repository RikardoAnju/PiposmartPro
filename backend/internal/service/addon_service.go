package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/model/admin"
	"github.com/RikardoAnju/PiposmartPro/internal/notifier"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/snap"
	"gorm.io/gorm"
)

type AddonService struct {
	db      *gorm.DB
	koinSvc *KoinService
	pgSvc   *PegawaiService
}

func NewAddonService(db *gorm.DB, koin *KoinService, pg *PegawaiService) *AddonService {
	return &AddonService{db: db, koinSvc: koin, pgSvc: pg}
}

// ==========================================
// 1. PRIVATE HELPERS
// ==========================================

func (s *AddonService) getSnapClient() snap.Client {
	// Baca kredensial dari environment (JANGAN hardcode). Sandbox/Production
	// ditentukan oleh MIDTRANS_IS_PRODUCTION — sama seperti KoinService, agar
	// pembelian add-on ikut ke akun Midtrans produksi saat di prod.
	var client snap.Client
	serverKey := strings.TrimSpace(config.GetEnv("MIDTRANS_SERVER_KEY", ""))
	if serverKey == "" {
		serverKey = strings.TrimSpace(config.GetEnv("MIDTRANS_SANDBOX_SERVER_KEY", ""))
	}

	env := midtrans.Sandbox
	if strings.EqualFold(strings.TrimSpace(config.GetEnv("MIDTRANS_IS_PRODUCTION", "false")), "true") {
		env = midtrans.Production
	}

	client.New(serverKey, env)
	return client
}

func (s *AddonService) getEconomyConfigs(tx *gorm.DB, keys ...string) map[string]float64 {
	var configs []model.EconomyConfig
	tx.Where("cfg_key IN ?", keys).Find(&configs)

	res := make(map[string]float64)
	for _, c := range configs {
		res[c.Key] = utils.StringToFloat64(c.Value)
	}

	if _, ok := res["price_per_coin"]; !ok {
		res["price_per_coin"] = 200.0
	}
	if _, ok := res["activation_fee"]; !ok {
		res["activation_fee"] = 1500000.0
	}

	return res
}

func (s *AddonService) getEconomyConfigValue(tx *gorm.DB, key, fallback string) string {
	var config model.EconomyConfig
	if err := tx.Where("cfg_key = ?", key).First(&config).Error; err != nil {
		return fallback
	}
	val := strings.TrimSpace(config.Value)
	if val == "" {
		return fallback
	}
	return val
}

func (s *AddonService) GetDB() *gorm.DB {
	return s.db
}

func (s *AddonService) getOutletLocation(outletID string) *time.Location {
	var ot model.Outlet
	if err := s.db.Select("ot_timezone").Where("ot_id = ?", outletID).First(&ot).Error; err != nil {
		return time.FixedZone("WIB", 7*3600)
	}
	return ot.GetLocation()
}

func (s *AddonService) nowForOutlet(outletID string) time.Time {
	return time.Now().In(s.getOutletLocation(outletID))
}

func (s *AddonService) broadcastStatus(outletID, trxID, status string) {
	title := "Status Add-on Diperbarui"
	message := "Status pembelian add-on kamu telah diperbarui."
	shouldNotify := false
	switch status {
	case "PENDING_VALIDATION":
		title = "Bukti Pembayaran Diterima"
		message = "Bukti pembayaran add-on atau aktivasi kamu sudah diterima. Tim AyoCuci akan memvalidasi pembayaran."
		shouldNotify = true
	case "SUCCESS":
		title = "Pembelian Add-on Berhasil"
		message = "Pembayaran berhasil dikonfirmasi. Fitur atau aktivasi yang kamu pilih sudah aktif."
		// Sisipkan tanggal jatuh tempo agar user tahu add-on berlaku bulanan.
		// Aktivasi PRO permanen tidak punya ha_berakhir → tetap pakai pesan dasar.
		if expiry := s.getAddonExpiryForTrx(trxID, outletID); expiry != nil {
			message = fmt.Sprintf(
				"Pembayaran berhasil dikonfirmasi. Fitur atau aktivasi yang kamu pilih sudah aktif dan berlaku sampai %s.",
				formatTanggalIndo(expiry.In(s.getOutletLocation(outletID))),
			)
		}
		shouldNotify = true
	case "FAILED":
		title = "Pembelian Add-on Tidak Berhasil"
		message = "Pembayaran add-on belum berhasil diproses. Kamu bisa mencoba lagi atau menghubungi bantuan AyoCuci."
		shouldNotify = true
	case "CANCELED":
		title = "Pembelian Add-on Dibatalkan"
		message = "Tagihan add-on atau aktivasi sudah dibatalkan."
	}

	if shouldNotify {
		if notifErr := notifier.CreateOutletNotification(
			s.db,
			outletID,
			"ADDON",
			title,
			message,
			map[string]interface{}{"id": trxID, "status": status},
		); notifErr != nil {
			fmt.Printf("Gagal membuat notifikasi add-on: %v\n", notifErr)
		}
	}

	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "ADDON_PAYMENT_STATUS",
		"title":   title,
		"message": message,
		"payload": map[string]interface{}{
			"id":     trxID,
			"status": status,
		},
	})
}

func (s *AddonService) emitOutletActivated(outletID string) {
	if strings.TrimSpace(outletID) == "" {
		return
	}

	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "OUTLET_ACTIVATED",
		"title":   "Outlet PRO Aktif",
		"message": "Outlet kamu sudah aktif permanen sebagai PRO. Semua fitur premium siap digunakan untuk operasional laundry.",
		"payload": map[string]interface{}{"outlet_id": outletID},
	})
	if notifErr := notifier.CreateOutletNotification(
		s.db,
		outletID,
		"ADDON",
		"Outlet PRO Aktif",
		"Outlet kamu sudah aktif permanen sebagai PRO. Semua fitur premium siap digunakan untuk operasional laundry.",
		map[string]interface{}{"outlet_id": outletID},
	); notifErr != nil {
		fmt.Printf("Gagal membuat notifikasi outlet aktif: %v\n", notifErr)
	}

	// Penting: cache profile baru dihapus setelah commit transaksi selesai,
	// agar request refresh berikutnya tidak mengisi ulang Redis dengan data trial lama.
	database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID))
}

func (s *AddonService) emitAddonActivated(outletID, addonID, addonName, featureLink, targetID string) {
	if strings.TrimSpace(outletID) == "" || strings.TrimSpace(addonID) == "" {
		return
	}

	payload := map[string]interface{}{
		"outlet_id":    outletID,
		"addon_id":     addonID,
		"addon_name":   addonName,
		"feature_link": featureLink,
	}
	if strings.TrimSpace(targetID) != "" {
		payload["target_id"] = targetID
	}

	utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
		"type":    "ADDON_ACTIVATED",
		"title":   "Add-on Aktif",
		"message": fmt.Sprintf("%s sudah aktif dan siap digunakan.", addonName),
		"payload": payload,
	})

	// Refresh sumber data yang sering dipakai UI setelah aktivasi add-on.
	// Key ini bisa diabaikan kalau belum dipakai, tapi aman untuk future cache layer.
	database.InvalidateCache(
		fmt.Sprintf("outlet:profile:%s", outletID),
		fmt.Sprintf("addon:active:%s", outletID),
	)
}

func (s *AddonService) ValidateVoucher(code string, outletID string) (model.Voucher, error) {
	var voucher model.Voucher
	err := s.db.Where("vc_voucher = ? AND vc_status = 1", code).First(&voucher).Error
	if err != nil {
		return voucher, errors.New("voucher tidak ditemukan atau tidak aktif")
	}
	now := time.Now()
	if now.Before(voucher.TanggalMulai) || now.After(voucher.TanggalBerakhir) {
		return voucher, errors.New("voucher sudah kedaluwarsa")
	}
	if voucher.SisaVoucher <= 0 {
		return voucher, errors.New("kuota voucher sudah habis")
	}
	if voucher.Target != "ALL" && voucher.Target != "ADDON" {
		return voucher, errors.New("voucher ini tidak berlaku untuk pembelian addon")
	}

	// Sistem wajib melakukan validasi berdasarkan Owner ID untuk mencegah penggunaan berulang
	if outletID != "" {
		var outlet model.Outlet
		if err := s.db.Select("ot_user").Where("ot_id = ?", outletID).First(&outlet).Error; err == nil {
			var count int64
			errCheck := s.db.Table("ac_transaksi_addons").
				Joins("JOIN ac_outlet ON ac_transaksi_addons.ha_outlet = ac_outlet.ot_id").
				Where("ac_outlet.ot_user = ? AND ac_transaksi_addons.ha_kode_voucher = ? AND ac_transaksi_addons.ha_status IN ('SUCCESS', 'PENDING', 'PENDING_VALIDATION')", outlet.UserID, code).
				Count(&count).Error
			if errCheck == nil && count > 0 {
				return voucher, errors.New("voucher ini hanya dapat digunakan 1 kali per akun owner")
			}
		}
	}

	return voucher, nil
}

// ==========================================
// 2. KATALOG & HISTORI
// ==========================================

func (s *AddonService) GetAvailableAddons() ([]model.Addon, error) {
	var addons []model.Addon
	err := s.db.Raw("SELECT * FROM ac_addons WHERE ad_status = 1 ORDER BY ad_harga ASC").Scan(&addons).Error
	return addons, err
}

func (s *AddonService) GetActiveAddons(outletID string) ([]model.HistoryAddon, error) {
	var list []model.HistoryAddon
	err := s.db.Raw(
		"SELECT * FROM ac_history_addons WHERE ha_outlet = ? AND ha_berakhir > ?",
		outletID,
		time.Now(),
	).Scan(&list).Error
	if err != nil {
		return nil, err
	}

	for i := range list {
		var ad model.Addon
		if err := s.db.Raw("SELECT * FROM ac_addons WHERE ad_id = ? LIMIT 1", list[i].AddonID).Scan(&ad).Error; err == nil && ad.ID != "" {
			list[i].Addon = &ad
		}
	}

	return list, err
}

// ==========================================
// 3. TRANSACTION LOGIC
// ==========================================

func (s *AddonService) PurchaseAddonWithKoin(outletID string, addonIDs []string, targetIDs map[string]string, actorID string) error {
	var activatedAddons []struct {
		addon  model.Addon
		target string
	}
	var successTrxID string

	err := s.db.Transaction(func(tx *gorm.DB) error {
		now := s.nowForOutlet(outletID)
		var totalKoinNeeded float64
		var addonsToActivate []model.Addon
		var names []string

		for _, id := range addonIDs {
			var ad model.Addon
			if err := tx.Raw("SELECT * FROM ac_addons WHERE ad_id = ? AND ad_status = 1 LIMIT 1", id).Scan(&ad).Error; err != nil || ad.ID == "" {
				return fmt.Errorf("layanan %s tidak ditemukan atau tidak aktif", id)
			}
			if ad.Link == "EXTRA_STAFF" && targetIDs[id] == "" {
				return fmt.Errorf("ID Pegawai wajib diisi untuk addon %s", ad.Nama)
			}
			addonsToActivate = append(addonsToActivate, ad)
			names = append(names, ad.Nama)
			totalKoinNeeded += ad.Harga
		}

		var currentKoin int
		tx.Raw("SELECT ot_koin FROM ac_outlet WHERE ot_id = ?", outletID).Scan(&currentKoin)
		if float64(currentKoin) < totalKoinNeeded {
			return fmt.Errorf("saldo koin tidak cukup. Butuh %d koin", int(totalKoinNeeded))
		}

		if err := s.koinSvc.DeductCoinManual(tx, outletID, int(totalKoinNeeded), "Beli Add-on via Koin (Bulk)", actorID); err != nil {
			return err
		}

		trxID := fmt.Sprintf("HA-KOIN-%d", now.Unix())
		itemNames := strings.Join(names, ", ")

		tx.Exec(`INSERT INTO ac_transaksi_addons (ha_id, ha_outlet, ha_total, ha_metode_bayar, ha_status, ha_item_names, ha_created) 
                 VALUES (?, ?, ?, 'KOIN', 'SUCCESS', ?, ?)`, trxID, outletID, totalKoinNeeded, itemNames, now)

		for _, ad := range addonsToActivate {
			tID := targetIDs[ad.ID]
			tx.Exec(`INSERT INTO ac_detail_transaksi_addons (dha_id, dha_transaksi, dha_addons, dha_harga, dha_target_id) 
                     VALUES (?, ?, ?, ?, ?)`, uuid.New().String(), trxID, ad.ID, ad.Harga, tID)
			if err := s.activateFeature(tx, outletID, ad, tID); err != nil {
				return err
			}
			activatedAddons = append(activatedAddons, struct {
				addon  model.Addon
				target string
			}{addon: ad, target: tID})
		}
		successTrxID = trxID
		return nil
	})

	if err == nil {
		// Broadcast setelah commit agar getAddonExpiryForTrx (via s.db) melihat
		// ha_berakhir yang baru tersimpan dan bisa menyertakan tanggal jatuh tempo.
		s.broadcastStatus(outletID, successTrxID, "SUCCESS")
		for _, item := range activatedAddons {
			s.emitAddonActivated(outletID, item.addon.ID, item.addon.Nama, item.addon.Link, item.target)
		}
	}
	return err
}

func (s *AddonService) CreateAddonOrder(outletID string, addonIDs []string, metode string, targetIDs map[string]string, bankID *uint, voucherCode string) (model.TransaksiAddon, error) {
	var ta model.TransaksiAddon
	normalizedMethod := strings.ToUpper(strings.TrimSpace(metode))
	if normalizedMethod == "MIDTRANS" {
		return ta, errors.New("pembelian add-on via Midtrans sudah tidak didukung")
	}
	err := s.db.Transaction(func(tx *gorm.DB) error {
		now := s.nowForOutlet(outletID)
		configs := s.getEconomyConfigs(tx, "price_per_coin")
		pricePerCoin := configs["price_per_coin"]

		ta.ID = fmt.Sprintf("HA-%d%s", now.Unix(), utils.RandomString(3))
		ta.OutletID = outletID
		ta.MetodeBayar = metode
		ta.Status = "PENDING"
		ta.CreatedAt = now
		ta.BankID = bankID

		var totalIDR float64
		var itemDetails []midtrans.ItemDetails
		var names []string

		for _, id := range addonIDs {
			var ad model.Addon
			if err := tx.Raw("SELECT * FROM ac_addons WHERE ad_id = ?", id).Scan(&ad).Error; err != nil || ad.ID == "" {
				return fmt.Errorf("addon ID %s tidak ditemukan", id)
			}
			if ad.Link == "EXTRA_STAFF" && targetIDs[id] == "" {
				return fmt.Errorf("ID Pegawai wajib diisi untuk addon %s", ad.Nama)
			}

			names = append(names, ad.Nama)
			hargaRupiah := ad.Harga * pricePerCoin
			totalIDR += hargaRupiah
			tID := targetIDs[id]

			tx.Exec(`INSERT INTO ac_detail_transaksi_addons (dha_id, dha_transaksi, dha_addons, dha_harga, dha_target_id) 
                     VALUES (?, ?, ?, ?, ?)`, uuid.New().String(), ta.ID, ad.ID, ad.Harga, tID)

			itemDetails = append(itemDetails, midtrans.ItemDetails{
				ID: ad.ID, Name: ad.Nama, Price: int64(hargaRupiah), Qty: 1,
			})
		}

		ta.Total = totalIDR
		ta.ItemNames = strings.Join(names, ", ")

		// VALIDASI VOUCHER
		if voucherCode != "" {
			v, errV := s.ValidateVoucher(voucherCode, outletID)
			if errV != nil {
				return errV
			}
			var potongan float64
			if v.Jenis == "persen" {
				potongan = ta.Total * (v.NilaiPotongan / 100)
			} else {
				potongan = v.NilaiPotongan
			}
			ta.Total -= potongan
			if ta.Total < 0 {
				ta.Total = 0
			}
			ta.KodeVoucher = &voucherCode
			ta.Potongan = potongan

		}

		if ta.Total <= 0 {
			ta.Status = "SUCCESS"
			ta.MetodeBayar = "PROMO_FREE"
			ta.TanggalValidasi = &now

			// Langsung Aktivasi Fitur
			for _, id := range addonIDs {
				var ad model.Addon
				tx.Raw("SELECT * FROM ac_addons WHERE ad_id = ?", id).Scan(&ad)
				if ad.ID != "" {
					if err := s.activateFeature(tx, outletID, ad, targetIDs[id]); err != nil {
						return err
					}
				}
			}

			if voucherCode != "" {
				if err := tx.Model(&model.Voucher{}).
					Where("vc_voucher = ? AND vc_status = 1 AND vc_sisa_voucher > 0", voucherCode).
					Update("vc_sisa_voucher", gorm.Expr("vc_sisa_voucher - ?", 1)).Error; err != nil {
					return err
				}
			}
		}

		ta.MetodeBayar = normalizedMethod

		query := `INSERT INTO ac_transaksi_addons (ha_id, ha_outlet, ha_total, ha_metode_bayar, ha_status, ha_snap_url, ha_bank_id, ha_item_names, ha_kode_voucher, ha_potongan, ha_tanggal_validasi, ha_created) 
                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
		return tx.Exec(query, ta.ID, ta.OutletID, ta.Total, ta.MetodeBayar, ta.Status, ta.SnapURL, ta.BankID, ta.ItemNames, ta.KodeVoucher, ta.Potongan, ta.TanggalValidasi, ta.CreatedAt).Error
	})

	if err == nil {
		s.broadcastStatus(outletID, ta.ID, ta.Status)
	}
	return ta, err
}

// FIX: User bisa re-upload jika status PENDING atau FAILED (Rejected by Admin)
func (s *AddonService) UploadBuktiTransferAddon(taID string, outletID string, filePath string) error {
	now := s.nowForOutlet(outletID)
	res := s.db.Exec(`
		UPDATE ac_transaksi_addons 
		SET ha_bukti = ?, ha_status = 'PENDING_VALIDATION', ha_lastupdate = ? 
		WHERE ha_id = ? AND ha_outlet = ? 
		AND ha_status IN ('PENDING', 'PENDING_VALIDATION', 'FAILED')`,
		filePath, now, taID, outletID)

	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("transaksi tidak ditemukan atau tidak dapat diupdate")
	}

	s.broadcastStatus(outletID, taID, "PENDING_VALIDATION")
	return nil
}

func (s *AddonService) ActivateOutlet(outletID, actorID, metode string, bankID *uint, voucherCode string) (interface{}, error) {
	var res interface{}
	didActivateInstantly := false
	err := s.db.Transaction(func(tx *gorm.DB) error {
		configs := s.getEconomyConfigs(tx, "activation_fee", "activation_discount_pct")
		activationMode := strings.ToLower(strings.TrimSpace(s.getEconomyConfigValue(tx, "activation_mode", "paid")))
		fee := configs["activation_fee"]
		disc := configs["activation_discount_pct"]
		totalBayar := fee - (fee * disc / 100)

		isFreeCampaign := activationMode == "free" || activationMode == "gratis" || activationMode == "0" || activationMode == "false"
		if isFreeCampaign {
			totalBayar = 0
		}

		var vCode *string
		var potongan float64

		// VALIDASI VOUCHER PROMO
		if voucherCode != "" {
			v, errV := s.ValidateVoucher(voucherCode, outletID)
			if errV != nil {
				return errV
			}
			var p float64
			if v.Jenis == "persen" {
				p = totalBayar * (v.NilaiPotongan / 100)
			} else {
				p = v.NilaiPotongan
			}
			totalBayar -= p
			if totalBayar < 0 {
				totalBayar = 0
			}
			vCode = &voucherCode
			potongan = p

		}

		var activatedAt *time.Time
		tx.Raw("SELECT ot_activated_at FROM ac_outlet WHERE ot_id = ? LIMIT 1", outletID).Row().Scan(&activatedAt)
		if activatedAt != nil {
			return errors.New("outlet sudah PRO")
		}
		now := s.nowForOutlet(outletID)

		if totalBayar <= 0 {
			if err := s.executeOutletActivation(tx, outletID); err != nil {
				return err
			}
			trxFreeID := fmt.Sprintf("PRO-FREE-%d", now.Unix())
			queryFree := `INSERT INTO ac_transaksi_addons (ha_id, ha_outlet, ha_total, ha_metode_bayar, ha_status, ha_item_names, ha_kode_voucher, ha_potongan, ha_created, ha_tanggal_validasi) 
                         VALUES (?, ?, 0, 'PROMO_FREE', 'SUCCESS', 'Aktivasi Lisensi PRO', ?, ?, ?, ?)`
			tx.Exec(queryFree, trxFreeID, outletID, vCode, potongan, now, now)
			res = map[string]string{"status": "INSTANT_SUCCESS"}
			didActivateInstantly = true
			return nil
		}

		trxID := fmt.Sprintf("PRO-%d%s", now.Unix(), utils.RandomString(3))
		ta := model.TransaksiAddon{
			ID:          trxID,
			OutletID:    outletID,
			Total:       totalBayar,
			MetodeBayar: metode,
			Status:      "PENDING",
			BankID:      bankID,
			ItemNames:   "Aktivasi Lisensi PRO",
			KodeVoucher: vCode,
			Potongan:    potongan,
			CreatedAt:   now,
		}

		if metode == "MIDTRANS" {
			client := s.getSnapClient()
			items := []midtrans.ItemDetails{{ID: "OUTLET_PRO_ACT", Name: "Aktivasi Lisensi PRO", Price: int64(totalBayar), Qty: 1}}
			req := &snap.Request{
				TransactionDetails: midtrans.TransactionDetails{OrderID: trxID, GrossAmt: int64(totalBayar)},
				Items:              &items,
			}
			snapResp, _ := client.CreateTransaction(req)
			if snapResp != nil {
				ta.SnapURL = &snapResp.RedirectURL
			}
		}

		tx.Exec(`INSERT INTO ac_transaksi_addons (ha_id, ha_outlet, ha_total, ha_metode_bayar, ha_status, ha_snap_url, ha_bank_id, ha_item_names, ha_kode_voucher, ha_potongan, ha_created) 
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, ta.ID, ta.OutletID, ta.Total, ta.MetodeBayar, ta.Status, ta.SnapURL, ta.BankID, ta.ItemNames, ta.KodeVoucher, ta.Potongan, ta.CreatedAt)

		tx.Exec(`INSERT INTO ac_detail_transaksi_addons (dha_id, dha_transaksi, dha_addons, dha_harga) 
                 VALUES (?, ?, 'OUTLET_ACTIVATION', ?)`, uuid.New().String(), ta.ID, ta.Total)

		res = ta
		return nil
	})

	if err == nil && didActivateInstantly {
		s.emitOutletActivated(outletID)
	}

	if err == nil {
		if ta, ok := res.(model.TransaksiAddon); ok {
			s.broadcastStatus(outletID, ta.ID, "PENDING")
		}
	}
	return res, err
}

// User sengaja membatalkan (Final status)
// User sengaja membatalkan (Final status)
func (s *AddonService) CancelOrder(taID string, outletID string) error {
	// UPDATE: Izinkan pembatalan untuk status PENDING maupun FAILED (rejection admin)
	now := s.nowForOutlet(outletID)
	query := `
		UPDATE ac_transaksi_addons 
		SET ha_status = 'CANCELED', ha_lastupdate = ? 
		WHERE ha_id = ? 
		  AND ha_outlet = ? 
		  AND ha_status IN ('PENDING', 'FAILED')`

	res := s.db.Exec(query, now, taID, outletID)

	if res.Error != nil {
		return res.Error
	}

	if res.RowsAffected == 0 {
		return errors.New("transaksi tidak ditemukan atau sudah tidak bisa dibatalkan")
	}

	// Kirim sinyal ke Flutter biar UI langsung update (pindah ke Riwayat)
	s.broadcastStatus(outletID, taID, "CANCELED")

	return nil
}

// FIX: Admin me-reject bukti transfer -> status jadi FAILED (agar user bisa re-upload)
func (s *AddonService) AdminCancelOrder(taID string, actorID string) error {
	var outletID string
	s.db.Raw("SELECT ha_outlet FROM ac_transaksi_addons WHERE ha_id = ?", taID).Scan(&outletID)
	now := s.nowForOutlet(outletID)

	res := s.db.Exec(`
		UPDATE ac_transaksi_addons 
		SET ha_status = 'FAILED', 
		    ha_staf_validasi = ?, 
		    ha_lastupdate = ? 
		WHERE ha_id = ? AND ha_status IN ('PENDING', 'PENDING_VALIDATION')`,
		actorID, now, taID)

	if res.Error != nil {
		return res.Error
	}
	if res.RowsAffected == 0 {
		return errors.New("gagal membatalkan transaksi")
	}

	s.broadcastStatus(outletID, taID, "FAILED")
	return nil
}

// ==========================================
// 4. CORE ENGINE
// ==========================================

func (s *AddonService) ProcessApproval(taID, actorID string) error {
	var (
		outletID        string
		shouldBroadcast bool
		shouldNotifyPRO bool
	)

	err := s.db.Transaction(func(tx *gorm.DB) error {
		var ta model.TransaksiAddon
		if err := tx.Raw("SELECT * FROM ac_transaksi_addons WHERE ha_id = ? LIMIT 1", taID).Scan(&ta).Error; err != nil || ta.ID == "" {
			return errors.New("transaksi tidak ditemukan")
		}
		if ta.Status == "SUCCESS" {
			return nil
		}

		var details []model.DetailTransaksiAddon
		tx.Raw(`SELECT * FROM ac_detail_transaksi_addons WHERE dha_transaksi = ?`, ta.ID).Scan(&details)

		for _, det := range details {
			if det.AddonID == "OUTLET_ACTIVATION" {
				if err := s.executeOutletActivation(tx, ta.OutletID); err != nil {
					return err
				}
				shouldNotifyPRO = true
			} else {
				var ad model.Addon
				tx.Raw("SELECT * FROM ac_addons WHERE ad_id = ? LIMIT 1", det.AddonID).Scan(&ad)
				if ad.ID != "" {
					if err := s.activateFeature(tx, ta.OutletID, ad, det.TargetID); err != nil {
						return err
					}
				}
			}
		}

		now := s.nowForOutlet(ta.OutletID)
		if ta.KodeVoucher != nil && *ta.KodeVoucher != "" {
			if err := tx.Model(&model.Voucher{}).
				Where("vc_voucher = ? AND vc_status = 1 AND vc_sisa_voucher > 0", *ta.KodeVoucher).
				Update("vc_sisa_voucher", gorm.Expr("vc_sisa_voucher - ?", 1)).Error; err != nil {
				return err
			}
		}
		err := tx.Exec(`UPDATE ac_transaksi_addons SET ha_status = 'SUCCESS', ha_staf_validasi = ?, ha_tanggal_validasi = ? WHERE ha_id = ?`,
			actorID, &now, taID).Error

		if err == nil {
			outletID = ta.OutletID
			shouldBroadcast = true
		}
		return err
	})

	if err != nil {
		return err
	}

	if shouldNotifyPRO {
		s.emitOutletActivated(outletID)
	}
	if shouldBroadcast {
		var ta model.TransaksiAddon
		if err := s.db.Raw("SELECT * FROM ac_transaksi_addons WHERE ha_id = ? LIMIT 1", taID).Scan(&ta).Error; err == nil && ta.ID != "" {
			var details []model.DetailTransaksiAddon
			s.db.Raw(`SELECT * FROM ac_detail_transaksi_addons WHERE dha_transaksi = ?`, ta.ID).Scan(&details)
			for _, det := range details {
				if det.AddonID == "" || det.AddonID == "OUTLET_ACTIVATION" {
					continue
				}
				var ad model.Addon
				if err := s.db.Raw("SELECT * FROM ac_addons WHERE ad_id = ? LIMIT 1", det.AddonID).Scan(&ad).Error; err == nil && ad.ID != "" {
					s.emitAddonActivated(outletID, ad.ID, ad.Nama, ad.Link, det.TargetID)
				}
			}
		}
		s.broadcastStatus(outletID, taID, "SUCCESS")
	}
	return nil
}

// getAddonExpiryForTrx mengambil tanggal jatuh tempo (ha_berakhir) terjauh dari
// add-on yang diaktifkan oleh sebuah transaksi. Mengembalikan nil bila transaksi
// tidak mengaktifkan add-on berdurasi (mis. aktivasi PRO permanen).
func (s *AddonService) getAddonExpiryForTrx(trxID, outletID string) *time.Time {
	var expiry *time.Time
	s.db.Raw(`
		SELECT MAX(h.ha_berakhir)
		FROM ac_history_addons h
		JOIN ac_detail_transaksi_addons d ON d.dha_addons = h.ha_addons
		WHERE d.dha_transaksi = ? AND h.ha_outlet = ?`,
		trxID, outletID,
	).Scan(&expiry)
	return expiry
}

var namaBulanIndo = [...]string{
	"Januari", "Februari", "Maret", "April", "Mei", "Juni",
	"Juli", "Agustus", "September", "Oktober", "November", "Desember",
}

func formatTanggalIndo(t time.Time) string {
	return fmt.Sprintf("%d %s %d", t.Day(), namaBulanIndo[int(t.Month())-1], t.Year())
}

func (s *AddonService) activateFeature(tx *gorm.DB, outletID string, addon model.Addon, targetID string) error {
	now := s.nowForOutlet(outletID)
	months := 1
	if addon.Link == "EXTRA_STAFF" {
		if targetID == "" {
			return errors.New("ID Pegawai wajib diisi untuk addon staff")
		}
		if err := s.pgSvc.ExtendAddon(targetID, months); err != nil {
			return err
		}
	}

	var existing model.HistoryAddon
	tx.Raw("SELECT * FROM ac_history_addons WHERE ha_outlet = ? AND ha_addons = ? AND ha_target_id = ? LIMIT 1", outletID, addon.ID, targetID).Scan(&existing)

	newExpiry := now.AddDate(0, months, 0)
	if existing.ID != "" && existing.Berakhir.After(now) {
		newExpiry = existing.Berakhir.AddDate(0, months, 0)
		return tx.Exec("UPDATE ac_history_addons SET ha_berakhir = ? WHERE ha_id = ?", newExpiry, existing.ID).Error
	}

	return tx.Exec(`INSERT INTO ac_history_addons (ha_id, ha_addons, ha_outlet, ha_mulai, ha_berakhir, ha_target_id, ha_created) 
                     VALUES (?, ?, ?, ?, ?, ?, ?)`, uuid.New().String(), addon.ID, outletID, now, newExpiry, targetID, now).Error
}

func (s *AddonService) executeOutletActivation(tx *gorm.DB, outletID string) error {
	now := s.nowForOutlet(outletID)
	err := tx.Exec("UPDATE ac_outlet SET ot_activated_at = ?, ot_status = 1 WHERE ot_id = ?", now, outletID).Error
	if err != nil {
		return err
	}
	return nil
}

// ==========================================
// 5. QUERY HELPERS
// ==========================================

func (s *AddonService) CheckFeatureAccess(outletID string, featureLink string) (bool, error) {
	// Cek apakah outlet masih dalam masa trial
	var outlet model.Outlet
	err := s.db.Select("ot_id, ot_activated_at, ot_trial_at").First(&outlet, "ot_id = ?", outletID).Error
	if err == nil {
		// Jika belum aktivasi PRO dan trial belum expired, beri akses penuh ke Addon
		if outlet.ActivatedAt == nil && time.Now().Before(outlet.TrialExpiresAt) {
			return true, nil
		}
	}

	var count int64
	query := `SELECT COUNT(*) FROM ac_history_addons h 
              JOIN ac_addons a ON h.ha_addons = a.ad_id 
              WHERE h.ha_outlet = ? AND a.ad_link = ? AND h.ha_berakhir > NOW()`
	err = s.db.Raw(query, outletID, featureLink).Scan(&count).Error
	return count > 0, err
}

// PENTING: Transaksi FAILED sekarang masuk "PendingOrders" di Flutter biar bisa di-retry/re-upload
func (s *AddonService) GetPendingOrders(outletID string) ([]model.TransaksiAddon, error) {
	var list []model.TransaksiAddon
	query := `SELECT * FROM ac_transaksi_addons WHERE ha_outlet = ? AND ha_status IN ('PENDING', 'PENDING_VALIDATION', 'FAILED') ORDER BY ha_created DESC`
	err := s.db.Raw(query, outletID).Scan(&list).Error
	return list, err
}

func (s *AddonService) GetAllTransactionHistory(outletID string) ([]model.TransaksiAddon, error) {
	var results []model.TransaksiAddon
	query := `SELECT * FROM ac_transaksi_addons WHERE ha_outlet = ? AND ha_status IN ('SUCCESS', 'CANCELED') ORDER BY ha_created DESC`
	err := s.db.Raw(query, outletID).Scan(&results).Error
	return results, err
}

func (s *AddonService) GetTransactionDetail(outletID string, taID string) (map[string]interface{}, error) {
	var header model.TransaksiAddon
	err := s.db.Raw("SELECT * FROM ac_transaksi_addons WHERE ha_id = ? AND ha_outlet = ? LIMIT 1", taID, outletID).Scan(&header).Error
	if err != nil || header.ID == "" {
		return nil, errors.New("transaksi tidak ditemukan")
	}

	var details []map[string]interface{}
	queryDetails := `
        SELECT 
            d.dha_id, d.dha_addons, d.dha_harga, d.dha_target_id,
            COALESCE(a.ad_addons, 'Aktivasi Lisensi PRO') as item_name,
            COALESCE(a.ad_keterangan, 'Aktivasi permanen ekosistem AyoCuci') as item_desc
        FROM ac_detail_transaksi_addons d
        LEFT JOIN ac_addons a ON d.dha_addons = a.ad_id
        WHERE d.dha_transaksi = ?`
	s.db.Raw(queryDetails, taID).Scan(&details)

	return map[string]interface{}{"header": header, "details": details}, nil
}

// ==========================================
// 6. NOTIFICATION HANDLER
// ==========================================

func (s *AddonService) ProcessMidtransNotification(payload map[string]interface{}) error {
	orderID, _ := payload["order_id"].(string)
	st, _ := payload["transaction_status"].(string)
	fraud, _ := payload["fraud_status"].(string)

	finalStatus := "PENDING"
	if st == "capture" {
		if fraud == "accept" {
			finalStatus = "SUCCESS"
		}
	} else if st == "settlement" {
		finalStatus = "SUCCESS"
	} else if st == "deny" || st == "expire" || st == "cancel" {
		finalStatus = "FAILED"
	}

	var ta model.TransaksiAddon
	s.db.Raw("SELECT ha_outlet, ha_status FROM ac_transaksi_addons WHERE ha_id = ?", orderID).Scan(&ta)
	if ta.OutletID == "" {
		return fmt.Errorf("outlet id tidak ditemukan untuk transaksi %s", orderID)
	}
	if ta.Status == "SUCCESS" {
		return nil
	}

	if finalStatus == "SUCCESS" {
		if err := s.ProcessApproval(orderID, "MIDTRANS_WEBHOOK"); err != nil {
			return err
		}
	} else if finalStatus == "FAILED" {
		now := s.nowForOutlet(ta.OutletID)
		s.db.Exec("UPDATE ac_transaksi_addons SET ha_status = 'FAILED', ha_lastupdate = ? WHERE ha_id = ?", now, orderID)
		s.broadcastStatus(ta.OutletID, orderID, "FAILED")
	}

	return nil
}

// 7. ADMIN PANEL LISTING
func (s *AddonService) AdminListTransactions(outletID, status, metode, startDate, endDate string) ([]admin.AddonTransactionAdminRes, error) {
	var results []admin.AddonTransactionAdminRes

	query := s.db.Table("ac_transaksi_addons t").
		Select(`t.ha_id, t.ha_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name, 
                t.ha_total, t.ha_metode_bayar, t.ha_status, 
                t.ha_bukti, b.bank_name, t.ha_item_names,
                t.ha_created, t.ha_tanggal_validasi`).
		Joins("LEFT JOIN ac_outlet o ON t.ha_outlet = o.ot_id").
		Joins("LEFT JOIN ac_user u ON o.ot_user = u.usr_id").
		Joins("LEFT JOIN ac_bank_accounts b ON t.ha_bank_id = b.id")

	if outletID != "" {
		query = query.Where("t.ha_outlet = ?", outletID)
	}
	if status != "" {
		query = query.Where("t.ha_status = ?", status)
	}
	if metode != "" {
		query = query.Where("t.ha_metode_bayar = ?", metode)
	}
	if startDate != "" && endDate != "" {
		query = query.Where("DATE(t.ha_created) BETWEEN ? AND ?", startDate, endDate)
	}

	err := query.Order("t.ha_created DESC").Scan(&results).Error
	if err != nil {
		return results, err
	}

	if err := s.attachAdminTransactionDetails(results); err != nil {
		return results, err
	}

	return results, nil
}

func (s *AddonService) AdminGetDetail(taID string) (admin.AddonTransactionAdminRes, error) {
	var result admin.AddonTransactionAdminRes

	query := `SELECT t.ha_id, t.ha_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name,
               t.ha_total, t.ha_metode_bayar, t.ha_status,
               t.ha_bukti, b.bank_name, t.ha_item_names,
               t.ha_created, t.ha_tanggal_validasi
        FROM ac_transaksi_addons t
        LEFT JOIN ac_outlet o ON t.ha_outlet = o.ot_id
        LEFT JOIN ac_user u ON o.ot_user = u.usr_id
        LEFT JOIN ac_bank_accounts b ON t.ha_bank_id = b.id WHERE t.ha_id = ?`

	err := s.db.Raw(query, taID).Scan(&result).Error
	if err != nil {
		return result, err
	}

	tmp := []admin.AddonTransactionAdminRes{result}
	if err := s.attachAdminTransactionDetails(tmp); err != nil {
		return result, err
	}
	result = tmp[0]

	return result, nil
}

func (s *AddonService) attachAdminTransactionDetails(results []admin.AddonTransactionAdminRes) error {
	if len(results) == 0 {
		return nil
	}

	ids := make([]string, 0, len(results))
	for _, item := range results {
		if item.ID != "" {
			ids = append(ids, item.ID)
		}
	}
	if len(ids) == 0 {
		return nil
	}

	var details []admin.AddonTransactionAdminDetail

	if err := s.db.Raw(`
		SELECT
			d.dha_id,
			d.dha_transaksi,
			d.dha_addons,
			COALESCE(a.ad_addons, 'Aktivasi Lisensi PRO') AS item_name,
			COALESCE(a.ad_keterangan, 'Aktivasi permanen ekosistem AyoCuci') AS item_desc,
			COALESCE(d.dha_harga, 0) AS dha_harga,
			d.dha_target_id,
			h.ha_berakhir,
			CASE
				WHEN d.dha_addons = 'OUTLET_ACTIVATION' THEN 'ACTIVE'
				WHEN h.ha_berakhir IS NULL THEN 'INACTIVE'
				WHEN h.ha_berakhir > NOW() THEN 'ACTIVE'
				ELSE 'EXPIRED'
			END AS feature_status
		FROM ac_detail_transaksi_addons d
		LEFT JOIN ac_addons a ON d.dha_addons = a.ad_id
		LEFT JOIN ac_history_addons h
			ON h.ha_outlet = (
				SELECT t.ha_outlet
				FROM ac_transaksi_addons t
				WHERE t.ha_id = d.dha_transaksi
				LIMIT 1
			)
			AND h.ha_addons = d.dha_addons
			AND COALESCE(h.ha_target_id, '') = COALESCE(d.dha_target_id, '')
		WHERE d.dha_transaksi IN ?
	`, ids).Scan(&details).Error; err != nil {
		return err
	}

	detailMap := make(map[string][]admin.AddonTransactionAdminDetail)
	for _, detail := range details {
		detailMap[detail.TransaksiID] = append(detailMap[detail.TransaksiID], detail)
	}

	for index := range results {
		results[index].Details = detailMap[results[index].ID]
	}

	return nil
}
