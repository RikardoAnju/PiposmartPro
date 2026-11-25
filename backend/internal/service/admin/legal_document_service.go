package admin

import (
	"github.com/RikardoAnju/PiposmartPro/internal/model"
	"errors"
	"strings"

	"gorm.io/gorm"
)

const (
	LegalTypeTerms         = "TERMS"
	LegalTypePrivacy       = "PRIVACY"
	LegalTypeReferralTerms = "REFERRAL_TERMS"
)

type AdminLegalDocumentService interface {
	SeedDefaults() error
	GetAll() ([]model.LegalDocument, error)
	GetByType(docType string) (model.LegalDocument, error)
	Upsert(docType string, data model.LegalDocument) (model.LegalDocument, error)
}

type adminLegalDocumentService struct {
	db *gorm.DB
}

func NewAdminLegalDocumentService(db *gorm.DB) AdminLegalDocumentService {
	return &adminLegalDocumentService{db: db}
}

func normalizeLegalType(docType string) string {
	return strings.ToUpper(strings.TrimSpace(docType))
}

func isAllowedLegalType(docType string) bool {
	return docType == LegalTypeTerms || docType == LegalTypePrivacy || docType == LegalTypeReferralTerms
}

func defaultLegalDocuments() []model.LegalDocument {
	return []model.LegalDocument{
		{
			Type:           LegalTypeTerms,
			Title:          "Syarat & Ketentuan",
			EffectiveLabel: "Terakhir diperbarui: Januari 2025",
			Body: `## Penerimaan Syarat
Dengan mengunduh, mengakses, atau menggunakan aplikasi Ayucuci Apps, Anda menyetujui untuk terikat oleh syarat dan ketentuan ini. Jika Anda tidak menyetujui syarat ini, harap tidak menggunakan aplikasi kami.

## Layanan yang Disediakan
Ayucuci Apps menyediakan platform digital untuk mengelola layanan laundry, termasuk:

• Pendaftaran dan manajemen pesanan laundry
• Pelacakan status cucian
• Sistem pembayaran digital
• Notifikasi dan reminder
• Riwayat transaksi dan laporan

## Akun Pengguna
Untuk menggunakan layanan kami, Anda harus:

• Berusia minimal 17 tahun atau memiliki izin orang tua/wali
• Memberikan informasi yang akurat dan lengkap
• Menjaga kerahasiaan kata sandi Anda
• Bertanggung jawab atas semua aktivitas di akun Anda
• Segera memberitahu kami jika terjadi penggunaan tidak sah

## Pesanan dan Pembayaran
Ketentuan terkait pesanan:

• Semua pesanan harus dikonfirmasi melalui aplikasi
• Harga dapat berubah sewaktu-waktu tanpa pemberitahuan
• Pembayaran harus dilakukan sesuai metode yang tersedia
• Pembatalan pesanan tunduk pada kebijakan yang berlaku
• Kami berhak menolak pesanan yang mencurigakan

## Tanggung Jawab Pengguna
Anda setuju untuk tidak:

• Menggunakan aplikasi untuk tujuan ilegal
• Mengganggu atau merusak layanan aplikasi
• Menyalahgunakan atau mencoba mengakses data pengguna lain
• Mengirimkan konten yang melanggar hukum atau merugikan
• Melakukan reverse engineering pada aplikasi

## Kualitas Layanan
Kami berusaha memberikan layanan terbaik, namun:

• Tidak menjamin layanan akan selalu tersedia tanpa gangguan
• Tidak bertanggung jawab atas kerugian akibat gangguan teknis
• Dapat melakukan pemeliharaan sistem secara berkala
• Berhak mengubah atau menghentikan fitur tertentu

## Penanganan Keluhan
Untuk keluhan terkait layanan:

• Laporkan melalui fitur bantuan di aplikasi
• Kami akan merespons dalam 1x24 jam
• Resolusi akan diberikan sesuai kebijakan yang berlaku
• Bukti transaksi mungkin diperlukan untuk verifikasi

## Hak Kekayaan Intelektual
Semua konten, logo, merek dagang, dan materi lainnya dalam aplikasi Ayucuci adalah milik kami atau pemberi lisensi kami. Anda tidak diperkenankan menggunakan, menyalin, atau mendistribusikan konten tanpa izin tertulis.

## Pembatasan Tanggung Jawab
Ayucuci Apps tidak bertanggung jawab atas:

• Kerusakan perangkat akibat penggunaan aplikasi
• Kehilangan data akibat kesalahan teknis
• Kerugian tidak langsung atau konsekuensial
• Tindakan pihak ketiga yang bekerja sama dengan kami

## Perubahan Syarat
Kami berhak mengubah syarat dan ketentuan ini kapan saja. Perubahan akan diberitahukan melalui aplikasi atau email. Penggunaan aplikasi setelah perubahan berarti Anda menyetujui syarat yang diperbarui.

## Penghentian Layanan
Kami berhak menangguhkan atau menghentikan akses Anda ke aplikasi jika:

• Anda melanggar syarat dan ketentuan ini
• Terdapat aktivitas mencurigakan pada akun Anda
• Diperlukan untuk menjaga keamanan sistem
• Diwajibkan oleh hukum yang berlaku

## Hukum yang Berlaku
Syarat dan ketentuan ini diatur oleh dan ditafsirkan sesuai dengan hukum Republik Indonesia. Setiap perselisihan akan diselesaikan melalui pengadilan yang berwenang di Indonesia.

## Kontak
Untuk pertanyaan tentang syarat dan ketentuan ini, hubungi kami:

Email: ayucuci@gmail.com
WhatsApp: 089587387236

Dengan menggunakan aplikasi Ayucuci Apps, Anda mengakui bahwa telah membaca, memahami, dan menyetujui syarat dan ketentuan ini.`,
		},
		{
			Type:           LegalTypePrivacy,
			Title:          "Kebijakan Privasi",
			EffectiveLabel: "Terakhir diperbarui: Januari 2025",
			Body: `## Pendahuluan
Selamat datang di Ayucuci Apps. Kami menghargai privasi Anda dan berkomitmen untuk melindungi data pribadi Anda. Kebijakan privasi ini menjelaskan bagaimana kami mengumpulkan, menggunakan, dan melindungi informasi Anda saat menggunakan aplikasi kami.

## Informasi yang Kami Kumpulkan
Kami mengumpulkan informasi yang Anda berikan secara langsung, termasuk:

• Nama dan informasi kontak
• Informasi outlet/toko
• Data transaksi laundry
• Informasi pembayaran
• Riwayat pesanan dan layanan

## Penggunaan Informasi
Informasi yang kami kumpulkan digunakan untuk:

• Menyediakan dan meningkatkan layanan kami
• Memproses transaksi Anda
• Mengirimkan notifikasi terkait pesanan
• Memberikan dukungan pelanggan
• Menganalisis penggunaan aplikasi

## Keamanan Data
Kami menerapkan langkah-langkah keamanan teknis dan organisasi yang sesuai untuk melindungi data pribadi Anda dari akses, penggunaan, atau pengungkapan yang tidak sah. Data Anda dienkripsi dan disimpan dengan aman di server kami.

## Berbagi Informasi
Kami tidak menjual, menyewakan, atau membagikan informasi pribadi Anda kepada pihak ketiga untuk tujuan pemasaran. Informasi hanya dibagikan dengan penyedia layanan yang membantu kami mengoperasikan aplikasi dan hanya sejauh yang diperlukan.

## Hak Pengguna
Anda memiliki hak untuk:

• Mengakses data pribadi Anda
• Memperbaiki informasi yang tidak akurat
• Menghapus akun dan data Anda
• Menarik persetujuan penggunaan data
• Mengajukan keluhan terkait privasi

## Cookies dan Teknologi Pelacakan
Aplikasi kami menggunakan teknologi pelacakan untuk meningkatkan pengalaman pengguna, menganalisis penggunaan aplikasi, dan menyediakan fitur yang dipersonalisasi.

## Perubahan Kebijakan
Kami dapat memperbarui kebijakan privasi ini dari waktu ke waktu. Perubahan signifikan akan diberitahukan melalui aplikasi atau email. Penggunaan berkelanjutan aplikasi setelah perubahan berarti Anda menyetujui kebijakan yang diperbarui.

## Hubungi Kami
Jika Anda memiliki pertanyaan tentang kebijakan privasi ini, silakan hubungi kami:

Email: ayucuci@gmail.com
WhatsApp: 089587387236`,
		},
		{
			Type:           LegalTypeReferralTerms,
			Title:          "Syarat Referral",
			EffectiveLabel: "Terakhir diperbarui: Juli 2026",
			Body: `## Program Referral AyoCuci
Program referral AyoCuci membantu owner mengajak owner lain bergabung dan mendapatkan benefit sesuai konfigurasi yang berlaku.

## Cara Kerja
• Setiap owner memiliki kode referral pribadi
• Kode referral dipakai saat owner baru mendaftar
• Benefit referral aktif setelah owner yang diajak melakukan top up sesuai ketentuan

## Benefit Pengajak
• Owner yang mengajak mendapat komisi dari top up owner yang diajak
• Besaran komisi top up pertama dan top up berikutnya mengikuti konfigurasi aktif dari AyoCuci
• Komisi masuk ke saldo referral dan mengikuti aturan pencairan yang berlaku

## Benefit Owner Yang Diajak
• Owner yang diajak bisa mendapat bonus saat top up pertama
• Besaran bonus mengikuti konfigurasi aktif dari AyoCuci
• Bonus hanya berlaku untuk top up pertama yang berhasil

## Ketentuan Penggunaan
• Kode referral tidak boleh digunakan untuk akun sendiri
• Kode referral tidak bisa dipasang setelah owner melakukan top up pertama
• AyoCuci berhak meninjau aktivitas referral yang terindikasi tidak wajar
• Benefit referral dapat dibatalkan jika ditemukan penyalahgunaan

## Perubahan Program
AyoCuci dapat menyesuaikan benefit, batasan, dan aturan referral sewaktu-waktu. Perubahan berlaku mengikuti konfigurasi dan kebijakan terbaru yang ditetapkan AyoCuci.`,
		},
	}
}

func (s *adminLegalDocumentService) SeedDefaults() error {
	for _, item := range defaultLegalDocuments() {
		var existing model.LegalDocument
		err := s.db.Where("type = ?", item.Type).First(&existing).Error
		if errors.Is(err, gorm.ErrRecordNotFound) {
			if err := s.db.Create(&item).Error; err != nil {
				return err
			}
			continue
		}
		if err != nil {
			return err
		}
	}
	return nil
}

func (s *adminLegalDocumentService) GetAll() ([]model.LegalDocument, error) {
	var items []model.LegalDocument
	err := s.db.Order("type ASC").Find(&items).Error
	return items, err
}

func (s *adminLegalDocumentService) GetByType(docType string) (model.LegalDocument, error) {
	var item model.LegalDocument
	docType = normalizeLegalType(docType)
	if !isAllowedLegalType(docType) {
		return item, errors.New("tipe dokumen legal tidak valid")
	}
	err := s.db.Where("type = ?", docType).First(&item).Error
	return item, err
}

func (s *adminLegalDocumentService) Upsert(docType string, data model.LegalDocument) (model.LegalDocument, error) {
	docType = normalizeLegalType(docType)
	if !isAllowedLegalType(docType) {
		return data, errors.New("tipe dokumen legal tidak valid")
	}
	if strings.TrimSpace(data.Title) == "" || strings.TrimSpace(data.Body) == "" {
		return data, errors.New("judul dan isi dokumen wajib diisi")
	}

	var item model.LegalDocument
	err := s.db.Where("type = ?", docType).First(&item).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		item = model.LegalDocument{
			Type:           docType,
			Title:          strings.TrimSpace(data.Title),
			EffectiveLabel: strings.TrimSpace(data.EffectiveLabel),
			Body:           strings.TrimSpace(data.Body),
		}
		if err := s.db.Create(&item).Error; err != nil {
			return item, err
		}
		return item, nil
	}
	if err != nil {
		return item, err
	}

	updates := map[string]interface{}{
		"title":           strings.TrimSpace(data.Title),
		"effective_label": strings.TrimSpace(data.EffectiveLabel),
		"body":            strings.TrimSpace(data.Body),
	}
	if err := s.db.Model(&item).Updates(updates).Error; err != nil {
		return item, err
	}
	if err := s.db.Where("type = ?", docType).First(&item).Error; err != nil {
		return item, err
	}
	return item, nil
}
