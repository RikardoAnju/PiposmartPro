import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralInviteCard extends StatefulWidget {
  const ReferralInviteCard({super.key});

  @override
  State<ReferralInviteCard> createState() => _ReferralInviteCardState();
}

class _ReferralInviteCardState extends State<ReferralInviteCard> {
  final TextEditingController _controller = TextEditingController();
  static const Color kPrimary = AppPalette.primary;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    final token = context.read<AuthProvider>().token;
    final error = await context.read<ReferralProvider>().applyReferralCode(
      code,
      token: token,
    );

    if (!mounted) return;

    if (error == null) {
      _controller.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode referral berhasil diterapkan!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<ReferralProvider>().isSubmitting;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.group_add_rounded,
                  color: kPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punya Kode Referral?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF222222),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gunakan kode temanmu sekarang',
                      style: TextStyle(fontSize: 12, color: Color(0xFF888888)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                    color: Color(0xFF333333),
                  ),
                  decoration: InputDecoration(
                    hintText: 'AFOEJFBC',
                    hintStyle: const TextStyle(
                      color: Color(0xFFBBBBBB),
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kPrimary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: isSubmitting ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(90, 50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Terapkan',
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFont.w700,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
