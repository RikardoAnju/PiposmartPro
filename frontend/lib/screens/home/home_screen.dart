// lib/screens/home/home_screen.dart

import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/content_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/core/service/fcm_service.dart';
import 'package:ayocucinew/core/service/lifecycle_event_service.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/app_image_cache.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/screens/home/widgets/custom_buttom_nav.dart';
import 'package:ayocucinew/screens/home/widgets/home_header.dart';
import 'package:ayocucinew/screens/home/widgets/info_slider.dart';
import 'package:ayocucinew/screens/home/widgets/promo_slider.dart';
import 'package:ayocucinew/screens/ringkasan/summary_screen.dart';
import 'package:ayocucinew/screens/status/status_pesanan_screen.dart';
import 'package:ayocucinew/screens/operational/transaction/order/order_screen.dart';
import 'package:ayocucinew/screens/settings/setting_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'widgets/summary_card.dart';
import 'widgets/operational_grid.dart';
import 'widgets/desktop_version_banner.dart';
import 'widgets/tutorial/first_home_tutorial_overlay.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _headerKey = GlobalKey();
  final _incomeKey = GlobalKey();
  final _operationalKey = GlobalKey();
  final _fabKey = GlobalKey();
  final _navKey = GlobalKey();
  int _currentIndex = 0;
  bool _showFirstTutorial = false;
  bool _didWarmSecondaryAssets = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      if (auth.actorType == 'pegawai') {
        await auth.silentRefreshToken();
        if (!mounted) return;
      }
      final appProv = context.read<AppProvider>();
      final contentProv = context.read<ContentProvider>();

      appProv.setContext(context);
      if (appProv.outlet == null || appProv.summaryData == null) {
        await appProv.fetchAppData();
      }
      if (!mounted) return;
      LifecycleEventService.track(
        'app_opened',
        metadata: {'source': 'home'},
        localCooldown: const Duration(hours: 6),
      );
      await FCMService.ensureNotificationReadiness(
        context: context,
        promptIfNeeded: true,
        reason: 'home_entry',
      );
      if (contentProv.items.isEmpty) {
        await contentProv.fetchContent();
      }
      if (!mounted) return;
      AppImageCache.warmNetworkImages(context, [
        ...contentProv.promos
            .take(4)
            .map(
              (item) =>
                  ApiClient.resolveImageVariantUrl(item.imageUrl, width: 720),
            ),
        ...contentProv.infos
            .take(4)
            .map(
              (item) =>
                  ApiClient.resolveImageVariantUrl(item.imageUrl, width: 720),
            ),
      ]);
      await _maybeStartFirstTutorial();
    });
  }

  Future<void> _maybeStartFirstTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getBool('pending_first_home_tutorial') ?? false;
    final completed = prefs.getBool('first_home_tutorial_done') ?? false;
    if (!mounted || (completed && !pending)) return;

    setState(() {
      _currentIndex = 0;
      _showFirstTutorial = true;
    });
  }

  Future<void> _completeFirstTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_home_tutorial_done', true);
    await prefs.remove('pending_first_home_tutorial');
    if (!mounted) return;
    setState(() => _showFirstTutorial = false);
  }

  List<TutorialStepData> get _tutorialSteps => [
    TutorialStepData(
      targetKey: _headerKey,
      icon: Icons.storefront_rounded,
      title: 'Profil outlet kamu',
      description:
          'Di sini kamu bisa melihat outlet aktif, akun yang sedang login, dan membuka notifikasi penting dari AyoCuci.',
    ),
    TutorialStepData(
      targetKey: _incomeKey,
      icon: Icons.insights_rounded,
      title: 'Ringkasan hari ini',
      description:
          'Pantau pendapatan, penjualan, pengeluaran, dan transaksi hari ini dalam satu ringkasan yang diperbarui otomatis.',
    ),
    TutorialStepData(
      targetKey: _operationalKey,
      icon: Icons.grid_view_rounded,
      title: 'Menu operasional',
      description:
          'Mulai atur layanan, pelanggan, karyawan, pengeluaran, laporan, sampai outlet dari shortcut ini.',
    ),
    TutorialStepData(
      targetKey: _fabKey,
      icon: Icons.add_shopping_cart_rounded,
      title: 'Buat pesanan baru',
      description:
          'Tombol utama ini dipakai untuk membuat order laundry baru. Ini akan jadi alur yang paling sering dipakai kasir.',
    ),
    TutorialStepData(
      targetKey: _navKey,
      icon: Icons.touch_app_rounded,
      title: 'Navigasi utama',
      description:
          'Pindah ke Status, Ringkasan, dan Setting dari bawah layar. Selesaikan panduan ini dulu, setelah itu aplikasi siap dipakai.',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didWarmSecondaryAssets) return;
    _didWarmSecondaryAssets = true;
    AppImageCache.warmSecondaryAssets(context);
  }

  List<Widget> _getPages() {
    return [
      _buildHomeContent(),
      const StatusPesananScreen(),
      const SummaryScreen(),
      const SettingScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _getPages();
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppPalette.surface,
          resizeToAvoidBottomInset: false,
          body: IndexedStack(
            index: _currentIndex.clamp(0, pages.length - 1),
            children: pages,
          ),
          floatingActionButton: Transform.translate(
            offset: const Offset(0, 10),
            child: SizedBox(
              key: _fabKey,
              width: 60,
              height: 60,
              child: FloatingActionButton(
                onPressed: () async {
                  final transactionProv = context.read<TransactionProvider>();
                  transactionProv.startNewOrder();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const OrderScreen(),
                    ),
                  );
                  if (mounted) transactionProv.endOrder();
                },
                backgroundColor: AppPalette.primary,
                elevation: 6,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white, size: 40),
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: KeyedSubtree(
            key: _navKey,
            child: CustomBottomNav(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
            ),
          ),
        ),
        if (_showFirstTutorial)
          FirstHomeTutorialOverlay(
            steps: _tutorialSteps,
            onCompleted: _completeFirstTutorial,
          ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phone-first: di tablet/iPad konten dikunci selebar ponsel & di tengah
        // agar kartu tidak melar. (Sebelumnya 800 → terlalu lebar.)
        bool isTablet = constraints.maxWidth > 600;
        double contentWidth = isTablet ? 500 : constraints.maxWidth;

        return Stack(
          children: [
            // ✅ Gradient Background: Dibuat tinggi agar transisinya melandai halus
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.58,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppPalette.primaryDeep,
                      AppPalette.primary,
                      AppPalette.surface,
                    ],
                    stops: [
                      0.0,
                      0.7,
                      1.0,
                    ], // Haluskan transisi ke background putih
                  ),
                ),
              ),
            ),
            // ✅ Content Layer
            SafeArea(
              bottom: false,
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    children: [
                      Padding(
                        key: _headerKey,
                        padding: const EdgeInsets.only(top: 10, bottom: 5),
                        child: const HomeHeader(),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppPalette.primary,
                          backgroundColor: Colors.white,
                          onRefresh: () async {
                            await Future.wait([
                              context.read<AppProvider>().fetchAppData(
                                force: true,
                              ),
                              context.read<ContentProvider>().fetchContent(),
                            ]);
                          },
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            physics: const ClampingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 20 : 0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 20),
                                KeyedSubtree(
                                  key: _incomeKey,
                                  child: const SummaryCard(),
                                ),
                                const SizedBox(height: 25),
                                KeyedSubtree(
                                  key: _operationalKey,
                                  child: const OperationalGrid(),
                                ),
                                const SizedBox(height: 16),
                                const DesktopVersionBanner(),
                                const SizedBox(height: 30),
                                Builder(
                                  builder: (context) {
                                    final offset = _scrollController.hasClients
                                        ? _scrollController.offset
                                        : 0.0;
                                    // Promo slider is dark if it's high enough in the scroll view (near top)
                                    // and the scroll hasn't pushed it past the orange area.
                                    // Since orange is at the top, as we scroll DOWN (offset increases),
                                    // the elements move UP.
                                    // So if offset is high, PromoSlider moves into the orange area?
                                    // No, PromoSlider starts at the bottom.
                                    // If offset is high, it moves UP into the top (orange) area.
                                    final isDark = offset > 200;
                                    return PromoSlider(
                                      isDarkBackground: isDark,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                Builder(
                                  builder: (context) {
                                    final offset = _scrollController.hasClients
                                        ? _scrollController.offset
                                        : 0.0;
                                    final isDark = offset > 450;
                                    return InfoSlider(isDarkBackground: isDark);
                                  },
                                ),
                                const SizedBox(height: 120),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
