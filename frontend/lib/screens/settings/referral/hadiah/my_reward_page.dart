import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/providers/setting_provider.dart';
import 'package:ayocucinew/screens/settings/referral/hadiah/cairkan_saldo/cairkan_saldo_page.dart';
import 'package:ayocucinew/screens/settings/referral/hadiah/reward_history_screen.dart';
import 'package:ayocucinew/screens/settings/referral/hadiah/tukar_koin/tukar_saldo_koin_page.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/my_reward_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'widgets/reward_balance_card.dart';
import 'widgets/reward_summary_card.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class MyRewardPage extends StatefulWidget {
  const MyRewardPage({super.key});

  @override
  State<MyRewardPage> createState() => _MyRewardPageState();
}

class _MyRewardPageState extends State<MyRewardPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  final _rupiahFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final token = context.read<AuthProvider>().token;
    await context.read<ReferralProvider>().fetchSummary(token: token);
  }

  String _fmtRp(int amount) => _rupiahFmt.format(amount);

  String _fmtDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('d MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return raw;
    }
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

  void _onTukarKoin() {
    final summary = context.read<ReferralProvider>().summary;

    if (summary == null) {
      CustomToast.show(
        context,
        message: 'Data belum tersedia, coba lagi',
        isError: true,
      );
      return;
    }

    if (summary.ownerOutlets.isEmpty) {
      CustomToast.show(
        context,
        message: 'Tidak ada outlet yang tersedia',
        isError: true,
      );
      return;
    }

    final outletList = summary.ownerOutlets
        .map((o) => OutletOption(id: o.id, name: o.name, currentKoin: o.koin))
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TukarSaldoKoinPage(
          availableBalance: summary.availableBalance,
          rewards: summary.availableRewards,
          outlets: outletList,
          onConfirm:
              ({
                required outletId,
                required rewardIds,
                required jumlahKoin,
              }) async {
                final token = context.read<AuthProvider>().token;

                final result = await context
                    .read<ReferralProvider>()
                    .convertToKoin(
                      outletId: outletId,
                      rewardIds: rewardIds,
                      token: token,
                    );

                if (result['success'] == true && mounted) {
                  final referralProv = context.read<ReferralProvider>();
                  final koinProv = context.read<KoinProvider>();
                  final settingProv = context.read<SettingProvider>();

                  await Future.wait([
                    referralProv.fetchSummary(token: token),
                    koinProv.refreshKoinData(
                      syncBalanceCallback: () => settingProv.refreshBalanceOnly(),
                    ),
                    settingProv.fetchSettingsData(silent: true),
                  ]);
                }

                return result['success'] == true;
              },
        ),
      ),
    );
  }

  void _onCairkan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CairkanSaldoPage()),
    ).then((_) {
      _refreshData();
    });
  }

  Widget _buildAvailableRewards(dynamic summary) {
    final rewards =
        (summary?.availableRewards ?? []) as List<ReferralRewardModel>;
    final latestRewards = rewards.take(5).toList();

    if (latestRewards.isEmpty) {
      return ListView(
        children: const [
          ReferralEmptyState(
            icon: Icons.card_giftcard_rounded,
            title: 'Belum ada hadiah tersedia',
            message:
                'Bonus yang bisa ditukar atau dicairkan akan muncul di sini setelah owner referral melakukan top up.',
            padding: EdgeInsets.fromLTRB(18, 42, 18, 28),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: latestRewards.length,
      itemBuilder: (context, index) {
        final r = latestRewards[index];
        final statusColor = _rewardStatusColor(r.status);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.04),
              width: 1,
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
                          r.ownerName.isNotEmpty
                              ? r.ownerName
                              : 'Komisi Top Up Koin',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.outletName.isNotEmpty
                              ? 'Outlet: ${r.outletName}'
                              : 'Outlet belum tersedia',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8A8F98),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+${_fmtRp(r.rewardAmount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _fmtDate(r.createdAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (r.percent > 0)
                    _RewardChip(
                      label: '${r.percent}% komisi',
                      icon: Icons.percent_rounded,
                      color: const Color(0xFF2563EB),
                      background: const Color(0xFFEFF6FF),
                    ),
                  _RewardChip(
                    label: _rewardStatusLabel(r.status),
                    icon: Icons.check_circle_outline_rounded,
                    color: statusColor,
                    background: statusColor.withValues(alpha: 0.1),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final summary = provider.summary;
    final isLoading =
        provider.status == ReferralStatus.loading && summary == null;

    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Hadiah Saya',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
      body: isLoading
          ? const MyRewardSkeleton()
          : provider.status == ReferralStatus.error
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.errorMessage ?? 'Terjadi kesalahan',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _refreshData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RewardBalanceCard(
                        balance: _fmtRp(summary?.totalEarned ?? 0),
                        exchangeRate: summary?.conversionRateText ?? '-',
                      ),
                      const SizedBox(height: 12),
                      RewardSummaryCard(
                        totalSaldo: _fmtRp(summary?.availableBalance ?? 0),
                        onTukarKoin: _onTukarKoin,
                        onCairkan: _onCairkan,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Hadiah Tersedia',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RewardHistoryScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SafeArea(
                    top: false,
                    child: RefreshIndicator(
                      color: kPrimary,
                      onRefresh: _refreshData,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildAvailableRewards(summary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color background;

  const _RewardChip({
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
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
