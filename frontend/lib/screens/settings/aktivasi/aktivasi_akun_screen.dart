import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/screens/settings/aktivasi/checkout_aktivasi_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/free_aktivasi_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/pembelian_saya_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/ringkasan_pesanan_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/widgets/aktivasi_banner_widget.dart';
import 'package:ayocucinew/screens/settings/aktivasi/widgets/bottom_cta_widget.dart';
import 'package:ayocucinew/screens/settings/aktivasi/widgets/outlet_pro_success_screen.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/data/models/addon_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'dart:math' as math;

class AktivasiAkunScreen extends StatefulWidget {
  const AktivasiAkunScreen({super.key});

  @override
  State<AktivasiAkunScreen> createState() => _AktivasiAkunScreenState();
}

class _AktivasiAkunScreenState extends State<AktivasiAkunScreen> {
  final List<String> _selectedAddonIds = [];
  bool _isInitialCatalogLoading = true;
  bool _activeFeaturesExpanded = false;
  StreamSubscription? _dataUpdateSub;

  void _loadData() async {
    final addonProv = context.read<AddonProvider>();
    final koinProv = context.read<KoinProvider>();
    final pegawaiProv = context.read<PegawaiProvider>();

    try {
      await context.read<AppProvider>().fetchAppData(force: true);
      await koinProv.fetchEconomyConfig();
      await pegawaiProv.fetchEmployees();
      await addonProv.fetchKatalog();
      await addonProv.fetchActiveAddons();
      await addonProv.fetchPendingOrders();
    } finally {
      if (mounted) {
        setState(() => _isInitialCatalogLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
    
    _dataUpdateSub = appEventBus.stream.listen((event) {
      if (event is OutletActivated || event is OutletSwitched) {
        if (mounted) _loadData();
      }
    });
  }

  @override
  void dispose() {
    _dataUpdateSub?.cancel();
    super.dispose();
  }

  String _formatRupiah(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  double _calculateTotalRupiah() {
    final addonProv = context.read<AddonProvider>();
    final koinProv = context.read<KoinProvider>();
    double totalKoin = 0;

    for (var id in _selectedAddonIds) {
      try {
        final addon = addonProv.katalogAddons.firstWhere((a) => a.id == id);
        totalKoin += addon.harga;
      } catch (e) {
        debugPrint("Addon ID $id tidak ditemukan");
      }
    }
    return totalKoin * koinProv.pricePerCoin;
  }

  void _toggleAddon(String id) {
    final addonProv = context.read<AddonProvider>();
    final pegawaiProv = context.read<PegawaiProvider>();
    final addon = addonProv.katalogAddons.cast<Addon?>().firstWhere(
      (item) => item?.id == id,
      orElse: () => null,
    );

    final bool needsAddonEmployee =
        addon?.link == 'EXTRA_STAFF' &&
        !pegawaiProv.employees.any((employee) => employee.type == 'addon');

    if (needsAddonEmployee) {
      CustomToast.show(
        context,
        message:
            'Extra Slot Pegawai baru diperlukan saat kuota gratis sudah penuh.',
        isError: true,
      );
      return;
    }

    setState(() {
      if (_selectedAddonIds.contains(id)) {
        _selectedAddonIds.remove(id);
      } else {
        _selectedAddonIds.add(id);
      }
    });
  }

  void _handleCheckoutAddon() {
    if (_selectedAddonIds.isEmpty) return;
    final addonProv = context.read<AddonProvider>();
    final koinProv = context.read<KoinProvider>();

    final selectedItems = addonProv.katalogAddons
        .where((a) => _selectedAddonIds.contains(a.id))
        .map((a) {
          final bool isActive = addonProv.activeAddons.any(
            (active) => active.addonId == a.id,
          );
          return {
            'id': a.id,
            'name': isActive ? "Perpanjang ${a.nama}" : a.nama,
            'price': (a.harga * koinProv.pricePerCoin).toInt(),
          };
        })
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RingkasanPesananScreen(
          items: selectedItems,
          total: _calculateTotalRupiah().toInt(),
          addonIds: _selectedAddonIds,
          isAktivasiOnly: false,
        ),
      ),
    );
  }

  void _handleAktivasiOutlet() {
    final addonProv = context.read<AddonProvider>();
    final koinProv = context.read<KoinProvider>();

    // ✅ FIX: Cek PENDING & PENDING_VALIDATION biar gak double order
    final pendingAktivasi = addonProv.pendingOrders.any(
      (order) =>
          order.id.startsWith("PRO-") &&
          (order.status == "PENDING" || order.status == "PENDING_VALIDATION"),
    );

    if (pendingAktivasi) {
      CustomToast.show(
        context,
        message: "Ada pesanan aktivasi yang sedang diproses.",
        isError: true,
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PembelianSayaScreen()),
      );
      return;
    }

    final destination = koinProv.isActivationFree
        ? const FreeAktivasiScreen()
        : CheckoutAktivasiScreen(
            hargaNormal: koinProv.activationFee,
            diskonPersen: koinProv.activationDiscount,
            hargaFinal: koinProv.totalAktivasiPRO,
          );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final addonProv = context.watch<AddonProvider>();
    final koinProv = context.watch<KoinProvider>();
    final outlet = appProv.outlet;
    final showCatalogSkeleton =
        (_isInitialCatalogLoading || addonProv.isLoading) &&
        addonProv.katalogAddons.isEmpty;

    bool isPro = outlet?.activatedAt != null;

    // ✅ FIX: Trigger is pending mencakup proses validasi struk
    bool hasPendingPRO = addonProv.pendingOrders.any(
      (o) =>
          o.id.startsWith("PRO-") &&
          (o.status == "PENDING" || o.status == "PENDING_VALIDATION"),
    );

    String statusAkunText = "Memuat...";
    if (outlet != null) {
      final trialDaysLeft = math.max(
        0,
        outlet.trialExpiresAt.difference(DateTime.now()).inDays,
      );
      if (isPro) {
        statusAkunText = "PRO Permanen";
      } else if (trialDaysLeft == 0) {
        statusAkunText = "Trial Habis";
      } else {
        statusAkunText = "$trialDaysLeft Hari Trial";
      }
    }

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFF2C3E50),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Aktivasi Akun',
          style: TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
        ),
      ),
      body:
          (_isInitialCatalogLoading &&
              addonProv.katalogAddons.isEmpty &&
              outlet == null)
          ? const ActivationPageSkeleton()
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => addonProv.refreshData(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AktivasiBannerWidget(
                            isPro: isPro,
                            masaAktif: statusAkunText,
                            hasPending: hasPendingPRO,
                            isFree: koinProv.isActivationFree,
                            onProTap: isPro
                                ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const OutletProSuccessScreen(),
                                    ),
                                  )
                                : null,
                            onAktifkan: isPro
                                ? () {}
                                : (hasPendingPRO
                                      ? () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                const PembelianSayaScreen(),
                                          ),
                                        )
                                      : _handleAktivasiOutlet),
                          ),
                          const SizedBox(height: 16),

                          if (addonProv.activeAddons.isNotEmpty)
                            _buildCollapsibleActiveFeatures(addonProv),

                          const SizedBox(height: 24),
                          _buildSectionHeader(
                            title: 'Katalog Fitur Tambahan',
                            onRiwayatTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PembelianSayaScreen(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          if (showCatalogSkeleton)
                            const _AddonCatalogSkeleton()
                          else if (addonProv.katalogAddons.isEmpty)
                            _buildEmptyAddonState()
                          else
                            ...addonProv.katalogAddons.map((addon) {
                              final bool isActive = addonProv.activeAddons.any(
                                (a) => a.addonId == addon.id,
                              );
                              return _buildKatalogItem(
                                addon,
                                isPro,
                                koinProv.pricePerCoin,
                                isActive,
                              );
                            }),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
                BottomCtaWidget(
                  totalFormatted: _formatRupiah(_calculateTotalRupiah()),
                  onPressed: _selectedAddonIds.isEmpty
                      ? null
                      : _handleCheckoutAddon,
                ),
              ],
            ),
    );
  }

  // --- UI COMPONENTS TETAP SAMA ---
  Widget _buildCollapsibleActiveFeatures(AddonProvider addonProv) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F3F5)),
        ),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (v) =>
              setState(() => _activeFeaturesExpanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8EF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: Color(0xFF27AE60),
              size: 18,
            ),
          ),
          title: const Text(
            "Fitur Aktif",
            style: TextStyle(fontSize: 14, color: Color(0xFF2C3E50)),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${addonProv.activeAddons.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: _activeFeaturesExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF95A5A6),
                  size: 22,
                ),
              ),
            ],
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF1F3F5)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: addonProv.activeAddons
                    .map(
                      (active) => _buildActiveAddonCard(
                        active,
                        addonProv.katalogAddons,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAddonCard(ActiveAddon active, List<Addon> katalog) {
    final startAt = active.mulai;
    final expiry = active.berakhir;
    final createdAt = active.createdAt;
    final isExpiredSoon = expiry.difference(DateTime.now()).inDays < 3;

    String addonName = active.detail?.nama ?? "";
    if (addonName.isEmpty) {
      try {
        addonName = katalog.firstWhere((a) => a.id == active.addonId).nama;
      } catch (_) {
        addonName = "Fitur Aktif";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpiredSoon ? Colors.orange.shade200 : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  addonName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ),
              if (active.targetId != null && active.targetId!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Text(
                    active.targetId!,
                    style: const TextStyle(fontSize: 9, color: Colors.blueGrey),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.shopping_cart_outlined,
                size: 12,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                "Dibeli: ${DateFormat('dd MMM yyyy, HH:mm').format(createdAt)}",
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.history_toggle_off_rounded,
                size: 12,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${DateFormat('dd MMM').format(startAt)} s/d ${DateFormat('dd MMM yyyy').format(expiry)}",
                  style: TextStyle(
                    fontSize: 10,
                    color: isExpiredSoon
                        ? Colors.orange[800]
                        : Colors.blueGrey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKatalogItem(
    Addon addon,
    bool isPro,
    double pricePerCoin,
    bool isActive,
  ) {
    final pegawaiProv = context.watch<PegawaiProvider>();
    bool isSelected = _selectedAddonIds.contains(addon.id);
    double hargaRupiah = addon.harga * pricePerCoin;
    final bool isExtraStaff = addon.link == 'EXTRA_STAFF';
    final bool hasAddonEmployee = pegawaiProv.employees.any(
      (employee) => employee.type == 'addon',
    );
    final bool canSelectAddon = !isExtraStaff || hasAddonEmployee;
    final bool isEnabled = canSelectAddon;

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? AppPalette.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          onTap: isEnabled ? () => _toggleAddon(addon.id) : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.extension_rounded,
              color: AppPalette.primary,
              size: 22,
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(addon.nama, style: const TextStyle(fontSize: 14)),
              if (isActive)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    "AKTIF (Perpanjang)",
                    style: TextStyle(color: Color(0xFF27AE60), fontSize: 8),
                  ),
                ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              isExtraStaff && !hasAddonEmployee
                  ? "Baru diperlukan saat kuota pegawai gratis sudah penuh."
                  : addon.keterangan,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatRupiah(hargaRupiah),
                style: const TextStyle(color: AppPalette.primary, fontSize: 13),
              ),
              Text(
                "${addon.harga.toInt()} Koin",
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedOverlay() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.lock_person_rounded, color: Colors.amber, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Aktivasi Lisensi PRO terlebih dahulu untuk dapat belanja fitur tambahan.",
              style: TextStyle(fontSize: 12, color: Colors.brown),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAddonState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(
            Icons.inventory_2_outlined,
            size: 60,
            color: Colors.grey.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            "Belum ada add-on tersedia",
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback onRiwayatTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
        ),
        GestureDetector(
          onTap: onRiwayatTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppPalette.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Text(
                  'Riwayat',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
                SizedBox(width: 4),
                Icon(Icons.history, size: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddonCatalogSkeleton extends StatelessWidget {
  const _AddonCatalogSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(width: 42, height: 42, radius: 12),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeletonBox(width: 150, height: 15, radius: 8),
                      SizedBox(height: 10),
                      AppSkeletonBox(height: 11, radius: 99),
                      SizedBox(height: 8),
                      AppSkeletonBox(width: 96, height: 11, radius: 99),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppSkeletonBox(width: 76, height: 14, radius: 8),
                    SizedBox(height: 8),
                    AppSkeletonBox(width: 54, height: 10, radius: 99),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
