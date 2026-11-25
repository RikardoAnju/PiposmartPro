import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/auth/login_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/register_provider.dart';
import 'package:ayocucinew/screens/auth/forgot_password_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/widgets/custom_textfield.dart';
import '../../shared/widgets/custom_toast.dart';
import '../../shared/widgets/app_version_text.dart';
import '../../shared/widgets/app_asset_image.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

/// Aktif hanya di build internal: `flutter build ... --dart-define=IMPERSONATION=true`.
/// Default false → tombol impersonation TIDAK ADA di build store.
const bool kImpersonationEnabled = bool.fromEnvironment('IMPERSONATION');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  bool _rememberMe = false;
  bool _isPasswordVisible = false;

  bool get _supportsAppleSignIn =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  void initState() {
    super.initState();
    _loadRememberMeStatus();
  }

  Future<void> _loadRememberMeStatus() async {
    // Baca status dari storage
    final rememberMeStr = await _storage.read(key: 'remember_me');
    final savedEmail = await _storage.read(key: 'saved_email');

    if (rememberMeStr == 'true') {
      setState(() {
        _rememberMe = true;
        if (savedEmail != null) {
          _emailController.text = savedEmail;
        }
      });
    }
  }

  void _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      CustomToast.show(
        context,
        message: "Email dan Password wajib diisi",
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final appProv = context.read<AppProvider>();

    // --- LOGIKA REMEMBER ME ---
    if (_rememberMe) {
      // Simpan flag dan email jika dicentang
      await _storage.write(key: 'remember_me', value: 'true');
      await _storage.write(key: 'saved_email', value: email);
    } else {
      // Hapus jika tidak dicentang agar saat logout data bersih
      await _storage.write(key: 'remember_me', value: 'false');
      await _storage.delete(key: 'saved_email');
    }

    final result = await auth.login(email, password, rememberMe: _rememberMe);

    if (result['success']) {
      if (result['has_outlet'] == true) {
        await appProv.fetchAppData(force: true);
        if (!mounted) return;
        final String? outletId = appProv.outlet?.id.toString();
        if (outletId != null) appProv.initRealtime(outletId);
      }

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
        CustomToast.show(context, message: "Selamat Datang Kembali!");
      }
    } else {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: result['message'] ?? 'Login Gagal',
        isError: true,
      );
    }
  }

  // Dialog impersonation (build internal): masukkan email user + secret,
  // lalu masuk sebagai user itu. Hanya muncul bila kImpersonationEnabled.
  void _handleImpersonate() async {
    final emailCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Impersonate User (Internal)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email user'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: secretCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Secret'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Masuk'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final appProv = context.read<AppProvider>();
    final result = await auth.impersonate(emailCtrl.text, secretCtrl.text);
    if (!mounted) return;
    if (result['success'] == true) {
      if (result['has_outlet'] == true) {
        await appProv.fetchAppData(force: true);
        if (!mounted) return;
        final String? outletId = appProv.outlet?.id.toString();
        if (outletId != null) appProv.initRealtime(outletId);
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
      CustomToast.show(context, message: "Masuk sebagai ${emailCtrl.text}");
    } else {
      CustomToast.show(
        context,
        message: result['message'] ?? 'Impersonation gagal',
        isError: true,
      );
    }
  }

  void _handleGoogleLogin() async {
    final auth = context.read<AuthProvider>();
    final regProv = context.read<RegisterProvider>();
    final appProv = context.read<AppProvider>();

    // Simpan status remember me untuk sesi Google juga
    if (_rememberMe) {
      await _storage.write(key: 'remember_me', value: 'true');
    } else {
      await _storage.write(key: 'remember_me', value: 'false');
    }

    final result = await auth.signInWithGoogle(rememberMe: _rememberMe);

    if (result['success']) {
      if (result['is_registered'] == false) {
        if (!mounted) return;
        regProv.initGoogleData(result['google_data']);
        Navigator.pushNamed(context, '/register');
        CustomToast.show(context, message: "Silakan lengkapi pendaftaran Anda");
      } else {
        if (result['has_outlet'] == true) {
          await appProv.fetchAppData(force: true);
          if (!mounted) return;
          final String? outletId = appProv.outlet?.id.toString();
          if (outletId != null) appProv.initRealtime(outletId);
        }

        if (mounted) {
          if (result['has_outlet'] == true) {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacementNamed(
              context,
              Platform.isIOS ? '/home' : '/setup-outlet',
            );
          }
          CustomToast.show(context, message: "Login Google Berhasil");
        }
      }
    } else if (result['message'] != 'Proses masuk dibatalkan') {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: result['message'] ?? 'Google Login Gagal',
        isError: true,
      );
    }
  }

  void _handleAppleLogin() async {
    final auth = context.read<AuthProvider>();
    final regProv = context.read<RegisterProvider>();
    final appProv = context.read<AppProvider>();

    await _storage.write(key: 'remember_me', value: _rememberMe.toString());

    final result = await auth.signInWithApple(rememberMe: _rememberMe);
    if (result['success']) {
      if (result['is_registered'] == false) {
        if (!mounted) return;
        regProv.initAppleData(result['apple_data']);
        Navigator.pushNamed(context, '/register');
        CustomToast.show(context, message: "Silakan lengkapi pendaftaran Anda");
      } else {
        if (result['has_outlet'] == true) {
          await appProv.fetchAppData(force: true);
          if (!mounted) return;
          final String? outletId = appProv.outlet?.id.toString();
          if (outletId != null) appProv.initRealtime(outletId);
        }

        if (mounted) {
          if (result['has_outlet'] == true) {
            Navigator.pushReplacementNamed(context, '/home');
          } else {
            Navigator.pushReplacementNamed(
              context,
              Platform.isIOS ? '/home' : '/setup-outlet',
            );
          }
          CustomToast.show(context, message: "Login Apple Berhasil");
        }
      }
    } else if (result['message'] != 'Proses masuk dibatalkan') {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: result['message'] ?? 'Apple Login Gagal',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return AppScaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isTablet = constraints.maxWidth > 600;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? constraints.maxWidth * 0.2 : 25,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      AppAssetImage(
                        'assets/icons/logo/baru.png',
                        height: isTablet ? 72 : 54,
                      ),
                      const Text(
                        'Welcome',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: AppFont.w700,
                          color: AppPalette.primary,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 5,
                        ),
                        child: Text(
                          'Senang menyambut Anda kembali.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 40),
                      _buildInputLabel("Email"),
                      CustomTextField(
                        controller: _emailController,
                        hintText: 'Email anda',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 15),
                      _buildInputLabel("Password"),
                      CustomTextField(
                        controller: _passwordController,
                        hintText: 'Password anda',
                        isPassword: true,
                        isPasswordVisible: _isPasswordVisible,
                        prefixIcon: const Icon(Icons.lock_outline, size: 20),
                        onTogglePassword: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildOptionsRow(),
                      const SizedBox(height: 30),
                      _buildActionButtons(auth),
                      const SizedBox(height: 20),
                      _buildRegisterLink(),
                      const SizedBox(height: 40),
                      const AppVersionText(
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(fontWeight: AppFont.w700, fontSize: 14),
      ),
    ),
  );

  Widget _buildOptionsRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: Checkbox(
              value: _rememberMe,
              activeColor: AppPalette.primary,
              onChanged: (v) => setState(() => _rememberMe = v!),
            ),
          ),
          const SizedBox(width: 8),
          const Text('Ingat saya', style: TextStyle(fontSize: 12)),
        ],
      ),
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ForgotPasswordScreen(
              initialEmail: _emailController.text.trim(),
            ),
          ),
        ),
        child: const Text(
          'Lupa password?',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: AppFont.w700,
          ),
        ),
      ),
    ],
  );

  Widget _buildActionButtons(AuthProvider auth) => Column(
    children: [
      ElevatedButton(
        onPressed: auth.isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: auth.isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'LOGIN',
                style: TextStyle(color: Colors.white, fontWeight: AppFont.w700),
              ),
      ),
      if (kImpersonationEnabled) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: auth.isLoading ? null : _handleImpersonate,
          icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
          label: const Text('Impersonate User (Internal)'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            foregroundColor: AppPalette.primaryDeep,
            side: BorderSide(color: AppPalette.primary.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ],
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text('Atau', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ),
      OutlinedButton(
        onPressed: auth.isLoading ? null : _handleGoogleLogin,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF3F4F6),
          side: BorderSide.none,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppAssetImage('assets/images/google_logo.webp', height: 20),
            const SizedBox(width: 10),
            const Text(
              'Masuk dengan Google',
              style: TextStyle(color: Colors.black, fontWeight: AppFont.w400),
            ),
          ],
        ),
      ),
      if (_supportsAppleSignIn) ...[
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: auth.isLoading ? null : _handleAppleLogin,
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.black,
            side: BorderSide.none,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.apple, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Masuk dengan Apple',
                style: TextStyle(color: Colors.white, fontWeight: AppFont.w600),
              ),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _buildRegisterLink() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text(
        "Belum punya akun? ",
        style: TextStyle(fontSize: 12, color: Colors.black87),
      ),
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/register'),
        child: const Text(
          "Daftar sekarang",
          style: TextStyle(
            fontSize: 12,
            color: AppPalette.primary,
            fontWeight: AppFont.w700,
          ),
        ),
      ),
    ],
  );
}
