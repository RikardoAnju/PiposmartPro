// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/auth/legal/kebijakan_privasi.dart';
import 'package:ayocucinew/screens/auth/legal/syarat_dan_ketentuan.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/register_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import '../widgets/registration_success_screen.dart';

class StepPassword extends StatefulWidget {
  final VoidCallback onBack;
  const StepPassword({super.key, required this.onBack});

  @override
  State<StepPassword> createState() => _StepPasswordState();
}

class _StepPasswordState extends State<StepPassword> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isAgreed = false;

  // Kriteria Validasi
  bool get _hasMinLength => _passwordController.text.length >= 6;
  bool get _hasAlphanumeric =>
      RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(_passwordController.text);

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleFinalRegister() async {
    final regProv = context.read<RegisterProvider>();
    final auth = context.read<AuthProvider>();

    // 1. Validasi Persetujuan
    if (!_isAgreed) {
      CustomToast.show(
        context,
        message: "Anda harus menyetujui Syarat & Ketentuan",
        isError: true,
      );
      return;
    }

    // 2. Validasi Kriteria Password (Berlaku untuk semua)
    if (!_hasMinLength || !_hasAlphanumeric) {
      CustomToast.show(
        context,
        message: "Password belum memenuhi kriteria",
        isError: true,
      );
      return;
    }

    // 3. Validasi Kecocokan Password
    if (_passwordController.text != _confirmPasswordController.text) {
      CustomToast.show(
        context,
        message: "Konfirmasi password tidak cocok",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    // 4. Pengumpulan Payload (Otomatis menyertakan google_id jika login google)
    final payload = regProv.collectFinalData();
    payload['password'] = _passwordController.text;
    payload['confirmPassword'] = _confirmPasswordController.text;

    try {
      final res = await auth.finalRegister(payload);
      if (res['success']) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_first_home_tutorial', true);
        await prefs.remove('first_home_tutorial_done');
        regProv.reset();
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (successContext) => RegistrationSuccessScreen(
              onPrimary: () {
                Navigator.of(successContext).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
            ),
          ),
          (route) => false,
        );
      } else {
        CustomToast.show(
          context,
          message: res['message'] ?? "Terjadi kesalahan pendaftaran",
          isError: true,
        );
      }
    } catch (e) {
      CustomToast.show(context, message: "Koneksi terputus", isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regProv = context.watch<RegisterProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 50, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER TEKS
                  const Text(
                    'Buat Kata Sandi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w900,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    regProv.isSocialLogin
                        ? 'Demi keamanan tambahan, harap buat password untuk akun AyoCuci Anda.'
                        : 'Gunakan kombinasi password yang kuat untuk melindungi akun Anda.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF95A5A6),
                      height: 1.4,
                    ),
                  ),

                  // INFO AKUN GOOGLE (Jika ada)
                  if (regProv.isSocialLogin) ...[
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        children: [
                          regProv.isAppleLogin
                              ? const Icon(
                                  Icons.apple,
                                  size: 16,
                                  color: Colors.black87,
                                )
                              : Image.asset(
                                  'assets/images/google_logo.webp',
                                  height: 16,
                                ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Terhubung: ${regProv.emailController.text}",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.w600,
                                color: Colors.blue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // INPUT PASSWORD UTAMA
                  CustomTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Masukkan password',
                    isRequired: true,
                    isPassword: true,
                    isPasswordVisible: _isPasswordVisible,
                    onTogglePassword: () => setState(
                      () => _isPasswordVisible = !_isPasswordVisible,
                    ),
                    onChanged: (_) => setState(() {}),
                    fillColor: const Color(0xFFF9F9F9),
                  ),
                  const SizedBox(height: 16),

                  // INPUT KONFIRMASI
                  CustomTextField(
                    controller: _confirmPasswordController,
                    labelText: 'Konfirmasi Password',
                    hintText: 'Ulangi password',
                    isRequired: true,
                    isPassword: true,
                    isPasswordVisible: _isConfirmPasswordVisible,
                    onTogglePassword: () => setState(
                      () => _isConfirmPasswordVisible =
                          !_isConfirmPasswordVisible,
                    ),
                    fillColor: const Color(0xFFF9F9F9),
                  ),

                  const SizedBox(height: 25),

                  // VALIDASI INDICATORS
                  _buildValidationRow('Minimal 6 Karakter', _hasMinLength),
                  const SizedBox(height: 10),
                  _buildValidationRow(
                    'Mengandung Angka & Huruf',
                    _hasAlphanumeric,
                  ),
                ],
              ),
            ),
          ),

          // AGREE CHECKBOX
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _isAgreed,
                  activeColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    setState(() => _isAgreed = val ?? false);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      "Saya menyetujui ",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SyaratKetentuanPage(),
                        ),
                      ),
                      child: const Text(
                        "Syarat & Ketentuan",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                    const Text(
                      " serta ",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const KebijakanPrivasiPage(),
                        ),
                      ),
                      child: const Text(
                        "Kebijakan Privasi",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // TOMBOL NAVIGASI
          SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      widget.onBack();
                    },
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
                        color: Colors.grey,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_isAgreed)
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _handleFinalRegister();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      disabledBackgroundColor: Colors.grey[300],
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
                            'DAFTAR',
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

  Widget _buildValidationRow(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 18,
          color: isValid ? AppPalette.primary : Colors.grey[400],
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isValid ? AppPalette.primary : const Color(0xFF95A5A6),
            fontWeight: isValid ? AppFont.w700 : AppFont.w400,
          ),
        ),
      ],
    );
  }
}
