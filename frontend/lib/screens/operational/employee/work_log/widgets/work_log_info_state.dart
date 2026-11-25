import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

/// Reusable feedback state for an empty or failed employee list.
class WorkLogInfoState extends StatelessWidget {
  const WorkLogInfoState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 72),
      child: Column(
        children: [
          Icon(icon, size: 58, color: AppPalette.primaryBorderStrong),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.ink,
              fontSize: 16,
              fontWeight: AppFont.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
