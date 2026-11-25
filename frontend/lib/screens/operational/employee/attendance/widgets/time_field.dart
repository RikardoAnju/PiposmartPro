import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const TimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 11,
            fontWeight: AppFont.w700,
          ),
        ),
        const SizedBox(height: 5),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE7E9ED)),
            ),
            child: Text(
              value,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 13,
                fontWeight: AppFont.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
