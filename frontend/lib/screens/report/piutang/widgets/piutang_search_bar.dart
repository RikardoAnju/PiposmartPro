import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';

class PiutangSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;
  final bool hasActiveFilter;

  const PiutangSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
    this.hasActiveFilter = false,
  });

  static const Color kPrimary = AppPalette.primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            controller: controller,
            onChanged: onChanged,
            hintText: 'Cari pelanggan',
            height: 44,
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onFilterTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveFilter
                    ? kPrimary
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: hasActiveFilter
                  ? AppShadows.colored(kPrimary)
                  : AppShadows.cardSoft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: hasActiveFilter ? kPrimary : Colors.black54,
                ),
                const SizedBox(width: 8),
                Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFont.w800,
                    color: hasActiveFilter ? kPrimary : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
