import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MetodePembayaranTile extends StatelessWidget {
  final String nama;
  final double total;
  final String? logoAsset;
  final Color bgColor;
  final IconData? icon;
  final Color? iconBgColor;
  final bool showDivider;

  const MetodePembayaranTile({
    super.key,
    required this.nama,
    required this.total,
    this.logoAsset,
    this.bgColor = const Color(0xFFF0F0F0),
    this.icon,
    this.iconBgColor,
    this.showDivider = true,
  });

  String _formatRupiah(double value) {
    final formatter = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
          child: Row(
            children: [
              _buildIconWidget(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(fontSize: 13, fontWeight: AppFont.w600, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatRupiah(total),
                    style: const TextStyle(fontSize: 13, fontWeight: AppFont.w700, color: Color(0xFF00A651)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider) Divider(height: 1, color: Colors.grey.shade100, indent: 54),
      ],
    );
  }

  Widget _buildIconWidget() {
    const iconSize = 44.0;
    const imageFitSize = 28.0;

    if (logoAsset != null && logoAsset!.isNotEmpty) {
      return Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Image.asset(
            logoAsset!,
            width: imageFitSize,
            height: imageFitSize,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.payment, size: 20, color: Colors.black54),
              );
            },
          ),
        ),
      );
    }

    if (icon != null) {
      return Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          color: iconBgColor ?? const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon!, size: 22, color: Colors.black54),
      );
    }

    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.payment, size: 20, color: Colors.black54),
    );
  }
}
