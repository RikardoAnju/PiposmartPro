import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'dart:async';

import 'package:ayocucinew/core/events/app_events.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/koin_provider.dart';
import 'detail_topup_screen.dart';
import 'koin_topup_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TopupHistoryScreen extends StatefulWidget {
  const TopupHistoryScreen({super.key});

  @override
  State<TopupHistoryScreen> createState() => _TopupHistoryScreenState();
}

class _TopupHistoryScreenState extends State<TopupHistoryScreen> {
  StreamSubscription? _eventSub;
  bool _hasShownTopupSuccess = false;

  @override
  void initState() {
    super.initState();
    _eventSub = appEventBus.stream.listen((event) async {
      if (!mounted) return;

      if (event is TopupStatusChanged || event is TopupSucceeded) {
        unawaited(context.read<KoinProvider>().fetchAllTopupRequests());
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
    // Tarik data semua tagihan pas pertama buka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KoinProvider>().fetchAllTopupRequests();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "RIWAYAT TAGIHAN",
          style: TextStyle(color: Colors.black, fontSize: 14, letterSpacing: 1),
        ),
        centerTitle: true,
      ),
      body: koinProv.isLoading
          ? const BankListSkeleton()
          : koinProv.allTopups.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              color: AppPalette.primaryDeep,
              onRefresh: () => koinProv.fetchAllTopupRequests(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                itemCount: koinProv.allTopups.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = koinProv.allTopups[index];
                  return _buildTopupCard(item);
                },
              ),
            ),
    );
  }

  Widget _buildTopupCard(Map<String, dynamic> item) {
    final status = item['tk_status'].toString().toLowerCase();
    final metode = item['tk_metode_bayar'].toString().toLowerCase();
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    Color statusColor;
    IconData statusIcon;
    // --- LOGIC COLOR & ICON ---
    if (status == 'success') {
      statusColor = const Color(0xFF087F5B);
      statusIcon = Icons.check_circle_rounded;
    } else if (status == 'failed' ||
        status == 'expire' ||
        status == 'cancel' ||
        status == 'deny') {
      statusColor = const Color(0xFFC92A2A);
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFE67E22);
      statusIcon = Icons.pending_rounded;
    }

    return GestureDetector(
      onTap: () {
        // 🚀 MASUK KE DETAIL UNTUK ACTION LANJUTAN (PAY/RETRY)
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailTopupScreen(topup: item)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F3F5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status Icon Container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),

            // Info Center
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Top Up ${item['tk_jumlah']} Koin",
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      'dd MMM yyyy, HH:mm',
                    ).format(DateTime.parse(item['tk_created']).toLocal()),
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Info Right (Amount & Method)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currencyFormat.format(item['tk_total']),
                  style: TextStyle(
                    fontSize: 13,
                    color: status == 'success' ? Colors.black : statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatMethodLabel(metode),
                    style: const TextStyle(color: Colors.blueGrey, fontSize: 8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _formatStatusLabel(status),
                    style: TextStyle(color: statusColor, fontSize: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatMethodLabel(String method) {
    switch (method) {
      case 'midtrans':
        return 'MIDTRANS';
      case 'transfer':
        return 'TRANSFER';
      default:
        return method.toUpperCase();
    }
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'success':
        return 'SUKSES';
      case 'pending':
        return 'MENUNGGU';
      case 'challenge':
        return 'KONFIRMASI';
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            "Belum ada riwayat tagihan",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            "Semua pengajuan top up koin kamu akan muncul di sini.",
            style: TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
