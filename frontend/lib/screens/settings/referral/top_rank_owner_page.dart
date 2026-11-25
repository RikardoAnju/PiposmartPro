import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/screens/settings/referral/top_rank_owner_skeleton.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TopRankOwnerPage extends StatefulWidget {
  const TopRankOwnerPage({super.key});

  @override
  State<TopRankOwnerPage> createState() => _TopRankOwnerPageState();
}

class _TopRankOwnerPageState extends State<TopRankOwnerPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;
      context.read<ReferralProvider>().fetchTopRanks(token: token);

      final result = await authProvider.getMe();
      if (result['success'] == true) {
        final data = result['data'];
        final id = int.tryParse(
          (data['usr_id'] ?? data['id'] ?? data['user_id'] ?? '').toString(),
        );
        if (mounted) setState(() => _currentUserId = id);
      }
    });
  }

  Future<void> _refresh() async {
    final authProvider = context.read<AuthProvider>();
    final token = authProvider.token;
    await context.read<ReferralProvider>().fetchTopRanks(token: token);

    final result = await authProvider.getMe();
    if (result['success'] == true) {
      final data = result['data'];
      final id = int.tryParse(
        (data['usr_id'] ?? data['id'] ?? data['user_id'] ?? '').toString(),
      );
      if (mounted) setState(() => _currentUserId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final ranks = provider.topRanks;
    final isLoading = provider.topRankStatus == ReferralStatus.loading;

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
          'Top Rank Owner',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: kPrimary,
        onRefresh: _refresh,
        child: isLoading
            ? const TopRankOwnerSkeleton()
            : ranks.isEmpty
            ? const _TopRankEmpty()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  _HeaderCard(totalOwner: ranks.length),
                  const SizedBox(height: 14),
                  ...ranks.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _RankTile(
                        item: item,
                        isMe:
                            _currentUserId != null &&
                            item.userId == _currentUserId,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int totalOwner;

  const _HeaderCard({required this.totalOwner});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.referralHeroGradient,
          stops: AppPalette.referralHeroStops,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Leaderboard Referral',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: AppFont.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalOwner owner masuk ranking berdasarkan total reward referral terbesar.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _censorName(String name) {
  if (name.isEmpty) return name;
  return name
      .trim()
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        return word[0] + '*' * (word.length - 1);
      })
      .join(' ');
}

class _RankTile extends StatelessWidget {
  final ReferralTopRankModel item;
  final bool isMe;

  const _RankTile({required this.item, this.isMe = false});

  Color get _rankColor {
    if (item.rank == 1) return const Color(0xFFFFB300);
    if (item.rank == 2) return const Color(0xFF9E9E9E);
    if (item.rank == 3) return const Color(0xFFB86B2B);
    return isMe ? AppPalette.primary : const Color(0xFF9E9E9E);
  }

  @override
  Widget build(BuildContext context) {
    final totalReward = CurrencyFormatter.formatToRupiah(item.totalReward);
    final displayName = isMe ? item.ownerName : _censorName(item.ownerName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.all(isMe ? 13 : 14),
      decoration: BoxDecoration(
        color: isMe ? AppPalette.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isMe
            ? Border.all(color: AppPalette.primary, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
        boxShadow: [
          isMe
              ? BoxShadow(
                  color: AppPalette.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                )
              : BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _rankColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: item.rank <= 3
                  ? Icon(
                      Icons.workspace_premium_rounded,
                      color: _rankColor,
                      size: 27,
                    )
                  : Text(
                      '${item.rank}',
                      style: TextStyle(
                        color: _rankColor,
                        fontSize: 15,
                        fontWeight: AppFont.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: AppFont.w800,
                          color: isMe ? AppPalette.primary : Colors.black87,
                        ),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppPalette.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Kamu',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.outletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                _InfoChip(
                  icon: Icons.group_rounded,
                  label: '${item.totalUsed} dipakai',
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Reward',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black45,
                  fontWeight: AppFont.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                totalReward,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppPalette.primary,
                  fontWeight: AppFont.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppPalette.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.black87,
              fontWeight: AppFont.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopRankEmpty extends StatelessWidget {
  const _TopRankEmpty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        ReferralEmptyState(
          icon: Icons.emoji_events_outlined,
          title: 'Belum ada ranking owner',
          message:
              'Leaderboard akan terbentuk setelah owner referral mulai menghasilkan komisi top up.',
          padding: EdgeInsets.fromLTRB(0, 88, 0, 24),
        ),
      ],
    );
  }
}
