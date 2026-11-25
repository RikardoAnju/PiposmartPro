import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OwnerDetailPage extends StatefulWidget {
  final ReferralRecruitedOwnerModel owner;

  const OwnerDetailPage({super.key, required this.owner});

  @override
  State<OwnerDetailPage> createState() => _OwnerDetailPageState();
}

class _OwnerDetailPageState extends State<OwnerDetailPage> {
  static const Color kBg = Color(0xFFF6F7F9);

  List<ReferralRewardModel> _activities = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadActivities());
  }

  void _loadActivities() {
    final summary = context.read<ReferralProvider>().summary;
    if (summary == null) return;

    setState(() {
      _activities = summary.recentRewards
          .where((reward) => reward.ownerName == widget.owner.ownerName)
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Detail Owner',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OwnerInfoCard(owner: widget.owner, rewards: _activities),
            const SizedBox(height: 20),
            _SectionTitle(total: _activities.length),
            const SizedBox(height: 10),
            if (_activities.isNotEmpty) ...[
              _ActivitySummaryCard(rewards: _activities),
              const SizedBox(height: 10),
            ],
            if (_activities.isEmpty)
              const _EmptyActivity()
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activities.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) =>
                    _ActivityTile(reward: _activities[index]),
              ),
          ],
        ),
      ),
    );
  }
}

class _OwnerInfoCard extends StatelessWidget {
  final ReferralRecruitedOwnerModel owner;
  final List<ReferralRewardModel> rewards;

  const _OwnerInfoCard({required this.owner, required this.rewards});

  int get _totalReward =>
      rewards.fold<int>(0, (sum, reward) => sum + reward.rewardAmount);

  String get _formattedReward {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return fmt.format(_totalReward);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.referralHeroGradient,
          stops: AppPalette.referralHeroStops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -28,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          owner.ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Outlet: ${owner.outletName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.78),
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeaderMetric(
                      label: 'Bergabung',
                      value: owner.joinDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeaderMetric(
                      label: 'Komisi Terbaru',
                      value: _formattedReward,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 11,
              fontWeight: AppFont.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: AppFont.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final int total;

  const _SectionTitle({required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aktivitas Komisi',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFont.w800,
                  color: Color(0xFF222222),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Top up owner yang menghasilkan komisi.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: AppFont.w500,
                  color: Color(0xFF9AA0A6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$total aktivitas',
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 12,
              fontWeight: AppFont.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  final List<ReferralRewardModel> rewards;

  const _ActivitySummaryCard({required this.rewards});

  int get _firstTopupCount =>
      rewards.where((reward) => reward.percent >= 15).length;

  int get _nextTopupCount =>
      rewards.where((reward) => reward.percent < 15).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E7E4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryPill(
              icon: Icons.trending_up_rounded,
              label: 'Top Up Pertama',
              value: '$_firstTopupCount aktivitas',
              color: const Color(0xFF2F80ED),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryPill(
              icon: Icons.repeat_rounded,
              label: 'Top Up Lanjutan',
              value: '$_nextTopupCount aktivitas',
              color: const Color(0xFF27AE60),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9AA0A6),
                  fontWeight: AppFont.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2B2B2B),
                  fontWeight: AppFont.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ReferralRewardModel reward;

  const _ActivityTile({required this.reward});

  bool get _isTopup => reward.type == 'topup';

  String get _formattedAmount {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return '+${fmt.format(reward.rewardAmount)}';
  }

  String get _formattedDate {
    try {
      final dt = DateTime.parse(reward.createdAt).toLocal();
      final months = [
        '',
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return reward.createdAt;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E7E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: AppPalette.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTopup ? 'Komisi Top Up' : 'Komisi Referral',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w800,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${reward.outletName} - $_formattedDate',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: AppFont.w600,
                  ),
                ),
                if (_isTopup) ...[
                  const SizedBox(height: 9),
                  _PercentChip(percent: reward.percent),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formattedAmount,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w800,
              color: Color(0xFF34A853),
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentChip extends StatelessWidget {
  final int percent;

  const _PercentChip({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2F80ED).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$percent% komisi',
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF2F80ED),
          fontWeight: AppFont.w800,
        ),
      ),
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity();

  @override
  Widget build(BuildContext context) {
    return const ReferralEmptyState(
      icon: Icons.history_rounded,
      title: 'Belum ada aktivitas',
      message:
          'Aktivitas top up dan komisi dari owner ini akan tampil setelah transaksi pertama terjadi.',
      padding: EdgeInsets.fromLTRB(24, 28, 24, 24),
    );
  }
}
