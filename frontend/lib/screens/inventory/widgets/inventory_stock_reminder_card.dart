import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_schedule_editor_sheet.dart';
import 'package:flutter/material.dart';

class InventoryStockReminderCard extends StatelessWidget {
  const InventoryStockReminderCard({
    super.key,
    required this.enabled,
    required this.frequency,
    required this.schedule,
    required this.onEnabledChanged,
    required this.onFrequencyChanged,
    required this.onScheduleChanged,
  });

  final bool enabled;
  final String frequency;
  final String schedule;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<String> onScheduleChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0E8E4)),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppPalette.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 11),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pengingat Stock Opname',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w700,
                      color: AppPalette.ink,
                    ),
                  ),
                  Text(
                    'Ingatkan jadwal pengecekan stok',
                    style: TextStyle(fontSize: 11, color: AppPalette.muted),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: onEnabledChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: AppPalette.primary,
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 13),
          child: Divider(height: 1, color: Color(0xFFF2F3F5)),
        ),
        Row(
          children: [
            const Text(
              'Jadwal Pengingat',
              style: TextStyle(fontSize: 12, color: AppPalette.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: frequency,
                isDense: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 9,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppPalette.primary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppPalette.primary),
                  ),
                ),
                items: const ['Harian', 'Mingguan', 'Bulanan']
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item, style: TextStyle(fontSize: 12)),
                      ),
                    )
                    .toList(),
                onChanged: enabled
                    ? (value) {
                        if (value != null) onFrequencyChanged(value);
                      }
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                schedule,
                style: const TextStyle(fontSize: 11, color: AppPalette.muted),
              ),
            ),
            TextButton(
              onPressed: enabled
                  ? () => InventoryScheduleEditorSheet.show(
                      context,
                      onSave: onScheduleChanged,
                    )
                  : null,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'ATUR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFont.w700,
                  color: AppPalette.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
