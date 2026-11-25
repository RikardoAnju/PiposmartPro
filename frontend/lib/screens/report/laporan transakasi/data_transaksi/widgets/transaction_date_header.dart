import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';

class TransactionDateHeader extends StatelessWidget {
  final String label;

  const TransactionDateHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFE53935),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w600,
              color: Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}
