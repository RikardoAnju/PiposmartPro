import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'dart:async';

import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/screens/settings/referral/referral_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/koin_provider.dart';
import '../../../providers/setting_provider.dart';
import '../../../data/models/koin_model.dart';
import 'history_koin_screen.dart';
import 'detail_topup_screen.dart';
import 'topup_history_screen.dart';
import 'topup_koin_screen.dart';
import 'detail_history_koin.dart';
import 'koin_topup_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class KoinManagementScreen extends StatefulWidget {
  const KoinManagementScreen({super.key});

  @override
  State<KoinManagementScreen> createState() => _KoinManagementScreenState();
}

class _KoinManagementScreenState extends State<KoinManagementScreen>
    with WidgetsBindingObserver {
  StreamSubscription? _eventSub;
  bool _hasShownTopupSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = appEventBus.stream.listen((event) async {
      if (!mounted) return;

      if (event is TopupStatusChanged || event is TopupSucceeded) {
        unawaited(_refreshData());
      }

      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (event is TopupSucceeded && !_hasShownTopupSuccess && isCurrentRoute) {
        _hasShownTopupSuccess = true;
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KoinTopupSuccessScreen(
              kind: KoinTopupSuccessKind.completed,
              onPrimary: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refreshData(withLoader: true),
    );
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshData();
  }

  Future<void> _refreshData({bool withLoader = false}) async {
    final koinProv = context.read<KoinProvider>();
    final setProv = context.read<SettingProvider>();
    await koinProv.refreshKoinData(
      showLoader: withLoader,
      syncBalanceCallback: () => setProv.refreshBalanceOnly(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();
    final settingProv = context.watch<SettingProvider>();

    double rawKoin =
        double.tryParse(
          settingProv.formattedKoin.replaceAll('.', '').replaceAll(',', ''),
        ) ??
        0;
    double totalIdr = rawKoin * koinProv.pricePerCoin;

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF8F9FA),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 14,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          "Dompet Koin",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
            child: _buildBalanceCard(
              koin: settingProv.formattedKoin,
              idr: totalIdr,
              rate: koinProv.pricePerCoin,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppPalette.primaryDeep,
              onRefresh: () => _refreshData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildReferralRewardCard(),
                    const SizedBox(height: 24),
                    _buildSectionHeader("Tagihan Aktif", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TopupHistoryScreen(),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    if (koinProv.activeTopups.isEmpty)
                      _buildEmptyState(
                        "Tidak ada tagihan tertunda saat ini.",
                        subtitle: "Semua kewajiban anda sudah terbayar",
                        icon: Icons.receipt_long_rounded,
                      )
                    else
                      ...koinProv.activeTopups
                          .take(3)
                          .map((t) => _buildTopupCard(t)),
                    const SizedBox(height: 32),
                    _buildSectionHeader("Mutasi Terakhir", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HistoryKoinScreen(),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    const Text(
                      "Menampilkan 5 aktivitas terbaru",
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
                    const SizedBox(height: 16),
                    if (koinProv.history.isEmpty)
                      _buildEmptyState("Belum ada mutasi koin")
                    else
                      Column(
                        children: koinProv.history
                            .take(5)
                            .map((h) => _buildMutationRow(h))
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildBalanceCard({
    required String koin,
    required double idr,
    required double rate,
  }) {
    return Container(
      width: double.infinity,
      height: 190,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B3D), AppPalette.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primaryDeep.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Pattern Accents
          Positioned(
            top: -40,
            right: -20,
            child: CircleAvatar(
              radius: 100,
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            bottom: -30,
            right: -20,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 160,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "TOTAL SALDO",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/ic_koin.webp',
                            width: 14,
                            height: 14,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "1 Koin = Rp ${NumberFormat.decimalPattern('id_ID').format(rate.toInt())}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      koin,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        height: 1,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        "KOIN",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: '≈ Rp ',
                    decimalDigits: 0,
                  ).format(idr),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "AyoCuci Secure Ecosystem",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onTap) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 15, color: Colors.black)),
        InkWell(
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Text(
              "Lihat Semua",
              style: TextStyle(fontSize: 12, color: AppPalette.primaryDeep),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopupCard(dynamic topup) {
    final status = topup['tk_status'].toString().toLowerCase();
    Color statusColor;
    if (status == 'success') {
      statusColor = const Color(0xFF087F5B);
    } else if (status == 'pending' || status == 'challenge') {
      statusColor = const Color(0xFFE67E22);
    } else {
      statusColor = const Color(0xFFC92A2A);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFF1F3F5), width: 1.5),
        ),
        child: ListTile(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DetailTopupScreen(topup: topup)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Text(
            "Top Up ${topup['tk_jumlah']} Koin",
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            _formatTopupStatusLabel(status),
            style: TextStyle(
              color: statusColor,
              fontSize: 9,
              letterSpacing: 0.5,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  String _formatTopupStatusLabel(String status) {
    switch (status) {
      case 'success':
        return 'SUKSES';
      case 'pending':
        return 'MENUNGGU PEMBAYARAN';
      case 'challenge':
        return 'MENUNGGU KONFIRMASI';
      case 'cancel':
        return 'DIBATALKAN';
      case 'expire':
        return 'KEDALUWARSA';
      case 'deny':
      case 'failed':
        return 'DITOLAK';
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildMutationRow(HistoryKoinModel item) {
    bool isMasuk = item.jenis == 'masuk';
    String title = item.keterangan;

    // Mapping Title Sesuai Desain
    if (title.toLowerCase().contains("laundry") ||
        title.toLowerCase().contains("trx/") ||
        title.toLowerCase().contains("pemakaian koin")) {
      title = "Transaksi Laundry";
    } else if (title.toLowerCase().contains("referral")) {
      title = "Bonus Referral";
    } else if (title.toLowerCase().contains("outlet baru")) {
      title = "Bonus Outlet";
    } else if (title.toLowerCase().contains("top up") ||
        title.toLowerCase().contains("topup")) {
      title = "Top Up";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.5),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailHistoryKoinScreen(item: item),
          ),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMasuk ? const Color(0xFFE6FCF5) : const Color(0xFFFFF5F5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isMasuk
                ? Icons.add_circle_outline_rounded
                : Icons.local_laundry_service_rounded,
            color: isMasuk ? const Color(0xFF087F5B) : const Color(0xFFC92A2A),
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, color: Color(0xFF2D3436)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              item.id,
              style: const TextStyle(fontSize: 11, color: Color(0xFF636E72)),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('dd MMMM yyyy, HH:mm', 'id_ID').format(item.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "${isMasuk ? '+' : '-'}${item.jumlah} Koin",
              style: TextStyle(
                fontSize: 14,
                color: isMasuk
                    ? const Color(0xFF087F5B)
                    : const Color(0xFFC92A2A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "Sukses",
              style: TextStyle(
                fontSize: 10,
                color: isMasuk
                    ? const Color(0xFF087F5B)
                    : const Color(0xFFC92A2A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, {String? subtitle, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: AppPalette.primaryDeep.withValues(alpha: 0.6),
                size: 32,
              ),
            ),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF636E72), fontSize: 13),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFab() {
    return Container(
      width: double.infinity,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TopupKoinScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primaryDeep,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          "Top Up Koin Sekarang",
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildReferralRewardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppPalette.primaryDeep,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Program Referral',
                      style: TextStyle(color: Colors.black, fontSize: 15),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Dapatkan reward dari Top Up temanmu',
                      style: TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReferralPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                  color: AppPalette.primaryDeep,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Lihat Saldo Referral',
                style: TextStyle(color: AppPalette.primaryDeep, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
