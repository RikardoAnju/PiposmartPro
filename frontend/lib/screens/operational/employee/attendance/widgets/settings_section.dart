import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final Widget child;
  const SettingsSection({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: AppShadows.cardSoft,
    ),
    child: child,
  );
}
