import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralCodeCard extends StatelessWidget {
  const ReferralCodeCard({super.key});

  static const Color kPrimary = AppPalette.primary;

  void _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.select<ReferralProvider, dynamic>((p) => p.summary);

    final code = summary?.referralCode ?? '-';

    return Container(
      width: double.infinity,
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
          const _FieldLabel(label: 'REFERRAL CODE'),

          const SizedBox(height: 6),

          _FieldRow(value: code, onCopy: () => _copy(code)),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        color: Color(0xFFAAAAAA),
        letterSpacing: 0.5,
        fontWeight: AppFont.w500,
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String value;
  final VoidCallback onCopy;

  const _FieldRow({required this.value, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w700,
              color: const Color(0xFF222222),
            ),
          ),
        ),

        GestureDetector(
          onTap: onCopy,
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(
              Icons.copy_rounded,
              size: 20,
              color: AppPalette.primary,
            ),
          ),
        ),
      ],
    );
  }
}
