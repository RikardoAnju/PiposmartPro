import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/unit_label.dart';
import 'package:ayocucinew/data/models/transaction_model.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class DetailLayananTile extends StatelessWidget {
  final CartItem item;

  const DetailLayananTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = item.qty % 1 == 0
        ? item.qty.toInt().toString()
        : item.qty
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'0+$'), '')
              .replaceAll(RegExp(r'\.$'), '');
    final hargaRaw = CurrencyFormatter.formatToRupiah(
      item.price,
    ).replaceFirst('Rp ', '').replaceFirst('Rp', '');
    final subtotal = CurrencyFormatter.formatToRupiah(item.subtotal);
    final durationText = _durationText(item);

    final String displayName = item.serviceName.isNotEmpty
        ? item.serviceName
        : item.categoryName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName.isNotEmpty ? displayName : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$qty ${displayUnitLabel(item.unit)} × $hargaRaw',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subtotal,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: AppFont.w700,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                durationText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _durationText(CartItem item) {
    final serviceDuration = _formatServiceDuration(item);
    final remaining = _formatRemaining(item.readyAt);

    if (remaining == null && serviceDuration == null) return '-';
    if (remaining == null) return serviceDuration!;
    if (serviceDuration == null) return remaining;
    return '$remaining ($serviceDuration)';
  }

  String? _formatServiceDuration(CartItem item) {
    if (item.duration <= 0 || item.durationUnit.trim().isEmpty) return null;
    return '${item.duration} ${_normalizeDurationUnit(item.durationUnit)}';
  }

  String _normalizeDurationUnit(String unit) {
    final lower = unit.toLowerCase().trim();
    if (lower == 'jam' || lower == 'hour' || lower == 'hours') return 'Jam';
    if (lower == 'hari' || lower == 'day' || lower == 'days') return 'Hari';
    return unit;
  }

  String? _formatRemaining(DateTime? readyAt) {
    if (readyAt == null) return null;

    final diff = readyAt.difference(DateTime.now());
    if (diff.inMinutes <= 0) return 'Lewat tenggat';
    if (diff.inMinutes < 60) return '${diff.inMinutes} Menit lagi';
    if (diff.inHours < 24) return '${(diff.inMinutes / 60).ceil()} Jam lagi';
    return '${(diff.inHours / 24).ceil()} Hari lagi';
  }
}
