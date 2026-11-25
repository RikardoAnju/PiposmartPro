import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/screens/settings/referral/hadiah/widgets/reward_activity_item.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RewardHistoryScreen extends StatefulWidget {
  final String? initialPayoutId;

  const RewardHistoryScreen({super.key, this.initialPayoutId});

  @override
  State<RewardHistoryScreen> createState() => _RewardHistoryScreenState();
}

class _RewardHistoryScreenState extends State<RewardHistoryScreen> {
  static const Color kPrimary = AppPalette.primary;

  late int _activeTab;
  final Set<String> _collapsedMonths = {};

  final _rupiahFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialPayoutId == null ? 0 : 2;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  Future<void> _refreshData() async {
    final token = context.read<AuthProvider>().token;
    await context.read<ReferralProvider>().fetchSummary(token: token);
  }

  String _fmtRp(int amount) => _rupiahFmt.format(amount);

  DateTime _parseDate(String raw) {
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  String _fmtDate(String raw) {
    final dt = _parseDate(raw);
    if (dt.millisecondsSinceEpoch == 0) return raw;
    return DateFormat('d MMM yyyy', 'id_ID').format(dt);
  }

  String _fmtDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw == 'null') return '-';
    final dt = _parseDate(raw);
    if (dt.millisecondsSinceEpoch == 0) return raw;
    return DateFormat('d MMM yyyy HH:mm', 'id_ID').format(dt);
  }

  String _monthKey(DateTime date) {
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  }

  String _rewardStatusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'credited':
      case 'available':
        return 'Tersedia';
      case 'pending':
        return 'Menunggu';
      case 'paid':
        return 'Dicairkan';
      case 'converted':
        return 'Ditukar';
      case 'cancelled':
      case 'canceled':
        return 'Dibatalkan';
      default:
        return status.isEmpty ? 'Tersedia' : status;
    }
  }

  Color _rewardStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'credited':
      case 'available':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFEA580C);
      case 'paid':
        return const Color(0xFF2563EB);
      case 'converted':
        return const Color(0xFF9333EA);
      case 'cancelled':
      case 'canceled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _payoutStatusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'approved':
      case 'to_approved':
        return 'DISETUJUI';
      case 'process':
      case 'to_process':
        return 'DIPROSES';
      case 'done':
      case 'success':
      case 'paid':
      case 'completed':
        return 'SELESAI';
      case 'pending':
        return 'MENUNGGU';
      case 'rejected':
      case 'failed':
      case 'cancelled':
      case 'cancel':
        return 'DITOLAK';
      default:
        return status.toUpperCase();
    }
  }

  Color _payoutStatusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'done':
      case 'success':
      case 'paid':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFEA580C);
      case 'rejected':
      case 'failed':
      case 'cancelled':
      case 'cancel':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF1E293B);
    }
  }

  List<ReferralRewardModel> _rewards(dynamic summary) {
    final rewards = (summary?.recentRewards ?? []) as List<ReferralRewardModel>;
    rewards.sort(
      (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
    );
    return rewards;
  }

  List<ReferralWalletHistoryModel> _coinConversions(dynamic summary) {
    final transactions =
        (summary?.recentTransactions ?? []) as List<ReferralWalletHistoryModel>;
    final items = transactions
        .where((t) => t.type.toLowerCase().trim() == 'convert_to_koin')
        .toList();
    items.sort(
      (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
    );
    return items;
  }

  List<ReferralPayoutModel> _payouts(dynamic summary) {
    final payouts =
        (summary?.payoutRequests ?? []) as List<ReferralPayoutModel>;
    final payoutById = <String, ReferralPayoutModel>{};
    for (final p in payouts) {
      payoutById[p.id] = p;
    }
    final items = payoutById.values.toList();
    items.sort(
      (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)),
    );
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final summary = provider.summary;
    final isLoading =
        provider.status == ReferralStatus.loading && summary == null;

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
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
          'Riwayat Hadiah',
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: isLoading
                ? const ManagementListSkeleton(showSearch: false, itemCount: 6)
                : RefreshIndicator(
                    color: kPrimary,
                    onRefresh: _refreshData,
                    child: switch (_activeTab) {
                      0 => _buildRewardList(summary),
                      1 => _buildCoinConversionList(summary),
                      _ => _buildPayoutList(summary),
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildTabItem(0, 'Masuk'),
            _buildTabItem(1, 'Tukar Koin'),
            _buildTabItem(2, 'Pencairan'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isActive = _activeTab == index;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? AppFont.w800 : AppFont.w600,
              color: isActive ? kPrimary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardList(dynamic summary) {
    final rewards = _rewards(summary);
    if (rewards.isEmpty) {
      return _buildEmptyState(
        icon: Icons.trending_up_rounded,
        title: 'Belum ada saldo masuk',
        message:
            'Komisi referral akan tercatat di sini setelah owner yang kamu ajak melakukan top up koin.',
      );
    }

    return _buildGroupedList<ReferralRewardModel>(
      rewards,
      dateOf: (item) => _parseDate(item.createdAt),
      itemBuilder: _buildRewardRow,
    );
  }

  Widget _buildCoinConversionList(dynamic summary) {
    final items = _coinConversions(summary);
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.currency_exchange_rounded,
        title: 'Belum ada penukaran koin',
        message:
            'Saat saldo referral ditukar menjadi koin laundry, riwayatnya akan muncul di tab ini.',
      );
    }

    return _buildGroupedList<ReferralWalletHistoryModel>(
      items,
      dateOf: (item) => _parseDate(item.createdAt),
      itemBuilder: _buildCoinConversionRow,
    );
  }

  Widget _buildPayoutList(dynamic summary) {
    final items = _payouts(summary);
    if (items.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_rounded,
        title: 'Belum ada pencairan',
        message:
            'Pengajuan pencairan saldo referral ke rekening akan ditampilkan lengkap dengan status prosesnya.',
      );
    }

    return _buildGroupedList<ReferralPayoutModel>(
      items,
      dateOf: (item) => _parseDate(item.createdAt),
      itemBuilder: _buildPayoutRow,
    );
  }

  Widget _buildGroupedList<T>(
    List<T> data, {
    required DateTime Function(T item) dateOf,
    required Widget Function(T item) itemBuilder,
  }) {
    final grouped = <String, List<T>>{};
    for (final item in data) {
      final key = _monthKey(dateOf(item));
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 120),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final monthKey = grouped.keys.elementAt(index);
        final items = grouped[monthKey]!;
        final isCollapsed = _collapsedMonths.contains(monthKey);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedMonths.remove(monthKey);
                  } else {
                    _collapsedMonths.add(monthKey);
                  }
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      isCollapsed
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      monthKey,
                      style: const TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 13,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${items.length} data',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: AppFont.w700,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(children: items.map(itemBuilder).toList()),
              crossFadeState: isCollapsed
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
            const Divider(height: 1, color: Color(0xFFF1F3F5)),
          ],
        );
      },
    );
  }

  Widget _buildRewardRow(ReferralRewardModel reward) {
    final statusColor = _rewardStatusColor(reward.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: kPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.ownerName.isNotEmpty
                          ? reward.ownerName
                          : 'Komisi Top Up Koin',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w800,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reward.outletName.isNotEmpty
                          ? 'Outlet: ${reward.outletName}'
                          : 'Outlet belum tersedia',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8F98),
                        fontWeight: AppFont.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${_fmtRp(reward.rewardAmount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w900,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtDate(reward.createdAt),
                    style: const TextStyle(fontSize: 10, color: Colors.black38),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (reward.percent > 0) ...[
                _InfoChip(
                  label: '${reward.percent}% komisi',
                  icon: Icons.percent_rounded,
                  color: const Color(0xFF2563EB),
                  background: const Color(0xFFEFF6FF),
                ),
                const SizedBox(width: 8),
              ],
              _InfoChip(
                label: _rewardStatusLabel(reward.status),
                icon: Icons.check_circle_outline_rounded,
                color: statusColor,
                background: statusColor.withValues(alpha: 0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoinConversionRow(ReferralWalletHistoryModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RewardActivityItem.riwayat(
        type: 'convert_to_koin',
        title: 'Tukar Saldo ke Koin',
        subtitle: item.description.isNotEmpty
            ? '${item.description} - ${_fmtDate(item.createdAt)}'
            : _fmtDate(item.createdAt),
        amount: _fmtRp(item.amount),
        status: 'Berhasil',
        statusColor: const Color(0xFF9333EA),
      ),
    );
  }

  Widget _buildPayoutRow(ReferralPayoutModel item) {
    final statusColor = _payoutStatusColor(item.status);
    final isTarget = widget.initialPayoutId == item.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTarget ? AppPalette.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isTarget ? kPrimary : const Color(0xFFF1F3F5),
          width: isTarget ? 1.8 : 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_rounded,
                  color: kPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pengajuan Pencairan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w800,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.bankName} • ${item.accountNumber}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A8F98),
                        fontWeight: AppFont.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'a.n ${item.accountName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFB0B5BD),
                        fontWeight: AppFont.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '-${_fmtRp(item.amount)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w900,
                      color: kPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _InfoChip(
                    label: _payoutStatusLabel(item.status),
                    icon: Icons.schedule_rounded,
                    color: statusColor,
                    background: statusColor.withValues(alpha: 0.1),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PayoutTimeline(
            requestedAt: _fmtDateTime(item.createdAt),
            processedAt: _fmtDateTime(item.processedAt),
            completedAt: _fmtDateTime(item.completedAt),
          ),
          if (item.adminNote != null &&
              item.adminNote!.trim().isNotEmpty &&
              item.adminNote != 'null') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Catatan admin: ${item.adminNote}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontWeight: AppFont.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return ListView(
      children: [
        ReferralEmptyState(
          icon: icon,
          title: title,
          message: message,
          padding: const EdgeInsets.fromLTRB(18, 80, 18, 28),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: AppFont.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutTimeline extends StatelessWidget {
  final String requestedAt;
  final String processedAt;
  final String completedAt;

  const _PayoutTimeline({
    required this.requestedAt,
    required this.processedAt,
    required this.completedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: Column(
        children: [
          _TimelineRow(label: 'Diajukan', value: requestedAt, isDone: true),
          const SizedBox(height: 8),
          _TimelineRow(
            label: 'Diproses',
            value: processedAt,
            isDone: processedAt != '-',
          ),
          const SizedBox(height: 8),
          _TimelineRow(
            label: 'Dibayar',
            value: completedAt,
            isDone: completedAt != '-',
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDone;

  const _TimelineRow({
    required this.label,
    required this.value,
    required this.isDone,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDone ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1);
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF64748B),
              fontWeight: AppFont.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 11,
              color: isDone ? const Color(0xFF334155) : const Color(0xFF94A3B8),
              fontWeight: AppFont.w700,
            ),
          ),
        ),
      ],
    );
  }
}
