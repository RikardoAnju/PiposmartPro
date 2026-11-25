// lib/screens/auth/register/steps/step_otp.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:async';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/register_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class StepOtp extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepOtp({super.key, required this.onNext, required this.onBack});

  @override
  State<StepOtp> createState() => _StepOtpState();
}

class _StepOtpState extends State<StepOtp> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  // Logic Timer
  Timer? _timer;
  int _start = 30;
  bool _isResendLoading = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer(); // Jalankan timer otomatis saat masuk halaman
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _start = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_start == 0) {
        setState(() => timer.cancel());
      } else {
        setState(() => _start--);
      }
    });
  }

  Future<void> _handleResendOtp() async {
    if (_start > 0) return; // Mencegah klik jika timer belum habis

    final regProv = context.read<RegisterProvider>();
    final auth = context.read<AuthProvider>();

    setState(() => _isResendLoading = true);

    try {
      final phone = regProv.phoneController.text.trim();
      final res = await auth.sendOtp(phone); // Panggil API Send OTP

      if (!mounted) return;
      if (res['success']) {
        CustomToast.show(
          context,
          message: "OTP baru telah dikirim ke WhatsApp",
        );
        _startTimer(); // Reset timer ke 30 detik
      } else {
        _showError(res['message'] ?? "Gagal mengirim ulang OTP");
      }
    } finally {
      if (mounted) setState(() => _isResendLoading = false);
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri url = Uri.parse(
      "https://wa.me/6281170030030?text=Halo%20Admin%2C%20saya%20terkendala%20menerima%20kode%20OTP%20AyoCuci.",
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) _showError("Tidak dapat membuka WhatsApp");
    }
  }

  void _handleVerify() async {
    final regProv = context.read<RegisterProvider>();
    final auth = context.read<AuthProvider>();

    String otpCode = _controllers.map((e) => e.text).join();
    if (otpCode.length < 4) {
      _showError("Masukkan 4 digit kode OTP");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phone = regProv.phoneController.text.trim();
      final res = await auth.verifyOtp(phone, otpCode);

      if (res['success']) {
        regProv.setOtpVerificationToken(res['verification_token']?.toString());
        widget.onNext();
      } else {
        _showError(res['message']);
        // UX: Kosongkan field jika salah agar user bisa input ulang
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    CustomToast.show(context, message: msg, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final phone = context.watch<RegisterProvider>().phoneController.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 50, 30, 30),
      child: Column(
        children: [
          const Text(
            'Kode Autentikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFont.w900,
              color: Color(0xFF2C3E50),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Masukkan Kode OTP yang sudah Anda terima\ndari WhatsApp ke nomor $phone',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF95A5A6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),

          // Row Input OTP Lingkaran
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(4, (index) => _buildOtpBox(index)),
          ),

          const SizedBox(height: 30),

          // Bagian Resend OTP dengan Timer
          _isResendLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: AppCircularLoader(
                    strokeWidth: 2,
                    color: AppPalette.primary,
                  ),
                )
              : TextButton(
                  onPressed: _start == 0 ? _handleResendOtp : null,
                  child: Text(
                    _start == 0
                        ? "KIRIM ULANG KODE"
                        : "Kirim ulang dalam ${_start}s",
                    style: TextStyle(
                      color: _start == 0 ? AppPalette.primary : Colors.grey,
                      fontWeight: AppFont.w700,
                      fontSize: 13,
                    ),
                  ),
                ),

          const Spacer(),

          // Chat Admin Section (WhatsApp Asli)
          Column(
            children: [
              const Text(
                'Tidak Menerima Kode OTP?',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2C3E50),
                  fontWeight: AppFont.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _launchWhatsApp,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/wa_icon_kecil.webp', // Ikon WA Asli
                      width: 22,
                      height: 22,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.chat,
                        color: Color(0xFF2ECC71),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Chat Disini',
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontWeight: AppFont.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Tombol Navigasi
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onBack,
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
                    onPressed: _isLoading ? null : _handleVerify,
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
                            'VERIFIKASI',
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

  Widget _buildOtpBox(int index) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppPalette.primary.withValues(alpha: 0.3),
          width: 2,
        ),
        color: const Color(0xFFF9F9F9),
      ),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: AppFont.w900,
            color: AppPalette.primary,
          ),
          decoration: const InputDecoration(
            counterText: "",
            border: InputBorder.none,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 3) {
              _focusNodes[index + 1].requestFocus();
            } else if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
            if (value.length == 1 && index == 3) {
              _focusNodes[index].unfocus();
              _handleVerify();
            }
          },
        ),
      ),
    );
  }
}
