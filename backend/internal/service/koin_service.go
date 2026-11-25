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
	"math"
	"math/rand"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/coreapi"
	"github.com/midtrans/midtrans-go/snap"
	"gorm.io/gorm"
)

type KoinService struct {
	db *gorm.DB
}

func NewKoinService(db *gorm.DB) *KoinService {
	return &KoinService{db: db}
}

// ==========================================
// 1. MIDTRANS CONFIG
// ==========================================

func (s *KoinService) getSnapClient() snap.Client {
	var client snap.Client
	serverKey := strings.TrimSpace(config.GetEnv("MIDTRANS_SERVER_KEY", ""))
	if serverKey == "" {
		serverKey = strings.TrimSpace(config.GetEnv("MIDTRANS_SANDBOX_SERVER_KEY", ""))
	}

	env := midtrans.Sandbox
	isProduction := strings.EqualFold(strings.TrimSpace(config.GetEnv("MIDTRANS_IS_PRODUCTION", "false")), "true")
	if isProduction {
		env = midtrans.Production
	}

	client.New(serverKey, env)
	return client
}

func (s *KoinService) getCoreAPIClient() coreapi.Client {
	var client coreapi.Client
	serverKey := strings.TrimSpace(config.GetEnv("MIDTRANS_SERVER_KEY", ""))
	if serverKey == "" {
		serverKey = strings.TrimSpace(config.GetEnv("MIDTRANS_SANDBOX_SERVER_KEY", ""))
	}

	env := midtrans.Sandbox
	isProduction := strings.EqualFold(strings.TrimSpace(config.GetEnv("MIDTRANS_IS_PRODUCTION", "false")), "true")
	if isProduction {
		env = midtrans.Production
	}

	client.New(serverKey, env)
	return client
}

// ==========================================
// 2. ANALYTICS & HISTORY
// ==========================================

func (s *KoinService) GetHistory(outletID string) ([]model.HistoryKoin, error) {
	var history []model.HistoryKoin
	err := s.db.Where("hk_outlet = ?", outletID).Order("hk_created DESC").Find(&history).Error
	return history, err
}

func (s *KoinService) GetActiveTopups(outletID string) ([]model.TopupKoin, error) {
	if err := s.expirePendingTopupsForOutlet(outletID); err != nil {
		return nil, err
	}
	var topups []model.TopupKoin
	err := s.db.Where("tk_outlet = ? AND tk_status IN ?", outletID, []string{"pending", "challenge"}).Order("tk_created DESC").Find(&topups).Error
	return topups, err
}

func (s *KoinService) GetAllTopupsByOutlet(outletID string) ([]model.TopupKoin, error) {
	if err := s.expirePendingTopupsForOutlet(outletID); err != nil {
		return nil, err
	}
	var topups []model.TopupKoin
	err := s.db.Where("tk_outlet = ?", outletID).Order("tk_created DESC").Find(&topups).Error
	return topups, err
}

// ==========================================
// 3. VOUCHER & TOPUP LOGIC
// ==========================================

func (s *KoinService) ValidateVoucher(code string) (model.Voucher, error) {
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
	if voucher.Target != "ALL" && voucher.Target != "KOIN" {
		return voucher, errors.New("voucher ini tidak berlaku untuk topup koin")
	}
	return voucher, nil
}

func (s *KoinService) getPackageDiscountPct(tx *gorm.DB, jumlahKoin int) int {
	var pkg model.KoinPackage
	if err := tx.Where("pk_jumlah = ? AND pk_status = ?", jumlahKoin, true).First(&pkg).Error; err == nil {
		return pkg.DiscountPct
	}
	return 0
}

func (s *KoinService) ValidateVoucherWithCalculation(code string, jumlah int, basePrice float64) (model.Voucher, float64, error) {
	v, err := s.ValidateVoucher(code)
	if err != nil {
		return v, 0, err
	}
	// Voucher validation is only ever invoked for a custom nominal, where a
	// voucher and a package discount must not stack. Apply the voucher to the
	// gross nominal with no package discount, matching CreateTopup and the
	// client's custom-mode total.
	totalGross := float64(jumlah) * basePrice
	if v.MinTopup > 0 && totalGross < v.MinTopup {
		return v, 0, fmt.Errorf("Voucher ini hanya berlaku untuk top up minimal Rp %s", formatRupiahInt(int(v.MinTopup)))
	}
	baseAfterPackageDiscount := totalGross
	var potongan float64 = 0
	if v.Jenis == "persen" {
		potongan = baseAfterPackageDiscount * (v.NilaiPotongan / 100)
	} else {
		potongan = v.NilaiPotongan
	}
	if potongan > baseAfterPackageDiscount {
		potongan = baseAfterPackageDiscount
	}
	return v, potongan, nil
}

func roundNominalToInt(value float64) float64 {
	return math.Round(value)
}

// roundNominalToThousand membulatkan ke kelipatan 1000 terdekat. Dipakai khusus
// untuk transfer manual agar kode unik 3-digit mengisi persis 3 digit terakhir
// (tanpa carry), sehingga tampilan "Rp xx.xxx" konsisten dengan kode unik.
func roundNominalToThousand(value float64) float64 {
	return math.Round(value/1000) * 1000
}

// normalizeKodeUnik memastikan kode unik yang dikirim frontend berada di rentang
// 100-999. Jika di luar rentang (mis. 0 karena field kosong), backend membuat
// sendiri kode acak agar tagihan transfer selalu punya 3 digit pembeda.
func normalizeKodeUnik(input int) int {
	if input >= 100 && input <= 999 {
		return input
	}
	return 100 + rand.Intn(900)
}

func (s *KoinService) expiredAtForTopup(now time.Time) time.Time {
	return now.Add(24 * time.Hour)
}

func (s *KoinService) isTopupCancelable(status string) bool {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "pending", "challenge", "failed":
		return true
	default:
		return false
	}
}

func (s *KoinService) expirePendingTopupsForOutlet(outletID string) error {
	now := time.Now()
	return s.db.Transaction(func(tx *gorm.DB) error {
		var topups []model.TopupKoin
		if err := tx.Where(
			"tk_outlet = ? AND tk_status IN ? AND tk_expired_at <= ?",
			outletID,
			[]string{"pending", "challenge"},
			now,
		).Find(&topups).Error; err != nil {
			return err
		}

		for _, topup := range topups {
			if err := tx.Model(&topup).Updates(map[string]interface{}{
				"tk_status":     "expire",
				"tk_lastupdate": now,
			}).Error; err != nil {
				return err
			}

			utils.AppHub.BroadcastToOutlet(topup.OutletID, map[string]interface{}{
				"type":    "TOPUP_STATUS_CHANGED",
				"title":   "Top Up Kedaluwarsa",
				"message": "Tagihan top up kamu telah kedaluwarsa. Silakan buat tagihan baru jika ingin melanjutkan pembelian koin.",
				"payload": map[string]interface{}{
					"topup_id": topup.ID,
					"status":   "expire",
				},
			})
		}
		return nil
	})
}

func (s *KoinService) expireTopupByIDIfNeeded(tx *gorm.DB, topup *model.TopupKoin) (bool, error) {
	status := strings.ToLower(strings.TrimSpace(topup.Status))
	if status != "pending" && status != "challenge" {
		return false, nil
	}
	if time.Now().Before(topup.ExpiredAt) {
		return false, nil
	}

	now := time.Now()
	if err := tx.Model(topup).Updates(map[string]interface{}{
		"tk_status":     "expire",
		"tk_lastupdate": now,
	}).Error; err != nil {
		return false, err
	}

	utils.AppHub.BroadcastToOutlet(topup.OutletID, map[string]interface{}{
		"type":    "TOPUP_STATUS_CHANGED",
		"title":   "Top Up Kedaluwarsa",
		"message": "Tagihan top up kamu telah kedaluwarsa. Silakan buat tagihan baru jika ingin melanjutkan pembelian koin.",
		"payload": map[string]interface{}{
			"topup_id": topup.ID,
			"status":   "expire",
		},
	})

	topup.Status = "expire"
	topup.UpdatedAt = now
	return true, nil
}

func (s *KoinService) CreateTopup(outletID string, jumlahKoin int, nominalBayar float64, metode string, bankID *uint, voucherCode *string, kodeUnikInput int, userID string) (model.TopupKoin, string, error) {
	var topup model.TopupKoin
	var snapURL string

	if jumlahKoin <= 0 {
		return topup, "", errors.New("jumlah koin harus lebih dari 0")
	}

	err := s.db.Transaction(func(tx *gorm.DB) error {
		var cfg model.EconomyConfig
		pricePerCoin := 200.0
		if errCfg := tx.Where("cfg_key = ?", "price_per_coin").First(&cfg).Error; errCfg == nil {
			if parsed, errParse := strconv.ParseFloat(cfg.Value, 64); errParse == nil && parsed > 0 {
				pricePerCoin = parsed
			}
		}

		minimumTopupNominal := 20000.0
		grossNominal := float64(jumlahKoin) * pricePerCoin

		// A voucher only applies to a custom nominal and must never stack on
		// top of a package discount (the Android UI enforces this by exposing
		// the voucher field only in custom mode). The package discount here is
		// derived purely from the koin amount, so a custom amount that happens
		// to equal a package size would otherwise get both — when a voucher is
		// present we skip the package discount entirely and let the voucher
		// apply to the gross nominal, matching the client's custom-mode total.
		hasVoucher := voucherCode != nil && strings.TrimSpace(*voucherCode) != ""
		packageDiscountPct := 0
		if !hasVoucher {
			packageDiscountPct = s.getPackageDiscountPct(tx, jumlahKoin)
		}
		packageDiscountNominal := grossNominal * (float64(packageDiscountPct) / 100)
		baseAfterPackageDiscount := grossNominal - packageDiscountNominal
		if baseAfterPackageDiscount < minimumTopupNominal {
			return fmt.Errorf("minimal top up koin adalah Rp %s", formatRupiahInt(int(minimumTopupNominal)))
		}

		potongan := 0.0
		netNominal := baseAfterPackageDiscount

		if hasVoucher {
			var v model.Voucher
			if errV := tx.Where("vc_voucher = ? AND vc_status = 1", *voucherCode).First(&v).Error; errV != nil {
				return errors.New("voucher tidak valid")
			}
			if v.Target != "ALL" && v.Target != "KOIN" {
				return errors.New("voucher ini tidak berlaku untuk topup koin")
			}
			now := time.Now()
			if now.Before(v.TanggalMulai) || now.After(v.TanggalBerakhir) {
				return errors.New("voucher sudah kedaluwarsa")
			}
			if v.SisaVoucher <= 0 {
				return errors.New("kuota voucher habis")
			}
			// Gate minimal top-up per voucher: nominal kotor (sebelum potongan)
			// harus >= vc_min_topup. Mencegah voucher diskon besar dipakai pada
			// top-up kecil.
			if v.MinTopup > 0 && grossNominal < v.MinTopup {
				return fmt.Errorf("Voucher ini hanya berlaku untuk top up minimal Rp %s", formatRupiahInt(int(v.MinTopup)))
			}

			if v.Jenis == "persen" {
				potongan = baseAfterPackageDiscount * (v.NilaiPotongan / 100)
			} else {
				potongan = v.NilaiPotongan
			}
			if potongan > baseAfterPackageDiscount {
				potongan = baseAfterPackageDiscount
			}
			netNominal = baseAfterPackageDiscount - potongan
			if netNominal < minimumTopupNominal {
				netNominal = minimumTopupNominal
			}

			if errUpd := tx.Model(&v).Update("vc_sisa_voucher", gorm.Expr("vc_sisa_voucher - ?", 1)).Error; errUpd != nil {
				return errUpd
			}
		}

		netNominal = roundNominalToInt(netNominal)
		finalNominal := netNominal
		kodeUnik := 0

		if metode == "transfer" {
			if bankID == nil || *bankID == 0 {
				return errors.New("rekening tujuan transfer wajib dipilih")
			}
			// Bulatkan nominal dasar ke ribuan agar kode unik 3-digit (dari
			// frontend) mengisi persis 3 digit terakhir tanpa carry. Total =
			// nominal dasar + kode unik. Nominal dasar selalu dihitung ulang di
			// sini, kode unik dari frontend hanya dipakai untuk 3 digit terakhir
			// sehingga total tetap tidak bisa dimanipulasi oleh client.
			netNominal = roundNominalToThousand(netNominal)
			if netNominal < minimumTopupNominal {
				netNominal = minimumTopupNominal
			}
			kodeUnik = normalizeKodeUnik(kodeUnikInput)
			finalNominal = netNominal + float64(kodeUnik)
		}

		topupID := fmt.Sprintf("TK-%d%s", time.Now().Unix(), utils.RandomString(4))
		topup = model.TopupKoin{
			ID:           topupID,
			OutletID:     outletID,
			Jumlah:       jumlahKoin,
			MetodeBayar:  metode,
			Potongan:     potongan,
			NominalDasar: netNominal,
			KodeUnik:     kodeUnik,
			Total:        finalNominal,
			ExpiredAt:    s.expiredAtForTopup(time.Now()),
			Status:       "pending",
			CreatedAt:    time.Now(),
			UpdatedAt:    time.Now(),
			UserUpdate:   userID,
			BankID:       bankID,
		}
		if voucherCode != nil && *voucherCode != "" {
			topup.KodeVoucher = voucherCode
		}

		if err := tx.Create(&topup).Error; err != nil {
			return err
		}

		if metode == "midtrans" {
			snapClient := s.getSnapClient()
			items := []midtrans.ItemDetails{{ID: "KOIN_TOPUP", Price: int64(finalNominal), Qty: 1, Name: fmt.Sprintf("Topup %d Koin AyoCuci", jumlahKoin)}}
			req := &snap.Request{
				TransactionDetails: midtrans.TransactionDetails{OrderID: topupID, GrossAmt: int64(finalNominal)},
				Items:              &items,
			}
			snapResp, errMid := snapClient.CreateTransaction(req)
			if errMid != nil {
				return errors.New("midtrans error: " + errMid.Message)
			}
			snapURL = snapResp.RedirectURL
			if errUpdate := tx.Model(&topup).Update("tk_snap_url", snapURL).Error; errUpdate != nil {
				return errUpdate
			}
			topup.SnapURL = snapURL
		}
		return nil
	})

	if err == nil {
		// Ambil nama outlet untuk memperjelas notifikasi.
		var namaOutlet string
		s.db.Model(&model.Outlet{}).
			Where("ot_id = ?", topup.OutletID).
			Select("ot_nama").Scan(&namaOutlet)
		if strings.TrimSpace(namaOutlet) == "" {
			namaOutlet = "-"
		}

		// Retensi: apakah outlet ini sudah pernah top up SUKSES sebelumnya?
		// 0 = pelanggan baru (top up pertama), >0 = pelanggan lama (repeat).
		var prevSukses int64
		s.db.Model(&model.TopupKoin{}).
			Where("tk_outlet = ? AND tk_status = ?", topup.OutletID, "success").
			Count(&prevSukses)
		tipePelanggan := "🟢 PELANGGAN BARU (top up pertama)"
		if prevSukses > 0 {
			tipePelanggan = fmt.Sprintf("🔁 PELANGGAN LAMA (sudah %d× top up)", prevSukses)
		}

		// NOTIFIKASI GRUP WA (Fonnte) — ada permintaan topup baru dibuat
		notifier.SendWhatsAppGroupAsync(fmt.Sprintf(
			"🆕 *TOPUP BARU DIBUAT*\n"+
				"Outlet: %s (%s)\n"+
				"Jumlah: %d koin (Rp%s)\n"+
				"Metode: %s\n"+
				"ID: %s\n"+
				"%s\n"+
				"Status: menunggu pembayaran.",
			namaOutlet, topup.OutletID, topup.Jumlah, notifier.FormatRupiah(topup.Total),
			topup.MetodeBayar, topup.ID, tipePelanggan,
		))
	}

	return topup, snapURL, err
}

func (s *KoinService) CancelTopupByUser(topupID string, outletID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var topup model.TopupKoin
		if err := tx.Where("id = ? AND tk_outlet = ?", topupID, outletID).First(&topup).Error; err != nil {
			return errors.New("tagihan tidak ditemukan")
		}

		if !s.isTopupCancelable(topup.Status) {
			return errors.New("tagihan ini sudah tidak bisa dibatalkan")
		}

		if strings.EqualFold(strings.TrimSpace(topup.MetodeBayar), "midtrans") &&
			(strings.EqualFold(strings.TrimSpace(topup.Status), "pending") ||
				strings.EqualFold(strings.TrimSpace(topup.Status), "challenge")) {
			coreClient := s.getCoreAPIClient()
			if _, errMid := coreClient.CancelTransaction(topup.ID); errMid != nil {
				// Best-effort: JANGAN kunci pengguna kalau cancel Midtrans gagal
				// (transaksi tidak ada di Midtrans, sudah kedaluwarsa, atau
				// kredensial belum siap). Cek status dulu — hanya tolak bila
				// benar-benar SUDAH DIBAYAR; selain itu lanjut batalkan lokal.
				// Tagihan Midtrans yang belum dibayar akan kedaluwarsa sendiri.
				if statusResp, errStatus := coreClient.CheckTransaction(topup.ID); errStatus == nil && statusResp != nil {
					st := strings.ToLower(strings.TrimSpace(statusResp.TransactionStatus))
					if st == "settlement" || st == "capture" {
						return errors.New("transaksi sudah dibayar, tidak bisa dibatalkan")
					}
				}
				fmt.Printf("⚠️ cancel Midtrans gagal utk %s: %v — lanjut batalkan lokal\n", topup.ID, errMid)
			}
		}

		if err := tx.Model(&topup).Updates(map[string]interface{}{
			"tk_status":     "cancel",
			"tk_lastupdate": time.Now(),
		}).Error; err != nil {
			return err
		}

		// REALTIME BROADCAST
		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
			"type":    "TOPUP_STATUS_CHANGED",
			"title":   "Tagihan Top Up Dibatalkan",
			"message": "Tagihan top up kamu telah dibatalkan. Buat tagihan baru jika ingin melanjutkan pembelian koin.",
			"payload": map[string]interface{}{
				"topup_id": topupID,
				"status":   "cancel",
			},
		})

		return nil
	})
}

func (s *KoinService) RegenerateSnapURL(oldTopupID string, outletID string) (string, error) {
	var oldTopup model.TopupKoin
	if err := s.db.Where("id = ? AND tk_outlet = ?", oldTopupID, outletID).First(&oldTopup).Error; err != nil {
		return "", errors.New("tagihan lama tidak ditemukan")
	}
	switch strings.ToLower(strings.TrimSpace(oldTopup.Status)) {
	case "success", "cancel", "expire":
		return "", errors.New("tagihan ini sudah lunas")
	}

	var newSnapURL string
	err := s.db.Transaction(func(tx *gorm.DB) error {
		tx.Model(&oldTopup).Update("tk_status", "failed")

		newID := fmt.Sprintf("TK-%d%s", time.Now().Unix(), utils.RandomString(4))
		newTopup := model.TopupKoin{
			ID: newID, OutletID: oldTopup.OutletID, Jumlah: oldTopup.Jumlah, MetodeBayar: oldTopup.MetodeBayar,
			Total: oldTopup.Total, KodeVoucher: oldTopup.KodeVoucher, Potongan: oldTopup.Potongan,
			NominalDasar: oldTopup.NominalDasar, KodeUnik: oldTopup.KodeUnik, ExpiredAt: oldTopup.ExpiredAt,
			Status: "pending", CreatedAt: time.Now(), UpdatedAt: time.Now(), UserUpdate: oldTopup.UserUpdate, BankID: oldTopup.BankID,
		}

		if err := tx.Create(&newTopup).Error; err != nil {
			return err
		}

		snapClient := s.getSnapClient()
		req := &snap.Request{
			TransactionDetails: midtrans.TransactionDetails{OrderID: newID, GrossAmt: int64(newTopup.Total)},
		}
		snapResp, errMid := snapClient.CreateTransaction(req)
		if errMid != nil {
			return errors.New("midtrans error: " + errMid.Message)
		}
		newSnapURL = snapResp.RedirectURL
		return tx.Model(&newTopup).Update("tk_snap_url", newSnapURL).Error
	})

	return newSnapURL, err
}

func (s *KoinService) SubmitBuktiTransfer(topupID string, imagePath string) error {
	var topup model.TopupKoin
	if err := s.db.Where("id = ?", topupID).First(&topup).Error; err != nil {
		return err
	}

	status := strings.ToLower(strings.TrimSpace(topup.Status))
	if status == "cancel" || status == "expire" || status == "success" {
		return errors.New("tagihan ini sudah tidak bisa diunggah ulang")
	}
	if topup.Status == "pending" || topup.Status == "challenge" {
		if expired, err := s.expireTopupByIDIfNeeded(s.db, &topup); err != nil {
			return err
		} else if expired {
			return errors.New("tagihan ini sudah kedaluwarsa")
		}
	}

	now := time.Now()
	err := s.db.Model(&topup).Updates(map[string]interface{}{
		"tk_bukti":                imagePath,
		"tk_status":               "pending",
		"tk_tanggal_upload_bukti": &now,
	}).Error

	if err == nil {
		if notifErr := notifier.CreateOutletNotification(
			s.db,
			topup.OutletID,
			"KOIN",
			"Bukti Top Up Diterima",
			"Bukti transfer kamu sudah diterima. Tim AyoCuci akan memvalidasi pembayaran sebelum koin ditambahkan.",
			map[string]interface{}{"topup_id": topupID, "status": "pending"},
		); notifErr != nil {
			fmt.Printf("Gagal membuat notifikasi bukti top up: %v\n", notifErr)
		}

		// NOTIFIKASI GRUP WA (Fonnte) — bukti sudah masuk, minta tim validasi
		var namaOutlet string
		s.db.Model(&model.Outlet{}).
			Where("ot_id = ?", topup.OutletID).
			Select("ot_nama").Scan(&namaOutlet)
		if strings.TrimSpace(namaOutlet) == "" {
			namaOutlet = "-"
		}
		notifier.SendWhatsAppGroupAsync(fmt.Sprintf(
			"🔔 *TOPUP PERLU DICEK*\n"+
				"Outlet: %s (%s)\n"+
				"Jumlah: %d koin (Rp%s)\n"+
				"Metode: %s\n"+
				"ID: %s\n"+
				"Status: PENDING — bukti transfer sudah diupload, mohon divalidasi.",
			namaOutlet, topup.OutletID, topup.Jumlah, notifier.FormatRupiah(topup.Total), topup.MetodeBayar, topup.ID,
		))

		// REALTIME
		utils.AppHub.BroadcastToOutlet(topup.OutletID, map[string]interface{}{
			"type":    "TOPUP_STATUS_CHANGED",
			"title":   "Bukti Transfer Diterima",
			"message": "Bukti transfer kamu sudah diterima. Tim AyoCuci akan memvalidasi pembayaran sebelum koin ditambahkan.",
			"payload": map[string]interface{}{
				"topup_id": topupID,
				"status":   "pending",
			},
		})
	}
	return err
}

// ==========================================
// 4. NOTIFICATION & WEBHOOK
// ==========================================

func (s *KoinService) ProcessMidtransNotification(payload map[string]interface{}) error {
	orderID, _ := payload["order_id"].(string)
	transactionStatus, _ := payload["transaction_status"].(string)
	fraudStatus, _ := payload["fraud_status"].(string)

	var (
		broadcastTopup *model.TopupKoin
		broadcastFinal string
	)

	err := s.db.Transaction(func(tx *gorm.DB) error {
		var topup model.TopupKoin
		if err := tx.Where("id = ?", orderID).First(&topup).Error; err != nil {
			return fmt.Errorf("topup %s tidak ditemukan", orderID)
		}

		if topup.Status == "success" {
			return nil
		}
		if _, err := s.expireTopupByIDIfNeeded(tx, &topup); err != nil {
			return err
		}
		if topup.Status == "expire" || topup.Status == "cancel" {
			return nil
		}

		finalStatus := "pending"
		switch transactionStatus {
		case "capture":
			switch fraudStatus {
			case "challenge":
				finalStatus = "challenge"
			case "accept":
				finalStatus = "success"
			}
		case "settlement":
			finalStatus = "success"
		case "deny", "expire", "cancel":
			finalStatus = "failed"
		}

		if err := tx.Model(&topup).Update("tk_status", finalStatus).Error; err != nil {
			return err
		}

		if finalStatus == "success" {
			if errApprove := s.ApproveTopupCoins(tx, topup); errApprove != nil {
				return errApprove
			}
			if notifErr := notifier.CreateOutletNotification(
				tx,
				topup.OutletID,
				"KOIN",
				"Top Up Berhasil",
				fmt.Sprintf("%d koin berhasil ditambahkan ke akun laundry kamu.", topup.Jumlah),
				map[string]interface{}{"topup_id": topup.ID, "status": finalStatus},
			); notifErr != nil {
				fmt.Printf("Gagal membuat notifikasi top up berhasil: %v\n", notifErr)
			}
			broadcastTopup = &topup
			broadcastFinal = finalStatus
		} else {
			title, message := topupStatusCopy(finalStatus)
			if finalStatus == "failed" || finalStatus == "challenge" {
				if notifErr := notifier.CreateOutletNotification(
					tx,
					topup.OutletID,
					"KOIN",
					title,
					message,
					map[string]interface{}{"topup_id": topup.ID, "status": finalStatus},
				); notifErr != nil {
					fmt.Printf("Gagal membuat notifikasi status top up: %v\n", notifErr)
				}
			}
			broadcastTopup = &topup
			broadcastFinal = finalStatus
		}
		return nil
	})

	if err == nil && broadcastTopup != nil {
		if broadcastFinal == "success" {
			database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", broadcastTopup.OutletID))
			utils.AppHub.BroadcastToOutlet(broadcastTopup.OutletID, map[string]interface{}{
				"type":    "TOPUP_SUCCESS",
				"title":   "Top Up Berhasil",
				"message": fmt.Sprintf("%d koin berhasil ditambahkan ke akun laundry kamu.", broadcastTopup.Jumlah),
				"payload": map[string]interface{}{"topup_id": broadcastTopup.ID, "status": broadcastFinal},
			})
		} else {
			title, message := topupStatusCopy(broadcastFinal)
			utils.AppHub.BroadcastToOutlet(broadcastTopup.OutletID, map[string]interface{}{
				"type":    "TOPUP_STATUS_CHANGED",
				"title":   title,
				"message": message,
				"payload": map[string]interface{}{
					"topup_id": broadcastTopup.ID,
					"status":   broadcastFinal,
				},
			})
		}
	}

	return err
}

func topupStatusCopy(status string) (string, string) {
	switch status {
	case "failed":
		return "Top Up Tidak Berhasil", "Pembayaran top up belum berhasil diproses. Kamu bisa membuat tagihan baru atau menghubungi bantuan jika sudah melakukan pembayaran."
	case "challenge":
		return "Top Up Perlu Ditinjau", "Pembayaran top up sedang ditinjau. Koin akan ditambahkan setelah status pembayaran terkonfirmasi."
	default:
		return "Top Up Menunggu Pembayaran", "Tagihan top up masih menunggu pembayaran. Selesaikan pembayaran agar koin dapat masuk ke akun laundry kamu."
	}
}

func (s *KoinService) ApproveTopupCoins(tx *gorm.DB, topup model.TopupKoin) error {
	errUpdate := tx.Model(&model.Outlet{}).
		Where("ot_id = ?", topup.OutletID).
		Update("ot_koin", gorm.Expr("ot_koin + ?", topup.Jumlah)).Error

	if errUpdate != nil {
		return fmt.Errorf("gagal update saldo koin: %v", errUpdate)
	}

	keterangan := fmt.Sprintf("Top Up %d Koin via %s (%s)", topup.Jumlah, topup.MetodeBayar, topup.ID)
	if err := s.AddHistoryKoin(tx, topup.OutletID, "masuk", topup.Jumlah, keterangan, topup.UserUpdate); err != nil {
		return err
	}

	// PROSES REWARD REFERRAL (PERCENTAGE TOPUP)
	referralSvc := NewReferralService(tx, s)
	if errRef := referralSvc.ProcessTopupReward(tx, topup); errRef != nil {
		// Kita log error tapi jangan gagalkan transaksi utama koin
		fmt.Printf("Error processing referral reward: %v\n", errRef)
	}

	// Invalidate cache profil koin
	database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", topup.OutletID))

	return nil
}

func (s *KoinService) AdminInjectCoin(outletID string, jumlahKoin int, alasan string, metodeBayar string, buktiPath *string, adminID string) error {
	if jumlahKoin <= 0 {
		return errors.New("jumlah koin harus lebih dari 0")
	}
	if strings.TrimSpace(alasan) == "" {
		return errors.New("alasan penambahan koin wajib diisi")
	}

	return s.db.Transaction(func(tx *gorm.DB) error {
		var totalNominal float64 = 0
		if metodeBayar == "transfer" {
			pricePerCoin := 200.0
			var cfg model.EconomyConfig
			if errCfg := tx.Where("cfg_key = ?", "price_per_coin").First(&cfg).Error; errCfg == nil {
				if parsed, errParse := strconv.ParseFloat(cfg.Value, 64); errParse == nil && parsed > 0 {
					pricePerCoin = parsed
				}
			}
			totalNominal = float64(jumlahKoin) * pricePerCoin
		}

		// 1. Buat record TopupKoin khusus inject
		topupID := fmt.Sprintf("TK-INJ-%d%s", time.Now().Unix(), utils.RandomString(4))
		now := time.Now()

		trimmedAlasan := strings.TrimSpace(alasan)
		topup := model.TopupKoin{
			ID:              topupID,
			OutletID:        outletID,
			Jumlah:          jumlahKoin,
			MetodeBayar:     metodeBayar,
			Potongan:        0,
			NominalDasar:    totalNominal,
			KodeUnik:        0,
			Total:           totalNominal,
			ExpiredAt:       now,
			Status:          "success",
			CreatedAt:       now,
			StafValidasi:    &adminID,
			TanggalValidasi: &now,
			UserUpdate:      adminID,
			BuktiTransfer:   buktiPath,
			// Alasan disimpan sebagai catatan internal admin (tidak pernah
			// ditampilkan ke owner).
			InternalNote: &trimmedAlasan,
		}

		if err := tx.Create(&topup).Error; err != nil {
			return fmt.Errorf("gagal membuat data transaksi inject: %v", err)
		}

		// 2. Tambahkan saldo koin ke outlet
		errUpdate := tx.Model(&model.Outlet{}).
			Where("ot_id = ?", outletID).
			Update("ot_koin", gorm.Expr("ot_koin + ?", jumlahKoin)).Error
		if errUpdate != nil {
			return fmt.Errorf("gagal menambahkan saldo koin: %v", errUpdate)
		}

		// 3. Catat history koin. Keterangan owner-facing dibuat GENERIK — alasan
		// admin TIDAK diikutkan di sini karena history tampil ke owner.
		keterangan := fmt.Sprintf("Tambahan %d Koin dari AyoCuci", jumlahKoin)
		if err := s.AddHistoryKoin(tx, outletID, "masuk", jumlahKoin, keterangan, adminID); err != nil {
			return fmt.Errorf("gagal mencatat riwayat koin: %v", err)
		}

		// 4. Kirim notifikasi sistem
		if notifErr := notifier.CreateOutletNotification(
			tx,
			outletID,
			"KOIN",
			"Tambahan Koin Masuk",
			fmt.Sprintf("AyoCuci telah menambahkan %d koin ke saldo laundry kamu.", jumlahKoin),
			map[string]interface{}{"topup_id": topup.ID, "status": "success", "type": "inject"},
		); notifErr != nil {

			fmt.Printf("Gagal membuat notifikasi koin inject: %v\n", notifErr)
		}

		// 5. Broadcast websocket agar aplikasi client kasir auto-refresh saldo
		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{
			"type":    "COIN_UPDATED",
			"title":   "Koin Ditambahkan",
			"message": fmt.Sprintf("Admin telah menambahkan %d koin ke saldo laundry kamu.", jumlahKoin),
			"payload": map[string]interface{}{"status": "success", "type": "inject"},
		})

		// Invalidate cache profil koin
		database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID))

		return nil
	})
}

// ==========================================
// 5. ECONOMY CORE LOGIC
// ==========================================

func (s *KoinService) DeductCoinForTransaction(tx *gorm.DB, outletID string, userID string, invoice string) error {
	var cfg model.EconomyConfig
	if err := tx.Where("cfg_key = ?", "coin_per_transaction").First(&cfg).Error; err != nil {
		cfg.Value = "1"
	}
	amount := utils.StringToInt(cfg.Value)

	var outlet model.Outlet
	if err := tx.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return errors.New("outlet tidak ditemukan")
	}

	if outlet.Koin < amount {
		return errors.New("saldo koin tidak mencukupi, silakan top up")
	}

	if err := tx.Model(&outlet).Update("ot_koin", gorm.Expr("ot_koin - ?", amount)).Error; err != nil {
		return errors.New("gagal memproses pemotongan koin")
	}

	keterangan := "Pemakaian koin untuk transaksi: " + invoice
	errHistory := s.AddHistoryKoin(tx, outletID, "keluar", amount, keterangan, userID)

	if errHistory == nil {
		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{"type": "COIN_UPDATED"})
		// Invalidate cache profil koin
		database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID))
	}
	return errHistory
}

func (s *KoinService) DeductCoinManual(tx *gorm.DB, outletID string, amount int, keterangan string, userID string) error {
	var outlet model.Outlet
	if err := tx.Where("ot_id = ?", outletID).First(&outlet).Error; err != nil {
		return errors.New("outlet tidak ditemukan")
	}

	if outlet.Koin < amount {
		return fmt.Errorf("saldo koin tidak cukup. Butuh %d koin", amount)
	}

	if err := tx.Model(&outlet).Update("ot_koin", gorm.Expr("ot_koin - ?", amount)).Error; err != nil {
		return errors.New("gagal update saldo koin")
	}

	errHistory := s.AddHistoryKoin(tx, outletID, "keluar", amount, keterangan, userID)
	if errHistory == nil {
		utils.AppHub.BroadcastToOutlet(outletID, map[string]interface{}{"type": "COIN_UPDATED"})
		// Invalidate cache profil koin
		database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", outletID))
	}
	return errHistory
}

func (s *KoinService) AddHistoryKoin(tx *gorm.DB, outletID string, jenis string, jumlah int, keterangan string, userID string) error {
	history := model.HistoryKoin{
		ID: utils.GenHistoryKoinID(tx, outletID), OutletID: outletID, JenisTransaksi: jenis,
		Jumlah: jumlah, Keterangan: keterangan, Status: 1, CreatedAt: time.Now(), UserUpdate: userID,
	}
	return tx.Create(&history).Error
}

// ==========================================
// 6. ADMIN PANEL LOGIC
// ==========================================

// getPricePerCoin membaca rate rupiah per koin dari EconomyConfig (sumber yang
// sama dengan topup Midtrans). Dipakai untuk mengestimasi nominal rupiah topup
// IAP, yang tidak menyimpan harga rupiah di ac_history_koin.
// GetPricePerCoin mengekspos rate rupiah per koin untuk service lain (mis. IAP).
func (s *KoinService) GetPricePerCoin() float64 {
	return s.getPricePerCoin()
}

func (s *KoinService) getPricePerCoin() float64 {
	pricePerCoin := 200.0
	var cfg model.EconomyConfig
	if err := s.db.Where("cfg_key = ?", "price_per_coin").First(&cfg).Error; err == nil {
		if parsed, errParse := strconv.ParseFloat(cfg.Value, 64); errParse == nil && parsed > 0 {
			pricePerCoin = parsed
		}
	}
	return pricePerCoin
}

func (s *KoinService) AdminListTopups(outletID, status, metode, startDate, endDate string) ([]admin.TopupKoinAdminRes, error) {
	var results []admin.TopupKoinAdminRes

	// FIX: Tambahkan COLLATE utf8mb4_unicode_ci pada CAST as CHAR untuk menyamakan collation dengan tabel
	query := s.db.Table("ac_top_koin t").
		Select(`t.id AS tk_id, t.tk_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name, 
                t.tk_jumlah, t.tk_metode_bayar, t.tk_nominal_dasar, t.tk_kode_unik, t.tk_total, t.tk_expired_at, t.tk_bukti, b.bank_name, 
                t.tk_status, t.tk_created, t.tk_lastupdate, t.tk_tanggal_upload_bukti, t.tk_tanggal_validasi, COALESCE(a.adm_nama, t.tk_staf_validasi) as tk_staf_validasi`).
		Joins("LEFT JOIN ac_outlet o ON t.tk_outlet = o.ot_id").
		Joins("LEFT JOIN ac_user u ON t.tk_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci").
		Joins("LEFT JOIN ac_bank_accounts b ON t.tk_bank_id = b.id").
		Joins("LEFT JOIN ac_admin a ON t.tk_staf_validasi = a.adm_id")

	if outletID != "" {
		query = query.Where("t.tk_outlet = ?", outletID)
	}
	if status != "" {
		query = query.Where("t.tk_status = ?", status)
	}
	if metode != "" {
		query = query.Where("t.tk_metode_bayar = ?", metode)
	}
	if startDate != "" && endDate != "" {
		query = query.Where("DATE(t.tk_created) BETWEEN ? AND ?", startDate, endDate)
	}

	if err := query.Order("t.tk_created DESC").Scan(&results).Error; err != nil {
		return nil, err
	}

	// Topup via Apple IAP tidak membuat row di ac_top_koin (langsung masuk
	// ac_history_koin), sehingga tanpa ini tidak muncul di widget/aktivitas
	// topup. Hanya IAP yang diikutkan — bonus lain (referral, pendaftaran,
	// promo) sengaja dikecualikan agar daftar tetap khusus topup.
	includeIap := (metode == "" || metode == "iap_topup" || metode == "iap") &&
		(status == "" || status == "success" || status == "completed" || status == "accepted")
	if includeIap {
		var iaps []admin.TopupKoinAdminRes
		iapQuery := s.db.Table("ac_history_koin h").
			Select(`h.hk_id AS tk_id, h.hk_outlet AS tk_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name,
                h.hk_jumlah AS tk_jumlah, 'iap_topup' AS tk_metode_bayar, 0 AS tk_nominal_dasar,
                0 AS tk_kode_unik, 0 AS tk_total, 'success' AS tk_status, h.hk_created AS tk_created`).
			Joins("LEFT JOIN ac_outlet o ON h.hk_outlet = o.ot_id").
			Joins("LEFT JOIN ac_user u ON o.ot_user = u.usr_id").
			Where("h.hk_jenis_transaksi = ?", "masuk").
			Where("(LOWER(h.hk_keterangan) LIKE ? OR LOWER(h.hk_keterangan) LIKE ? OR LOWER(h.hk_keterangan) LIKE ?)",
				"%apple iap%", "%app store%", "%ios iap%")

		if outletID != "" {
			iapQuery = iapQuery.Where("h.hk_outlet = ?", outletID)
		}
		if startDate != "" && endDate != "" {
			iapQuery = iapQuery.Where("DATE(h.hk_created) BETWEEN ? AND ?", startDate, endDate)
		}

		if err := iapQuery.Scan(&iaps).Error; err != nil {
			return nil, err
		}

		// Estimasi nominal rupiah dari rate koin internal (koin × price_per_coin),
		// karena ac_history_koin tidak menyimpan harga rupiah IAP.
		pricePerCoin := s.getPricePerCoin()
		for i := range iaps {
			iaps[i].Total = float64(iaps[i].Jumlah) * pricePerCoin
		}
		results = append(results, iaps...)

		// Urutkan ulang gabungan (ac_top_koin + IAP) berdasarkan waktu dibuat.
		sort.Slice(results, func(i, j int) bool {
			return results[i].CreatedAt.After(results[j].CreatedAt)
		})
	}

	return results, nil
}

func (s *KoinService) AdminGetTopupDetail(topupID string) (admin.TopupKoinAdminRes, error) {
	var result admin.TopupKoinAdminRes

	// FIX: Tambahkan COLLATE utf8mb4_unicode_ci pada CAST as CHAR
	query := `SELECT t.id AS tk_id, t.tk_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name,
               t.tk_jumlah, t.tk_metode_bayar, t.tk_nominal_dasar, t.tk_kode_unik, t.tk_total, t.tk_expired_at, t.tk_bukti, b.bank_name,
               t.tk_status, t.tk_created, t.tk_snap_url, t.tk_lastupdate, t.tk_tanggal_upload_bukti, t.tk_tanggal_validasi, COALESCE(a.adm_nama, t.tk_staf_validasi) as tk_staf_validasi
        FROM ac_top_koin t
        LEFT JOIN ac_outlet o ON t.tk_outlet = o.ot_id
        LEFT JOIN ac_user u ON t.tk_userupdate = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci
        LEFT JOIN ac_bank_accounts b ON t.tk_bank_id = b.id
        LEFT JOIN ac_admin a ON t.tk_staf_validasi = a.adm_id WHERE t.id = ?`
	err := s.db.Raw(query, topupID).Scan(&result).Error
	return result, err
}

func (s *KoinService) AdminCancelMidtrans(topupID string, adminID string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		var topup model.TopupKoin
		if err := tx.Where("id = ? AND tk_metode_bayar = ? AND tk_status = ?", topupID, "midtrans", "pending").First(&topup).Error; err != nil {
			return errors.New("transaksi tidak ditemukan atau tidak bisa dibatalkan")
		}
		now := time.Now()
		err := tx.Model(&topup).Updates(map[string]interface{}{
			"tk_status":           "failed",
			"tk_staf_validasi":    adminID,
			"tk_tanggal_validasi": &now,
			"tk_userupdate":       adminID,
		}).Error

		if err == nil {
			if notifErr := notifier.CreateOutletNotification(
				tx,
				topup.OutletID,
				"KOIN",
				"Top Up Dibatalkan",
				"Tagihan top up Midtrans dibatalkan oleh admin. Buat tagihan baru jika kamu masih ingin membeli koin.",
				map[string]interface{}{"topup_id": topup.ID, "status": "failed"},
			); notifErr != nil {
				fmt.Printf("Gagal membuat notifikasi top up dibatalkan: %v\n", notifErr)
			}
			utils.AppHub.BroadcastToOutlet(topup.OutletID, map[string]interface{}{
				"type":    "TOPUP_STATUS_CHANGED",
				"title":   "Top Up Dibatalkan",
				"message": "Tagihan top up Midtrans dibatalkan oleh admin. Buat tagihan baru jika kamu masih ingin membeli koin.",
				"payload": map[string]interface{}{"topup_id": topup.ID, "status": "failed"},
			})
		}
		return err
	})
}

func (s *KoinService) AdminConfirmPayment(topupID string, status string, adminID string) error {
	var (
		broadcastTopup *model.TopupKoin
		finalStatus    string
	)

	err := s.db.Transaction(func(tx *gorm.DB) error {
		var topup model.TopupKoin
		if err := tx.Where("id = ? AND tk_status = ?", topupID, "pending").First(&topup).Error; err != nil {
			return errors.New("transaksi tidak ditemukan atau sudah diproses")
		}

		now := time.Now()
		if status == "success" {
			if err := tx.Model(&topup).Updates(map[string]interface{}{"tk_status": "success", "tk_staf_validasi": adminID, "tk_tanggal_validasi": &now}).Error; err != nil {
				return err
			}
			errApprove := s.ApproveTopupCoins(tx, topup)
			if errApprove == nil {
				if notifErr := notifier.CreateOutletNotification(
					tx,
					topup.OutletID,
					"KOIN",
					"Top Up Disetujui",
					fmt.Sprintf("Pembayaran kamu sudah dikonfirmasi. %d koin berhasil ditambahkan ke akun laundry kamu.", topup.Jumlah),
					map[string]interface{}{"topup_id": topup.ID, "status": "success"},
				); notifErr != nil {
					fmt.Printf("Gagal membuat notifikasi top up disetujui: %v\n", notifErr)
				}
				broadcastTopup = &topup
				finalStatus = "success"
			}
			return errApprove
		}

		err := tx.Model(&topup).Updates(map[string]interface{}{"tk_status": "failed", "tk_staf_validasi": adminID, "tk_tanggal_validasi": &now}).Error
		if err == nil {
			if notifErr := notifier.CreateOutletNotification(
				tx,
				topup.OutletID,
				"KOIN",
				"Top Up Ditolak",
				"Pembayaran top up belum dapat disetujui. Periksa kembali bukti transfer atau hubungi bantuan AyoCuci.",
				map[string]interface{}{"topup_id": topup.ID, "status": "failed"},
			); notifErr != nil {
				fmt.Printf("Gagal membuat notifikasi top up ditolak: %v\n", notifErr)
			}
			broadcastTopup = &topup
			finalStatus = "failed"
		}
		return err
	})

	if err == nil && broadcastTopup != nil {
		database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", broadcastTopup.OutletID))
		if finalStatus == "success" {
			utils.AppHub.BroadcastToOutlet(broadcastTopup.OutletID, map[string]interface{}{
				"type":    "TOPUP_STATUS_CHANGED",
				"title":   "Top Up Disetujui",
				"message": fmt.Sprintf("Pembayaran kamu sudah dikonfirmasi. %d koin berhasil ditambahkan ke akun laundry kamu.", broadcastTopup.Jumlah),
				"payload": map[string]interface{}{"topup_id": broadcastTopup.ID, "status": "success"},
			})
		} else {
			utils.AppHub.BroadcastToOutlet(broadcastTopup.OutletID, map[string]interface{}{
				"type":    "TOPUP_STATUS_CHANGED",
				"title":   "Top Up Ditolak",
				"message": "Pembayaran top up belum dapat disetujui. Periksa kembali bukti transfer atau hubungi bantuan AyoCuci.",
				"payload": map[string]interface{}{"topup_id": broadcastTopup.ID, "status": "failed"},
			})
		}
	}

	return err
}

// AdminListAllPemasukan aggregates all incoming coin transactions (topups and bonus histories)
func (s *KoinService) AdminListAllPemasukan(outletID, status, metode, startDate, endDate string) ([]admin.PemasukanKoinAdminRes, error) {
	var results []admin.PemasukanKoinAdminRes

	// 1. Fetch topups from ac_top_koin if metode is not "bonus"
	var topups []admin.TopupKoinAdminRes
	if metode == "" || metode == "all" || metode == "transfer" || metode == "midtrans" {
		query := s.db.Table("ac_top_koin t").
			Select(`t.id AS tk_id, t.tk_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name, 
					t.tk_jumlah, t.tk_metode_bayar, t.tk_nominal_dasar, t.tk_kode_unik, t.tk_total, t.tk_expired_at, t.tk_bukti, b.bank_name, 
					t.tk_status, t.tk_created, t.tk_lastupdate, t.tk_tanggal_upload_bukti, t.tk_tanggal_validasi, COALESCE(a.adm_nama, t.tk_staf_validasi) as tk_staf_validasi`).
			Joins("LEFT JOIN ac_outlet o ON t.tk_outlet = o.ot_id").
			Joins("LEFT JOIN ac_user u ON o.ot_user = u.usr_id").
			Joins("LEFT JOIN ac_bank_accounts b ON t.tk_bank_id = b.id").
			Joins("LEFT JOIN ac_admin a ON t.tk_staf_validasi = a.adm_id")

		if outletID != "" {
			query = query.Where("t.tk_outlet = ?", outletID)
		}
		if status != "" && status != "all" {
			dbStatus := status
			if status == "completed" {
				dbStatus = "success"
			}
			query = query.Where("t.tk_status = ?", dbStatus)
		}
		if metode != "" && metode != "all" {
			query = query.Where("t.tk_metode_bayar = ?", metode)
		}
		if startDate != "" && endDate != "" {
			query = query.Where("DATE(t.tk_created) BETWEEN ? AND ?", startDate, endDate)
		}

		if err := query.Find(&topups).Error; err != nil {
			return nil, err
		}
	}

	// 2. Fetch history from ac_history_koin if status is not "pending" or "failed", and metode is not "transfer" or "midtrans"
	var histories []struct {
		ID         string    `gorm:"column:tk_id"`
		OutletID   string    `gorm:"column:tk_outlet"`
		OutletName string    `gorm:"column:outlet_name"`
		OwnerName  string    `gorm:"column:owner_name"`
		Jumlah     int       `gorm:"column:tk_jumlah"`
		CreatedAt  time.Time `gorm:"column:tk_created"`
		Keterangan string    `gorm:"column:keterangan"`
	}
	if (status == "" || status == "all" || status == "success" || status == "completed") &&
		(metode == "" || metode == "all" || metode == "bonus") {
		queryHist := s.db.Table("ac_history_koin h").
			Select(`h.hk_id AS tk_id, h.hk_outlet AS tk_outlet, o.ot_nama AS outlet_name, u.usr_nama AS owner_name, 
					h.hk_jumlah AS tk_jumlah, h.hk_created AS tk_created, h.hk_keterangan AS keterangan`).
			Joins("LEFT JOIN ac_outlet o ON h.hk_outlet = o.ot_id").
			Joins("LEFT JOIN ac_user u ON o.ot_user = u.usr_id").
			Where("h.hk_jenis_transaksi = ?", "masuk").
			Where("h.hk_keterangan NOT LIKE ?", "%TK-%")

		if outletID != "" {
			queryHist = queryHist.Where("h.hk_outlet = ?", outletID)
		}
		if startDate != "" && endDate != "" {
			queryHist = queryHist.Where("DATE(h.hk_created) BETWEEN ? AND ?", startDate, endDate)
		}

		if err := queryHist.Find(&histories).Error; err != nil {
			return nil, err
		}
	}

	// Ambil urutan historis dari seluruh data (tanpa filter periode). Urutan ini
	// harus melekat pada transaksi saat terjadi dan tidak boleh berubah hanya
	// karena outlet melakukan top up berikutnya.
	topupSequenceByID := map[string]int{}
	{
		outletSet := map[string]struct{}{}
		for _, t := range topups {
			if t.OutletID != "" {
				outletSet[t.OutletID] = struct{}{}
			}
		}
		for _, h := range histories {
			if h.OutletID != "" {
				outletSet[h.OutletID] = struct{}{}
			}
		}
		if len(outletSet) > 0 {
			ids := make([]string, 0, len(outletSet))
			for id := range outletSet {
				ids = append(ids, id)
			}
			var events []struct {
				EventID   string    `gorm:"column:event_id"`
				OutletID  string    `gorm:"column:outlet_id"`
				CreatedAt time.Time `gorm:"column:created_at"`
			}
			// Top up pertama adalah bonus pendaftaran. Berikutnya adalah top up
			// berbayar sukses, termasuk IAP yang dicatat di history koin.
			eventQuery := `
				SELECT CONCAT('topup:', id) AS event_id, tk_outlet AS outlet_id, tk_created AS created_at
				FROM ac_top_koin
				WHERE LOWER(COALESCE(tk_status, '')) IN ('success', 'completed', 'accepted') AND tk_outlet IN ?
				UNION ALL
				SELECT CONCAT('history:', hk_id) AS event_id, hk_outlet AS outlet_id, hk_created AS created_at
				FROM ac_history_koin
				WHERE hk_jenis_transaksi = 'masuk' AND hk_outlet IN ?
				  AND (LOWER(hk_keterangan) LIKE '%pendaftaran%'
				       OR LOWER(hk_keterangan) LIKE '%apple iap%'
				       OR LOWER(hk_keterangan) LIKE '%app store%'
				       OR LOWER(hk_keterangan) LIKE '%ios iap%')`
			if err := s.db.Raw(eventQuery, ids, ids).Scan(&events).Error; err != nil {
				return nil, err
			}
			sort.SliceStable(events, func(i, j int) bool {
				if events[i].OutletID == events[j].OutletID && events[i].CreatedAt.Equal(events[j].CreatedAt) {
					return events[i].EventID < events[j].EventID
				}
				if events[i].OutletID == events[j].OutletID {
					return events[i].CreatedAt.Before(events[j].CreatedAt)
				}
				return events[i].OutletID < events[j].OutletID
			})
			sequenceByOutlet := map[string]int{}
			for _, event := range events {
				sequenceByOutlet[event.OutletID]++
				topupSequenceByID[event.EventID] = sequenceByOutlet[event.OutletID]
			}
		}
	}
	topupType := func(sequence int) string {
		if sequence == 1 {
			return "bonus_nasabah_baru"
		}
		if sequence == 2 {
			return "nasabah_baru"
		}
		if sequence >= 3 {
			return "repeat_topup"
		}
		return ""
	}

	// 3. Map and merge
	for _, t := range topups {
		uiStatus := t.Status
		if t.Status == "success" {
			uiStatus = "completed"
		}

		sequence := topupSequenceByID["topup:"+t.ID]
		results = append(results, admin.PemasukanKoinAdminRes{
			ID:                 t.ID,
			OutletID:           t.OutletID,
			TopupSequence:      sequence,
			CustomerTopupType:  topupType(sequence),
			OutletName:         t.OutletName,
			OwnerName:          t.OwnerName,
			Jumlah:             t.Jumlah,
			MetodeBayar:        t.MetodeBayar,
			SourceType:         "topup_koin",
			NominalDasar:       t.NominalDasar,
			KodeUnik:           t.KodeUnik,
			Total:              t.Total,
			Bukti:              t.Bukti,
			BankName:           t.BankName,
			Status:             uiStatus,
			CreatedAt:          t.CreatedAt,
			LastUpdate:         t.LastUpdate,
			TanggalUploadBukti: t.TanggalUploadBukti,
			TanggalValidasi:    t.TanggalValidasi,
			StafValidasi:       t.StafValidasi,
			Keterangan:         "",
			BonusType:          "",
		})
	}

	pricePerCoin := s.getPricePerCoin()
	for _, h := range histories {
		bonusType := "Bonus"
		sourceType := "bonus"
		total := 0.0
		descLower := strings.ToLower(h.Keterangan)
		if strings.Contains(descLower, "apple iap") ||
			strings.Contains(descLower, "app store") ||
			strings.Contains(descLower, "ios iap") {
			bonusType = "Top Up IAP"
			sourceType = "iap_topup"
			// Estimasi nominal rupiah IAP dari rate koin internal.
			total = float64(h.Jumlah) * pricePerCoin
		} else if strings.Contains(descLower, "pendaftaran") {
			bonusType = "Pendaftaran"
		} else if strings.Contains(descLower, "referral") {
			bonusType = "Referral"
		} else if strings.Contains(descLower, "konversi") {
			bonusType = "Referral Koin"
		} else if strings.Contains(descLower, "manual") || strings.Contains(descLower, "pengisian") || strings.Contains(descLower, "tambah") {
			bonusType = "Manual"
		} else {
			bonusType = "Promo/Event"
		}

		sequence := topupSequenceByID["history:"+h.ID]
		results = append(results, admin.PemasukanKoinAdminRes{
			ID:                h.ID,
			OutletID:          h.OutletID,
			TopupSequence:     sequence,
			CustomerTopupType: topupType(sequence),
			OutletName:        h.OutletName,
			OwnerName:         h.OwnerName,
			Jumlah:            h.Jumlah,
			MetodeBayar:       sourceType,
			SourceType:        sourceType,
			Total:             total,
			Bukti:             nil,
			BankName:          nil,
			Status:            "completed",
			CreatedAt:         h.CreatedAt,
			Keterangan:        h.Keterangan,
			BonusType:         bonusType,
		})
	}

	// 4. Sort by CreatedAt DESC
	sort.Slice(results, func(i, j int) bool {
		return results[i].CreatedAt.After(results[j].CreatedAt)
	})

	return results, nil
}

func (s *KoinService) AdminCoinLedger(outletID, jenis, sourceType, startDate, endDate, search string) ([]admin.CoinLedgerAdminRes, error) {
	var results []admin.CoinLedgerAdminRes

	query := s.db.Table("ac_history_koin h").
		Select(`
			h.hk_id,
			h.hk_outlet,
			o.ot_nama AS outlet_name,
			u.usr_nama AS owner_name,
			h.hk_jenis_transaksi,
			h.hk_jumlah,
			h.hk_keterangan,
			h.hk_status,
			h.hk_created,
			CASE
				WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%add-on%' OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%addon%' THEN 'addon_koin'
				WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%transaksi%' THEN 'transaksi_laundry'
				WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%top up%' OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%topup%' OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%tambahan%' THEN 'topup_koin'
				WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%referral%' THEN 'referral'
				WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%pendaftaran%' THEN 'bonus_pendaftaran'
				WHEN LOWER(COALESCE(h.hk_keterangan, '')) LIKE '%manual%' THEN 'manual'
				ELSE 'lainnya'
			END AS source_type`).
		Joins("LEFT JOIN ac_outlet o ON h.hk_outlet = o.ot_id").
		Joins("LEFT JOIN ac_user u ON o.ot_user = u.usr_id")

	if outletID != "" && outletID != "all" {
		query = query.Where("h.hk_outlet = ?", outletID)
	}
	if jenis != "" && jenis != "all" {
		query = query.Where("h.hk_jenis_transaksi = ?", jenis)
	}
	if sourceType != "" && sourceType != "all" {
		switch sourceType {
		case "addon_koin":
			query = query.Where("(LOWER(COALESCE(h.hk_keterangan, '')) LIKE ? OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?)", "%add-on%", "%addon%")
		case "transaksi_laundry":
			query = query.Where("LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?", "%transaksi%")
		case "topup_koin":
			query = query.Where("(LOWER(COALESCE(h.hk_keterangan, '')) LIKE ? OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE ? OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?)", "%top up%", "%topup%", "%tambahan%")
		case "referral":
			query = query.Where("LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?", "%referral%")
		case "bonus_pendaftaran":
			query = query.Where("LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?", "%pendaftaran%")
		case "manual":
			query = query.Where("LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?", "%manual%")
		case "lainnya":
			query = query.Where(`
				LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?
				AND LOWER(COALESCE(h.hk_keterangan, '')) NOT LIKE ?`,
				"%add-on%", "%addon%", "%transaksi%", "%top up%", "%topup%", "%referral%", "%pendaftaran%", "%manual%", "%tambahan%")
		}
	}
	if startDate != "" && endDate != "" {
		query = query.Where("DATE(h.hk_created) BETWEEN ? AND ?", startDate, endDate)
	}
	if search != "" {
		like := "%" + strings.ToLower(search) + "%"
		query = query.Where(`
			LOWER(COALESCE(h.hk_id, '')) LIKE ?
			OR LOWER(COALESCE(h.hk_keterangan, '')) LIKE ?
			OR LOWER(COALESCE(o.ot_nama, '')) LIKE ?
			OR LOWER(COALESCE(u.usr_nama, '')) LIKE ?`,
			like, like, like, like,
		)
	}

	if err := query.Order("h.hk_created DESC").Scan(&results).Error; err != nil {
		return nil, err
	}

	return results, nil
}
