import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const SectionTitle({super.key, required this.icon, required this.title});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AppPalette.primary),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 14,
            fontWeight: AppFont.w700,
          ),
        ),
      ),
    ],
  );
}
