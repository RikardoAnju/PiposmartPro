import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../data/models/addon_model.dart';
import 'list_transaksi_aktif_screen.dart';
import 'list_riwayat_transaksi_screen.dart';
import 'widgets/detail_addon_trx_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PembelianSayaScreen extends StatefulWidget {
  const PembelianSayaScreen({super.key});

  @override
  State<PembelianSayaScreen> createState() => _PembelianSayaScreenState();
}

class _PembelianSayaScreenState extends State<PembelianSayaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddonProvider>().refreshData();
    });
  }

  String _formatRupiah(num value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  // Add-on yang dibayar KOIN menyimpan total sebagai JUMLAH KOIN (bukan
  // rupiah), jadi jangan diberi prefix "Rp" — tampilkan "N Koin".
  String _formatAmount(TransaksiAddon trx) {
    if (trx.metodeBayar.trim().toUpperCase() == 'KOIN') {
      final koin = NumberFormat.decimalPattern('id').format(trx.total);
      return '$koin Koin';
    }
    return _formatRupiah(trx.total);
  }

  @override
  Widget build(BuildContext context) {
    final addonProv = context.watch<AddonProvider>();
    const Color primaryColor = AppPalette.primary;
    const Color darkColor = Color(0xFF2C3E50);

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
            color: darkColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pembelian Saya',
          style: TextStyle(
            color: darkColor,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => addonProv.refreshData(),
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderInfo(primaryColor),
              const SizedBox(height: 24),

              // --- SECTION 1: TRANSAKSI AKTIF (PENDING & PENDING_VALIDATION) ---
              _buildSectionHeader(
                title: 'Transaksi Aktif',
                onSeeAll: addonProv.pendingOrders.length > 2
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListTransaksiAktifScreen(),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              if (addonProv.pendingOrders.isEmpty)
                _buildMiniEmptyState("Tidak ada tagihan aktif")
              else
                ...addonProv.pendingOrders
                    .take(2)
                    .map((trx) => _buildTrxCard(context, trx)),

              const SizedBox(height: 24),

              // --- SECTION 2: RIWAYAT (SUCCESS, FAILED, CANCELED) ---
              _buildSectionHeader(
                title: 'Riwayat Transaksi',
                onSeeAll: addonProv.fullHistory.length > 5
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListRiwayatTransaksiScreen(),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              if (addonProv.fullHistory.isEmpty)
                _buildMiniEmptyState("Belum ada riwayat")
              else
                ...addonProv.fullHistory
                    .take(5)
                    .map((trx) => _buildTrxCard(context, trx)),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_rounded, color: primaryColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Transaksi Anda",
                  style: TextStyle(fontWeight: AppFont.w900, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  "Kelola tagihan fitur dan pantau status aktivasi layanan PRO Anda.",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w900,
            color: Color(0xFF2C3E50),
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: const Row(
              children: [
                Text(
                  "Lihat Semua",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: AppFont.w800,
                    color: AppPalette.primary,
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppPalette.primary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTrxCard(BuildContext context, TransaksiAddon trx) {
    final String rawStatus = trx.status.toUpperCase();
    bool isValidation = rawStatus == 'PENDING_VALIDATION';
    bool isPending = rawStatus == 'PENDING';

    // UI Feedback berdasarkan status
    Color statusColor;
    if (isPending) {
      statusColor = AppPalette.primaryWarm; // Orange
    } else if (isValidation) {
      statusColor = Colors.blue; // Biru (Proses Cek Struk)
    } else if (rawStatus == 'SUCCESS') {
      statusColor = const Color(0xFF27AE60); // Hijau
    } else {
      statusColor = Colors.red; // Merah
    }

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
                  rawStatus.replaceAll('_', ' '),
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
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                  fontWeight: AppFont.w500,
                ),
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
                        color: Color(0xFF2C3E50),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
            height: 40,
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
                backgroundColor: const Color(0xFFF8F9FA),
                foregroundColor: const Color(0xFF2C3E50),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: const Color(0xFFEEEEEE)),
                ),
              ),
              child: Text(
                "LIHAT DETAIL",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: AppFont.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEmptyState(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: AppFont.w600,
          ),
        ),
      ),
    );
  }
}
