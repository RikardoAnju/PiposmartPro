import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../data/models/addon_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'widgets/detail_addon_trx_screen.dart';

class ListTransaksiAktifScreen extends StatelessWidget {
  const ListTransaksiAktifScreen({super.key});

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
    final items = addonProv.pendingOrders;

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
          "Transaksi Aktif",
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
                  _buildTrxCard(context, items[index]),
            ),
    );
  }

  Widget _buildTrxCard(BuildContext context, TransaksiAddon trx) {
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
                  color: AppPalette.primaryWarm.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  "MENUNGGU",
                  style: TextStyle(
                    color: AppPalette.primaryWarm,
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
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        DetailAddonTrxScreen(transaction: trx),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "LIHAT DETAIL",
                style: TextStyle(fontSize: 12, fontWeight: AppFont.w900),
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
            Icons.receipt_long_outlined,
            size: 80,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            "Tidak ada transaksi aktif",
            style: TextStyle(fontWeight: AppFont.w700, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
