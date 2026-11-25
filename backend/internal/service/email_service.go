package service

import (
	"github.com/RikardoAnju/PiposmartPro/internal/thirdparty/resend"
	"fmt"
	"html"
	"strings"
	"time"
)

type EmailService struct{}

func NewEmailService() *EmailService {
	return &EmailService{}
}

func (s *EmailService) SendForgotPasswordOTP(email string, otp string) (*resend.SendEmailResult, error) {
	trimmedEmail := strings.TrimSpace(email)
	if trimmedEmail == "" {
		return nil, fmt.Errorf("email tujuan wajib diisi")
	}

	subject := "Kode OTP Reset Password AyoCuci"
	htmlBody := fmt.Sprintf(`
<div style="font-family:Arial,sans-serif;background:#f8fafc;padding:24px;color:#0f172a">
  <div style="max-width:520px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:18px;padding:28px">
    <p style="margin:0 0 8px;font-size:12px;letter-spacing:.12em;color:#94a3b8">AYOCUCI</p>
    <h1 style="margin:0 0 12px;font-size:24px;line-height:1.3">Reset Password</h1>
    <p style="margin:0 0 16px;font-size:14px;line-height:1.7;color:#475569">
      Gunakan kode OTP berikut untuk melanjutkan reset password akun AyoCuci Anda.
    </p>
    <div style="margin:0 0 18px;padding:18px 20px;border-radius:14px;background:#fff7ed;border:1px solid #fed7aa;text-align:center">
      <div style="font-size:28px;font-weight:700;letter-spacing:.28em;color:#ea580c">%s</div>
    </div>
    <p style="margin:0 0 8px;font-size:13px;line-height:1.7;color:#64748b">
      Kode berlaku selama 5 menit. Jangan bagikan kode ini kepada siapa pun.
    </p>
    <p style="margin:0;font-size:13px;line-height:1.7;color:#64748b">
      Jika Anda tidak merasa meminta reset password, abaikan email ini.
    </p>
  </div>
</div>`, html.EscapeString(otp))

	textBody := fmt.Sprintf(
		"Kode OTP reset password AyoCuci Anda adalah %s. Berlaku selama 5 menit. Jangan bagikan kode ini kepada siapa pun.",
		otp,
	)

	return resend.SendEmail(resend.SendEmailRequest{
		To:      trimmedEmail,
		Subject: subject,
		HTML:    htmlBody,
		Text:    textBody,
	})
}

func (s *EmailService) SendWelcomeEmail(email, ownerName, outletName string, bonusKoin int) (*resend.SendEmailResult, error) {
	trimmedEmail := strings.TrimSpace(email)
	if trimmedEmail == "" {
		return nil, fmt.Errorf("email tujuan wajib diisi")
	}

	safeOwner := html.EscapeString(strings.TrimSpace(ownerName))
	safeOutlet := html.EscapeString(strings.TrimSpace(outletName))
	subject := "Selamat Datang di AyoCuci"

	htmlBody := fmt.Sprintf(`
<div style="font-family:Arial,sans-serif;background:#f8fafc;padding:24px;color:#0f172a">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:18px;padding:28px">
    <p style="margin:0 0 8px;font-size:12px;letter-spacing:.12em;color:#94a3b8">AYOCUCI</p>
    <h1 style="margin:0 0 12px;font-size:24px;line-height:1.3">Akun Anda Sudah Aktif</h1>
    <p style="margin:0 0 14px;font-size:14px;line-height:1.7;color:#475569">
      Halo %s, selamat datang di AyoCuci.
    </p>
    <div style="margin:0 0 18px;padding:18px 20px;border-radius:14px;background:#fff7ed;border:1px solid #fed7aa">
      <div style="font-size:15px;font-weight:700;color:#ea580c">%s</div>
      <div style="margin-top:6px;font-size:13px;line-height:1.6;color:#7c2d12">Bonus awal %d koin sudah masuk. Trial outlet Anda juga sudah aktif.</div>
    </div>
    <p style="margin:0;font-size:13px;line-height:1.7;color:#64748b">
      Anda sudah bisa mulai mengatur layanan, pelanggan, transaksi, dan operasional laundry langsung dari aplikasi AyoCuci.
    </p>
  </div>
</div>`, safeOwner, safeOutlet, bonusKoin)

	textBody := fmt.Sprintf(
		"Halo %s, selamat datang di AyoCuci. Outlet %s sudah aktif. Bonus awal %d koin sudah masuk dan trial outlet Anda sudah berjalan.",
		strings.TrimSpace(ownerName),
		strings.TrimSpace(outletName),
		bonusKoin,
	)

	return resend.SendEmail(resend.SendEmailRequest{
		To:      trimmedEmail,
		Subject: subject,
		HTML:    htmlBody,
		Text:    textBody,
	})
}

func (s *EmailService) SendOwnerDailyReport(email, ownerName, outletName string, reportDate time.Time, totalTransaksi int64, penjualan, pendapatan, pengeluaran float64) (*resend.SendEmailResult, error) {
	trimmedEmail := strings.TrimSpace(email)
	if trimmedEmail == "" {
		return nil, fmt.Errorf("email tujuan wajib diisi")
	}

	dateLabel := reportDate.Format("02 January 2006")
	subject := fmt.Sprintf("Ringkasan Harian %s - %s", strings.TrimSpace(outletName), dateLabel)

	htmlBody := fmt.Sprintf(`
<div style="font-family:Arial,sans-serif;background:#f8fafc;padding:24px;color:#0f172a">
  <div style="max-width:560px;margin:0 auto;background:#ffffff;border:1px solid #e2e8f0;border-radius:18px;padding:28px">
    <p style="margin:0 0 8px;font-size:12px;letter-spacing:.12em;color:#94a3b8">AYOCUCI DAILY REPORT</p>
    <h1 style="margin:0 0 10px;font-size:24px;line-height:1.3">%s</h1>
    <p style="margin:0 0 18px;font-size:14px;line-height:1.7;color:#475569">
      Halo %s, berikut ringkasan operasional outlet Anda untuk %s.
    </p>
    <table width="100%%" cellpadding="0" cellspacing="0" style="border-collapse:collapse">
      <tr><td style="padding:10px 0;border-bottom:1px solid #e2e8f0;color:#64748b">Penjualan</td><td align="right" style="padding:10px 0;border-bottom:1px solid #e2e8f0;font-weight:700">Rp%s</td></tr>
      <tr><td style="padding:10px 0;border-bottom:1px solid #e2e8f0;color:#64748b">Pendapatan Hari Ini</td><td align="right" style="padding:10px 0;border-bottom:1px solid #e2e8f0;font-weight:700">Rp%s</td></tr>
      <tr><td style="padding:10px 0;border-bottom:1px solid #e2e8f0;color:#64748b">Pengeluaran</td><td align="right" style="padding:10px 0;border-bottom:1px solid #e2e8f0;font-weight:700">Rp%s</td></tr>
      <tr><td style="padding:10px 0;color:#64748b">Total Transaksi</td><td align="right" style="padding:10px 0;font-weight:700">%d</td></tr>
    </table>
  </div>
</div>`,
		html.EscapeString(strings.TrimSpace(outletName)),
		html.EscapeString(strings.TrimSpace(ownerName)),
		html.EscapeString(dateLabel),
		formatRupiahEmail(penjualan),
		formatRupiahEmail(pendapatan),
		formatRupiahEmail(pengeluaran),
		totalTransaksi,
	)

	textBody := fmt.Sprintf(
		"Ringkasan harian %s (%s)\nPenjualan: Rp%s\nPendapatan Hari Ini: Rp%s\nPengeluaran: Rp%s\nTotal Transaksi: %d",
		strings.TrimSpace(outletName),
		dateLabel,
		formatRupiahEmail(penjualan),
		formatRupiahEmail(pendapatan),
		formatRupiahEmail(pengeluaran),
		totalTransaksi,
	)

	return resend.SendEmail(resend.SendEmailRequest{
		To:      trimmedEmail,
		Subject: subject,
		HTML:    htmlBody,
		Text:    textBody,
	})
}

func formatRupiahEmail(amount float64) string {
	rounded := int64(amount + 0.5)
	raw := fmt.Sprintf("%d", rounded)
	if len(raw) <= 3 {
		return raw
	}

	var parts []string
	for len(raw) > 3 {
		parts = append([]string{raw[len(raw)-3:]}, parts...)
		raw = raw[:len(raw)-3]
	}
	if raw != "" {
		parts = append([]string{raw}, parts...)
	}
	return strings.Join(parts, ".")
}
