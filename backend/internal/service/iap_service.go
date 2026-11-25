package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/notifier"
	appleclient "github.com/RikardoAnju/PiposmartPro/internal/thirdparty/apple"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type AppleProductSpec struct {
	ProductID   string `json:"product_id"`
	ProductType string `json:"product_type"`
	CoinAmount  int    `json:"coin_amount"`
}

type IapService struct {
	db         *gorm.DB
	koinSvc    *KoinService
	addonSvc   *AddonService
	apple      *appleclient.VerifyClient
	bundleID   string
	productMap map[string]AppleProductSpec
}

func NewIapService(db *gorm.DB, koin *KoinService, addon *AddonService) *IapService {
	svc := &IapService{
		db:       db,
		koinSvc:  koin,
		addonSvc: addon,
		apple:    appleclient.NewVerifyClient(),
		bundleID: strings.TrimSpace(config.GetEnv("APPLE_BUNDLE_ID", "")),
		productMap: map[string]AppleProductSpec{
			"com.coin_100":                         {ProductID: "com.coin_100", ProductType: "COIN", CoinAmount: 100},
			"com.coin_200":                         {ProductID: "com.coin_200", ProductType: "COIN", CoinAmount: 200},
			"com.coin_500":                         {ProductID: "com.coin_500", ProductType: "COIN", CoinAmount: 500},
			"com.coin_1000":                        {ProductID: "com.coin_1000", ProductType: "COIN", CoinAmount: 1000},
			"com.coin_1500":                        {ProductID: "com.coin_1500", ProductType: "COIN", CoinAmount: 1500},
			"com.outlet_pro_activation":            {ProductID: "com.outlet_pro_activation", ProductType: "OUTLET_PRO"},
			"com.outlet_pro_activation_v2":         {ProductID: "com.outlet_pro_activation_v2", ProductType: "OUTLET_PRO"},
			"com.outlet_pro_activation_consumable": {ProductID: "com.outlet_pro_activation_consumable", ProductType: "OUTLET_PRO"},
		},
	}

	if raw := strings.TrimSpace(config.GetEnv("APPLE_IAP_PRODUCT_IDS", "")); raw != "" {
		_ = raw
	}

	return svc
}

type VerifyIosPurchaseInput struct {
	OutletID              string
	OwnerUserID           uint
	ProductID             string
	TransactionID         string
	OriginalTransactionID string
	ReceiptData           string
	EnvironmentHint       string
}

type VerifyIosPurchaseResult struct {
	StoreTransactionID string `json:"store_transaction_id"`
	OutletID           string `json:"outlet_id"`
	ProductID          string `json:"product_id"`
	ProductType        string `json:"product_type"`
	Environment        string `json:"environment"`
	CoinAmount         int    `json:"coin_amount,omitempty"`
	Activated          bool   `json:"activated,omitempty"`
}

func buildVerifyResultFromStoreTx(tx model.StoreTransaction) VerifyIosPurchaseResult {
	return VerifyIosPurchaseResult{
		StoreTransactionID: tx.ID,
		OutletID:           derefString(tx.OutletID),
		ProductID:          tx.ProductID,
		ProductType:        tx.ProductType,
		Environment:        tx.Environment,
		CoinAmount:         tx.CoinAmount,
		Activated:          tx.ProActivated,
	}
}

func (s *IapService) GetIosProducts() []AppleProductSpec {
	activeIDs := map[string]bool{
		"com.coin_100":                 true,
		"com.coin_200":                 true,
		"com.coin_500":                 true,
		"com.coin_1000":                true,
		"com.coin_1500":                true,
		"com.outlet_pro_activation_v2": true,
	}

	products := make([]AppleProductSpec, 0, len(activeIDs))
	for _, spec := range s.productMap {
		if activeIDs[spec.ProductID] {
			products = append(products, spec)
		}
	}
	return products
}

func (s *IapService) VerifyIosCoinTopup(input VerifyIosPurchaseInput) (VerifyIosPurchaseResult, error) {
	spec, err := s.getProductSpec(input.ProductID, "COIN")
	if err != nil {
		return VerifyIosPurchaseResult{}, err
	}

	if spec.CoinAmount <= 0 {
		return VerifyIosPurchaseResult{}, errors.New("produk koin tidak valid")
	}

	return s.verifyAndGrant(input, spec)
}

func (s *IapService) VerifyIosOutletPro(input VerifyIosPurchaseInput) (VerifyIosPurchaseResult, error) {
	spec, err := s.getProductSpec(input.ProductID, "OUTLET_PRO")
	if err != nil {
		return VerifyIosPurchaseResult{}, err
	}
	return s.verifyAndGrant(input, spec)
}

func (s *IapService) verifyAndGrant(input VerifyIosPurchaseInput, spec AppleProductSpec) (VerifyIosPurchaseResult, error) {
	if input.OutletID == "" {
		return VerifyIosPurchaseResult{}, errors.New("outlet_id wajib diisi")
	}
	if input.OwnerUserID == 0 {
		return VerifyIosPurchaseResult{}, errors.New("owner user tidak valid")
	}
	if strings.TrimSpace(input.TransactionID) == "" || strings.TrimSpace(input.ReceiptData) == "" {
		return VerifyIosPurchaseResult{}, errors.New("transaction_id dan receipt_data wajib diisi")
	}

	var outlet model.Outlet
	if err := s.db.Where("ot_id = ? AND ot_user = ?", input.OutletID, input.OwnerUserID).First(&outlet).Error; err != nil {
		return VerifyIosPurchaseResult{}, errors.New("outlet tidak ditemukan atau bukan milik akun ini")
	}

	forceSandbox := strings.EqualFold(strings.TrimSpace(input.EnvironmentHint), "sandbox")
	verification, err := s.apple.VerifyReceipt(input.ReceiptData, forceSandbox)
	if err != nil {
		return VerifyIosPurchaseResult{}, err
	}

	matched, err := s.findMatchingPurchase(verification, spec.ProductID, input.TransactionID)
	if err != nil {
		return VerifyIosPurchaseResult{}, err
	}

	if s.bundleID != "" && verification.Receipt.BundleID != "" && verification.Receipt.BundleID != s.bundleID {
		return VerifyIosPurchaseResult{}, errors.New("bundle id receipt tidak sesuai")
	}

	var result VerifyIosPurchaseResult
	var freshlyGranted bool
	err = s.db.Transaction(func(tx *gorm.DB) error {
		var existing model.StoreTransaction
		err := tx.Where("st_transaction_id = ?", input.TransactionID).First(&existing).Error
		if err == nil {
			if existing.GrantStatus != "DONE" {
				return errors.New("pembelian App Store ini sedang diproses. Tunggu sebentar lalu buka lagi halaman dompet koin")
			}
			result = buildVerifyResultFromStoreTx(existing)
			return nil
		}
		if !errors.Is(err, gorm.ErrRecordNotFound) {
			return err
		}

		now := time.Now()
		originalTx := strings.TrimSpace(matched.OriginalTransactionID)
		if originalTx == "" {
			originalTx = strings.TrimSpace(input.OriginalTransactionID)
		}

		storeTx := model.StoreTransaction{
			ID:             "ST-" + uuid.NewString(),
			Platform:       "IOS",
			Store:          "APP_STORE",
			ProductID:      spec.ProductID,
			ProductType:    spec.ProductType,
			TransactionID:  input.TransactionID,
			OwnerUserID:    input.OwnerUserID,
			OutletID:       &input.OutletID,
			ReceiptPayload: &input.ReceiptData,
			Status:         "VERIFIED",
			GrantStatus:    "PENDING",
			CoinAmount:     spec.CoinAmount,
			Environment:    verification.Environment,
			VerifiedAt:     &now,
			CreatedAt:      now,
		}
		if originalTx != "" {
			storeTx.OriginalTransactionID = &originalTx
		}

		if err := tx.Create(&storeTx).Error; err != nil {
			if strings.Contains(err.Error(), "1062") || strings.Contains(strings.ToLower(err.Error()), "duplicate entry") {
				var existingDuplicate model.StoreTransaction
				if errFind := s.db.Where("st_transaction_id = ?", input.TransactionID).First(&existingDuplicate).Error; errFind == nil {
					if existingDuplicate.GrantStatus != "DONE" {
						return errors.New("pembelian App Store ini sedang diproses. Tunggu sebentar lalu buka lagi halaman dompet koin")
					}
					result = buildVerifyResultFromStoreTx(existingDuplicate)
					return nil
				}
			}
			return err
		}

		switch spec.ProductType {
		case "COIN":
			if err := s.grantCoins(tx, outlet, spec.CoinAmount, input.OwnerUserID, storeTx.TransactionID); err != nil {
				return err
			}
		case "OUTLET_PRO":
			if outlet.ActivatedAt != nil {
				return errors.New("outlet sudah PRO")
			}
			if err := s.grantOutletPro(tx, outlet.ID, fmt.Sprintf("%d", input.OwnerUserID), storeTx.TransactionID); err != nil {
				return err
			}
			storeTx.ProActivated = true
		default:
			return errors.New("jenis produk store tidak dikenali")
		}

		storeTx.Status = "GRANTED"
		storeTx.GrantStatus = "DONE"
		storeTx.GrantedAt = &now
		if err := tx.Model(&model.StoreTransaction{}).
			Where("st_id = ?", storeTx.ID).
			Updates(map[string]interface{}{
				"st_status":        storeTx.Status,
				"st_grant_status":  storeTx.GrantStatus,
				"st_pro_activated": storeTx.ProActivated,
				"st_granted_at":    now,
				"st_lastupdate":    now,
			}).Error; err != nil {
			return err
		}

		result = VerifyIosPurchaseResult{
			StoreTransactionID: storeTx.ID,
			OutletID:           outlet.ID,
			ProductID:          spec.ProductID,
			ProductType:        spec.ProductType,
			Environment:        verification.Environment,
			CoinAmount:         spec.CoinAmount,
			Activated:          storeTx.ProActivated,
		}
		freshlyGranted = true
		return nil
	})

	if err == nil {
		database.InvalidateCache(fmt.Sprintf("outlet:profile:%s", result.OutletID))

		// Only notify/push on the call that actually performed the grant.
		// A retried/duplicate verify request (same transaction_id, e.g. from
		// StoreKit redelivering an unfinished transaction) hits the
		// idempotency check above and returns the same success result
		// without freshlyGranted — sending a notification for that too
		// would duplicate the push for a single purchase.
		if freshlyGranted && result.ProductType == "COIN" {
			topupTitle := "Top Up Berhasil"
			topupMessage := fmt.Sprintf("Top up %d koin via Apple IAP berhasil ditambahkan.", result.CoinAmount)
			topupPayload := map[string]interface{}{
				"topup_id":             result.StoreTransactionID,
				"store_transaction_id": result.StoreTransactionID,
				"status":               "success",
				"product_type":         result.ProductType,
				"product_id":           result.ProductID,
			}

			if notifErr := notifier.CreateOutletNotification(
				s.db,
				result.OutletID,
				"KOIN",
				topupTitle,
				topupMessage,
				topupPayload,
			); notifErr != nil {
				fmt.Printf("Gagal membuat notifikasi top up IAP: %v\n", notifErr)
			}

			utils.AppHub.BroadcastToOutlet(result.OutletID, map[string]interface{}{
				"type":    "TOPUP_SUCCESS",
				"title":   topupTitle,
				"message": topupMessage,
				"payload": topupPayload,
			})

			// NOTIFIKASI GRUP WA (Fonnte) — topup via Apple IAP langsung sukses
			// (tidak lewat tahap "dibuat / validasi bukti" seperti manual & midtrans).
			namaOutlet := strings.TrimSpace(outlet.Nama)
			if namaOutlet == "" {
				namaOutlet = "-"
			}
			estimasiRp := float64(result.CoinAmount) * s.koinSvc.GetPricePerCoin()

			var prevSukses int64
			s.db.Model(&model.StoreTransaction{}).
				Where("st_outlet_id = ? AND st_product_type = ? AND st_grant_status = ? AND st_transaction_id <> ?",
					result.OutletID, "COIN", "DONE", result.StoreTransactionID).
				Count(&prevSukses)
			tipePelanggan := "🟢 PELANGGAN BARU (top up IAP pertama)"
			if prevSukses > 0 {
				tipePelanggan = fmt.Sprintf("🔁 PELANGGAN LAMA (sudah %d× top up IAP)", prevSukses)
			}

			notifier.SendWhatsAppGroupAsync(fmt.Sprintf(
				"✅ *TOPUP IAP BERHASIL*\n"+
					"Outlet: %s (%s)\n"+
					"Jumlah: %d koin (est. Rp%s)\n"+
					"Metode: Apple IAP (%s)\n"+
					"Transaction ID: %s\n"+
					"%s\n"+
					"Status: koin sudah ditambahkan.",
				namaOutlet, result.OutletID, result.CoinAmount, notifier.FormatRupiah(estimasiRp),
				result.ProductID, input.TransactionID, tipePelanggan,
			))
		} else if freshlyGranted && result.ProductType == "OUTLET_PRO" {
			activationTitle := "Aktivasi PRO Berhasil"
			activationMessage := "Outlet ini telah berhasil ditingkatkan ke lisensi PRO."
			activationPayload := map[string]interface{}{"outlet_id": result.OutletID}

			if notifErr := notifier.CreateOutletNotification(
				s.db,
				result.OutletID,
				"SISTEM",
				activationTitle,
				activationMessage,
				activationPayload,
			); notifErr != nil {
				fmt.Printf("Gagal membuat notifikasi aktivasi PRO IAP: %v\n", notifErr)
			}

			utils.AppHub.BroadcastToOutlet(result.OutletID, map[string]interface{}{
				"type":    "OUTLET_ACTIVATED",
				"title":   activationTitle,
				"message": activationMessage,
				"payload": activationPayload,
			})
		}
	}

	return result, err
}

func (s *IapService) getProductSpec(productID, expectedType string) (AppleProductSpec, error) {
	spec, ok := s.productMap[productID]
	if !ok {
		return AppleProductSpec{}, errors.New("product_id iOS tidak terdaftar")
	}
	if spec.ProductType != expectedType {
		return AppleProductSpec{}, errors.New("product_id tidak cocok dengan jenis pembelian")
	}
	return spec, nil
}

func (s *IapService) findMatchingPurchase(verification appleclient.VerifyResponse, productID, transactionID string) (appleclient.InAppReceipt, error) {
	candidates := append([]appleclient.InAppReceipt{}, verification.Receipt.InApp...)
	candidates = append(candidates, verification.LatestInfo...)
	for _, item := range candidates {
		if item.ProductID == productID && item.TransactionID == transactionID {
			return item, nil
		}
	}
	return appleclient.InAppReceipt{}, errors.New("transaksi tidak ditemukan di receipt Apple")
}

func (s *IapService) grantCoins(tx *gorm.DB, outlet model.Outlet, amount int, ownerUserID uint, transactionID string) error {
	if err := tx.Model(&model.Outlet{}).
		Where("ot_id = ?", outlet.ID).
		Update("ot_koin", gorm.Expr("ot_koin + ?", amount)).Error; err != nil {
		return fmt.Errorf("gagal menambah saldo koin: %w", err)
	}

	if err := s.koinSvc.AddHistoryKoin(
		tx,
		outlet.ID,
		"masuk",
		amount,
		fmt.Sprintf("Top Up %d Koin via Apple IAP (%s)", amount, transactionID),
		fmt.Sprintf("%d", ownerUserID),
	); err != nil {
		return err
	}

	referralSvc := NewReferralService(tx, s.koinSvc)
	storeTx := model.StoreTransaction{
		ID:         transactionID,
		OutletID:   &outlet.ID,
		CoinAmount: amount,
	}
	if errRef := referralSvc.ProcessStoreTopupReward(tx, storeTx); errRef != nil {
		fmt.Printf("Error processing iOS referral reward: %v\n", errRef)
	}

	return nil
}

func (s *IapService) grantOutletPro(tx *gorm.DB, outletID, actorID, transactionID string) error {
	if err := s.addonSvc.executeOutletActivation(tx, outletID); err != nil {
		return err
	}

	configs := s.addonSvc.getEconomyConfigs(tx, "activation_fee", "activation_discount_pct")
	fee := configs["activation_fee"]
	disc := configs["activation_discount_pct"]
	totalBayar := fee - (fee * disc / 100)

	now := time.Now()
	trxID := fmt.Sprintf("PRO-IOS-%d", now.Unix())
	if err := tx.Exec(`INSERT INTO ac_transaksi_addons (ha_id, ha_outlet, ha_total, ha_metode_bayar, ha_status, ha_item_names, ha_created, ha_tanggal_validasi, ha_staf_validasi) 
			VALUES (?, ?, ?, 'APPLE_IAP', 'SUCCESS', 'Aktivasi Lisensi PRO', ?, ?, ?)`,
		trxID, outletID, totalBayar, now, now, "APPLE_IAP:"+transactionID).Error; err != nil {
		return err
	}
	if err := tx.Exec(`INSERT INTO ac_detail_transaksi_addons (dha_id, dha_transaksi, dha_addons, dha_harga) 
			VALUES (?, ?, 'OUTLET_ACTIVATION', ?)`,
		uuid.New().String(), trxID, totalBayar).Error; err != nil {
		return err
	}

	return nil
}

func derefString(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}
