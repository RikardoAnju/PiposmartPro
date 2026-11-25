import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'app_asset_image.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String imagePath;
  final double imageWidth;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ButtonStyle? actionButtonStyle;

  const EmptyStateWidget({
    super.key,
    this.title = "Tidak Ada Data",
    this.message = "Saat ini belum ada data yang dapat ditampilkan",
    this.imagePath = 'assets/no-data/no_data_status.webp',
    this.imageWidth = 250,
    this.actionLabel,
    this.onAction,
    this.actionButtonStyle,
  });

  const EmptyStateWidget.status({
    super.key,
    this.title = "Tidak Ada Pesanan",
    this.message = "Belum ada pesanan",
    this.imagePath = 'assets/no-data/no_data_status.webp',
    this.imageWidth = 250,
    this.actionLabel,
    this.onAction,
    this.actionButtonStyle,
  });

  const EmptyStateWidget.laporan({
    super.key,
    this.title = "Tidak Ada Laporan",
    this.message = "Belum ada data laporan",
    this.imagePath = 'assets/no-data/no data menu laporan.webp',
    this.imageWidth = 250,
    this.actionLabel,
    this.onAction,
    this.actionButtonStyle,
  });

  const EmptyStateWidget.pelanggan({
    super.key,
    this.title = "Tidak Ada Pelanggan",
    this.message = "Belum ada data pelanggan",
    this.imagePath = 'assets/no-data/no data menu pelanggan.webp',
    this.imageWidth = 250,
    this.actionLabel,
    this.onAction,
    this.actionButtonStyle,
  });

  const EmptyStateWidget.pengeluaran({
    super.key,
    this.title = "Tidak Ada Pengeluaran",
    this.message = "Belum ada data pengeluaran",
    this.imagePath = 'assets/no-data/no data menu pengeluaran.webp',
    this.imageWidth = 250,
    this.actionLabel,
    this.onAction,
    this.actionButtonStyle,
  });

  const EmptyStateWidget.ringkasan({
    super.key,
    this.title = "Tidak Ada Data",
    this.message = "Belum ada data ringkasan",
    this.imagePath = 'assets/no-data/no data ringkasan.webp',
    this.imageWidth = 250,
    this.actionLabel,
    this.onAction,
    this.actionButtonStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: Center(
                child: SizedBox(
                  width: imageWidth,
                  child: AppAssetImage(
                    imagePath,
                    width: imageWidth,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: AppFont.w700,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: actionButtonStyle,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
