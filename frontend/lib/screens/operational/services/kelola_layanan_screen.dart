import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_palette.dart';

class KelolaLayananScreen extends StatelessWidget {
  const KelolaLayananScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final menus = <_MenuData>[
      if (auth.hasAccess('layanan', 'read'))
        _MenuData(
          icon: Icons.storefront_rounded,
          title: 'Kelola Layanan',
          subtitle: 'Kategori & produk layanan cuci',
          color: AppPalette.primary,
          route: '/service-list',
        ),
      if (auth.hasAccess('parfum', 'read'))
        _MenuData(
          icon: Icons.local_florist_rounded,
          title: 'Parfum',
          subtitle: 'Pilihan aroma parfum laundry',
          color: AppPalette.info,
          route: '/parfum-list',
        ),
      if (auth.hasAccess('item', 'read'))
        _MenuData(
          icon: Icons.local_laundry_service_rounded,
          title: 'Item yang dicuci',
          subtitle: 'Jenis item & barang cucian',
          color: AppPalette.success,
          route: '/item-cuci-list',
        ),
      if (auth.hasAccess('diskon', 'read'))
        _MenuData(
          icon: Icons.sell_rounded,
          title: 'Diskon',
          subtitle: 'Promo & potongan harga',
          color: AppPalette.warning,
          route: '/diskon-list',
        ),
    ];

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Kelola Layanan',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _HeroHeader(),
          const SizedBox(height: 22),
          if (menus.isEmpty)
            const _EmptyState()
          else
            for (int i = 0; i < menus.length; i++) ...[
              _MenuCard(data: menus[i]),
              if (i != menus.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String route;

  const _MenuData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.colored(AppPalette.primaryDeep),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppPalette.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -18,
              bottom: -22,
              child: Opacity(
                opacity: 0.12,
                child: Icon(Icons.tune_rounded, size: 150, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pusat Layanan Outlet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Atur layanan, parfum, item, dan diskon dalam satu tempat.',
                          style: TextStyle(
                            color: Color(0xFFFFE7DE),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _MenuData data;

  const _MenuCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pushNamed(context, data.route),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEFF3), width: 1.2),
            boxShadow: AppShadows.cardSoft,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(data.icon, color: data.color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 15,
                        fontWeight: AppFont.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.muted,
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
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              color: AppPalette.primary,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Belum ada menu tersedia',
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 15,
              fontWeight: AppFont.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kamu belum punya akses ke pengaturan layanan.\nHubungi owner untuk mengaturnya.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
