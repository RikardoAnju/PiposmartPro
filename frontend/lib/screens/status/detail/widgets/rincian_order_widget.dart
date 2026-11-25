import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../shared/widgets/app_asset_image.dart';
import '../constants/app_colors.dart';
import '../constants/app_helpers.dart';
import 'section_card_widget.dart';

class RincianOrderWidget extends StatefulWidget {
  const RincianOrderWidget({super.key});

  @override
  State<RincianOrderWidget> createState() => _RincianOrderWidgetState();
}

class _RincianOrderWidgetState extends State<RincianOrderWidget> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      const targetSize = 40.0;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final cacheSize = (targetSize * dpr).round();
      for (final path in const [
        AppImages.icTanggalMasuk,
        AppImages.icEstimasiSelesai,
        AppImages.icStatusSelesai,
        AppImages.icParfume,
      ]) {
        precacheImage(
          ResizeImage.resizeIfNeeded(
            cacheSize,
            cacheSize,
            AssetImage(path),
          ),
          context,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final trx = provider.currentDetail;
        if (trx == null) return const SizedBox.shrink();

        final estimasi = trx.items
            .map((item) => item.readyAt)
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (latest, dt) =>
                  latest == null || dt.isAfter(latest) ? dt : latest,
            );

        final isBatal = trx.orderStatus == 'Batal';
        final isSelesai = trx.orderStatus.toLowerCase() == 'selesai';
        final hasAlasan = isBatal && (trx.alasanBatal ?? '').isNotEmpty;

        final hasJemput = (trx.jemputAlamat ?? '').isNotEmpty;
        final hasAntar = (trx.antarAlamat ?? '').isNotEmpty;

        return SectionCardWidget(
          title: 'Rincian Orderan',
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
          child: Column(
            children: [
              _DetailRow(
                imagePath: AppImages.icTanggalMasuk,
                label: 'Tgl Masuk',
                value: trx.createdAt != null
                    ? AppHelpers.formatDate(trx.createdAt!)
                    : '-',
              ),
              if (estimasi != null) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icEstimasiSelesai,
                  label: 'Est Selesai',
                  value: AppHelpers.formatDate(estimasi),
                  valueColor: const Color(0xFF333333),
                ),
              ],
              if (isSelesai && trx.completedAt != null) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icStatusSelesai,
                  label: 'Tgl Selesai',
                  value: AppHelpers.formatDate(trx.completedAt!),
                  valueColor: const Color(0xFF16A34A),
                  icon: Icons.check_rounded,
                  iconColor: const Color(0xFF16A34A),
                ),
              ],
              if (trx.parfum != null) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icParfume,
                  label: 'Parfum',
                  value: trx.parfum!.nama,
                  valueColor: AppColors.purple,
                ),
              ],
              if (trx.notes.isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icTanggalMasuk,
                  label: 'Catatan',
                  value: trx.notes,
                  icon: Icons.notes_rounded,
                  iconColor: AppColors.primary,
                ),
              ],

              // ─── Alamat Jemput ────────────────────────────────────────
              if (hasJemput) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icTanggalMasuk,
                  label: 'Alamat Jemput',
                  value: trx.jemputAlamat!,
                  icon: Icons.directions_bike_rounded,
                  iconColor: Colors.teal,
                ),
              ],

              // ─── Alamat Antar ─────────────────────────────────────────
              if (hasAntar) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icTanggalMasuk,
                  label: 'Alamat Antar',
                  value: trx.antarAlamat!,
                  icon: Icons.delivery_dining_rounded,
                  iconColor: Colors.indigo,
                ),
              ],

              // ─── Status Pesanan ───────────────────────────────────────
              const Divider(height: 1, color: AppColors.border),
              _DetailRow(
                imagePath: AppImages.icStatusSelesai,
                label: 'Status Pesanan',
                value: trx.orderStatus,
                valueColor: _getStatusColor(trx.orderStatus),
                icon: Icons.check_rounded,
                iconColor: const Color(0xFF16A34A),
              ),

              // ─── Alasan Batal ─────────────────────────────────────────
              if (hasAlasan) ...[
                const Divider(height: 1, color: AppColors.border),
                _DetailRow(
                  imagePath: AppImages.icTanggalMasuk,
                  label: 'Alasan Batal',
                  value: trx.alasanBatal!,
                  valueColor: Colors.red.shade400,
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.red.shade400,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Selesai':
        return const Color(0xFF53B336);
      case 'Batal':
        return Colors.red;
      case 'Siap Ambil':
        return Colors.blue;
      case 'Proses':
        return Colors.orange;
      case 'Antrian':
        return Colors.amber.shade700;
      default:
        return Colors.black87;
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String imagePath;
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;

  const _DetailRow({
    required this.imagePath,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: 40,
              height: 40,
              child: icon != null
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Icon(
                        icon,
                        size: 22,
                        color: iconColor ?? AppColors.primary,
                      ),
                    )
                  : AppAssetImage(
                      imagePath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      cacheWidth: 120,
                      cacheHeight: 120,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                value,
                textAlign: TextAlign.end,
                softWrap: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w600,
                  color: valueColor ?? Colors.black87,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
