import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:ayocucinew/data/models/transaction_model.dart';
import 'package:ayocucinew/providers/work_log_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

Widget _dateLine(IconData icon, String label, String value) => Row(
  children: [
    Icon(icon, size: 13, color: AppPalette.muted),
    const SizedBox(width: 5),
    Flexible(
      child: Text(
        '$label : $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppPalette.muted,
          fontSize: 11,
          fontWeight: AppFont.w600,
        ),
      ),
    ),
  ],
);

class WorkLogStageDetail extends StatefulWidget {
  const WorkLogStageDetail({super.key, required this.workLog});

  final WorkLogProvider workLog;

  @override
  State<WorkLogStageDetail> createState() => _WorkLogStageDetailState();
}

class _WorkLogStageDetailState extends State<WorkLogStageDetail> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.workLog.searchQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ({String title, Color color, String asset}) get _stage =>
      switch (widget.workLog.selectedStage!) {
        WorkLogStage.newOrder => (
          title: 'Cucian Baru',
          color: AppPalette.primary,
          asset: AppImages.icAntrian,
        ),
        WorkLogStage.processing => (
          title: 'Cucian Dikerjakan',
          color: AppPalette.info,
          asset: AppImages.icProses,
        ),
        WorkLogStage.ready => (
          title: 'Pesanan Siap Ambil',
          color: AppPalette.warning,
          asset: AppImages.icSiapAmbil,
        ),
        WorkLogStage.completed => (
          title: 'Menyelesaikan Pesanan',
          color: AppPalette.success,
          asset: AppImages.icSelesai,
        ),
        WorkLogStage.cancelled => (
          title: 'Membatalkan Pesanan',
          color: AppPalette.danger,
          asset: AppImages.icBatal,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final workLog = widget.workLog;
    final stage = _stage;
    final items = workLog.stageTransactions;
    final serviceCount = items
        .expand((item) => item.items)
        .map((item) => item.serviceName)
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .length;
    final total = items.fold<double>(0, (sum, item) => sum + item.totalPrice);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        // ================= HERO / SUMMARY CARD =================
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: AppBorders.card,
            boxShadow: AppShadows.cardSoft,
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Stage icon, title, badge, collapse button
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: stage.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: stage.color.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      stage.asset,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      gaplessPlayback: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stage.title,
                          style: const TextStyle(
                            color: AppPalette.ink,
                            fontSize: 17,
                            fontWeight: AppFont.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: stage.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${items.length} aktivitas transaksi',
                              style: const TextStyle(
                                color: AppPalette.muted,
                                fontSize: 11,
                                fontWeight: AppFont.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Featured Hero Card: TOTAL NOMINAL
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      stage.color.withValues(alpha: 0.09),
                      stage.color.withValues(alpha: 0.02),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: stage.color.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: stage.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        color: stage.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TOTAL NOMINAL',
                            style: TextStyle(
                              color: AppPalette.muted,
                              fontSize: 10,
                              fontWeight: AppFont.w800,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            NumberFormat.currency(
                              locale: 'id_ID',
                              symbol: 'Rp',
                              decimalDigits: 0,
                            ).format(total),
                            style: const TextStyle(
                              color: AppPalette.ink,
                              fontSize: 20,
                              fontWeight: AppFont.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: stage.color.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: stage.color.withValues(alpha: 0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '${items.length} Trx',
                        style: TextStyle(
                          color: stage.color,
                          fontSize: 11,
                          fontWeight: AppFont.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // 2-Column Bento Stat Cards: AKTIVITAS & LAYANAN
              Row(
                children: [
                  Expanded(
                    child: _ModernStatTile(
                      icon: Icons.bar_chart_rounded,
                      iconColor: AppPalette.info,
                      label: 'AKTIVITAS',
                      value: '${items.length}',
                      unit: 'pesanan',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ModernStatTile(
                      icon: Icons.inventory_2_rounded,
                      iconColor: AppPalette.warning,
                      label: 'LAYANAN',
                      value: '$serviceCount',
                      unit: 'layanan',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // TOTAL KUANTITAS Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFEDEFF3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.scale_rounded,
                        color: AppPalette.primary,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'TOTAL KUANTITAS',
                        style: TextStyle(
                          color: AppPalette.muted,
                          fontSize: 10,
                          fontWeight: AppFont.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    Flexible(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _ModernQuantityBadges(
                          quantities: workLog.stageQuantities,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ================= SEARCH BAR =================
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEFF3), width: 1.2),
            boxShadow: AppShadows.cardSoft,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {});
              workLog.setSearchQuery(value);
            },
            decoration: InputDecoration(
              hintText: 'Cari pelanggan atau nomor...',
              hintStyle: const TextStyle(color: AppPalette.muted, fontSize: 13),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppPalette.muted,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        workLog.setSearchQuery('');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),

        // ================= LIST OF TRANSACTIONS =================
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: EmptyStateWidget(
              title: workLog.searchQuery.isNotEmpty
                  ? 'Tidak ditemukan'
                  : 'Tidak ada aktivitas',
              message: workLog.searchQuery.isNotEmpty
                  ? 'Tidak ada pesanan yang cocok dengan "${workLog.searchQuery}".'
                  : 'Belum ada aktivitas pada periode yang dipilih.',
              imageWidth: 140,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Row(
              children: [
                const Text(
                  'DAFTAR PESANAN',
                  style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    letterSpacing: 0.8,
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      color: AppPalette.primary,
                      fontSize: 10,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...items.map((item) => _TransactionCard(item: item)),
        ],
      ],
    );
  }
}

class _ModernStatTile extends StatelessWidget {
  const _ModernStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: iconColor, size: 13),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 10,
                  fontWeight: AppFont.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 20,
                  fontWeight: AppFont.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  fontWeight: AppFont.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModernQuantityBadges extends StatelessWidget {
  const _ModernQuantityBadges({required this.quantities});

  final Map<String, double> quantities;

  @override
  Widget build(BuildContext context) {
    final values = quantities.entries.toList();
    if (values.isEmpty) {
      return const Text(
        '-',
        style: TextStyle(
          color: AppPalette.ink,
          fontSize: 14,
          fontWeight: AppFont.w800,
        ),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      runAlignment: WrapAlignment.end,
      children: values.map((entry) {
        final formattedQty = entry.value.toStringAsFixed(
          entry.value % 1 == 0 ? 0 : 1,
        );
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 13,
                fontWeight: AppFont.w800,
              ),
              children: [
                TextSpan(text: formattedQty),
                TextSpan(
                  text: ' ${entry.key}',
                  style: const TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.item});

  final TransactionModel item;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt;
    final created = date == null
        ? '-'
        : DateFormat('EEEE, dd-MM-yy', 'id_ID').format(date);
    final estimatedDates = item.items
        .map((cartItem) => cartItem.readyAt)
        .whereType<DateTime>()
        .toList();
    final estimatedAt = estimatedDates.isNotEmpty
        ? estimatedDates.reduce((a, b) => a.isAfter(b) ? a : b)
        : item.completedAt;
    final estimate = estimatedAt == null
        ? '-'
        : DateFormat('EEEE, dd-MM-yy', 'id_ID').format(estimatedAt);

    final isPaid = item.paymentStatus.toLowerCase() == 'lunas';
    final customerName = item.customer?.name ?? 'Tanpa Nama';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final id = item.id;
          if (id == null || id.trim().isEmpty) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailPesananScreen(
                transactionId: id,
                readOnly: context.read<AuthProvider>().actorType != 'pegawai',
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: AppBorders.card,
            boxShadow: AppShadows.cardSoft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ringkas: nama pelanggan dan status pembayaran.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 15,
                        fontWeight: AppFont.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _Chip(
                    label: item.paymentStatus,
                    color: isPaid ? AppPalette.success : AppPalette.warning,
                    bgColor: isPaid
                        ? const Color(0xFFE7F7EC)
                        : const Color(0xFFFFF3E6),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _dateLine(Icons.schedule_rounded, 'Masuk', created),
                        const SizedBox(height: 3),
                        _dateLine(
                          Icons.event_available_outlined,
                          'Selesai',
                          estimate,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp',
                      decimalDigits: 0,
                    ).format(item.totalPrice),
                    style: const TextStyle(
                      color: AppPalette.primary,
                      fontSize: 16,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ],
              ),

              // Items breakdown preview if available
              if (item.items.isNotEmpty) ...[
                const SizedBox(height: 10),
                Column(
                  children: item.items.map((cartItem) {
                    final qtyStr = cartItem.qty % 1 == 0
                        ? cartItem.qty.toInt().toString()
                        : cartItem.qty.toString();
                    final unit = cartItem.unit.isEmpty ? 'pcs' : cartItem.unit;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cartItem.serviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppPalette.ink,
                                fontSize: 11,
                                fontWeight: AppFont.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$qtyStr $unit',
                            style: const TextStyle(
                              color: AppPalette.muted,
                              fontSize: 10,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 9),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),

              // Footer row: Invoice & action.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.invoiceNumber ?? '-',
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11,
                        fontWeight: AppFont.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Lihat Detail',
                        style: TextStyle(
                          color: AppPalette.primary,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppPalette.primary,
                        size: 16,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  final String label;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: AppFont.w700,
        letterSpacing: 0.4,
      ),
    ),
  );
}
