package utils

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

func getLastSeq(db *gorm.DB, tableName, idColumn, pattern string, seqLen int) int {
	var lastID string
	query := fmt.Sprintf("SELECT %s FROM %s WHERE %s LIKE ? ORDER BY %s DESC LIMIT 1", idColumn, tableName, idColumn, idColumn)

	db.Unscoped().Raw(query, pattern+"%").Scan(&lastID)

	if lastID == "" {
		return 0
	}

	if len(lastID) < seqLen {
		return 0
	}

	var seq int
	part := lastID[len(lastID)-seqLen:]
	fmt.Sscanf(part, "%d", &seq)
	return seq
}

// ---------------------------------------------------------
// MODUL ADD-ON & AKTIVASI (NEW)
// ---------------------------------------------------------

// ac_transaksi_addon (ADD/YYYYMMDD/XXXX) -> e.g. ADD/20260413/0001
func GenAddonTrxID(db *gorm.DB) string {
	datePart := time.Now().Format("20060102")
	prefix := fmt.Sprintf("ADD/%s/", datePart)
	seq := getLastSeq(db, "ac_transaksi_addon", "ta_id", prefix, 4) + 1
	return fmt.Sprintf("%s%04d", prefix, seq)
}

// ---------------------------------------------------------
// MODUL SISTEM KOIN & NOTIFIKASI
// ---------------------------------------------------------

// 1. ac_voucher (VC.YYYYMM.XXX) -> e.g. VC.202603.001
func GenVoucherID(db *gorm.DB) string {
	datePart := time.Now().Format("200601")
	prefix := fmt.Sprintf("VC.%s.", datePart)
	seq := getLastSeq(db, "ac_voucher", "vc_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

// 2. ac_top_koin (TK/OUTLETID/YYYYMMDD/XXX) -> e.g. TK/7.001/20260310/001
func GenTopupKoinID(db *gorm.DB, outletID string) string {
	datePart := time.Now().Format("20060102")
	prefix := fmt.Sprintf("TK/%s/%s/", outletID, datePart)
	seq := getLastSeq(db, "ac_top_koin", "tk_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

// 3. ac_history_koin (HK/OUTLETID/YYYYMMDDXXXX) -> e.g. HK/7.001/202603100001
func GenHistoryKoinID(db *gorm.DB, outletID string) string {
	datePart := time.Now().Format("20060102")
	prefix := fmt.Sprintf("HK/%s/%s", outletID, datePart)
	seq := getLastSeq(db, "ac_history_koin", "hk_id", prefix, 4) + 1
	return fmt.Sprintf("%s%04d", prefix, seq)
}

// 4. ac_notif (NT/OUTLETID/YYYYMMXXXX) -> e.g. NT/7.001/2026030001
// GenNotifID menghasilkan ID yang bener-bener random menggunakan UUID v4.
// Tidak menggunakan prefix NT atau tanggal agar tidak terbaca polanya.
func GenNotifID() string {
	// Menggunakan google/uuid untuk generate random ID
	// Contoh hasil: 550e8400-e29b-41d4-a716-446655440000
	return uuid.New().String()
}

// ---------------------------------------------------------
// MODUL LAMA (OPERASIONAL)
// ---------------------------------------------------------

func GenRoleID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("RL.%s.", outletID)
	seq := getLastSeq(db, "ac_role", "rl_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenAdminID(db *gorm.DB) string {
	prefix := "ADM."
	seq := getLastSeq(db, "ac_admin", "adm_id", prefix, 6) + 1
	return fmt.Sprintf("%s%06d", prefix, seq)
}

func GenOutletID(db *gorm.DB, userID uint) string {
	prefix := fmt.Sprintf("%d.", userID)
	seq := getLastSeq(db, "ac_outlet", "ot_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenPegawaiID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("PGW.%s.", outletID)
	seq := getLastSeq(db, "ac_pegawai", "pg_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenDiskonID(db *gorm.DB, outletID string) string {
	month := time.Now().Format("01")
	prefix := fmt.Sprintf("DIS.%s.%s.", outletID, month)
	seq := getLastSeq(db, "ac_diskon", "dis_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenParfumID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("PF.%s.", outletID)
	seq := getLastSeq(db, "ac_parfum", "pf_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenKatPengeluaranID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("KP.%s.", outletID)
	seq := getLastNumericSuffix(db, "ac_kategori_pengeluaran", "kp_id", prefix) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func getLastNumericSuffix(db *gorm.DB, tableName, idColumn, prefix string) int {
	var ids []string
	query := fmt.Sprintf("SELECT %s FROM %s WHERE %s LIKE ? ORDER BY %s DESC", idColumn, tableName, idColumn, idColumn)

	db.Unscoped().Raw(query, prefix+"%").Scan(&ids)

	maxSeq := 0
	for _, id := range ids {
		suffix := strings.TrimPrefix(id, prefix)
		seq, err := strconv.Atoi(suffix)
		if err == nil && seq > maxSeq {
			maxSeq = seq
		}
	}

	return maxSeq
}

func GenLayananID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("LN.%s.", outletID)
	seq := getLastSeq(db, "ac_layanan", "ly_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenProdukID(db *gorm.DB, layananID string) string {
	prefix := fmt.Sprintf("JP.%s.", layananID)
	seq := getLastSeq(db, "ac_jenis_produk", "jp_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenMetodeBayarID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("MP.%s.", outletID)
	seq := getLastSeq(db, "ac_metode_pembayaran", "mp_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenItemID(db *gorm.DB, outletID string) string {
	prefix := fmt.Sprintf("IT.%s.", outletID)
	seq := getLastSeq(db, "ac_item", "it_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}

func GenPengeluaranID(db *gorm.DB, outletID string) string {
	datePart := time.Now().Format("200601")
	prefix := fmt.Sprintf("PG.%s.%s", outletID, datePart)
	seq := getLastSeq(db, "ac_pengeluaran", "pg_id", prefix, 4) + 1
	return fmt.Sprintf("%s%04d", prefix, seq)
}

func GenPelangganID(db *gorm.DB, outletID string) string {
	datePart := time.Now().Format("200601")
	prefix := fmt.Sprintf("PL.%s.%s", outletID, datePart)
	seq := getLastSeq(db, "ac_pelanggan", "pl_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenTransaksiID(db *gorm.DB, outletID string) string {
	datePart := time.Now().Format("20060102")
	prefix := fmt.Sprintf("TRX/%s/%s", outletID, datePart)
	seq := getLastSeq(db, "ac_transaksi", "tr_id", prefix, 4) + 1
	return fmt.Sprintf("%s%04d", prefix, seq)
}

func GenDetailTrxID(db *gorm.DB, trxID string) string {
	prefix := fmt.Sprintf("DTRX/%s/", trxID)
	seq := getLastSeq(db, "ac_detail_transaksi", "dtr_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenLogTrxID(db *gorm.DB, trxID string) string {
	prefix := fmt.Sprintf("LTRX/%s/", trxID)
	seq := getLastSeq(db, "ac_log_transaksi", "lr_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenItemTrxID(db *gorm.DB, trxID string) string {
	prefix := fmt.Sprintf("ITRX/%s/", trxID)
	seq := getLastSeq(db, "ac_item_transaksi", "itr_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenDPTrxID(db *gorm.DB, trxID string) string {
	prefix := fmt.Sprintf("DPTRX/%s/", trxID)
	seq := getLastSeq(db, "ac_dp_transaksi", "dptr_id", prefix, 3) + 1
	return fmt.Sprintf("%s%03d", prefix, seq)
}

func GenNotaSettingID(outletID string) string {
	return fmt.Sprintf("NS-%s", outletID)
}

// Catatan: GenSubscriptID tetap ada untuk kompatibilitas sementara atau histori lama
func GenSubscriptID(db *gorm.DB, outletID string) string {
	year := time.Now().Format("2006")
	prefix := fmt.Sprintf("TP.%s.%s.", outletID, year)
	seq := getLastSeq(db, "ac_transaksi_paket", "tp_id", prefix, 2) + 1
	return fmt.Sprintf("%s%02d", prefix, seq)
}
