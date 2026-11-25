import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class WorkTimeNote extends StatelessWidget {
  const WorkTimeNote({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppPalette.primarySoft,
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, color: AppPalette.primary, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'Jam operasional ini akan menjadi tolak ukur status Tepat Waktu atau Terlambat bagi karyawan setiap harinya.',
            style: TextStyle(color: AppPalette.ink, fontSize: 11, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
