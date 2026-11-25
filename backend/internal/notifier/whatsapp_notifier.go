package notifier

import (
	"github.com/RikardoAnju/PiposmartPro/internal/config"
	"github.com/RikardoAnju/PiposmartPro/internal/thirdparty/fonnte"
	"fmt"
	"strings"
)

// isProduction hanya true bila ENV bernilai "production"/"prod".
// Di server dev (ENV=development) notifikasi grup WA dimatikan.
func isProduction() bool {
	env := strings.ToLower(strings.TrimSpace(config.GetEnv("ENV", "")))
	return env == "production" || env == "prod"
}

// SendWhatsAppGroup mengirim pesan ke grup WhatsApp (FONNTE_GROUP_ID) lewat
// Fonnte. HANYA aktif di server produksi. Mengembalikan nil (no-op) bila bukan
// produksi atau bila FONNTE_GROUP_ID belum diset.
func SendWhatsAppGroup(message string) error {
	if !isProduction() {
		return nil
	}
	groupID := strings.TrimSpace(config.GetEnv("FONNTE_GROUP_ID", ""))
	if groupID == "" {
		return nil
	}
	_, err := fonnte.SendGroup(groupID, message)
	return err
}

// SendWhatsAppGroupAsync menjalankan SendWhatsAppGroup di goroutine terpisah
// supaya tidak memblokir jalur request. Error hanya dicatat ke log.
func SendWhatsAppGroupAsync(message string) {
	if !isProduction() {
		return
	}
	go func() {
		if err := SendWhatsAppGroup(message); err != nil {
			fmt.Printf("Gagal kirim notifikasi WhatsApp Fonnte: %v\n", err)
		}
	}()
}

// FormatRupiah memformat angka menjadi string dengan pemisah ribuan titik,
// mis. 100000 -> "100.000".
func FormatRupiah(v float64) string {
	n := int64(v)
	neg := n < 0
	if neg {
		n = -n
	}
	s := fmt.Sprintf("%d", n)
	var out []byte
	for i := range []byte(s) {
		if i > 0 && (len(s)-i)%3 == 0 {
			out = append(out, '.')
		}
		out = append(out, s[i])
	}
	if neg {
		return "-" + string(out)
	}
	return string(out)
}
