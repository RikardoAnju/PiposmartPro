import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class LayananSummaryHeader extends StatelessWidget {
  final TransaksiPerLayananHeader header;
  final String dateLabel;
  final String filterLabel;
  final bool isCustomPeriod;
  final VoidCallback onPeriodTap;

  const LayananSummaryHeader({
    super.key,
    required this.header,
    required this.dateLabel,
    required this.filterLabel,
    required this.isCustomPeriod,
    required this.onPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    const primaryColor = AppPalette.primary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ringkasan Operasional',
            style: TextStyle(
              fontSize: 20,
              height: 1.08,
              fontWeight: AppFont.w900,
              color: Color(0xFF1F1715),
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Analisis performa layanan berdasarkan jumlah pesanan, kuantitas, dan penjualan.',
            style: TextStyle(
              fontSize: 10.5,
              height: 1.5,
              color: Color(0xFF8D807A),
              fontWeight: AppFont.w500,
            ),
          ),
          const SizedBox(height: 12),
          _HeroRevenueCard(value: currencyFormatter.format(header.totalHarga)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CompactMetric(
                  label: 'Total Layanan',
                  value: '${header.totalLayanan} Layanan',
                  icon: Icons.layers_rounded,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactMetric(
                  label: 'Total Pesanan',
                  value: '${header.totalPesanan} Pesanan',
                  icon: Icons.shopping_bag_rounded,
                  color: AppPalette.primaryWarm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _QuantityMetric(
            value: _formatQuantity(header.totalQuantity),
            color: const Color(0xFF2DBE7F),
          ),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPeriodTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isCustomPeriod
                      ? AppPalette.primaryPale
                      : const Color(0xFFFFFCFA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCustomPeriod
                        ? const Color(0xFFF5D2C4)
                        : const Color(0xFFF3E7E1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Periode:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w800,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$filterLabel ($dateLabel)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: AppFont.w900,
                          color: Color(0xFF2A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Color(0xFF8E7D76),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(Map<String, double> qty) {
    List<String> parts = [];
    String clean(double d) {
      if (d == d.truncateToDouble()) return d.toInt().toString();
      return d
          .toStringAsFixed(4)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }

    if (qty['kg']! > 0) parts.add('${clean(qty['kg']!)} Kg');
    if (qty['pcs']! > 0) parts.add('${clean(qty['pcs']!)} Pcs');
    if (qty['m']! > 0) parts.add('${clean(qty['m']!)} M');
    if ((qty['koin'] ?? 0) > 0) parts.add('${clean(qty['koin']!)} Koin');
    if (parts.isEmpty) return '0';
    return parts.join(' • ');
  }
}

class _HeroRevenueCard extends StatelessWidget {
  final String value;

  const _HeroRevenueCard({required this.value});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            isCompact ? 14 : 16,
            isCompact ? 14 : 16,
            isCompact ? 14 : 16,
            isCompact ? 15 : 17,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6A43), Color(0xFFFFB13D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF6A43).withValues(alpha: 0.20),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: isCompact ? -10 : -8,
                top: isCompact ? -8 : -4,
                child: Icon(
                  Icons.payments_rounded,
                  size: isCompact ? 76 : 88,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Penjualan Layanan',
                    style: TextStyle(
                      fontSize: isCompact ? 12 : 13,
                      fontWeight: AppFont.w600,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: isCompact ? 3 : 4),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 24 : 27,
                      height: 1.05,
                      fontWeight: AppFont.w900,
                      letterSpacing: isCompact ? -0.35 : -0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _CompactMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 150;
        final isLongValue = value.length > 16 || value.contains('\n');

        return Container(
          constraints: BoxConstraints(minHeight: isCompact ? 104 : 112),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 12 : 14,
            isCompact ? 10 : 12,
            isCompact ? 12 : 14,
            isCompact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCFA),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF5ECE8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCompact ? 9 : 10,
                        fontWeight: AppFont.w900,
                        color: const Color(0xFFB4A39D),
                        letterSpacing: isCompact ? 0.15 : 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.all(isCompact ? 7 : 8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: isCompact ? 14 : 16, color: color),
                  ),
                ],
              ),
              SizedBox(height: isCompact ? 12 : 14),
              Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isLongValue
                        ? (isCompact ? 12 : 13)
                        : (isCompact ? 16 : 18),
                    height: isLongValue ? 1.18 : 1.08,
                    fontWeight: AppFont.w900,
                    color: const Color(0xFF201716),
                    letterSpacing: isLongValue ? -0.2 : -0.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuantityMetric extends StatelessWidget {
  final String value;
  final Color color;

  const _QuantityMetric({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final parts = value == '0' ? <String>['0'] : value.split(' • ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCFA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5ECE8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL QUANTITY',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: AppFont.w900,
                    color: Color(0xFFB4A39D),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: List.generate(parts.length, (index) {
                    final part = parts[index];
                    final isLast = index == parts.length - 1;
                    return Text(
                      isLast ? part : '$part •',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.15,
                        fontWeight: AppFont.w900,
                        color: Color(0xFF201716),
                        letterSpacing: -0.25,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
