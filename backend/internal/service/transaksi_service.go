package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/database"
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"github.com/RikardoAnju/PiposmartPro/internal/notifier"
	"github.com/RikardoAnju/PiposmartPro/internal/utils"
	"errors"
	"fmt"
	"math"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

// isDiskonValidNow memastikan diskon boleh diterapkan pada waktu tertentu.
// Mendukung dua jadwal: rentang tanggal (inklusif) & hari berulang (weekday
// 1=Senin..7=Minggu). Dipakai sebagai guard sisi server agar diskon tidak
// bisa dipakai di luar jadwalnya (mis. lewat API langsung / client basi).
func isDiskonValidNow(d model.Diskon, now time.Time) bool {
	if d.Status != 1 {
		return false
	}
	if d.JadwalTipe == "hari_berulang" {
		wd := int(now.Weekday()) // Go: Minggu=0..Sabtu=6
		if wd == 0 {
			wd = 7 // jadikan Minggu=7 (skema 1=Senin..7=Minggu)
		}
		target := strconv.Itoa(wd)
		for _, p := range strings.Split(d.Hari, ",") {
			if strings.TrimSpace(p) == target {
				return true
			}
		}
		return false
	}
	// rentang_tanggal: berlaku [mulai, akhir] inklusif hingga akhir hari.
	end := d.TanggalAkhir.AddDate(0, 0, 1)
	return !now.Before(d.TanggalMulai) && now.Before(end)
}

var ValidStatusOrder = []string{
	"Antrian",
	"Proses",
	"Siap Ambil",
	"Selesai",
}

var TerminalStatus = map[string]bool{
	"Selesai": true,
	"Batal":   true,
}

type TransaksiService struct {
	db      *gorm.DB
	koinSvc *KoinService
}

func NewTransaksiService(db *gorm.DB, koin *KoinService) *TransaksiService {
	return &TransaksiService{
		db:      db,
		koinSvc: koin,
	}
}

func (s *TransaksiService) resolveActorName(tx *gorm.DB, actorID, actorType string) string {
	var nama string
	switch actorType {
	case "user":
		tx.Table("ac_user").Select("usr_nama").Where("usr_id = ?", actorID).Scan(&nama)
	case "pegawai":
		tx.Table("ac_pegawai").Select("pg_nama").Where("pg_id = ?", actorID).Scan(&nama)
	}
	if nama == "" {
		return "Sistem"
	}
	return nama
}

func (s *TransaksiService) GetByID(id string, outletID string) (model.Transaksi, error) {
	var result model.Transaksi

	mainQuery := `
        SELECT t.*, 
               p.pl_id as p_id, p.pl_nama as p_nama, p.pl_nohp as p_nohp, 
               p.pl_alamat as p_alamat, p.pl_kode as p_kode, p.pl_outlet as p_outlet,
               pf.pf_id as pf_id, pf.pf_outlet as pf_outlet,
               pf.pf_nama as pf_nama, pf.pf_status as pf_status,
               d.dis_id as d_id, d.dis_nama as d_nama, d.dis_nilai_diskon as d_nilai, 
               d.dis_jenis as d_tipe, d.dis_tanggal_mulai as d_start, d.dis_tanggal_akhir as d_end,
               d.dis_status as d_status
        FROM ac_transaksi t
        LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
        LEFT JOIN ac_parfum pf ON t.tr_parfum = pf.pf_id
        LEFT JOIN ac_diskon d ON t.tr_diskon = d.dis_id
        WHERE t.tr_id = ? AND t.tr_outlet = ? LIMIT 1`

	var row struct {
		model.Transaksi
		PId      string    `gorm:"column:p_id"`
		PNama    string    `gorm:"column:p_nama"`
		PNohp    string    `gorm:"column:p_nohp"`
		PAlamat  string    `gorm:"column:p_alamat"`
		PKode    string    `gorm:"column:p_kode"`
		POutlet  string    `gorm:"column:p_outlet"`
		PfID     string    `gorm:"column:pf_id"`
		PfOutlet string    `gorm:"column:pf_outlet"`
		PfNama   string    `gorm:"column:pf_nama"`
		PfStatus int       `gorm:"column:pf_status"`
		DId      string    `gorm:"column:d_id"`
		DNama    string    `gorm:"column:d_nama"`
		DNilai   float64   `gorm:"column:d_nilai"`
		DTipe    string    `gorm:"column:d_tipe"`
		DStart   time.Time `gorm:"column:d_start"`
		DEnd     time.Time `gorm:"column:d_end"`
		DStatus  int       `gorm:"column:d_status"`
	}

	if err := s.db.Raw(mainQuery, id, outletID).Scan(&row).Error; err != nil {
		return result, err
	}
	if row.ID == "" {
		return result, errors.New("transaksi tidak ditemukan")
	}

	result = row.Transaksi
	result.Pelanggan = model.Pelanggan{
		ID: row.PId, Nama: row.PNama, NoHP: row.PNohp, Alamat: row.PAlamat, Kode: row.PKode, OutletID: row.POutlet,
	}

	if row.PfNama != "" {
		result.Parfum = &model.Parfum{
			ID:       row.PfID,
			OutletID: row.PfOutlet,
			Nama:     row.PfNama,
			Status:   row.PfStatus,
		}
	}

	if row.DId != "" {
		result.Diskon = &model.Diskon{
			ID:           row.DId,
			Nama:         row.DNama,
			Nilai:        row.DNilai,
			Tipe:         row.DTipe,
			TanggalMulai: row.DStart,
			TanggalAkhir: row.DEnd,
			Status:       row.DStatus,
		}
	}

	s.db.Raw(`
        SELECT 
            d.*,
            ly.ly_nama as category_name,
            ly.ly_nama as nama_kategori,
            jp.jp_gambar as icon_path,
            jp.jp_gambar as dtr_icon,
            jp.jp_nama as "product_metadata__nama",
            jp.jp_gambar as "product_metadata__icon",
            jp.jp_harga as "product_metadata__harga",
            jp.jp_satuan as "product_metadata__satuan",
            jp.jp_durasi as "product_metadata__durasi",
            jp.jp_durasi_satuan as "product_metadata__durasi_satuan"
        FROM ac_detail_transaksi d
        LEFT JOIN ac_jenis_produk jp ON d.dtr_layanan = jp.jp_id
        LEFT JOIN ac_layanan ly ON jp.jp_layanan = ly.ly_id
        WHERE d.dtr_transaksi = ?`, id).Scan(&result.Details)

	s.db.Raw(`
        SELECT i.*, mi.it_item as nama_item, mi.it_item as "master_item__nama"
        FROM ac_item_transaksi i
        LEFT JOIN ac_item mi ON i.itr_item = mi.it_id
        WHERE i.itr_transaksi = ?`, id).Scan(&result.Items)

	s.db.Preload("MetodePembayaran").Where("dptr_transaksi = ?", id).Find(&result.PaymentHistory)
	// Deposit memakai payment ID virtual (tidak memiliki row di tabel metode).
	// Isi metadata agar detail transaksi tidak salah menampilkannya sebagai Cash.
	for i := range result.PaymentHistory {
		payment := &result.PaymentHistory[i]
		if payment.MetodePembayaran != nil {
			continue
		}
		switch payment.MetodePembayaranID {
		case "DEPOSIT_RUPIAH":
			payment.MetodePembayaran = &model.MetodePembayaran{
				ID: payment.MetodePembayaranID, OutletID: result.OutletID,
				Nama: "Deposit Rupiah", Deskripsi: "Pembayaran dari saldo deposit Rupiah", Kategori: "Deposit", Status: 1,
			}
		case "DEPOSIT_KG":
			payment.MetodePembayaran = &model.MetodePembayaran{
				ID: payment.MetodePembayaranID, OutletID: result.OutletID,
				Nama: "Deposit Kg", Deskripsi: "Pembayaran dari saldo deposit Kg", Kategori: "Deposit", Status: 1,
			}
		}
		if payment.MetodePembayaranID == "DEPOSIT_KG" || payment.MetodePembayaranID == "DEPOSIT_RUPIAH" {
			depositType := "RUPIAH"
			if payment.MetodePembayaranID == "DEPOSIT_KG" {
				depositType = "KG"
			}
			var usage model.CustomerDepositLedger
			if err := s.db.Where("cdl_reference = ? AND cdl_entry_type = ? AND cdl_type = ?", id, "USAGE", depositType).First(&usage).Error; err == nil {
				payment.DepositUsageAmount = usage.Amount
				balanceAfter := usage.BalanceAfter
				payment.DepositBalanceAfter = &balanceAfter
			}
		}
	}

	type tempLog struct {
		model.LogTransaksi
		ActorNameRes string `gorm:"column:lr_actor_name"`
	}
	var tLogs []tempLog
	s.db.Raw(`
        SELECT l.*, COALESCE(u.usr_nama, pg.pg_nama, 'System') as lr_actor_name
        FROM ac_log_transaksi l
        LEFT JOIN ac_user u ON l.lr_actor_id = CAST(u.usr_id AS CHAR) COLLATE utf8mb4_unicode_ci AND l.lr_actor_type = 'user'
        LEFT JOIN ac_pegawai pg ON l.lr_actor_id = pg.pg_id AND l.lr_actor_type = 'pegawai'
        WHERE l.lr_transaksi = ?
        ORDER BY l.lr_created ASC`, id).Scan(&tLogs)

	result.Logs = []model.LogTransaksi{}
	for _, tl := range tLogs {
		log := tl.LogTransaksi
		log.ActorName = tl.ActorNameRes
		result.Logs = append(result.Logs, log)
	}

	var totalPaid float64
	for _, p := range result.PaymentHistory {
		totalPaid += p.JumlahDP
	}
	result.DPAmount = totalPaid
	result.SisaBayar = result.Total - totalPaid
	if result.SisaBayar < 0 {
		result.SisaBayar = 0
	}

	return result, nil
}

func (s *TransaksiService) GetByIDPublic(id string) (model.Transaksi, error) {
	var trx model.Transaksi
	if err := s.db.Table("ac_transaksi").Select("tr_outlet").Where("tr_id = ?", id).First(&trx).Error; err != nil {
		return trx, err
	}
	return s.GetByID(id, trx.OutletID)
}

func (s *TransaksiService) GetAll(outletID string) ([]model.Transaksi, error) {
	var results []model.Transaksi
	query := `
		SELECT t.*, p.pl_nama as "Pelanggan.Nama", p.pl_nohp as "Pelanggan.NoHP"
		FROM ac_transaksi t
		LEFT JOIN ac_pelanggan p ON t.tr_pelanggan = p.pl_id
		WHERE t.tr_outlet = ? 
		ORDER BY t.tr_created DESC`

	err := s.db.Raw(query, outletID).Scan(&results).Error
	if err != nil {
		return results, err
	}

	// Keep list responses as complete as detail responses. The work-log view
	// needs customer, service quantities, and every status transition actor.
	for index := range results {
		complete, err := s.GetByID(results[index].ID, outletID)
		if err != nil {
			return results, err
		}
		results[index] = complete
	}

	return results, nil
}

func (s *TransaksiService) Create(input model.Transaksi, inputDetails []model.DetailTransaksi, inputItems []model.ItemTransaksi, dpAmount float64, metodeBayarID string, roundingMode string) (model.Transaksi, error) {
	err := s.db.Transaction(func(tx *gorm.DB) error {
		// 1. VALIDASI AKSES TRIAL / PRO
		var outlet model.Outlet
		if err := tx.Select("ot_id, ot_activated_at, ot_trial_at").First(&outlet, "ot_id = ?", input.OutletID).Error; err != nil {
			return fmt.Errorf("outlet tidak ditemukan")
		}

		now := time.Now()
		if outlet.ActivatedAt == nil && !outlet.TrialExpiresAt.After(now) {
			return fmt.Errorf("trial outlet sudah habis. silakan aktivasi PRO terlebih dahulu")
		}

		// 2. POTONG KOIN
		if errKoin := s.koinSvc.DeductCoinForTransaction(tx, input.OutletID, *input.UserUpdate, "TEMP_ID"); errKoin != nil {
			return fmt.Errorf("ekonomi: %v", errKoin)
		}

		input.ID = utils.GenTransaksiID(tx, input.OutletID)
		input.StatusOrder = "Antrian"

		input.KasirNama = s.resolveActorName(tx, *input.UserUpdate, *input.UserUpdateType)

		// 3. KALKULASI LAYANAN
		var totalItemSaja float64
		for i := range inputDetails {
			var produk model.JenisProduk
			if err := tx.First(&produk, "jp_id = ?", inputDetails[i].ProductID).Error; err != nil {
				return fmt.Errorf("layanan %s tidak ditemukan", inputDetails[i].ProductID)
			}
			if produk.MinimalOrder != nil && inputDetails[i].Qty < *produk.MinimalOrder {
				return fmt.Errorf("minimal order untuk layanan %s adalah %.2f %s", produk.Nama, *produk.MinimalOrder, produk.Satuan)
			}

			var readyAt time.Time
			switch produk.DurasiSatuan {
			case "Hari":
				readyAt = now.AddDate(0, 0, produk.Durasi)
			case "Jam":
				readyAt = now.Add(time.Duration(produk.Durasi) * time.Hour)
			case "Menit":
				readyAt = now.Add(time.Duration(produk.Durasi) * time.Minute)
			default:
				readyAt = now.AddDate(0, 0, 1)
			}

			inputDetails[i].ID = fmt.Sprintf("DTRX/%s/%03d", input.ID, i+1)
			inputDetails[i].TransaksiID = input.ID
			inputDetails[i].NamaLayanan = produk.Nama
			inputDetails[i].Harga = produk.Harga
			inputDetails[i].Satuan = produk.Satuan
			inputDetails[i].Subtotal = inputDetails[i].Harga * inputDetails[i].Qty
			inputDetails[i].ReadyAt = &readyAt
			inputDetails[i].UserUpdate = *input.UserUpdate
			inputDetails[i].UserUpdateType = *input.UserUpdateType

			totalItemSaja += inputDetails[i].Subtotal
		}

		// Set tr_estimate dari readyAt terbesar
		var latestEstimate time.Time
		for _, d := range inputDetails {
			if d.ReadyAt != nil && d.ReadyAt.After(latestEstimate) {
				latestEstimate = *d.ReadyAt
			}
		}
		if !latestEstimate.IsZero() {
			input.Estimate = &latestEstimate
		}

		// 4. HITUNG TOTAL KOTOR
		biayaLain := 0.0
		if input.JemputBiaya != nil {
			biayaLain += *input.JemputBiaya
		}
		if input.AntarBiaya != nil {
			biayaLain += *input.AntarBiaya
		}
		input.TotalKotor = totalItemSaja + biayaLain

		// 5. HITUNG POTONGAN DISKON
		var potongan float64
		if input.DiskonID != nil && *input.DiskonID != "" {
			var diskon model.Diskon
			if err := tx.First(&diskon, "dis_id = ?", *input.DiskonID).Error; err == nil {
				// Guard: hanya terapkan bila diskon valid saat ini (status,
				// rentang tanggal, atau hari berulang). Bila tidak valid,
				// potongan 0 dan diskon tidak dicatat pada transaksi.
				if isDiskonValidNow(diskon, time.Now()) {
					if diskon.Tipe == "persen" {
						potongan = input.TotalKotor * (diskon.Nilai / 100)
					} else {
						potongan = diskon.Nilai
					}
				} else {
					input.DiskonID = nil
				}
			}
		}
		if potongan > input.TotalKotor {
			potongan = input.TotalKotor
		}
		input.PotonganDiskon = potongan

		// 6. ROUNDING
		// Must match TransactionProvider.roundingUnit on the client — the
		// client only sends the rounding mode (ceil/floor/round), not the
		// computed amount, so a mismatched unit here silently recalculates
		// a different total than what the client showed/confirmed.
		totalBeforeRounding := input.TotalKotor - potongan
		unit := 500.0
		finalTotal := totalBeforeRounding
		switch roundingMode {
		case "ceil":
			finalTotal = math.Ceil(totalBeforeRounding/unit) * unit
		case "floor":
			finalTotal = math.Floor(totalBeforeRounding/unit) * unit
		case "round":
			finalTotal = math.Round(totalBeforeRounding/unit) * unit
		}
		input.Total = finalTotal
		if input.Total < 0 {
			input.Total = 0
		}
		input.RoundingAmount = input.Total - totalBeforeRounding

		// Deposit is a virtual payment method. Consume it under the same DB
		// transaction as the order so a balance can never be spent twice.
		if metodeBayarID == "DEPOSIT_RUPIAH" || metodeBayarID == "DEPOSIT_KG" {
			if input.StatusPembayaran != "Lunas" {
				return fmt.Errorf("deposit hanya dapat digunakan untuk pelunasan penuh")
			}
			hasDelivery := (input.JemputBiaya != nil && *input.JemputBiaya > 0) ||
				(input.AntarBiaya != nil && *input.AntarBiaya > 0) ||
				(input.JemputAlamat != nil && strings.TrimSpace(*input.JemputAlamat) != "") ||
				(input.AntarAlamat != nil && strings.TrimSpace(*input.AntarAlamat) != "")
			if hasDelivery {
				return fmt.Errorf("deposit hanya dapat digunakan untuk layanan cucian tanpa antar/jemput")
			}
			var account model.CustomerDepositAccount
			if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).Where("cda_customer = ? AND cda_outlet = ?", input.PelangganID, input.OutletID).First(&account).Error; err != nil {
				return fmt.Errorf("saldo deposit pelanggan belum tersedia")
			}

			// KG deposit is only valid when every service in the transaction is
			// priced by kilogram. Delivery charges cannot be paid with KG.
			isKiloTransaction := len(inputDetails) > 0 && !hasDelivery
			var totalKg float64
			for _, detail := range inputDetails {
				if strings.ToLower(strings.TrimSpace(detail.Satuan)) != "kg" {
					isKiloTransaction = false
				}
				totalKg += detail.Qty
			}

			depositType := "RUPIAH"
			consumed := input.Total
			if metodeBayarID == "DEPOSIT_KG" {
				if !isKiloTransaction {
					return fmt.Errorf("deposit Kg hanya dapat digunakan untuk transaksi kiloan tanpa biaya antar/jemput")
				}
				if account.BalanceKg < totalKg || totalKg <= 0 {
					return fmt.Errorf("saldo deposit kiloan tidak mencukupi")
				}
			}
			if metodeBayarID == "DEPOSIT_KG" {
				depositType = "KG"
				consumed = totalKg
				before := account.BalanceKg
				account.BalanceKg -= totalKg
				if err := tx.Create(&model.CustomerDepositLedger{ID: uuid.New().String(), AccountID: account.ID, CustomerID: input.PelangganID, OutletID: input.OutletID, EntryType: "USAGE", DepositType: depositType, Amount: consumed, BalanceBefore: before, BalanceAfter: account.BalanceKg, ReferenceID: input.ID, Note: "Pemakaian deposit kiloan untuk transaksi", CreatedBy: *input.UserUpdate}).Error; err != nil {
					return err
				}
			} else {
				if account.BalanceRupiah < input.Total {
					if isKiloTransaction {
						return fmt.Errorf("saldo deposit kiloan tidak mencukupi")
					}
					return fmt.Errorf("saldo deposit tidak mencukupi")
				}
				before := account.BalanceRupiah
				account.BalanceRupiah -= input.Total
				if err := tx.Create(&model.CustomerDepositLedger{ID: uuid.New().String(), AccountID: account.ID, CustomerID: input.PelangganID, OutletID: input.OutletID, EntryType: "USAGE", DepositType: depositType, Amount: consumed, BalanceBefore: before, BalanceAfter: account.BalanceRupiah, ReferenceID: input.ID, Note: "Pemakaian deposit untuk transaksi", CreatedBy: *input.UserUpdate}).Error; err != nil {
					return err
				}
			}
			if err := tx.Save(&account).Error; err != nil {
				return err
			}
			dpAmount = input.Total
		}

		// 7. STATUS PEMBAYARAN
		if (dpAmount >= input.Total && input.Total > 0) || input.StatusPembayaran == "Lunas" {
			input.StatusPembayaran = "Lunas"
			if dpAmount <= 0 {
				dpAmount = input.Total
			}
		}

		// 8. SIMPAN DATA
		if err := tx.Create(&input).Error; err != nil {
			return err
		}
		for i := range inputDetails {
			if err := tx.Create(&inputDetails[i]).Error; err != nil {
				return err
			}
		}
		for i := range inputItems {
			inputItems[i].ID = fmt.Sprintf("ITRX/%s/%03d", input.ID, i+1)
			inputItems[i].TransaksiID = input.ID
			inputItems[i].UserUpdate = *input.UserUpdate
			inputItems[i].UserUpdateType = *input.UserUpdateType
			if err := tx.Create(&inputItems[i]).Error; err != nil {
				return err
			}
		}

		// 9. RECORD PEMBAYARAN
		if metodeBayarID != "" && (dpAmount > 0 || input.Total == 0) {
			bayar := dpAmount
			if input.StatusPembayaran == "Lunas" && bayar > input.Total {
				bayar = input.Total
			}
			dpRec := model.DPTransaksi{
				ID: utils.GenDPTrxID(tx, input.ID), TransaksiID: input.ID, MetodePembayaranID: metodeBayarID,
				TanggalDP: now, JumlahDP: bayar, JumlahSisa: input.Total - bayar, UserUpdate: *input.UserUpdate,
			}
			if err := tx.Create(&dpRec).Error; err != nil {
				return err
			}

			if bayar > 0 {
				msg := fmt.Sprintf("Pembayaran DP Rp %.0f", bayar)
				if input.StatusPembayaran == "Lunas" {
					msg = fmt.Sprintf("Pelunasan Rp %.0f", bayar)
				}
				s.createLog(tx, input.ID, "header", "payment", nil, &msg, *input.UserUpdate, *input.UserUpdateType)
			}
		}

		// 10. LOG KOIN SYNC
		tx.Table("ac_history_koin").Where("hk_outlet = ? AND hk_keterangan = ?", input.OutletID, "Pemakaian koin untuk transaksi: TEMP_ID").Update("hk_keterangan", "Pemakaian koin untuk transaksi: "+input.ID)

		msg := "Nota Dibuat"
		s.createLog(tx, input.ID, "header", "status_order", nil, &msg, *input.UserUpdate, *input.UserUpdateType)
		return nil
	})

	if err == nil {
		// Invalidate Cache
		s.invalidateCache(input.OutletID)

		fullData, _ := s.GetByID(input.ID, input.OutletID)
		utils.AppHub.BroadcastToOutlet(input.OutletID, gin.H{"type": "ORDER_UPDATED", "message": "Transaksi baru berhasil dibuat", "data": fullData})
		return fullData, nil
	}
	return input, err
}

func indexOfStatus(status string) int {
	for i, s := range ValidStatusOrder {
		if s == status {
			return i
		}
	}
	return -1
}

func ptrStringValue(value *string) string {
	if value == nil {
		return ""
	}
	return strings.TrimSpace(*value)
}

func ptrFloatValue(value *float64) float64 {
	if value == nil {
		return 0
	}
	return *value
}

func normalizedDelivery(address string, fee float64) (string, float64) {
	address = strings.TrimSpace(address)
	if address == "" || fee <= 0 {
		return "", 0
	}
	return address, fee
}

func (s *TransaksiService) ProcessPayment(
	trxID string,
	bayar float64,
	metodeID string,

	jemputAlamat *string,
	jemputBiaya *float64,

	antarAlamat *string,
	antarBiaya *float64,

	actorID string,
	actorType string,
) error {
	var outletID string

	err := s.db.Transaction(func(tx *gorm.DB) error {
		var trx model.Transaksi
		if err := tx.First(&trx, "tr_id = ?", trxID).Error; err != nil {
			return errors.New("transaksi tidak ditemukan")
		}
		outletID = trx.OutletID

		// Pengaman: pelunasan/pembayaran via QRIS Nobu wajib melalui pemindaian
		// QR (settlement datang dari callback/polling Nobu, bukan ditandai lunas
		// secara manual). Endpoint ini tidak boleh menandai lunas untuk metode
		// Nobu — melindungi dari app versi lama yang masih mengirim method_id
		// QRIS Nobu ke sini.
		var payMethod model.MetodePembayaran
		if err := tx.First(&payMethod, "mp_id = ?", metodeID).Error; err == nil {
			if strings.EqualFold(payMethod.Kategori, "QRIS") &&
				strings.Contains(strings.ToLower(payMethod.Nama), "nobu") {
				return errors.New("Pembayaran QRIS Nobu harus melalui pemindaian QR, tidak dapat ditandai lunas manual")
			}
		}

		var totalPaid float64
		tx.Table("ac_dp_transaksi").
			Where("dptr_transaksi = ?", trxID).
			Select("COALESCE(SUM(dptr_jumlah_dp), 0)").
			Scan(&totalPaid)

		updateData := map[string]interface{}{}
		oldJemputBiaya := ptrFloatValue(trx.JemputBiaya)
		oldAntarBiaya := ptrFloatValue(trx.AntarBiaya)
		targetJemputAlamat := ptrStringValue(trx.JemputAlamat)
		targetJemputBiaya := oldJemputBiaya
		targetAntarAlamat := ptrStringValue(trx.AntarAlamat)
		targetAntarBiaya := oldAntarBiaya

		if jemputAlamat != nil || jemputBiaya != nil {
			if jemputAlamat != nil {
				targetJemputAlamat = ptrStringValue(jemputAlamat)
			}
			if jemputBiaya != nil {
				targetJemputBiaya = ptrFloatValue(jemputBiaya)
			}
			targetJemputAlamat, targetJemputBiaya = normalizedDelivery(targetJemputAlamat, targetJemputBiaya)
			updateData["tr_jemput_alamat"] = nil
			if targetJemputAlamat != "" {
				updateData["tr_jemput_alamat"] = targetJemputAlamat
			}
			updateData["tr_jemput_biaya"] = targetJemputBiaya
		}

		if antarAlamat != nil || antarBiaya != nil {
			if antarAlamat != nil {
				targetAntarAlamat = ptrStringValue(antarAlamat)
			}
			if antarBiaya != nil {
				targetAntarBiaya = ptrFloatValue(antarBiaya)
			}
			targetAntarAlamat, targetAntarBiaya = normalizedDelivery(targetAntarAlamat, targetAntarBiaya)
			updateData["tr_antar_alamat"] = nil
			if targetAntarAlamat != "" {
				updateData["tr_antar_alamat"] = targetAntarAlamat
			}
			updateData["tr_antar_biaya"] = targetAntarBiaya
		}

		selisihBiaya := (targetJemputBiaya + targetAntarBiaya) - (oldJemputBiaya + oldAntarBiaya)
		if math.Abs(selisihBiaya) > 0.01 {
			trx.TotalKotor += selisihBiaya
			trx.Total += selisihBiaya

			updateData["tr_total_kotor"] = trx.TotalKotor
			updateData["tr_total"] = trx.Total
		}

		if len(updateData) > 0 {
			if err := tx.Model(&trx).Updates(updateData).Error; err != nil {
				return err
			}
		}

		currentSisa := trx.Total - totalPaid
		if currentSisa < 0 {
			currentSisa = 0
		}

		if math.Abs(bayar-currentSisa) > 0.01 {
			selisih := bayar - currentSisa
			newTotal := trx.Total + selisih
			newRounding := trx.RoundingAmount + selisih

			if err := tx.Model(&trx).Updates(map[string]interface{}{
				"tr_total":    newTotal,
				"tr_rounding": newRounding,
			}).Error; err != nil {
				return err
			}

			trx.Total = newTotal
			trx.RoundingAmount = newRounding
		}

		payRec := model.DPTransaksi{
			ID:                 utils.GenDPTrxID(tx, trx.ID),
			TransaksiID:        trx.ID,
			MetodePembayaranID: metodeID,
			TanggalDP:          time.Now(),
			JumlahDP:           bayar,
			JumlahSisa:         0,
			UserUpdate:         actorID,
		}

		if err := tx.Create(&payRec).Error; err != nil {
			return err
		}

		kasirNama := s.resolveActorName(tx, actorID, actorType)

		if err := tx.Model(&trx).Updates(map[string]interface{}{
			"tr_status_pembayaran": "Lunas",
			"tr_kasir_nama":        kasirNama,
			"tr_userupdate":        actorID,
			"tr_userupdate_type":   actorType,
		}).Error; err != nil {
			return err
		}

		if math.Abs(selisihBiaya) > 0.01 {
			msgTambahan := fmt.Sprintf(
				"Koreksi biaya antar/jemput Rp %.0f saat pelunasan",
				selisihBiaya,
			)
			s.createLog(tx, trxID, "header", "delivery_fee", nil, &msgTambahan, actorID, actorType)
		}

		msg := fmt.Sprintf("Pelunasan Rp %.0f", bayar)
		s.createLog(tx, trxID, "header", "payment", nil, &msg, actorID, actorType)

		// Batalkan QR Nobu yang masih menggantung untuk order ini. Karena
		// pelunasan sudah diselesaikan dengan metode lain, QR lama yang masih
		// aktif harus dibatalkan agar tidak menghasilkan pembayaran ganda bila
		// pelanggan sempat memindainya (guard settlement ada di
		// NobuPaymentService.applyProviderUpdate yang mengabaikan order CANCELLED).
		if err := tx.Model(&model.NobuPaymentTransaction{}).
			Where("npt_order_id = ? AND npt_internal_status IN ?", trxID,
				[]string{"CREATED", "QR_GENERATED", "WAITING_PAYMENT"}).
			Updates(map[string]any{
				"npt_internal_status": "CANCELLED",
				"npt_updated":         time.Now(),
			}).Error; err != nil {
			return err
		}

		s.invalidateCache(trx.OutletID)

		return nil
	})

	if err != nil {
		return err
	}

	if outletID != "" {
		utils.AppHub.BroadcastToOutlet(outletID, gin.H{
			"type":    "ORDER_UPDATED",
			"message": fmt.Sprintf("Pembayaran transaksi %s berhasil diperbarui", trxID),
			"payload": gin.H{
				"id":                trxID,
				"status_pembayaran": "Lunas",
			},
		})
	}

	return nil
}

func (s *TransaksiService) UpdateStatus(ids []string, status, actorID, actorType, alasan string) error {
	return s.db.Transaction(func(tx *gorm.DB) error {
		kasirNama := s.resolveActorName(tx, actorID, actorType)

		for _, id := range ids {
			var trx model.Transaksi
			if err := tx.First(&trx, "tr_id = ?", id).Error; err != nil {
				continue
			}
			if TerminalStatus[trx.StatusOrder] {
				continue
			}

			oldStatus := trx.StatusOrder
			updates := map[string]interface{}{
				"tr_status_order":    status,
				"tr_userupdate":      actorID,
				"tr_userupdate_type": actorType,
				"tr_kasir_nama":      kasirNama,
			}

			if err := tx.Model(&trx).Updates(updates).Error; err != nil {
				return err
			}

			if status == "Batal" {
				if err := s.refundDepositForTransaction(tx, trx, actorID); err != nil {
					return err
				}
			}

			s.createLog(tx, id, "header", "status_order", &oldStatus, &status, actorID, actorType)

			fullData, _ := s.GetByID(id, trx.OutletID)
			utils.AppHub.BroadcastToOutlet(trx.OutletID, gin.H{
				"type":    "ORDER_UPDATED",
				"message": fmt.Sprintf("Status %s diubah ke %s", id, status),
				"data":    fullData,
			})

			if notifErr := notifier.CreateOutletNotificationWithoutPush(
				tx,
				trx.OutletID,
				"ORDER_STATUS",
				"Status pesanan diperbarui",
				fmt.Sprintf("Pesanan %s dipindahkan ke status %s.", id, status),
				map[string]interface{}{
					"type":   "ORDER_UPDATED",
					"id":     id,
					"status": status,
				},
			); notifErr != nil {
				fmt.Printf("⚠️ Gagal membuat notifikasi status transaksi %s: %v\n", id, notifErr)
			}

			// Invalidate Cache
			s.invalidateCache(trx.OutletID)
		}
		return nil
	})
}

// refundDepositForTransaction reverses every deposit usage attached to a
// cancelled order. The refund reference is the order id, so retries remain
// idempotent and cannot credit the balance twice.
func (s *TransaksiService) refundDepositForTransaction(tx *gorm.DB, trx model.Transaksi, actorID string) error {
	var usages []model.CustomerDepositLedger
	if err := tx.Where("cdl_reference = ? AND cdl_entry_type = ?", trx.ID, "USAGE").Find(&usages).Error; err != nil {
		return err
	}
	for _, usage := range usages {
		var existing int64
		if err := tx.Model(&model.CustomerDepositLedger{}).
			Where("cdl_reference = ? AND cdl_entry_type IN ? AND cdl_type = ?", trx.ID, []string{"USAGE_REVERSAL", "REFUND"}, usage.DepositType).
			Count(&existing).Error; err != nil {
			return err
		}
		if existing > 0 {
			continue
		}

		var account model.CustomerDepositAccount
		if err := tx.Clauses(clause.Locking{Strength: "UPDATE"}).First(&account, "cda_id = ?", usage.AccountID).Error; err != nil {
			return err
		}
		before := account.BalanceRupiah
		if usage.DepositType == "KG" {
			before = account.BalanceKg
			account.BalanceKg += usage.Amount
		} else {
			account.BalanceRupiah += usage.Amount
		}
		if err := tx.Save(&account).Error; err != nil {
			return err
		}
		balanceAfter := account.BalanceRupiah
		if usage.DepositType == "KG" {
			balanceAfter = account.BalanceKg
		}
		if err := tx.Create(&model.CustomerDepositLedger{
			ID: uuid.New().String(), AccountID: account.ID, CustomerID: usage.CustomerID,
			OutletID: usage.OutletID, EntryType: "USAGE_REVERSAL", DepositType: usage.DepositType,
			Amount: usage.Amount, BalanceBefore: before, BalanceAfter: balanceAfter,
			ReferenceID: trx.ID, Note: "Pengembalian deposit karena transaksi dibatalkan",
			CreatedBy: actorID,
		}).Error; err != nil {
			return err
		}
	}
	return nil
}

func (s *TransaksiService) createLog(tx *gorm.DB, trxID, scope, field string, oldVal, newVal *string, actorID, actorType string) {
	log := model.LogTransaksi{
		ID: utils.GenLogTrxID(tx, trxID), TransaksiID: trxID, Scope: scope, Field: field,
		OldValue: oldVal, NewValue: newVal, ActorID: actorID, ActorType: actorType,
	}
	tx.Create(&log)
}

func (s *TransaksiService) Update(trxID string, input model.Transaksi, newDetails []model.DetailTransaksi, newItems []model.ItemTransaksi, actorID, actorType string, canUpdateDeliveryFee bool) (model.Transaksi, error) {
	err := s.db.Transaction(func(tx *gorm.DB) error {
		var oldTrx model.Transaksi
		if err := tx.Where("tr_id = ? AND tr_outlet = ?", trxID, input.OutletID).First(&oldTrx).Error; err != nil {
			return errors.New("transaksi tidak ditemukan")
		}
		if oldTrx.StatusOrder == "Selesai" || oldTrx.StatusOrder == "Batal" {
			return fmt.Errorf("status %s tidak bisa diedit", oldTrx.StatusOrder)
		}

		kasirNama := s.resolveActorName(tx, actorID, actorType)

		updates := map[string]interface{}{
			"tr_userupdate":      actorID,
			"tr_userupdate_type": actorType,
			"tr_kasir_nama":      kasirNama,
		}
		oldJemputBiaya := ptrFloatValue(oldTrx.JemputBiaya)
		oldAntarBiaya := ptrFloatValue(oldTrx.AntarBiaya)
		targetJemputAlamat := ptrStringValue(oldTrx.JemputAlamat)
		targetJemputBiaya := oldJemputBiaya
		targetAntarAlamat := ptrStringValue(oldTrx.AntarAlamat)
		targetAntarBiaya := oldAntarBiaya

		deliveryTouched := input.JemputAlamat != nil ||
			input.JemputBiaya != nil ||
			input.AntarAlamat != nil ||
			input.AntarBiaya != nil

		if input.JemputAlamat != nil {
			targetJemputAlamat = ptrStringValue(input.JemputAlamat)
		}
		if input.JemputBiaya != nil {
			targetJemputBiaya = ptrFloatValue(input.JemputBiaya)
		}
		if input.AntarAlamat != nil {
			targetAntarAlamat = ptrStringValue(input.AntarAlamat)
		}
		if input.AntarBiaya != nil {
			targetAntarBiaya = ptrFloatValue(input.AntarBiaya)
		}

		targetJemputAlamat, targetJemputBiaya = normalizedDelivery(targetJemputAlamat, targetJemputBiaya)
		targetAntarAlamat, targetAntarBiaya = normalizedDelivery(targetAntarAlamat, targetAntarBiaya)
		deliveryDelta := (targetJemputBiaya + targetAntarBiaya) - (oldJemputBiaya + oldAntarBiaya)
		deliveryFeeChanged := math.Abs(targetJemputBiaya-oldJemputBiaya) > 0.01 ||
			math.Abs(targetAntarBiaya-oldAntarBiaya) > 0.01

		if deliveryFeeChanged && !canUpdateDeliveryFee {
			return errors.New("Anda tidak memiliki izin untuk mengubah biaya antar/jemput")
		}

		if deliveryTouched {
			updates["tr_jemput_alamat"] = nil
			if targetJemputAlamat != "" {
				updates["tr_jemput_alamat"] = targetJemputAlamat
			}
			updates["tr_jemput_biaya"] = targetJemputBiaya
			updates["tr_antar_alamat"] = nil
			if targetAntarAlamat != "" {
				updates["tr_antar_alamat"] = targetAntarAlamat
			}
			updates["tr_antar_biaya"] = targetAntarBiaya
		}

		if input.ParfumID != nil && (oldTrx.ParfumID == nil || *input.ParfumID != *oldTrx.ParfumID) {
			updates["tr_parfum"] = input.ParfumID
		}
		if input.Catatan != nil && (oldTrx.Catatan == nil || *input.Catatan != *oldTrx.Catatan) {
			updates["tr_catatan"] = input.Catatan
		}

		diskonChanged := input.DiskonID != nil && (oldTrx.DiskonID == nil || *input.DiskonID != *oldTrx.DiskonID)
		shouldRecalculateTotal := len(newDetails) > 0 || diskonChanged || math.Abs(deliveryDelta) > 0.01

		if shouldRecalculateTotal {
			if oldTrx.StatusPembayaran == "Lunas" {
				return errors.New("sudah lunas, tidak boleh edit nilai tagihan")
			}

			subtotal := oldTrx.TotalKotor - oldJemputBiaya - oldAntarBiaya
			if subtotal < 0 {
				subtotal = 0
			}

			if len(newDetails) > 0 {
				tx.Where("dtr_transaksi = ?", trxID).Delete(&model.DetailTransaksi{})

				subtotal = 0
				var latestEstimate time.Time
				for i, d := range newDetails {
					var p model.JenisProduk
					if err := tx.First(&p, "jp_id = ?", d.ProductID).Error; err != nil {
						return fmt.Errorf("produk %s tidak ditemukan", d.ProductID)
					}
					if p.MinimalOrder != nil && d.Qty < *p.MinimalOrder {
						return fmt.Errorf("minimal order untuk layanan %s adalah %.2f %s", p.Nama, *p.MinimalOrder, p.Satuan)
					}

					d.ID = fmt.Sprintf("DTRX/%s/%03d", trxID, i+1)
					d.TransaksiID = trxID
					d.NamaLayanan = p.Nama
					d.Harga = p.Harga
					d.Satuan = p.Satuan
					d.Subtotal = p.Harga * d.Qty
					now := time.Now()
					var readyAt time.Time
					switch p.DurasiSatuan {
					case "Hari":
						readyAt = now.AddDate(0, 0, p.Durasi)
					case "Jam":
						readyAt = now.Add(time.Duration(p.Durasi) * time.Hour)
					case "Menit":
						readyAt = now.Add(time.Duration(p.Durasi) * time.Minute)
					default:
						readyAt = now.AddDate(0, 0, 1)
					}
					d.ReadyAt = &readyAt
					d.UserUpdate = actorID
					d.UserUpdateType = actorType
					subtotal += d.Subtotal

					if readyAt.After(latestEstimate) {
						latestEstimate = readyAt
					}

					if err := tx.Create(&d).Error; err != nil {
						return err
					}
				}

				// Update tr_estimate saat edit layanan
				if !latestEstimate.IsZero() {
					updates["tr_estimate"] = latestEstimate
				}
			}

			var pot float64
			targetDiskon := oldTrx.DiskonID
			if input.DiskonID != nil {
				targetDiskon = input.DiskonID
			}

			if targetDiskon != nil && *targetDiskon != "" {
				var diskon model.Diskon
				if err := tx.First(&diskon, "dis_id = ?", *targetDiskon).Error; err == nil {
					if diskon.Tipe == "persen" {
						pot = (subtotal + targetJemputBiaya + targetAntarBiaya) * (diskon.Nilai / 100)
					} else {
						pot = diskon.Nilai
					}
				}
			}

			totalKotor := subtotal + targetJemputBiaya + targetAntarBiaya
			if pot > totalKotor {
				pot = totalKotor
			}
			updates["tr_diskon"] = targetDiskon
			updates["tr_total_kotor"] = totalKotor
			updates["tr_potongan_diskon"] = pot
			updates["tr_total"] = totalKotor - pot
		}

		if len(newItems) > 0 {
			tx.Where("itr_transaksi = ?", trxID).Delete(&model.ItemTransaksi{})
			for i, it := range newItems {
				it.ID = fmt.Sprintf("ITRX/%s/%03d", trxID, i+1)
				it.TransaksiID = trxID
				it.UserUpdate = actorID
				it.UserUpdateType = actorType
				if err := tx.Create(&it).Error; err != nil {
					return err
				}
			}
		}

		return tx.Model(&oldTrx).Updates(updates).Error
	})

	if err != nil {
		return model.Transaksi{}, err
	}

	var fullData model.Transaksi
	if err == nil {
		// Invalidate Cache
		s.invalidateCache(input.OutletID)

		fullData, _ = s.GetByID(trxID, input.OutletID)
		utils.AppHub.BroadcastToOutlet(input.OutletID, map[string]interface{}{
			"type":    "ORDER_UPDATED",
			"message": fmt.Sprintf("Transaksi %s telah diperbarui", trxID),
			"payload": fullData,
		})
	}

	return fullData, nil
}

func (s *TransaksiService) invalidateCache(outletID string) {
	// 1. Hapus dashboard summary
	database.InvalidateCache(fmt.Sprintf("summary:dashboard:%s", outletID))
	database.ClearCacheByPattern(fmt.Sprintf("summary:aggregated*:%s", outletID))
	// 2. Hapus semua laporan finance terkait outlet ini (pattern matching)
	database.ClearCacheByPattern(fmt.Sprintf("finance:*:%s:*", outletID))
}
