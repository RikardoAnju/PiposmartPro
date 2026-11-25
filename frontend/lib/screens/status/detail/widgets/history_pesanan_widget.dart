import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:ayocucinew/data/models/transaction_model.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../../shared/widgets/app_asset_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_helpers.dart';

class HistoryPesananWidget extends StatelessWidget {
  const HistoryPesananWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final trx = provider.currentDetail;
        final logs = trx?.logs ?? [];
        if (logs.isEmpty) return const SizedBox.shrink();

        final isBatal = trx?.orderStatus == 'Batal';
        final alasanBatal = trx?.alasanBatal ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'History Pesanan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFont.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 16),
              ...logs.asMap().entries.map(
                (e) => _HistoryItem(
                  log: e.value,
                  isLast: e.key == logs.length - 1,
                  isFirst: e.key == 0,
                ),
              ),
              if (isBatal) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.cancel_outlined,
                              size: 16,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Alasan Pembatalan',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: AppFont.w700,
                                color: Colors.red.shade400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          alasanBatal.isNotEmpty
                              ? alasanBatal
                              : 'Tidak ada alasan yang diberikan.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w500,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistoryItem extends StatelessWidget {
  final OrderLog log;
  final bool isLast;
  final bool isFirst;

  const _HistoryItem({
    required this.log,
    required this.isLast,
    required this.isFirst,
  });

  bool get _isPaymentLog => log.isPaymentLog;

  String _iconPathForLog() {
    if (_isPaymentLog) {
      return AppImages.icSelesai;
    }

    final status = log.status;
    switch (status) {
      case 'Nota Dibuat':
      case 'Antrian':
        return AppImages.icAntrian;
      case 'Proses':
        return AppImages.icProses;
      case 'Siap Ambil':
        return AppImages.icSiapAmbil;
      case 'Selesai':
        return AppImages.icSelesai;
      case 'Batal':
        return AppImages.icBatal;
      default:
        return AppImages.icAntrian;
    }
  }

  String _labelForLog() {
    if (_isPaymentLog) {
      final value = (log.newValue ?? '').toLowerCase();
      return value.contains('pelunasan') ? 'Pelunasan' : 'Pembayaran';
    }

    final status = log.status;
    switch (status) {
      case 'Nota Dibuat':
      case 'Antrian':
        return 'Cucian Baru';
      case 'Proses':
        return 'Cucian Dikerjakan';
      case 'Siap Ambil':
        return 'Pesanan Siap Diambil';
      case 'Selesai':
        return 'Pesanan Selesai';
      case 'Batal':
        return 'Pesanan Dibatalkan';
      default:
        return status;
    }
  }

  String _formatRupiahInText(String text) {
    final regex = RegExp(r'Rp\s?(\d+)');
    return text.replaceAllMapped(regex, (match) {
      final numberStr = match.group(1);
      if (numberStr != null) {
        final number = int.tryParse(numberStr);
        if (number != null) {
          return NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(number);
        }
      }
      return match.group(0)!;
    });
  }

  String _detailTextForLog() {
    if (_isPaymentLog) {
      final text = log.newValue?.trim().isNotEmpty == true
          ? log.newValue!.trim()
          : 'Pembayaran berhasil';
      return _formatRupiahInText(text);
    }

    final status = log.status;
    switch (status) {
      case 'Nota Dibuat':
      case 'Antrian':
        return 'Antrian → Proses';
      case 'Proses':
        return 'Proses → Siap Ambil';
      case 'Siap Ambil':
        return 'Siap Ambil → Selesai';
      case 'Selesai':
        return 'Pesanan Sudah Diambil';
      case 'Batal':
        return 'Pesanan Dibatalkan';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                  border: Border.all(color: AppColors.primary, width: 2),
                ),
                child: Center(
                  child: AppAssetImage(_iconPathForLog(), width: 24, height: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelForLog(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFont.w600,
                        color: Colors.grey.shade800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Oleh: ${log.adminName}, ${AppHelpers.formatDate(log.createdAt)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w400,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detailTextForLog(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w600,
                        color: AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 31),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CustomPaint(
                size: const Size(2, 20),
                painter: _DashedLinePainter(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;

  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashHeight = 5.0;
    const dashSpace = 4.0;
    double startY = 0;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
