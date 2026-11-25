import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart'; // Dibutuhkan untuk inputFormatters
import 'package:provider/provider.dart';
import '../../../providers/register_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class StepPhone extends StatefulWidget {
  final VoidCallback onNext;
  const StepPhone({super.key, required this.onNext});

  @override
  State<StepPhone> createState() => _StepPhoneState();
}

class _StepPhoneState extends State<StepPhone> {
  bool _isLoading = false;

  void _handleStepPhone() async {
    final regProv = context.read<RegisterProvider>();
    final phone = regProv.phoneController.text.trim();

    // Validasi 1: Field Kosong
    if (phone.isEmpty) {
      CustomToast.show(
        context,
        message: "Nomor WhatsApp wajib diisi",
        isError: true,
      );
      return;
    }

    // Validasi 2: Minimal Karakter (Nomor HP Indonesia min. 9-10 digit)
    if (phone.length < 9) {
      CustomToast.show(
        context,
        message: "Nomor WhatsApp tidak valid (terlalu pendek)",
        isError: true,
      );
      return;
    }

    // Validasi 3: Awalan nomor (Opsional: Memastikan mulai dengan 08 atau 62)
    if (!phone.startsWith('08') &&
        !phone.startsWith('62') &&
        !phone.startsWith('8')) {
      CustomToast.show(
        context,
        message: "Gunakan format nomor yang benar (contoh: 0812...)",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = context.read<AuthProvider>();

    try {
      // Langsung panggil sendOtp untuk registrasi dan Foonte WA check.
      final otpRes = await auth.sendOtp(phone);
      if (!mounted) return;
      
      if (otpRes['success']) {
        // Karena OTP sudah dibypass dengan validasi aktif WA dari Fonte,
        // kita ambil token verifikasi yang dihasilkan backend.
        final token = otpRes['verification_token'];
        regProv.setOtpVerificationToken(token);
        
        // Pindah ke step berikutnya
        widget.onNext();
      } else {
        CustomToast.show(context, message: otpRes['message'], isError: true);
      }
    } catch (e) {
      CustomToast.show(
        context,
        message: "Terjadi kesalahan koneksi",
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regProv = context.watch<RegisterProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 50, 30, 30),
      child: Column(
        children: [
          const Text(
            'Nomor WhatsApp Owner',
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFont.w900,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            regProv.isSocialLogin
                ? 'Masukkan nomor WhatsApp owner. Untuk login sosial, nomor ini hanya divalidasi dan disimpan sebagai identitas akun.'
                : 'Gunakan nomor WhatsApp pribadi Owner untuk menerima kode verifikasi keamanan.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF95A5A6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          CustomTextField(
            controller: regProv.phoneController,
            labelText: 'Nomor WhatsApp Aktif',
            hintText: 'Contoh: 081234567890',
            isRequired: true,
            keyboardType: TextInputType.phone, // Memunculkan keyboard angka
            fillColor: const Color(0xFFF9F9F9),
            // Menambahkan validasi input formatters
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly, // Hanya izinkan angka
              LengthLimitingTextInputFormatter(15), // Maksimal 15 digit
            ],
            onChanged: (value) {
              // Menghapus karakter pertama jika user input spasi atau simbol secara tidak sengaja
              if (value.startsWith(' ')) {
                regProv.phoneController.clear();
              }
            },
          ),

          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppPalette.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Nomor ini akan digunakan sebagai identitas utama akun Anda.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2C3E50),
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),
          const SizedBox(height: 30),

          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'KEMBALI',
                      style: TextStyle(
                        color: Color(0xFF95A5A6),
                        fontWeight: AppFont.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleStepPhone,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: AppCircularLoader(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'LANJUTKAN',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
