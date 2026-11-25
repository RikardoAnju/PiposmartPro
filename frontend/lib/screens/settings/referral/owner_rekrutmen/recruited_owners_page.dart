import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/referral_model.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/screens/settings/referral/owner_rekrutmen/owner_detail_page.dart';
import 'package:ayocucinew/screens/settings/referral/widgets/referral_empty_state.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RecruitedOwnersPage extends StatefulWidget {
  const RecruitedOwnersPage({super.key});

  @override
  State<RecruitedOwnersPage> createState() => _RecruitedOwnersPageState();
}

class _RecruitedOwnersPageState extends State<RecruitedOwnersPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      context.read<ReferralProvider>().fetchRecruitedOwners(token: token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final owners = provider.recruitedOwners;
    final isLoading = provider.recruitedStatus == ReferralStatus.loading;

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
          'Owner Direkrut',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: isLoading
          ? const ManagementListSkeleton(showSearch: false, itemCount: 6)
          : provider.recruitedStatus == ReferralStatus.error
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    provider.errorMessage ?? 'Terjadi kesalahan',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      final token = context.read<AuthProvider>().token;
                      provider.fetchRecruitedOwners(token: token);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: kPrimary,
              onRefresh: () async {
                final token = context.read<AuthProvider>().token;
                await provider.fetchRecruitedOwners(token: token);
              },
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: _TotalOwnerCard(total: owners.length),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeader(total: owners.length),
                    ),
                  ),
                  if (owners.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList.separated(
                        itemCount: owners.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          return _OwnerTile(owner: owners[index]);
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TotalOwnerCard extends StatelessWidget {
  final int total;
  const _TotalOwnerCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppPalette.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.colored(AppPalette.primary),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.group_add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Referral Owner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Owner yang berhasil direkrut',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: AppFont.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    total.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 5),
                    child: Text(
                      'Owner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: AppFont.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                total == 0
                    ? 'Bagikan kode referral untuk mulai membangun jaringan owner.'
                    : 'Pantau owner yang daftar memakai kode referral kamu.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: AppFont.w500,
                ),
              ),
            ],
          ),
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: Center(
              child: Icon(
                Icons.group_add_rounded,
                color: Colors.white.withValues(alpha: 0.35),
                size: 52,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final int total;
  const _SectionHeader({required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daftar Owner',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: AppFont.w800,
                  color: Color(0xFF222222),
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Owner yang terhubung dengan referral kamu.',
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
            '$total owner',
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

class _OwnerTile extends StatelessWidget {
  final ReferralRecruitedOwnerModel owner;
  const _OwnerTile({required this.owner});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OwnerDetailPage(owner: owner)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppPalette.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      owner.ownerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w800,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Outlet: ${owner.outletName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9AA0A6),
                        fontWeight: AppFont.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Bergabung ${owner.joinDate}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                              fontWeight: AppFont.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const ReferralEmptyState(
      icon: Icons.group_add_rounded,
      title: 'Belum ada owner yang direkrut',
      message:
          'Bagikan kode referral kamu. Owner yang berhasil mendaftar akan muncul di daftar ini.',
      padding: EdgeInsets.fromLTRB(24, 60, 24, 32),
    );
  }
}
