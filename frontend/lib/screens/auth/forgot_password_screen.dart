import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:async';

import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/custom_textfield.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final PageController _pageController = PageController();
  final _lookupController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  int _currentStep = 0;
  String _lookupMethod = 'email';
  String? _otpChannel;
  String? _resolvedEmail;
  String? _resolvedPhone;
  String? _maskedEmail;
  String? _maskedPhone;
  String? _accountName;
  Timer? _timer;
  int _start = 30;
  bool _isResendLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;

  @override
  void initState() {
    super.initState();
    final initialEmail = (widget.initialEmail ?? '').trim();
    if (initialEmail.isNotEmpty) {
      _lookupMethod = 'email';
      _lookupController.text = initialEmail;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _lookupController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  void _setStep(int step) {
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
    setState(() => _currentStep = step);
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

  Future<void> _lookupAccount() async {
    final value = _lookupController.text.trim();
    if (value.isEmpty) {
      CustomToast.show(
        context,
        message: _lookupMethod == 'email' ? 'Email wajib diisi' : 'Nomor HP wajib diisi',
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.forgotPasswordLookupAccount(
      method: _lookupMethod,
      value: value,
    );
    if (!mounted) return;
    if (res['success'] != true) {
      CustomToast.show(
        context,
        message: res['message'] ?? 'Akun tidak ditemukan',
        isError: true,
      );
      return;
    }

    final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
    setState(() {
      _accountName = data['name']?.toString();
      _resolvedEmail = data['email']?.toString();
      _resolvedPhone = data['phone']?.toString();
      _maskedEmail = data['masked_email']?.toString();
      _maskedPhone = data['masked_phone']?.toString();
      final canSendEmail = data['can_send_email'] == true;
      final canSendWA = data['can_send_whatsapp'] == true;
      _otpChannel = canSendEmail ? 'email' : (canSendWA ? 'whatsapp' : null);
    });
    _setStep(1);
  }

  Future<void> _sendOtp({bool isResend = false}) async {
    if (_resolvedEmail == null || _resolvedPhone == null || _otpChannel == null) {
      CustomToast.show(context, message: 'Akun belum siap diverifikasi', isError: true);
      return;
    }

    if (isResend) {
      setState(() => _isResendLoading = true);
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.forgotPasswordSendOtp(
      _resolvedEmail!,
      _resolvedPhone!,
      channel: _otpChannel!,
    );

    if (!mounted) return;
    if (isResend) {
      setState(() => _isResendLoading = false);
    }

    if (res['success'] == true) {
      CustomToast.show(
        context,
        message: _otpChannel == 'email'
            ? 'Kode OTP dikirim ke email'
            : 'Kode OTP dikirim ke WhatsApp',
      );
      _startTimer();
      _setStep(2);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _otpFocusNode.requestFocus();
        }
      });
      return;
    }

    CustomToast.show(
      context,
      message: res['message'] ?? 'Gagal mengirim OTP',
      isError: true,
    );
  }

  Future<void> _verifyOtp() async {
    if (_resolvedEmail == null || _resolvedPhone == null) {
      CustomToast.show(context, message: 'Akun tidak ditemukan', isError: true);
      return;
    }

    final otp = _otpController.text.trim();
    if (otp.length < 4) {
      CustomToast.show(context, message: 'Masukkan 4 digit OTP', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.forgotPasswordVerifyOtp(
      _resolvedEmail!,
      _resolvedPhone!,
      otp,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      _setStep(3);
      return;
    }

    _otpController.clear();
    setState(() {});
    _otpFocusNode.requestFocus();
    CustomToast.show(
      context,
      message: res['message'] ?? 'OTP salah atau kedaluwarsa',
      isError: true,
    );
  }

  Future<void> _resetPassword() async {
    if (_resolvedEmail == null || _resolvedPhone == null) {
      CustomToast.show(context, message: 'Akun tidak ditemukan', isError: true);
      return;
    }
    if (_passController.text.length < 6) {
      CustomToast.show(context, message: 'Password minimal 6 karakter', isError: true);
      return;
    }
    if (_passController.text != _confirmPassController.text) {
      CustomToast.show(context, message: 'Konfirmasi password tidak cocok', isError: true);
      return;
    }

    final auth = context.read<AuthProvider>();
    final res = await auth.forgotPasswordReset(
      email: _resolvedEmail!,
      phone: _resolvedPhone!,
      otp: _otpController.text.trim(),
      newPassword: _passController.text,
    );
    if (!mounted) return;
    if (res['success'] == true) {
      CustomToast.show(context, message: 'Password berhasil diubah');
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      return;
    }

    CustomToast.show(
      context,
      message: res['message'] ?? 'Gagal mereset password',
      isError: true,
    );
  }

  Future<void> _launchWhatsApp() async {
    final url = Uri.parse(
      'https://wa.me/6281170030030?text=Halo%20Admin%2C%20saya%20terkendala%20saat%20reset%20password%20AyoCuci.',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      CustomToast.show(context, message: 'Gagal membuka WhatsApp', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: AppScaffold(
        backgroundColor: AppPalette.primary,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                    ),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _stepLookup(auth),
                        _stepConfirm(auth),
                        _stepOtp(auth),
                        _stepReset(auth),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -35,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
                          ],
                        ),
                        child: Image.asset(
                          'assets/icons/logo/logo_final_with_frame.webp',
                          height: 50,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    String title = 'LUPA PASSWORD?';
    String sub = 'Cari akun Anda lebih dulu';
    if (_currentStep == 1) {
      sub = 'Pastikan akun yang ditemukan benar';
    } else if (_currentStep == 2) {
      sub = 'Masukkan kode OTP yang dikirim';
    } else if (_currentStep == 3) {
      title = 'RESET PASSWORD';
      sub = 'Buat kata sandi baru untuk akun Anda';
    }

    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.fromLTRB(30, 40, 30, 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: AppFont.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5, fontWeight: AppFont.w500),
          ),
        ],
      ),
    );
  }

  Widget _stepLookup(AuthProvider auth) {
    return _buildStepBase(
      content: [
        _buildStepInfo(
          'Pilih data yang masih Anda ingat',
          'Cukup masukkan email atau nomor WhatsApp owner untuk mencari akun.',
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(child: _buildMethodChip('email', 'Cari via Email')),
            const SizedBox(width: 12),
            Expanded(child: _buildMethodChip('phone', 'Cari via No HP')),
          ],
        ),
        const SizedBox(height: 24),
        CustomTextField(
          controller: _lookupController,
          labelText: _lookupMethod == 'email' ? 'Email akun' : 'No WhatsApp owner',
          hintText: _lookupMethod == 'email' ? 'Contoh: email@anda.com' : 'Contoh: 0812xxxx',
          keyboardType: _lookupMethod == 'email' ? TextInputType.emailAddress : TextInputType.number,
          inputFormatters: _lookupMethod == 'phone'
              ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(15)]
              : null,
          fillColor: const Color(0xFFF9F9F9),
          onChanged: (_) => setState(() {}),
        ),
      ],
      bottom: _buildActionButtons(
        onNext: _lookupAccount,
        isLoading: auth.isLoading,
        nextLabel: 'CARI AKUN',
      ),
    );
  }

  Widget _stepConfirm(AuthProvider auth) {
    final canSendEmail = (_resolvedEmail ?? '').isNotEmpty;
    final canSendWA = (_resolvedPhone ?? '').isNotEmpty;

    return _buildStepBase(
      content: [
        _buildStepInfo(
          'Apakah ini akun Anda?',
          'Pastikan data yang kami temukan sesuai sebelum mengirim OTP.',
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _accountName ?? '-',
                style: const TextStyle(fontSize: 18, fontWeight: AppFont.w900, color: Color(0xFF2C3E50)),
              ),
              const SizedBox(height: 16),
              _buildAccountLine(Icons.email_outlined, _maskedEmail ?? '-'),
              const SizedBox(height: 10),
              _buildAccountLine(Icons.phone_iphone_rounded, _maskedPhone ?? '-'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Kirim OTP lewat',
          style: TextStyle(fontSize: 15, fontWeight: AppFont.w800, color: Color(0xFF2C3E50)),
        ),
        const SizedBox(height: 12),
        if (canSendEmail) _buildChannelTile('email', 'Email', _maskedEmail ?? '-', Icons.mail_outline_rounded),
        if (canSendWA) ...[
          if (canSendEmail) const SizedBox(height: 10),
          _buildChannelTile('whatsapp', 'WhatsApp', _maskedPhone ?? '-', Icons.chat_bubble_outline_rounded),
        ],
      ],
      bottom: _buildActionButtons(
        onNext: _sendOtp,
        onBack: () => _setStep(0),
        isLoading: auth.isLoading,
        nextLabel: 'KIRIM OTP',
      ),
    );
  }

  Widget _stepOtp(AuthProvider auth) {
    return _buildStepBase(
      content: [
        _buildStepInfo(
          'Masukkan kode OTP',
          _otpChannel == 'email'
              ? 'Kami sudah mengirimkan kode ke $_maskedEmail.'
              : 'Kami sudah mengirimkan kode ke $_maskedPhone.',
        ),
        const SizedBox(height: 36),
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          child: Column(
            children: [
              SizedBox(
                height: 0,
                width: 0,
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 4,
                  enableSuggestions: false,
                  autocorrect: false,
                  showCursor: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isCollapsed: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => _buildOtpBox(index)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: _isResendLoading
              ? const SizedBox(height: 20, width: 20, child: AppCircularLoader(strokeWidth: 2))
              : TextButton(
                  onPressed: _start == 0 ? () => _sendOtp(isResend: true) : null,
                  child: Text(
                    _start == 0 ? 'KIRIM ULANG KODE' : 'Kirim ulang dalam ${_start}s',
                    style: TextStyle(
                      color: _start == 0 ? AppPalette.primary : Colors.grey,
                      fontWeight: AppFont.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
        ),
      ],
      bottom: Column(
        children: [
          _buildChatAdmin(),
          const SizedBox(height: 20),
          _buildActionButtons(
            onNext: _verifyOtp,
            onBack: () => _setStep(1),
            isLoading: auth.isLoading,
            nextLabel: 'VERIFIKASI',
          ),
        ],
      ),
    );
  }

  Widget _stepReset(AuthProvider auth) {
    return _buildStepBase(
      content: [
        if (_accountName != null) ...[
          Text(
            _accountName!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: AppFont.w900, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 24),
        ],
        CustomTextField(
          controller: _passController,
          labelText: 'Password Baru',
          hintText: 'Buat password baru',
          isPassword: true,
          isPasswordVisible: _isPasswordVisible,
          onTogglePassword: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _confirmPassController,
          labelText: 'Konfirmasi Password',
          hintText: 'Ulangi password baru',
          isPassword: true,
          isPasswordVisible: _isConfirmVisible,
          onTogglePassword: () => setState(() => _isConfirmVisible = !_isConfirmVisible),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        _buildValidationRow('Minimal Password 6 Karakter', _passController.text.length >= 6),
        const SizedBox(height: 10),
        _buildValidationRow(
          'Password Angka & Huruf',
          RegExp(r'^(?=.*[a-zA-Z])(?=.*\d)').hasMatch(_passController.text),
        ),
      ],
      bottom: _buildActionButtons(
        onNext: _resetPassword,
        onBack: () => _setStep(2),
        isLoading: auth.isLoading,
        nextLabel: 'RESET PASSWORD',
      ),
    );
  }

  Widget _buildStepBase({required List<Widget> content, required Widget bottom}) {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(36, 75, 36, 20),
                sliver: SliverList(delegate: SliverChildListDelegate(content)),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(36, 0, 36, MediaQuery.of(context).padding.bottom + 20),
          child: bottom,
        ),
      ],
    );
  }

  Widget _buildStepInfo(String title, String sub) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppPalette.primary, fontSize: 16, fontWeight: AppFont.w700),
        ),
        const SizedBox(height: 10),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildMethodChip(String value, String label) {
    final active = _lookupMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _lookupMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: active ? AppPalette.primary : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? AppPalette.primary : Colors.grey.shade200),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF2C3E50),
            fontWeight: AppFont.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAccountLine(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: Color(0xFF2C3E50), fontWeight: AppFont.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelTile(String value, String title, String subtitle, IconData icon) {
    final active = _otpChannel == value;
    return GestureDetector(
      onTap: () => setState(() => _otpChannel = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? AppPalette.primary.withValues(alpha: 0.06) : const Color(0xFFF9F9F9),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? AppPalette.primary : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppPalette.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: AppFont.w800, color: Color(0xFF2C3E50))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            if (active) const Icon(Icons.check_circle, color: AppPalette.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final otpValue = _otpController.text;
    final digit = index < otpValue.length ? otpValue[index] : '';
    final isFocused = _otpFocusNode.hasFocus;
    final isActive = isFocused && otpValue.length == index;
    final hasValue = digit.isNotEmpty;

    return Container(
      width: 55,
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive || hasValue ? AppPalette.primary : Colors.grey.shade200,
          width: 2,
        ),
        color: const Color(0xFFF9F9F9),
      ),
      child: Text(
        digit,
        style: const TextStyle(fontSize: 20, fontWeight: AppFont.w900, color: AppPalette.primary),
      ),
    );
  }

  Widget _buildActionButtons({
    required VoidCallback onNext,
    VoidCallback? onBack,
    bool isLoading = false,
    required String nextLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : (onBack ?? () => Navigator.pop(context)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'KEMBALI',
                style: TextStyle(color: Colors.white, fontWeight: AppFont.w700, fontSize: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      nextLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: AppFont.w700, fontSize: 11),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatAdmin() {
    return Column(
      children: [
        const Text(
          'Tidak menerima kode OTP?',
          style: TextStyle(fontSize: 12, color: Color(0xFF2C3E50), fontWeight: AppFont.w600),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _launchWhatsApp,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icons/wa_icon_kecil.webp', width: 22),
              const SizedBox(width: 8),
              const Text(
                'Chat Disini',
                style: TextStyle(color: Color(0xFF2ECC71), fontWeight: AppFont.w800, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildValidationRow(String text, bool isValid) {
    return Row(
      children: [
        Icon(
          isValid ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isValid ? AppPalette.primary : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? AppPalette.primary : Colors.grey,
              fontWeight: isValid ? AppFont.w700 : AppFont.w400,
            ),
          ),
        ),
      ],
    );
  }
}
