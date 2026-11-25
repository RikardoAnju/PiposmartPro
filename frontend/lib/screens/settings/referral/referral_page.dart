import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/referral_provider.dart';
import 'package:ayocucinew/screens/settings/referral/hadiah/my_reward_page.dart';
import 'package:ayocucinew/screens/settings/referral/owner_rekrutmen/recruited_owners_page.dart';
import 'package:ayocucinew/screens/settings/referral/top_rank_owner_page.dart';
import 'package:ayocucinew/screens/settings/referral/owner_rekrutmen/terms_and_conditions_page.dart';
import 'package:ayocucinew/screens/settings/referral/skleton_reffreal_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets/referral_commission_scheme_card.dart';
import 'widgets/referral_info_card.dart';
import 'widgets/referral_invitation_history_card.dart';
import 'widgets/referral_invite_card.dart';
import 'widgets/referral_menu_tile.dart';
import 'widgets/referral_promo_tiles.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  int _lastSeenOwnerCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthProvider>().token;
      context.read<ReferralProvider>().fetchSummary(token: token);
      _loadLastSeenCount();
    });
  }

  Future<void> _loadLastSeenCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSeenOwnerCount = prefs.getInt('owner_last_seen_count') ?? 0;
    });
  }

  Future<void> _markOwnerSeen(int currentCount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('owner_last_seen_count', currentCount);
    setState(() => _lastSeenOwnerCount = currentCount);
  }

  List<String> _buildHowItWorksItems(dynamic summary) {
    final inviterPercent = summary?.firstTopupPercent ?? 0;
    final referredPercent = summary?.firstTopupReferredPercent ?? 0;

    return [
      'Bagikan kode referral kamu ke owner lain.',
      'Owner baru mendaftar lalu memasukkan kode referral kamu sebelum top up pertama.',
      if (inviterPercent > 0)
        'Saat top up pertama berhasil, pengajak mendapat komisi $inviterPercent%.',
      if (referredPercent > 0)
        'Owner yang diajak juga mendapat bonus top up pertama sebesar $referredPercent%.',
    ];
  }

  int _parsePricePerCoin(dynamic summary) {
    final text = summary?.conversionRateText?.toString() ?? '';
    final match = RegExp(r'(\d+)').firstMatch(text);
    if (match == null) return 200;
    return int.tryParse(match.group(1)!) ?? 200;
  }

  List<String> _buildBenefitItems(dynamic summary) {
    final inviterPercent = summary?.firstTopupPercent ?? 0;
    final nextPercent = summary?.nextTopupPercent ?? 0;
    final referredPercent = summary?.firstTopupReferredPercent ?? 0;
    final monthlyLimit = summary?.monthlyRewardLimit ?? 0;

    return [
      if (inviterPercent > 0)
        'Pengajak mendapat komisi $inviterPercent% dari top up pertama owner yang diajak.',
      if (nextPercent > 0)
        'Pengajak mendapat komisi $nextPercent% dari top up berikutnya.',
      if (referredPercent > 0)
        'Owner yang diajak mendapat bonus $referredPercent% saat top up pertama berhasil.',
      if (monthlyLimit > 0)
        'Benefit top up dari owner yang sama dibatasi $monthlyLimit kali per bulan.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReferralProvider>();
    final summary = context.select<ReferralProvider, dynamic>((p) => p.summary);
    final isLoading =
        provider.status == ReferralStatus.loading && summary == null;

    final currentOwnerCount = summary?.recruitedOwners ?? 0;
    final hasNewOwner = currentOwnerCount > _lastSeenOwnerCount;

    return AppScaffold(
      backgroundColor: kBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Referral',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: isLoading
          ? const ReferralPageSkeleton()
          : provider.status == ReferralStatus.error
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
                      provider.fetchSummary(token: token);
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
          : Builder(
              builder: (context) {
                final screenHeight = MediaQuery.sizeOf(context).height;
                return Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: screenHeight * 0.75,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.fromARGB(255, 251, 93, 2),
                              Color.fromARGB(255, 252, 131, 31),
                              Color.fromARGB(255, 254, 164, 61),
                              Color(0xFFFFE1C2),
                              Color(0xFFF6F7F9),
                            ],
                            stops: [0.0, 0.7, 0.8, 0.9, 1.0],
                          ),
                        ),
                      ),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                      child: Column(
                        children: [
                          ReferralPromoTiles(
                            bonusPercent:
                                (summary?.firstTopupPercent ?? 0) as int,
                          ),
                          const SizedBox(height: 12),
                          ReferralInfoCard(
                            code: summary?.referralCode ?? '-',
                            howItWorksItems: _buildHowItWorksItems(summary),
                            benefitItems: _buildBenefitItems(summary),
                          ),
                          const SizedBox(height: 12),
                          ReferralInvitationHistoryCard(
                            periodText:
                                'Periode program berjalan hingga diperbarui',
                            recruitedOwners: currentOwnerCount,
                            ownerBadge: hasNewOwner
                                ? currentOwnerCount.toString()
                                : null,
                            onKomisiSayaTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyRewardPage(),
                                ),
                              );
                            },
                            onOwnerDirekrutTap: () async {
                              await _markOwnerSeen(currentOwnerCount);
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const RecruitedOwnersPage(),
                                  ),
                                );
                              }
                            },
                            onTopRankTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const TopRankOwnerPage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          ReferralCommissionSchemeCard(
                            firstTopupPercent:
                                (summary?.firstTopupPercent ?? 0) as int,
                            pricePerCoin: _parsePricePerCoin(summary),
                          ),
                          if (summary == null ||
                              (!summary.hasReferrer &&
                                  !summary.isReferralLocked)) ...[
                            const SizedBox(height: 12),
                            const ReferralInviteCard(),
                          ],
                          const SizedBox(height: 10),
                          ReferralMenuTile(
                            icon: Icons.description_rounded,
                            title: 'Syarat dan Ketentuan',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const TermsAndConditionsPage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
