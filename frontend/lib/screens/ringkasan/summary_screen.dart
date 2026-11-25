import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/summary_provider.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/screens/ringkasan/summary_detail_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/responsive_center.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SummaryProvider>().fetchSummaryData();
    });
  }

  @override
  Widget build(BuildContext context) {
    const cards = [
      _SummaryCardData(
        title: 'Pesanan Terlambat',
        subtitle: 'Cucian yang sudah lewat tenggat',
        color: AppPalette.danger,
        glowColor: Color(0xFFFF7A83),
        icon: Icons.priority_high_rounded,
      ),
      _SummaryCardData(
        title: 'Harus Selesai',
        subtitle: 'Cucian yang harus selesai hari ini',
        color: AppPalette.warning,
        glowColor: Color(0xFFFFC25E),
        icon: Icons.hourglass_empty_rounded,
      ),
      _SummaryCardData(
        title: 'Selesai',
        subtitle: 'Cucian yang selesai hari ini',
        color: Color(0xFF00C92F),
        glowColor: Color(0xFF5AF279),
        icon: Icons.check_rounded,
      ),
      _SummaryCardData(
        title: 'Baru Masuk',
        subtitle: 'Semua cucian aktif yang masuk hari ini',
        color: Color(0xFF31B8EF),
        glowColor: Color(0xFF74D4FF),
        icon: Icons.local_laundry_service_outlined,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 25,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icons/ic_logo.webp',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
      body: Consumer<SummaryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const SummaryDashboardSkeleton();
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchSummaryData(),
            child: ResponsiveCenter(
              child: ListView(
              padding: const EdgeInsets.fromLTRB(17, 20, 17, 104),
              children: [
                for (final card in cards)
                  _buildSummaryCard(
                    data: card,
                    count: provider.counts[card.title] ?? 0,
                    onTap: () => _navigateToDetail(context, card.title),
                  ),
                const SizedBox(height: 10),
                _buildInfoNote(),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToDetail(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SummaryDetailScreen(category: category),
      ),
    );
  }

  Widget _buildSummaryCard({
    required _SummaryCardData data,
    required int count,
    required VoidCallback onTap,
  }) {
    final countText = count < 10
        ? count.toString().padLeft(2, '0')
        : count.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 123,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          color: data.color,
          boxShadow: AppShadows.colored(data.color),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ArcPainter(lightColor: data.glowColor),
                ),
              ),

              Positioned(
                right: -4,
                bottom: -18,
                child: Icon(
                  data.icon,
                  size: 124,
                  color: Colors.white.withValues(alpha: 0.34),
                ),
              ),

              Positioned(
                top: 18,
                right: 14,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(17, 17, 82, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: AppFont.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 10,
                        fontWeight: AppFont.w500,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          countText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: AppFont.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 11),
                        const Padding(
                          padding: EdgeInsets.only(top: 7),
                          child: Text(
                            "Pesanan",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: AppFont.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.green.shade800, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Semua ringkasan data layanan yang diambil hari ini dan akan tereset di hari selanjutnya.",
              style: TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardData {
  final String title;
  final String subtitle;
  final Color color;
  final Color glowColor;
  final IconData icon;

  const _SummaryCardData({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.glowColor,
    required this.icon,
  });
}

/// Two concentric filled circles centered just outside the right edge,
/// vertically centered. The ClipRRect on the card clips them so only
/// the arc portion inside the card is visible — matching the reference UI.
class _ArcPainter extends CustomPainter {
  final Color lightColor;
  const _ArcPainter({required this.lightColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Center is ~5% beyond the right edge, vertically centered
    final center = Offset(size.width * 1.05, size.height / 2);

    // Outer circle — radius slightly larger than card height
    canvas.drawCircle(
      center,
      size.height * 1.05,
      Paint()..color = lightColor.withValues(alpha: 0.28),
    );

    // Inner circle — smaller, more opaque
    canvas.drawCircle(
      center,
      size.height * 0.65,
      Paint()..color = lightColor.withValues(alpha: 0.38),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.lightColor != lightColor;
}
