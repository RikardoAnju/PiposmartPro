import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:async';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/register_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class StepAccount extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepAccount({super.key, required this.onNext, required this.onBack});

  @override
  State<StepAccount> createState() => _StepAccountState();
}

class _StepAccountState extends State<StepAccount> {
  bool _isLoading = false;
  bool _isCheckingReferral = false;
  bool? _isReferralValid;
  String? _referralMessage;
  Timer? _debounce;
  bool _showReferralTooltip = false;

  // List sumber informasi yang diperbanyak
  final List<String> _leadSources = [
    "Instagram",
    "Facebook",
    "TikTok",
    "Google Search",
    "Iklan Youtube",
    "Teman/Rekomendasi",
    "Sales / Agen Ayo Cuci",
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // --- LOGIKA VALIDASI EMAIL ---
  bool _isValidEmail(String email) {
    return RegExp(
      r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
    ).hasMatch(email);
  }

  // --- LOGIKA REFERRAL ---
  void _onReferralChanged(String code) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    if (code.isEmpty) {
      setState(() {
        _isReferralValid = null;
        _referralMessage = null;
        _isCheckingReferral = false;
      });
      return;
    }
    setState(() {
      _isCheckingReferral = true;
      _isReferralValid = null;
    });
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _checkReferral(code);
    });
  }

  void _checkReferral(String code) async {
    final res = await context.read<AuthProvider>().validateReferral(code);
    if (mounted) {
      setState(() {
        _isCheckingReferral = false;
        if (res['success']) {
          _isReferralValid = true;
          _referralMessage =
              "✓ Kode referral valid: ${res['data']['referrer_name']}";
        } else {
          _isReferralValid = false;
          _referralMessage = "✕ Kode referral tidak ditemukan";
        }
      });
    }
  }

  // --- UI PICKER SUMBER INFORMASI ---
  void _showSourcePicker(RegisterProvider regProv) {
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 15),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 25),
                child: Text(
                  "Tahu aplikasi ini dari mana?",
                  style: TextStyle(
                    fontWeight: AppFont.w800,
                    fontSize: 16,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  children: _leadSources.map((source) {
                    final isSelected = regProv.selectedLeadSource == source;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        regProv.updateLeadSource(source);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 18,
                        ),
                        color: isSelected
                            ? AppPalette.primary.withValues(alpha: 0.05)
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                source,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? AppFont.w800
                                      : AppFont.w500,
                                  color: isSelected
                                      ? AppPalette.primary
                                      : const Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppPalette.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // --- LOGIKA SUBMIT ---
  void _handleStepAccount() async {
    final regProv = context.read<RegisterProvider>();
    final name = regProv.nameController.text.trim();
    final email = regProv.emailController.text.trim();
    final referralCode = regProv.referralController.text.trim();

    // 1. Validasi Nama
    if (name.length < 3) {
      CustomToast.show(
        context,
        message: "Nama lengkap terlalu pendek",
        isError: true,
      );
      return;
    }

    // 2. Validasi Email (Format)
    if (email.isEmpty || !_isValidEmail(email)) {
      CustomToast.show(
        context,
        message: "Masukkan format email yang valid",
        isError: true,
      );
      return;
    }

    // 3. Validasi Referral (Jika diisi harus valid)
    if (referralCode.isNotEmpty && _isReferralValid == false) {
      CustomToast.show(
        context,
        message: "Kode referral tidak valid, silahkan hapus",
        isError: true,
      );
      return;
    }

    // 4. Validasi Sumber Lead
    if (regProv.selectedLeadSource == null) {
      CustomToast.show(
        context,
        message: "Pilih sumber informasi dulu",
        isError: true,
      );
      return;
    }

    if (_isCheckingReferral) return;

    setState(() => _isLoading = true);
    try {
      final res = await context.read<AuthProvider>().validateAccount(
        nama: name,
        email: email,
      );
      if (!mounted) return;
      if (res['success']) {
        widget.onNext();
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regProv = context.watch<RegisterProvider>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 50, 30, 20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomTextField(
                    controller: regProv.nameController,
                    labelText: 'Nama lengkap anda',
                    hintText: 'Helwiza Fahry',
                    isRequired: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: regProv.emailController,
                    labelText: 'Email',
                    hintText: 'ayocuci@gmail.com',
                    isRequired: true,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !regProv.isSocialLogin,
                    prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: regProv.referralController,
                    onChanged: _onReferralChanged,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      UpperCaseTextFormatter(),
                      LengthLimitingTextInputFormatter(
                        10,
                      ), // Memperketat panjang kode
                    ],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w600,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Kode referral',
                      hintText: 'Tulis kode referral jika ada',
                      filled: true,
                      fillColor: const Color(0xFFF9F9F9),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(
                          color: AppPalette.primary,
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: _buildReferralSuffix(),
                    ),
                  ),
                  if (_showReferralTooltip) _buildTooltip(),
                  if (_referralMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 12),
                      child: Text(
                        _referralMessage!,
                        style: TextStyle(
                          color: _isReferralValid == true
                              ? Colors.green
                              : Colors.red,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    "Tahu aplikasi ini dari mana?",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: AppFont.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _showSourcePicker(regProv),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9F9F9),
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            regProv.selectedLeadSource ??
                                "Pilih Sumber Informasi",
                            style: TextStyle(
                              fontSize: 13,
                              color: regProv.selectedLeadSource == null
                                  ? Colors.grey
                                  : const Color(0xFF2C3E50),
                              fontWeight: regProv.selectedLeadSource == null
                                  ? AppFont.w400
                                  : AppFont.w600,
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: Color(0xFF2C3E50),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '*Wajib diisi',
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
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
                    onPressed: (_isLoading || (_isReferralValid == false))
                        ? null
                        : _handleStepAccount,
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
                            'SELANJUTNYA',
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

  Widget? _buildReferralSuffix() {
    if (_isCheckingReferral) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          height: 10,
          width: 10,
          child: AppCircularLoader(strokeWidth: 2, color: AppPalette.primary),
        ),
      );
    }
    return IconButton(
      icon: Icon(
        Icons.help_outline,
        size: 20,
        color: _showReferralTooltip ? AppPalette.primary : Colors.grey,
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() => _showReferralTooltip = !_showReferralTooltip);
      },
    );
  }

  Widget _buildTooltip() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info, size: 16, color: Color(0xFF2C3E50)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Masukkan kode referral jika ada untuk mendapatkan benefit tambahan.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF2C3E50),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
