import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../data/models/addon_model.dart';

class ListRiwayatTransaksiScreen extends StatelessWidget {
  const ListRiwayatTransaksiScreen({super.key});

  String _formatRupiah(num value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  // Add-on bayar KOIN menyimpan total sebagai jumlah koin (bukan rupiah).
  String _formatAmount(TransaksiAddon trx) {
    if (trx.metodeBayar.trim().toUpperCase() == 'KOIN') {
      return '${NumberFormat.decimalPattern('id').format(trx.total)} Koin';
    }
    return _formatRupiah(trx.total);
  }

  @override
  Widget build(BuildContext context) {
    final addonProv = context.watch<AddonProvider>();
    final items = addonProv.fullHistory;

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFF2C3E50),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Riwayat Transaksi",
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: items.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) =>
                  _buildHistoryCard(context, items[index]),
            ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, TransaksiAddon trx) {
    bool isSuccess = trx.status.toUpperCase() == 'SUCCESS';
    Color statusColor = isSuccess ? const Color(0xFF27AE60) : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isSuccess ? "BERHASIL" : trx.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: AppFont.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM yyyy, HH:mm').format(trx.createdAt),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trx.id,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w700,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      trx.itemNames ?? "Aktivasi Layanan",
                      style: const TextStyle(
                        fontWeight: AppFont.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _formatAmount(trx),
                style: const TextStyle(
                  fontWeight: AppFont.w900,
                  fontSize: 14,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: OutlinedButton(
              onPressed: () {
                // Logic lihat detail transaksi
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFEEEEEE)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "LIHAT DETAIL",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFont.w900,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            "Belum ada riwayat transaksi",
            style: TextStyle(fontWeight: AppFont.w700, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
