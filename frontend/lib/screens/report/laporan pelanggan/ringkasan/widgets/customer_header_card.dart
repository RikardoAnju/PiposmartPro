import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';

class CustomerHeaderCard extends StatelessWidget {
  final int totalPelanggan;
  final int totalOrder;
  final String totalNominal;
  final String periodLabel;
  final VoidCallback onPeriodTap;

  const CustomerHeaderCard({
    super.key,
    required this.totalPelanggan,
    required this.totalOrder,
    required this.totalNominal,
    required this.periodLabel,
    required this.onPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF5F2E), Color(0xFFFF9F43)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            bottom: -20,
            child: CustomPaint(
              size: const Size(156, 132),
              painter: _CustomerPainter(),
            ),
          ),
          Positioned(
            right: -26,
            top: -34,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pelanggan Aktif Transaksi',
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _FilterPill(
                          label: 'Periode',
                          helper: periodLabel,
                          onTap: onPeriodTap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _CustomerCountBadge(count: totalPelanggan, label: 'Aktif'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetricCard(
                      label: 'Total Order',
                      value: '$totalOrder order',
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetricCard(
                      label: 'Nilai Transaksi',
                      value: totalNominal,
                      icon: Icons.payments_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerCountBadge extends StatelessWidget {
  final int count;
  final String label;

  const _CustomerCountBadge({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              count.toString(),
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFFF5F4D),
                fontSize: 24,
                fontWeight: AppFont.w900,
                height: 0.95,
              ),
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Color(0xFFFF5F4D),
                fontSize: 9,
                fontWeight: AppFont.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final String helper;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.helper,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 196),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 13,
                  color: Colors.white,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$label  $helper',
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: AppFont.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 9.5,
                    fontWeight: AppFont.w700,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: AppFont.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = Colors.white.withValues(alpha: 0.09)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.17)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(54, 46, 92, 78),
        const Radius.circular(16),
      ),
      fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 92, 86, 28),
        const Radius.circular(8),
      ),
      stroke,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(54, 46, 92, 78),
        const Radius.circular(16),
      ),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(64, 46)
        ..lineTo(88, 20)
        ..lineTo(136, 60),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
