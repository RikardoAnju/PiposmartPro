import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Small label used for an employee's role and subscription type.
class WorkLogBadge extends StatelessWidget {
  const WorkLogBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppPalette.primary,
          fontSize: 8,
          fontWeight: AppFont.w700,
        ),
      ),
    );
  }
}
