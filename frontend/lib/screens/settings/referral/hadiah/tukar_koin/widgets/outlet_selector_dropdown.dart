import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OutletSelectorDropdown extends StatelessWidget {
  final String? selectedOutletName;
  final int? selectedOutletKoin;
  final VoidCallback onTap;

  const OutletSelectorDropdown({
    super.key,
    this.selectedOutletName,
    this.selectedOutletKoin,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selectedOutletName != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasSelection ? AppPalette.primary : Colors.grey.shade300,
            width: hasSelection ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (hasSelection) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppPalette.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.store_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: hasSelection
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedOutletName!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: AppFont.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Total Koin: ${selectedOutletKoin ?? 0} Koin',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Pilih outlet tujuan',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
