package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/thirdparty/nobu"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

type NobuPaymentService struct {
	db               *gorm.DB
	client           *nobu.Client
	queryMu          sync.Mutex
	lastQueryByOrder map[string]time.Time
}

type B2BTokenRequest struct {
	GrantType      string `json:"grantType"`
	AdditionalInfo struct {
		PartnerID   string `json:"partnerId"`
		CallbackURL string `json:"callbackUrl"`
	} `json:"additionalInfo"`
}

func (s *NobuPaymentService) IssueCallbackToken(req B2BTokenRequest, headers http.Header) (map[string]any, error) {
	// Nobu mengirim X-CLIENT-KEY dan partnerId memakai Partner ID (tanpa dash),
	// sedangkan Client ID kita berformat dengan dash. Dokumen menyebut
	// "Client-Id should be same as X-PARTNER-ID", jadi kita terima cocok dengan
	// Client ID maupun Partner ID, dibandingkan tanpa memperhatikan dash/case.
	if req.GrantType != "client_credentials" ||
		!credMatches(req.AdditionalInfo.PartnerID, s.client.PartnerID, s.client.ClientID) ||
		!credMatches(headers.Get("X-CLIENT-KEY"), s.client.ClientID, s.client.PartnerID) {
		return nil, errors.New("credential B2B Nobu tidak valid")
	}
	// Verifikasi asymmetric signature Nobu bila public key dikonfigurasi.
	// stringToSign = X-CLIENT-KEY + "|" + X-TIMESTAMP (RSA PKCS1v15 SHA256).
	if s.client.PublicKeyPEM != "" {
		ts := headers.Get("X-TIMESTAMP")
		sig := headers.Get("X-SIGNATURE")
		if ts == "" || sig == "" {
			return nil, errors.New("signature/timestamp B2B Nobu tidak lengkap")
		}
		if err := nobu.VerifyRSASignature(s.client.PublicKeyPEM, headers.Get("X-CLIENT-KEY")+"|"+ts, sig); err != nil {
			return nil, fmt.Errorf("signature B2B Nobu tidak valid: %w", err)
		}
	}
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return nil, err
	}
	token := hex.EncodeToString(raw)
	hash := sha256.Sum256([]byte(token))
	expires := time.Now().Add(15 * time.Minute)
	// Simpan dengan Partner ID resmi kita agar konsisten dengan ValidateCallbackToken.
	entry := model.NobuCallbackToken{ID: uuid.NewString(), TokenHash: fmt.Sprintf("%x", hash[:]), PartnerID: s.client.PartnerID, ExpiresAt: expires}
	if err := s.db.Create(&entry).Error; err != nil {
		return nil, err
	}
	return map[string]any{"responseCode": "2007300", "responseMessage": "Request has been processed successfully", "accessToken": token, "tokenType": "Bearer", "expiresIn": "900", "additionalInfo": map[string]any{}}, nil
}

func (s *NobuPaymentService) RecordCallbackAudit(raw []byte, headers http.Header, validSignature, validToken bool, status string, processingErr error) {
	bodyHash := sha256.Sum256(raw)
	ref := ""
	var payload struct {
		OriginalPartnerReferenceNo string `json:"originalPartnerReferenceNo"`
	}
	_ = json.Unmarshal(raw, &payload)
	if payload.OriginalPartnerReferenceNo != "" {
		ref = payload.OriginalPartnerReferenceNo
	}
	errText := ""
	if processingErr != nil {
		errText = processingErr.Error()
	}
	safeHeaders, _ := json.Marshal(map[string]string{"content-type": headers.Get("Content-Type"), "x-external-id": headers.Get("X-EXTERNAL-ID"), "x-partner-id": headers.Get("X-PARTNER-ID"), "x-timestamp": headers.Get("X-TIMESTAMP"), "authorization_present": fmt.Sprintf("%t", headers.Get("Authorization") != ""), "signature_present": fmt.Sprintf("%t", headers.Get("X-SIGNATURE") != "")})
	_ = s.db.Create(&model.NobuCallbackAudit{ID: uuid.NewString(), ExternalID: headers.Get("X-EXTERNAL-ID"), PartnerID: headers.Get("X-PARTNER-ID"), OrderReference: ref, BodyHash: fmt.Sprintf("%x", bodyHash[:]), RequestBody: string(raw), RequestHeaders: string(safeHeaders), SignatureValid: validSignature, TokenValid: validToken, ProcessingStatus: status, ProcessingError: func() *string {
		if errText == "" {
			return nil
		}
		return &errText
	}()}).Error
}

func (s *NobuPaymentService) ValidateCallbackToken(token string) bool {
	token = strings.TrimSpace(strings.TrimPrefix(token, "Bearer"))
	if token == "" {
		return false
	}
	hash := sha256.Sum256([]byte(token))
	var entry model.NobuCallbackToken
	return s.db.Where("nct_token_hash = ? AND nct_expires_at > ? AND nct_partner_id = ?", fmt.Sprintf("%x", hash[:]), time.Now(), s.client.PartnerID).First(&entry).Error == nil
}

func NewNobuPaymentService(db *gorm.DB) *NobuPaymentService {
	privateKey := config.GetEnv("NOBU_PRIVATE_KEY", "")
	if path := config.GetEnv("NOBU_PRIVATE_KEY_PATH", ""); privateKey == "" && path != "" {
		if data, err := os.ReadFile(path); err == nil {
			privateKey = string(data)
		}
	}
	publicKey := config.GetEnv("NOBU_PUBLIC_KEY", "")
	if path := config.GetEnv("NOBU_PUBLIC_KEY_PATH", ""); publicKey == "" && path != "" {
		if data, err := os.ReadFile(path); err == nil {
			publicKey = string(data)
		}
	}
	return &NobuPaymentService{db: db, lastQueryByOrder: make(map[string]time.Time), client: &nobu.Client{
		PublicKeyPEM: publicKey,
		BaseURL:      config.GetEnv("NOBU_BASE_URL", "https://sandbox-api.nobubank.com"),
		ClientID:     config.GetEnv("NOBU_CLIENT_ID", ""), ClientSecret: config.GetEnv("NOBU_CLIENT_SECRET", ""),
		PartnerID: config.GetEnv("NOBU_PARTNER_ID", ""), MerchantID: config.GetEnv("NOBU_MERCHANT_ID", ""),
		ChannelID:     config.GetEnv("NOBU_CHANNEL_ID", ""),
		SubMerchantID: config.GetEnv("NOBU_SUB_MERCHANT_ID", ""), StoreID: config.GetEnv("NOBU_STORE_ID", ""),
		TerminalID: config.GetEnv("NOBU_TERMINAL_ID", ""), PrivateKeyPEM: privateKey,
	}}
}

type GenerateNobuQRResult struct {
	Payment      model.NobuPaymentTransaction `json:"payment"`
	NMID         string                       `json:"nmid"`
	MerchantName string                       `json:"merchant_name"`
	AcquirerCode string                       `json:"acquirer_code"`
	QRContent    string                       `json:"qr_content"`
	QRURL        string                       `json:"qr_url,omitempty"`
	QRImage      string                       `json:"qr_image,omitempty"`
}

type NobuQRStatusResult struct {
	Payment      model.NobuPaymentTransaction `json:"payment"`
	NMID         string                       `json:"nmid"`
	MerchantName string                       `json:"merchant_name"`
	AcquirerCode string                       `json:"acquirer_code"`
	QRContent    string                       `json:"qr_content"`
	QRURL        string                       `json:"qr_url,omitempty"`
	QRImage      string                       `json:"qr_image,omitempty"`
}

// acquirerCode mengambil kode institusi acquirer (8 digit awal MPAN/merchantId)
// untuk label "Dicetak oleh" sesuai panduan tampilan QRIS ASPI.
func (s *NobuPaymentService) acquirerCode() string {
	if len(s.client.MerchantID) >= 8 {
		return s.client.MerchantID[:8]
	}
	return s.client.MerchantID
}

// merchantName mengambil nama outlet untuk ditampilkan pada kartu QRIS.
func (s *NobuPaymentService) merchantName(outletID string) string {
	var outlet model.Outlet
	if err := s.db.Select("ot_nama").First(&outlet, "ot_id = ?", outletID).Error; err != nil {
		return ""
	}
	return outlet.Nama
}

func (s *NobuPaymentService) GenerateQR(orderID, clientIP string) (*GenerateNobuQRResult, error) {
	if !nobuQRISEnabled() {
		return nil, errors.New("QRIS Nobu belum tersedia")
	}
	// Nobu whitelists the server egress IP, not the end-user IP forwarded by the API.
	nobuIP := config.GetEnv("NOBU_IP_ADDRESS", clientIP)
	var trx model.Transaksi
	if err := s.db.First(&trx, "tr_id = ?", orderID).Error; err != nil {
		return nil, errors.New("transaksi tidak ditemukan")
	}
	if strings.EqualFold(trx.StatusPembayaran, "Lunas") {
		return nil, errors.New("transaksi sudah lunas")
	}
	var nobuMethod model.MetodePembayaran
	if err := s.db.Where(
		"mp_outlet = ? AND mp_kategori = ? AND mp_nama_metode = ? AND mp_status = ?",
		trx.OutletID, "QRIS", "QRIS Nobu", 1,
	).First(&nobuMethod).Error; errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, errors.New("QRIS Nobu belum diaktifkan untuk outlet ini")
	} else if err != nil {
		return nil, err
	}
	var paid float64
	s.db.Table("ac_dp_transaksi").Where("dptr_transaksi = ?", orderID).Select("COALESCE(SUM(dptr_jumlah_dp),0)").Scan(&paid)
	outstanding := trx.Total - paid
	if outstanding <= 0 {
		return nil, errors.New("sisa pembayaran tidak valid")
	}

	var existing model.NobuPaymentTransaction
	if err := s.db.Where("npt_order_id = ? AND npt_internal_status IN ?", orderID, []string{"CREATED", "QR_GENERATED", "WAITING_PAYMENT"}).Order("npt_created DESC").First(&existing).Error; err == nil && (existing.QRExpiredAt == nil || existing.QRExpiredAt.After(time.Now())) {
		return &GenerateNobuQRResult{Payment: existing, NMID: s.client.StoreID, MerchantName: s.merchantName(existing.OutletID), AcquirerCode: s.acquirerCode(), QRContent: value(existing.QRContent), QRURL: value(existing.QRURL), QRImage: value(existing.QRImage)}, nil
	}

	partnerRef := makePartnerReference(orderID)
	req := nobu.GenerateQRRequest{PartnerReferenceNo: partnerRef, Amount: nobu.Amount{Value: fmt.Sprintf("%.2f", outstanding), Currency: "IDR"}, MerchantID: s.client.MerchantID, SubMerchantID: s.client.SubMerchantID, StoreID: s.client.StoreID, TerminalID: s.client.TerminalID}
	req.AdditionalInfo.ValidTime = config.GetEnv("NOBU_QR_VALID_SECONDS", "900")
	req.AdditionalInfo.Tip = "false"
	req.AdditionalInfo.QRType = "03"

	// Nobu sandbox kerap membalas HTTP 500 / timeout. Coba beberapa kali dengan
	// partnerReferenceNo yang sama (idempotent di sisi Nobu) tapi X-EXTERNAL-ID
	// baru tiap percobaan, agar 500/timeout sesaat tidak langsung menggagalkan
	// pembuatan QR. Hanya galat transient (network/timeout atau responseCode 5xx)
	// yang diulang.
	attempts := parseSeconds(config.GetEnv("NOBU_GENERATE_ATTEMPTS", "3"), 3)
	var res nobu.GenerateQRResponse
	var externalID string
	var lastErr error
	for i := 0; i < attempts; i++ {
		externalID = time.Now().Format("20060102150405")
		res, lastErr = s.client.GenerateQR(req, externalID, nobuIP)
		if lastErr == nil && res.ResponseCode == "2004700" {
			break
		}
		transient := lastErr != nil || strings.HasPrefix(res.ResponseCode, "5")
		if lastErr == nil {
			lastErr = fmt.Errorf("Nobu generate QR: %s %s", res.ResponseCode, res.ResponseMessage)
		}
		if !transient || i == attempts-1 {
			if !transient {
				return nil, lastErr
			}
			log.Printf("nobu: generate QR gagal untuk %s setelah %d percobaan: %v", orderID, attempts, lastErr)
			return nil, errors.New("Nobu sedang sibuk membuat QRIS, silakan coba lagi")
		}
		log.Printf("nobu: generate QR percobaan %d/%d untuk %s gagal (transient): %v", i+1, attempts, orderID, lastErr)
		time.Sleep(time.Duration(400*(i+1)) * time.Millisecond)
	}
	if res.ResponseCode != "2004700" {
		return nil, fmt.Errorf("Nobu generate QR: %s %s", res.ResponseCode, res.ResponseMessage)
	}
	expiry := time.Now().Add(time.Duration(parseSeconds(req.AdditionalInfo.ValidTime, 900)) * time.Second)
	payment := model.NobuPaymentTransaction{ID: uuid.NewString(), OrderID: orderID, OutletID: trx.OutletID, Provider: "NOBU", PartnerReferenceNo: partnerRef, ExternalID: externalID, MerchantID: s.client.MerchantID, SubMerchantID: s.client.SubMerchantID, StoreID: s.client.StoreID, TerminalID: s.client.TerminalID, AmountValue: req.Amount.Value, AmountCurrency: "IDR", QRContent: &res.QRContent, QRURL: &res.QRURL, QRImage: &res.QRImage, ProviderStatus: "01", InternalStatus: "WAITING_PAYMENT", QRExpiredAt: &expiry}
	if err := s.db.Create(&payment).Error; err != nil {
		return nil, err
	}
	return &GenerateNobuQRResult{Payment: payment, NMID: s.client.StoreID, MerchantName: s.merchantName(payment.OutletID), AcquirerCode: s.acquirerCode(), QRContent: res.QRContent, QRURL: res.QRURL, QRImage: res.QRImage}, nil
}

func (s *NobuPaymentService) GetQRStatus(orderID string) (*NobuQRStatusResult, error) {
	if !nobuQRISEnabled() {
		return nil, errors.New("QRIS Nobu belum tersedia")
	}
	var payment model.NobuPaymentTransaction
	if err := s.db.Where("npt_order_id = ?", orderID).Order("npt_created DESC").First(&payment).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, errors.New("QRIS belum dibuat untuk transaksi ini")
		}
		return nil, err
	}
	if payment.InternalStatus == "WAITING_PAYMENT" && payment.QRExpiredAt != nil && payment.QRExpiredAt.Before(time.Now()) {
		payment.InternalStatus = "EXPIRED"
		_ = s.db.Model(&payment).Updates(map[string]any{"npt_internal_status": "EXPIRED"}).Error
	}

	// Query Nobu directly, while keeping callback as the source of truth for
	// final accounting and order settlement.
	s.queryMu.Lock()
	lastQuery := s.lastQueryByOrder[orderID]
	if time.Since(lastQuery) < 3*time.Second {
		s.queryMu.Unlock()
		return &NobuQRStatusResult{Payment: payment, NMID: s.client.StoreID, MerchantName: s.merchantName(payment.OutletID), AcquirerCode: s.acquirerCode(), QRContent: value(payment.QRContent), QRURL: value(payment.QRURL), QRImage: value(payment.QRImage)}, nil
	}
	s.lastQueryByOrder[orderID] = time.Now()
	s.queryMu.Unlock()

	query := nobu.QueryRequest{
		OriginalPartnerReferenceNo: payment.PartnerReferenceNo,
		OriginalReferenceNo:        value(payment.NobuReferenceNo),
		ServiceCode:                "51",
		MerchantID:                 payment.MerchantID,
		SubMerchantID:              payment.SubMerchantID,
		ExternalStoreID:            payment.StoreID,
	}
	query.AdditionalInfo.POSID = payment.TerminalID
	queryResult, err := s.client.QueryPayment(query, time.Now().Format("20060102150405"), config.GetEnv("NOBU_IP_ADDRESS", ""))
	if err != nil {
		// Nobu sandbox kerap 500/timeout. Jangan gagalkan pengecekan status
		// (yang akan tampil sebagai 404 di app dan menghentikan polling); cukup
		// kembalikan status lokal terakhir dan biarkan polling mencoba lagi.
		log.Printf("nobu: query status gagal untuk %s: %v (fallback ke status lokal)", orderID, err)
		return &NobuQRStatusResult{Payment: payment, NMID: s.client.StoreID, MerchantName: s.merchantName(payment.OutletID), AcquirerCode: s.acquirerCode(), QRContent: value(payment.QRContent), QRURL: value(payment.QRURL), QRImage: value(payment.QRImage)}, nil
	}
	if queryResult.LatestTransactionStatus == "00" && payment.InternalStatus != "PAID" {
		// Callback notify Nobu belum bisa diverifikasi (dikirim via aggregator dengan
		// partner-id/secret yang berbeda), jadi hasil Query dipakai sebagai sumber
		// settlement. applyProviderUpdate bersifat idempotent sehingga aman terhadap
		// polling berulang: settlement hanya terjadi sekali per order.
		if err := s.applyProviderUpdate(&payment, providerUpdate{
			ExternalID:           payment.ExternalID,
			EventType:            "QRIS_QUERY",
			SignatureValid:       true,
			RawBody:              "",
			LatestStatus:         queryResult.LatestTransactionStatus,
			StatusDesc:           queryResult.TransactionStatusDesc,
			NobuReferenceNo:      queryResult.OriginalReferenceNo,
			PaymentReferenceNo:   queryResult.AdditionalInfo.PaymentReferenceNo,
			RetrievalReferenceNo: queryResult.AdditionalInfo.RetrievalReferenceNo,
			NetAmount:            queryResult.AdditionalInfo.NetAmount,
		}); err != nil {
			return nil, err
		}
	} else {
		updates := map[string]any{
			"npt_provider_status":      queryResult.LatestTransactionStatus,
			"npt_provider_status_desc": queryResult.TransactionStatusDesc,
		}
		if queryResult.OriginalReferenceNo != "" {
			updates["npt_nobu_reference_no"] = queryResult.OriginalReferenceNo
		}
		_ = s.db.Model(&payment).Updates(updates).Error
		payment.ProviderStatus = queryResult.LatestTransactionStatus
		payment.ProviderStatusDesc = &queryResult.TransactionStatusDesc
	}
	return &NobuQRStatusResult{Payment: payment, NMID: s.client.StoreID, MerchantName: s.merchantName(payment.OutletID), AcquirerCode: s.acquirerCode(), QRContent: value(payment.QRContent), QRURL: value(payment.QRURL), QRImage: value(payment.QRImage)}, nil
}

type NobuNotify struct {
	OriginalReferenceNo        string      `json:"originalReferenceNo"`
	OriginalPartnerReferenceNo string      `json:"originalPartnerReferenceNo"`
	LatestTransactionStatus    string      `json:"latestTransactionStatus"`
	TransactionStatusDesc      string      `json:"transactionStatusDesc"`
	Amount                     nobu.Amount `json:"amount"`
	AdditionalInfo             struct {
		IssuerID             string `json:"issuerId"`
		MerchantID           string `json:"merchantId"`
		PaymentDate          string `json:"paymentDate"`
		RetrievalReferenceNo string `json:"retrievalReferenceNo"`
		PaymentReferenceNo   string `json:"paymentReferenceNo"`
		NetAmount            string `json:"nettAmount"`
	} `json:"additionalInfo"`
}

func (s *NobuPaymentService) ProcessNotify(raw []byte, headers http.Header) error {
	if s.client.ClientSecret == "" {
		return errors.New("NOBU_CLIENT_SECRET belum dikonfigurasi")
	}
	accessToken := strings.TrimSpace(strings.TrimPrefix(headers.Get("Authorization"), "Bearer"))
	timestamp := headers.Get("X-TIMESTAMP")
	signature := headers.Get("X-SIGNATURE")
	if accessToken == "" || timestamp == "" || signature == "" || !s.ValidateCallbackToken(accessToken) {
		return errors.New("header callback Nobu tidak lengkap")
	}
	var compact bytes.Buffer
	if err := json.Compact(&compact, raw); err != nil {
		return err
	}
	expected := nobu.SignTransaction(s.client.ClientSecret, http.MethodPost, "/v1.0/qr/qr-mpm-notify/", accessToken, timestamp, compact.String())
	if subtle.ConstantTimeCompare([]byte(expected), []byte(signature)) != 1 {
		return errors.New("signature callback Nobu tidak valid")
	}
	var n NobuNotify
	if err := json.Unmarshal(raw, &n); err != nil {
		return err
	}
	ref := n.OriginalPartnerReferenceNo
	if ref == "" {
		return errors.New("originalPartnerReferenceNo wajib untuk QRIS dynamic")
	}
	var payment model.NobuPaymentTransaction
	if err := s.db.Where("npt_partner_reference_no = ?", ref).First(&payment).Error; err != nil {
		return errors.New("payment reference tidak ditemukan")
	}
	return s.applyProviderUpdate(&payment, providerUpdate{
		ExternalID:           headers.Get("X-EXTERNAL-ID"),
		EventType:            "QRIS_NOTIFY",
		SignatureValid:       true,
		RawBody:              string(raw),
		LatestStatus:         n.LatestTransactionStatus,
		StatusDesc:           n.TransactionStatusDesc,
		NobuReferenceNo:      n.OriginalReferenceNo,
		PaymentReferenceNo:   n.AdditionalInfo.PaymentReferenceNo,
		RetrievalReferenceNo: n.AdditionalInfo.RetrievalReferenceNo,
		NetAmount:            n.AdditionalInfo.NetAmount,
		CheckAmountValue:     n.Amount.Value,
		CheckAmountCurrency:  n.Amount.Currency,
	})
}

// providerUpdate merangkum status pembayaran Nobu dari salah satu sumber:
// callback notify (server-to-server) atau hasil Query. CheckAmountValue/
// CheckAmountCurrency hanya diisi untuk callback notify (divalidasi terhadap
// nominal order); untuk Query dibiarkan kosong.
type providerUpdate struct {
	ExternalID           string
	EventType            string
	SignatureValid       bool
	RawBody              string
	LatestStatus         string
	StatusDesc           string
	NobuReferenceNo      string
	PaymentReferenceNo   string
	RetrievalReferenceNo string
	NetAmount            string
	CheckAmountValue     string
	CheckAmountCurrency  string
}

// applyProviderUpdate menerapkan status pembayaran Nobu secara idempotent dan
// atomik. Baris payment dikunci (SELECT ... FOR UPDATE) agar callback notify dan
// polling Query yang datang bersamaan tidak double-settle. Settlement (DP,
// status Lunas, ledger, owner payable) hanya terjadi sekali saat status "00";
// pemanggilan berikutnya pada order yang sudah PAID dicatat sebagai DUPLICATE.
func (s *NobuPaymentService) applyProviderUpdate(payment *model.NobuPaymentTransaction, in providerUpdate) error {
	now := time.Now()
	settled := false
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var current model.NobuPaymentTransaction
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("npt_id = ?", payment.ID).First(&current).Error; err != nil {
			return err
		}
		event := model.NobuProviderEvent{ID: uuid.NewString(), ExternalID: in.ExternalID, PartnerReferenceNo: current.PartnerReferenceNo, EventType: in.EventType, RequestHeaders: "{}", RequestBody: in.RawBody, SignatureValid: in.SignatureValid, ProcessingStatus: "RECEIVED", PaymentTransactionID: &current.ID}
		if err := tx.Create(&event).Error; err != nil {
			return err
		}
		if current.InternalStatus == "PAID" {
			return tx.Model(&event).Updates(map[string]any{"npe_processing_status": "DUPLICATE", "npe_processed_at": now}).Error
		}
		// Order sudah dibatalkan (mis. dilunasi dengan metode lain saat QR masih
		// menggantung). Jangan settle agar tidak double-record; catat sebagai
		// event yang diabaikan untuk keperluan rekonsiliasi manual bila ternyata
		// pelanggan tetap membayar via QR lama.
		if current.InternalStatus == "CANCELLED" {
			return tx.Model(&event).Updates(map[string]any{"npe_processing_status": "IGNORED_CANCELLED", "npe_processed_at": now}).Error
		}
		updates := map[string]any{"npt_provider_status": in.LatestStatus, "npt_provider_status_desc": in.StatusDesc, "npt_updated": now}
		if in.NobuReferenceNo != "" {
			updates["npt_nobu_reference_no"] = in.NobuReferenceNo
		}
		if in.PaymentReferenceNo != "" {
			updates["npt_payment_reference_no"] = in.PaymentReferenceNo
		}
		if in.RetrievalReferenceNo != "" {
			updates["npt_retrieval_reference_no"] = in.RetrievalReferenceNo
		}
		if in.LatestStatus == "00" {
			if in.CheckAmountCurrency != "" && in.CheckAmountCurrency != "IDR" {
				return errors.New("currency callback bukan IDR")
			}
			if in.CheckAmountValue != "" && in.CheckAmountValue != current.AmountValue {
				return errors.New("nominal callback berbeda")
			}
			var method model.MetodePembayaran
			if err := tx.Where("mp_outlet = ? AND mp_kategori = ? AND mp_nama_metode = ?", current.OutletID, "QRIS", "QRIS Nobu").First(&method).Error; errors.Is(err, gorm.ErrRecordNotFound) {
				// Fallback (jarang terpicu karena metode biasanya sudah di-seed):
				// pakai penomoran ID standar agar konsisten dengan metode lain.
				method = model.MetodePembayaran{ID: utils.GenMetodeBayarID(tx, current.OutletID), OutletID: current.OutletID, Nama: "QRIS Nobu", Deskripsi: "Pembayaran QRIS otomatis via Nobu", Kategori: "QRIS", Status: 0, UserUpdate: "NOBU", UserUpdateType: "system"}
				if err := tx.Create(&method).Error; err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
			var count int64
			tx.Model(&model.DPTransaksi{}).Where("dptr_transaksi = ? AND dptr_metode_pembayaran = ?", current.OrderID, method.ID).Count(&count)
			if count == 0 {
				if err := tx.Create(&model.DPTransaksi{ID: utils.GenDPTrxID(tx, current.OrderID), TransaksiID: current.OrderID, MetodePembayaranID: method.ID, TanggalDP: now, JumlahDP: parseAmount(current.AmountValue), JumlahSisa: 0, UserUpdate: "NOBU"}).Error; err != nil {
					return err
				}
			}
			if err := tx.Model(&model.Transaksi{}).Where("tr_id = ? AND tr_status_pembayaran <> ?", current.OrderID, "Lunas").Updates(map[string]any{"tr_status_pembayaran": "Lunas", "tr_userupdate": "NOBU", "tr_userupdate_type": "system"}).Error; err != nil {
				return err
			}
			gross := parseAmount(current.AmountValue)
			net := gross
			if in.NetAmount != "" {
				net = parseAmount(in.NetAmount)
			}
			mdr := gross - net
			platformFeePercent := 0.0
			fmt.Sscanf(config.GetEnv("NOBU_PLATFORM_FEE_PERCENT", "0"), "%f", &platformFeePercent)
			platformFee := gross * platformFeePercent / 100
			ownerNet := net - platformFee
			payable := model.OwnerPayable{ID: uuid.NewString(), OrderID: current.OrderID, PaymentID: current.ID, OutletID: current.OutletID, GrossAmount: gross, MDRAmount: mdr, PlatformFee: platformFee, NetAmount: ownerNet, Status: "OPEN"}
			if err := tx.Where("op_payment_id = ?", current.ID).First(&model.OwnerPayable{}).Error; errors.Is(err, gorm.ErrRecordNotFound) {
				if err := tx.Create(&payable).Error; err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
			fund := model.NobuFundLedger{ID: uuid.NewString(), PaymentID: current.ID, OutletID: current.OutletID, GrossAmount: gross, MDRAmount: mdr, NetAmount: net, Status: "RECEIVED"}
			if err := tx.Where("nfl_payment_id = ?", current.ID).First(&model.NobuFundLedger{}).Error; errors.Is(err, gorm.ErrRecordNotFound) {
				if err := tx.Create(&fund).Error; err != nil {
					return err
				}
			} else if err != nil {
				return err
			}
			updates["npt_internal_status"] = "PAID"
			updates["npt_paid_at"] = now
			settled = true
		} else if in.LatestStatus == "06" {
			updates["npt_internal_status"] = "FAILED"
		} else {
			updates["npt_internal_status"] = "WAITING_PAYMENT"
		}
		if err := tx.Model(&current).Updates(updates).Error; err != nil {
			return err
		}
		return tx.Model(&event).Updates(map[string]any{"npe_processing_status": "PROCESSED", "npe_processed_at": now}).Error
	})
	if err != nil {
		return err
	}
	payment.ProviderStatus = in.LatestStatus
	desc := in.StatusDesc
	payment.ProviderStatusDesc = &desc
	if settled {
		payment.InternalStatus = "PAID"
		payment.PaidAt = &now
		// Settlement Nobu terjadi di luar alur pelunasan manual (via callback /
		// polling Query), sehingga cache Redis daftar status & ringkasan tidak
		// otomatis dibersihkan. Tanpa ini, lane "Belum Lunas" di daftar status
		// tetap basi meski detail transaksi sudah Lunas. Broadcast websocket
		// juga dikirim agar kasir yang sedang membuka daftar langsung ter-refresh.
		s.invalidateAfterSettle(payment.OutletID, payment.OrderID)
	}
	return nil
}

// invalidateAfterSettle membersihkan cache yang bergantung pada status
// pembayaran/urutan transaksi dan mengabarkan perubahan ke outlet, meniru
// pembersihan yang dilakukan controller ProcessPayment pada pelunasan manual.
func (s *NobuPaymentService) invalidateAfterSettle(outletID, orderID string) {
	if outletID == "" {
		return
	}
	database.ClearCacheByPattern(fmt.Sprintf("status:counts:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("status:aggregated:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("status:list:%s:*", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
	database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID))

	utils.AppHub.BroadcastToOutlet(outletID, gin.H{
		"type":    "ORDER_UPDATED",
		"message": fmt.Sprintf("Pembayaran QRIS transaksi %s telah lunas", orderID),
		"payload": gin.H{
			"id":                orderID,
			"status_pembayaran": "Lunas",
		},
	})
}

// credMatches membandingkan kredensial dari Nobu terhadap salah satu nilai yang
// diterima, tanpa memperhatikan tanda hubung (dash) maupun besar-kecil huruf.
// Nobu kadang mengirim Partner ID (tanpa dash) di tempat Client ID (dengan dash).
func credMatches(got string, accepted ...string) bool {
	norm := func(v string) string { return strings.ToLower(strings.ReplaceAll(v, "-", "")) }
	g := norm(got)
	if g == "" {
		return false
	}
	for _, a := range accepted {
		if g == norm(a) {
			return true
		}
	}
	return false
}

func value(v *string) string {
	if v == nil {
		return ""
	}
	return *v
}
func parseSeconds(v string, fallback int) int {
	var n int
	fmt.Sscanf(v, "%d", &n)
	if n <= 0 {
		return fallback
	}
	return n
}
func parseAmount(v string) float64 { var n float64; fmt.Sscanf(v, "%f", &n); return n }
func makePartnerReference(orderID string) string {
	_ = orderID
	return fmt.Sprintf("%014d%011d", time.Now().Unix(), time.Now().UnixNano()%100000000000)
}
