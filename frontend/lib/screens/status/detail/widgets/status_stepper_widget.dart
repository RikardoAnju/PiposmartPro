import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/app_asset_image.dart';
import '../constants/app_colors.dart';

class StatusStepperWidget extends StatelessWidget {
  final String currentStatus;
  final String? createdBy;
  final bool skipProses;
  final VoidCallback? onLanjutkan;
  final VoidCallback? onBatalkan;

  const StatusStepperWidget({
    super.key,
    required this.currentStatus,
    this.createdBy,
    this.skipProses = false,
    this.onLanjutkan,
    this.onBatalkan,
  });

  bool get _isBatal => currentStatus == 'Batal';

  bool get _canProcess =>
      !_isBatal && _nextStatusLabels.containsKey(currentStatus);

  List<String> get _statuses => skipProses
      ? const ['Antrian', 'Selesai']
      : const ['Antrian', 'Proses', 'Siap Ambil', 'Selesai'];

  List<String> get _icons => skipProses
      ? const [AppImages.icAntrian, AppImages.icSelesai]
      : const [
          AppImages.icAntrian,
          AppImages.icProses,
          AppImages.icSiapAmbil,
          AppImages.icSelesai,
        ];

  Map<String, String> get _nextStatusLabels => skipProses
      ? const {
          'Antrian': 'Selesai',
        }
      : const {
          'Antrian': 'Proses',
          'Proses': 'Siap Ambil',
          'Siap Ambil': 'Selesai',
        };

  Map<String, String> get _nextStatusIcons => skipProses
      ? const {
          'Antrian': AppImages.icSelesai,
        }
      : const {
          'Antrian': AppImages.icProses,
          'Proses': AppImages.icSiapAmbil,
          'Siap Ambil': AppImages.icSelesai,
        };

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final nextStatus = _nextStatusLabels[currentStatus] ?? '';
    final nextIcon = _nextStatusIcons[currentStatus] ?? AppImages.icProses;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: _ConfirmationDialogContent(
          currentStatus: currentStatus,
          nextStatus: nextStatus,
          nextStatusIcon: nextIcon,
          onConfirm: () => Navigator.of(ctx).pop(true),
          onCancel: () => Navigator.of(ctx).pop(false),
        ),
      ),
    );

    if (confirmed == true && onLanjutkan != null) {
      onLanjutkan!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _statuses.indexOf(currentStatus);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Status Order',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFont.w600,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if ((createdBy ?? '').trim().isNotEmpty)
                Flexible(
                  child: Text(
                    'Dibuat: ${createdBy!.trim()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: Stack(
              children: [
                Positioned(
                  top: 26,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      for (int i = 0; i < _statuses.length - 1; i++) ...[
                        Expanded(
                          flex: 2,
                          child: CustomPaint(
                            size: const Size(double.infinity, 2),
                            painter: _DashedLinePainter(
                              color: i < currentIndex
                                  ? AppColors.primary
                                  : const Color(0xFFDDDDDD),
                            ),
                          ),
                        ),
                        const Expanded(child: SizedBox()),
                      ],
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = 0; i < _statuses.length; i++)
                      Expanded(
                        child: _StepItem(
                          label: _statuses[i],
                          iconPath: _icons[i],
                          index: i,
                          currentIndex: currentIndex,
                          isBatal: _isBatal,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (_canProcess || _isBatal) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProcess && onLanjutkan != null
                    ? () => _showConfirmationDialog(context)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  skipProses ? 'Selesaikan Pesanan' : 'Lanjutkan Proses',
                  style: const TextStyle(fontSize: 14, fontWeight: AppFont.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ConfirmationDialogContent extends StatelessWidget {
  final String currentStatus;
  final String nextStatus;
  final String nextStatusIcon;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmationDialogContent({
    required this.currentStatus,
    required this.nextStatus,
    required this.nextStatusIcon,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AppAssetImage(nextStatusIcon, width: 30, height: 30),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Konfirmasi Update Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: 'Apakah kamu yakin ingin mengubah status dari '),
                TextSpan(
                  text: currentStatus,
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: ' menjadi '),
                TextSpan(
                  text: nextStatus,
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontSize: 14, fontWeight: AppFont.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Ya, Lanjutkan',
                    style: TextStyle(fontSize: 14, fontWeight: AppFont.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final String label;
  final String iconPath;
  final int index;
  final int currentIndex;
  final bool isBatal;

  const _StepItem({
    required this.label,
    required this.iconPath,
    required this.index,
    required this.currentIndex,
    required this.isBatal,
  });

  bool get isDone => index < currentIndex;

  bool get isActive => index == currentIndex;

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = (isDone || isActive) && !isBatal;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHighlighted ? AppColors.primaryLight : Colors.grey.shade100,
            border: Border.all(
              color: isHighlighted ? AppColors.primary : Colors.grey.shade300,
              width: isHighlighted ? 2 : 1.5,
            ),
            boxShadow: isActive && !isBatal
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: ColorFiltered(
              colorFilter: isBatal
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(
                      Colors.transparent,
                      BlendMode.dst,
                    ),
              child: AppAssetImage(iconPath, width: 26, height: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: AppFont.w600,
            color: isHighlighted ? Colors.black87 : Colors.grey,
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

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}
