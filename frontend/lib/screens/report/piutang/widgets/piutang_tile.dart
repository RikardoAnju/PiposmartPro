import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PiutangTile extends StatelessWidget {
  final PiutangReport item;

  const PiutangTile({super.key, required this.item});

  static const Color kPrimary = AppPalette.primary;

  String _formatDate(String raw) {
    try {
      final parsed = parseReportDate(raw);
      if (parsed == null) return raw;
      return DateFormat('EEEE, dd-MM-yy', 'id_ID').format(parsed);
    } catch (_) {
      return raw;
    }
  }

  void _navigateToDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPesananScreen(transactionId: item.nomorNota),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToDetail(context),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.namaPelanggan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: AppFont.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.isJatuhTempo
                            ? const Color(0xFFFFF1F1)
                            : AppPalette.primaryPale,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: item.isJatuhTempo
                              ? const Color(0xFFFFD8D8)
                              : const Color(0xFFFFE1C7),
                        ),
                      ),
                      child: Text(
                        item.isJatuhTempo ? 'Jatuh Tempo' : 'Belum Jatuh Tempo',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: AppFont.w900,
                          letterSpacing: 0.5,
                          color: item.isJatuhTempo
                              ? AppPalette.primary
                              : const Color(0xFFF59E0B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInlineInfo(
                            Icons.schedule_rounded,
                            'Masuk : ${_formatDate(item.tanggalMasuk)}',
                          ),
                          const SizedBox(height: 6),
                          _buildInlineInfo(
                            Icons.event_available_rounded,
                            'Est Selesai : ${_formatDate(item.tanggalEstimasi)}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFmt.format(item.sisaPiutang),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.w900,
                            color: kPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Sisa Piutang',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: AppFont.w700,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F1F1)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.nomorNota,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: AppFont.w600,
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Total Nota ${currencyFmt.format(item.totalHarga)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w800,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 10, color: Colors.black26),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: AppFont.w700,
              color: Colors.black38,
            ),
          ),
        ),
      ],
    );
  }
}
