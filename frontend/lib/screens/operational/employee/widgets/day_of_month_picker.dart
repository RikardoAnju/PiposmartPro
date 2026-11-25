import 'package:flutter/material.dart';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

/// Dialog pemilih tanggal murni (1-31) untuk jadwal gaji bulanan berulang.
/// Tidak menampilkan konteks bulan/tahun seperti [showDatePicker] — hanya grid
/// angka tanggal. Mengembalikan angka hari yang dipilih, atau null bila batal.
Future<int?> showDayOfMonthPicker({
  required BuildContext context,
  required int selectedDay,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _DayOfMonthPickerDialog(selectedDay: selectedDay),
  );
}

class _DayOfMonthPickerDialog extends StatefulWidget {
  final int selectedDay;

  const _DayOfMonthPickerDialog({required this.selectedDay});

  @override
  State<_DayOfMonthPickerDialog> createState() =>
      _DayOfMonthPickerDialogState();
}

class _DayOfMonthPickerDialogState extends State<_DayOfMonthPickerDialog> {
  late int _selected = widget.selectedDay.clamp(1, 31);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Tanggal Gajian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFont.w800,
                color: AppPalette.ink,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Tanggal berulang setiap bulan',
              style: TextStyle(fontSize: 12, color: AppPalette.muted),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: List.generate(31, (index) {
                final day = index + 1;
                final isSelected = day == _selected;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => setState(() => _selected = day),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppPalette.primary
                          : const Color(0xFFF3F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? AppFont.w800 : FontWeight.w500,
                        color: isSelected ? Colors.white : AppPalette.ink,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'BATAL',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  child: const Text(
                    'PILIH',
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
