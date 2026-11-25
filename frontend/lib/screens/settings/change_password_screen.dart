import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/settings/change_password_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_oldPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      CustomToast.show(
        context,
        message: "Semua kolom wajib diisi",
        isError: true,
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      CustomToast.show(
        context,
        message: "Password baru minimal 6 karakter",
        isError: true,
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      CustomToast.show(
        context,
        message: "Konfirmasi password tidak cocok",
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();

    final res = await auth.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      CustomToast.show(context, message: "Kata sandi berhasil diubah");
      Navigator.pop(context);
    } else {
      CustomToast.show(
        context,
        message: res['message'] ?? "Gagal mengubah kata sandi",
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return AppScaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Ganti Kata Sandi",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 130),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 130,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _oldPasswordController,
                        labelText: "Kata Sandi Sekarang",
                        isPassword: true,
                        isPasswordVisible: !_obscureOld,
                        onTogglePassword: () {
                          setState(() => _obscureOld = !_obscureOld);
                        },
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: "Masukkan kata sandi saat ini",
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _newPasswordController,
                        labelText: "Kata Sandi Baru",
                        isPassword: true,
                        isPasswordVisible: !_obscureNew,
                        onTogglePassword: () {
                          setState(() => _obscureNew = !_obscureNew);
                        },
                        prefixIcon: const Icon(Icons.vpn_key_outlined),
                        hintText: "Minimal 6 karakter",
                      ),
                      const SizedBox(height: 16),

                      CustomTextField(
                        controller: _confirmPasswordController,
                        labelText: "Ulangi Kata Sandi Baru",
                        isPassword: true,
                        isPasswordVisible: !_obscureConfirm,
                        onTogglePassword: () {
                          setState(() => _obscureConfirm = !_obscureConfirm);
                        },
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        hintText: "Masukkan  kata sandi baru",
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: AnimatedPadding(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(22, 12, 22, bottomSafe > 0 ? 10 : 18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: auth.isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppPalette.primary,
                  disabledBackgroundColor: AppPalette.primary.withValues(
                    alpha: 0.6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: auth.isLoading
                    ? const AppCircularLoader(color: Colors.white)
                    : const Text(
                        "UPDATE KATA SANDI",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: AppFont.w800,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
