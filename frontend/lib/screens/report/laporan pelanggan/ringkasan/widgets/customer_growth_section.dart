import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CustomerGrowthSection extends StatelessWidget {
  final String dateLabel;
  final String trendLabel;
  final bool isTrendPositive;
  final List<CustomerChartData> chartData;
  final int pelangganHariIni;

  const CustomerGrowthSection({
    super.key,
    required this.dateLabel,
    required this.trendLabel,
    required this.chartData,
    required this.pelangganHariIni,
    this.isTrendPositive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1E5DE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dateLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF915D4E),
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isTrendPositive
                        ? const Color(0xFFEAF7EC)
                        : const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isTrendPositive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: isTrendPositive
                            ? const Color(0xFF2E9B52)
                            : AppPalette.danger,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          trendLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.w700,
                            color: isTrendPositive
                                ? const Color(0xFF2E9B52)
                                : AppPalette.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Pelanggan Baru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFont.w800,
              color: Color(0xFF2B1E1A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jumlah pelanggan yang baru dibuat pada periode ini.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Color(0xFF8D807A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.primaryPale,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFF3E4DE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Baru Periode Ini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFont.w700,
                          color: Color(0xFF8D807A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        pelangganHariIni.toString(),
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: AppFont.w800,
                          color: AppPalette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCFA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF3E8E2)),
            ),
            child: Column(
              children: [
                _SimpleAreaChart(chartData: chartData),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    _WeekLabel('WEEK 1'),
                    _WeekLabel('WEEK 2'),
                    _WeekLabel('WEEK 3'),
                    _WeekLabel('WEEK 4'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekLabel extends StatelessWidget {
  final String text;
  const _WeekLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        color: Color(0xFFB3A7A1),
        fontWeight: AppFont.w600,
      ),
    );
  }
}

class _SimpleAreaChart extends StatelessWidget {
  final List<CustomerChartData> chartData;

  const _SimpleAreaChart({required this.chartData});

  List<double> _normalize() {
    if (chartData.isEmpty) return [];
    final values = chartData.map((e) => e.value.toDouble()).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return List.filled(values.length, 0.1);
    return values.map((v) => (v / maxVal).clamp(0.05, 1.0)).toList();
  }

  String _formatDate(String raw) {
    try {
      final dt = parseReportDate(raw);
      if (dt == null) return raw;
      const bulan = [
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
      return '${dt.day} ${bulan[dt.month - 1]}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (chartData.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: Text(
            'Belum ada data grafik',
            style: TextStyle(
              color: Color(0xFFB3A7A1),
              fontSize: 12,
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      );
    }

    final points = _normalize();
    final hasPositiveValue = chartData.any((item) => item.value > 0);

    final peakIndex = points.indexOf(points.reduce((a, b) => a > b ? a : b));
    final peakLabel = hasPositiveValue && peakIndex < chartData.length
        ? '${_formatDate(chartData[peakIndex].date)} +${chartData[peakIndex].value}'
        : '';

    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _AreaChartPainter(
          points: points,
          peakLabel: peakLabel,
          showPeak: hasPositiveValue,
        ),
        size: const Size(double.infinity, 120),
      ),
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double> points;
  final String peakLabel;
  final bool showPeak;

  const _AreaChartPainter({
    required this.points,
    required this.peakLabel,
    required this.showPeak,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final linePaint = Paint()
      ..color = AppPalette.danger
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppPalette.danger.withValues(alpha: 0.3),
          AppPalette.danger.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? size.width / 2
          : (i / (points.length - 1)) * size.width;
      final y = size.height - (points[i] * size.height * 0.85) - 10;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        final prevX = ((i - 1) / (points.length - 1)) * size.width;
        final prevY = size.height - (points[i - 1] * size.height * 0.85) - 10;
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
        fillPath.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    final peakIndex = points.indexOf(points.reduce((a, b) => a > b ? a : b));
    final peakX = points.length == 1
        ? size.width / 2
        : (peakIndex / (points.length - 1)) * size.width;
    final peakY = size.height - (points[peakIndex] * size.height * 0.85) - 10;

    if (!showPeak) return;

    canvas.drawCircle(
      Offset(peakX, peakY),
      5,
      Paint()
        ..color = AppPalette.danger
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(peakX, peakY),
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: peakLabel,
        style: const TextStyle(
          fontSize: 10,
          color: Color(0xFF555555),
          fontWeight: AppFont.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final labelX = (peakX - textPainter.width / 2).clamp(
      0.0,
      size.width - textPainter.width,
    );
    textPainter.paint(canvas, Offset(labelX, peakY - 22));
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.points != points ||
      old.peakLabel != peakLabel ||
      old.showPeak != showPeak;
}
