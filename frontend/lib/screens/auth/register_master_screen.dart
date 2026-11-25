import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/providers/register_provider.dart';
import 'package:ayocucinew/screens/auth/steps/step_outlet.dart';
import 'package:ayocucinew/screens/auth/steps/step_password.dart';
import 'package:ayocucinew/screens/auth/steps/step_phone.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'steps/step_account.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RegisterMasterScreen extends StatefulWidget {
  final Map<String, dynamic>? googleData;
  const RegisterMasterScreen({super.key, this.googleData});

  @override
  State<RegisterMasterScreen> createState() => _RegisterMasterScreenState();
}

class _RegisterMasterScreenState extends State<RegisterMasterScreen> {
  int _currentStep = 0;

  void _nextPage() => setState(() => _currentStep++);
  void _prevPage() => setState(() => _currentStep--);

  int _maxStep(RegisterProvider regProv) => 3;

  int _mapDisplayStepToCurrentStep(RegisterProvider regProv, int targetStep) {
    return targetStep;
  }

  void _jumpToStep(int targetStep) {
    final regProv = context.read<RegisterProvider>();
    if (targetStep > 0 && regProv.phoneController.text.isEmpty) {
      CustomToast.show(
        context,
        message: 'Masukkan Nomor HP terlebih dahulu',
        isError: true,
      );
      return;
    }
    setState(
      () => _currentStep = _mapDisplayStepToCurrentStep(regProv, targetStep),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: AppPalette.primary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildStepperHeader(),
                  const SizedBox(height: 20),
                  _buildDynamicWelcomeText(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(40),
                    topRight: Radius.circular(40),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Konten Step
                    _buildCurrentStep(),
                    // Logo Melayang
                    _buildFloatingLogo(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return StepPhone(onNext: _nextPage);
      case 1:
        return StepAccount(onNext: _nextPage, onBack: _prevPage);
      case 2:
        return StepOutlet(onNext: _nextPage, onBack: _prevPage);
      case 3:
        return StepPassword(onBack: _prevPage);
      default:
        return const SizedBox();
    }
  }

  Widget _buildStepperHeader() {
    final verifyActive = _currentStep == 0;
    final dataStepActive = _currentStep == 1 || _currentStep == 2;
    final securityActive = _currentStep == 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _stepPill(1, 'Verifikasi', verifyActive, () => _jumpToStep(0)),
            _stepPill(2, 'Data Anda', dataStepActive, () => _jumpToStep(1)),
            _stepPill(3, 'Keamanan', securityActive, () => _jumpToStep(3)),
          ],
        ),
      ),
    );
  }

  Widget _stepPill(int step, String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 8,
                backgroundColor: isActive ? AppPalette.primary : Colors.white,
                child: Text(
                  step.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.white : AppPalette.primary,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.w700,
                  color: isActive ? const Color(0xFF2C3E50) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingLogo() {
    return Positioned(
      top: -40,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icons/logo/logo_final.webp',
            height: 50,
            width: 50,
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicWelcomeText() {
    final regProv = context.watch<RegisterProvider>();
    final lastStep = _maxStep(regProv);
    String title = '';
    String subtitle = '';
    switch (_currentStep) {
      case 0:
        if (regProv.isSocialLogin) {
          title = 'Nomor owner dulu';
          subtitle = 'Kami tetap butuh nomor HP aktif sebagai identitas akun.';
          break;
        }
        title = 'Selamat datang di ayo cuci!';
        subtitle = 'Terima kasih sudah mendownload aplikasi ayo cuci.';
        break;
      case 1:
        if (regProv.isSocialLogin) {
          title = 'Lengkapi Data Diri';
          subtitle = 'Gunakan data asli untuk memudahkan koordinasi.';
          break;
        }
        title = 'Selamat datang di ayo cuci!';
        subtitle = 'Terima kasih sudah mendownload aplikasi ayo cuci.';
        break;
      case 2:
        if (regProv.isSocialLogin) {
          title = 'Pendaftaran anda hampir selesai';
          subtitle = 'Mari isi data outlet anda dibawah ini';
          break;
        }
        title = 'Lengkapi Data Diri';
        subtitle = 'Gunakan data asli untuk memudahkan koordinasi.';
        break;
      case 3:
        if (lastStep == 3) {
          title = 'Tinggal satu step lagi';
          subtitle = 'Ayo selesaikan pendaftaran anda';
          break;
        }
        title = 'Pendaftaran anda hampir selesai';
        subtitle = 'Mari isi data outlet anda dibawah ini';
        break;
      case 4:
        title = 'Tinggal satu step lagi';
        subtitle = 'Ayo selesaikan pendaftaran anda';
        break;
    }

    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: AppFont.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }
}
