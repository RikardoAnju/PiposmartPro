import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OmsetTile extends StatelessWidget {
  final OmsetReport item;
  final VoidCallback onLihatDetail;

  const OmsetTile({super.key, required this.item, required this.onLihatDetail});

  static const _bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  static final _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String get _dateLabel {
    try {
      final parsed = parseReportDate(item.tanggal);
      if (parsed == null) return item.tanggal;
      return '${parsed.day} ${_bulan[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return item.tanggal;
    }
  }

  bool get _isToday {
    try {
      final parsed = parseReportDate(item.tanggal);
      if (parsed == null) return false;
      final now = DateTime.now();
      return parsed.year == now.year &&
          parsed.month == now.month &&
          parsed.day == now.day;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool today = _isToday;

    return GestureDetector(
      onTap: onLihatDetail,
      child: Container(
        decoration: AppDecorations.card(
          radius: 18,
          border: today
              ? Border.all(
                  color: AppPalette.primary.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : AppBorders.card,
          shadow: today ? AppShadows.card : AppShadows.cardSoft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              if (today)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: const BoxDecoration(
                      color: AppPalette.primary,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'HARI INI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: AppFont.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.insert_chart_outlined_rounded,
                        color: AppPalette.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _dateLabel,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: today
                                  ? AppFont.w800
                                  : AppFont.w600,
                              color: today
                                  ? AppPalette.primary
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.jumlahTransaksi} transaksi',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black45,
                              fontWeight: AppFont.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currencyFmt.format(item.totalOmset),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: AppFont.w900,
                                color: AppPalette.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: Color(0xFFD0D0D0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
