import 'package:ayocucinew/shared/widgets/responsive_center.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/status/status_pesanan_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart'
    show DetailPesananScreen;
import 'package:ayocucinew/screens/status/widgets/qr_scanner_screen.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/core/utils/assets_utils.dart';
import 'package:ayocucinew/screens/status/detail/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:provider/provider.dart';
import '../../../providers/status_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../data/models/queue_item_model.dart';
import 'widgets/bulk_action_bar_widget.dart';
import 'widgets/filter_date_bottom_sheet.dart';
import 'widgets/status_tab_bar_view.dart';
import 'widgets/transaction_card_widget.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class StatusPesananScreen extends StatefulWidget {
  final int? initialTabIndex;
  const StatusPesananScreen({super.key, this.initialTabIndex});

  @override
  State<StatusPesananScreen> createState() => _StatusPesananScreenState();
}

class _StatusPesananScreenState extends State<StatusPesananScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  List<QueueItem>? _searchResults;

  final List<String> _selectedTrxIds = [];
  bool _isManualSelectionMode = false;

  late final List<String> _statuses;

  @override
  void initState() {
    super.initState();
    final skipProses = context.read<AppProvider>().outlet?.skipProses == 1;
    _statuses = skipProses
        ? ["Antrian", "Selesai", "Batal"]
        : ["Antrian", "Proses", "Siap Ambil", "Selesai", "Batal"];
    final int initialIndex = (widget.initialTabIndex ?? 0).clamp(
      0,
      _statuses.length - 1,
    );
    _tabController = TabController(
      length: _statuses.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StatusProvider>().fetchInitialData(_statuses);
      }
    });
  }

  void _onTabChanged() {
    if (_tabController != null && !_tabController!.indexIsChanging) {
      // Hanya fetch & clear jika BUKAN dalam mode search/scan
      if (_searchResults == null) {
        context.read<StatusProvider>().fetchQueue(
          _statuses[_tabController!.index],
        );
      }
      setState(() {
        _selectedTrxIds.clear();
        _isManualSelectionMode = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final prov = context.read<StatusProvider>();
    if (_searchResults != null) {
      _onSearchChanged(_searchController.text);
    } else {
      await prov.fetchInitialData(_statuses);
    }
  }

  Future<void> _handleBulkAction() async {
    final String currentStatus = _statuses[_tabController!.index];
    final bool skipProses = context.read<AppProvider>().outlet?.skipProses == 1;
    String? nextStatus;

    if (currentStatus == "Antrian") {
      nextStatus = skipProses ? "Selesai" : "Proses";
    } else if (currentStatus == "Proses") {
      nextStatus = "Siap Ambil";
    }

    if (nextStatus == null) {
      CustomToast.show(
        context,
        message: "Status ini tidak mendukung pemrosesan massal",
        isError: true,
      );
      return;
    }

    _showBulkConfirmDialog(currentStatus, nextStatus);
  }

  Future<void> _showBulkConfirmDialog(
    String currentStatus,
    String nextStatus,
  ) async {
    final nextIcon =
        {
          'Antrian': nextStatus == 'Selesai'
              ? AppImages.icSelesai
              : AppImages.icProses,
          'Proses': AppImages.icSiapAmbil,
          'Siap Ambil': AppImages.icSelesai,
        }[currentStatus] ??
        AppImages.icProses;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: _BulkConfirmationDialogContent(
          count: _selectedTrxIds.length,
          currentStatus: currentStatus,
          nextStatus: nextStatus,
          nextStatusIcon: nextIcon,
          onConfirm: () => Navigator.of(ctx).pop(true),
          onCancel: () => Navigator.of(ctx).pop(false),
        ),
      ),
    );

    if (confirmed == true) {
      await _executeBulk(nextStatus);
    }
  }

  Future<void> _executeBulk(String nextStatus) async {
    final prov = context.read<StatusProvider>();
    final ids = List<String>.from(_selectedTrxIds);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: AppCircularLoader(color: AppPalette.primary)),
    );

    final ok = await prov.updateStatusBulk(ids, nextStatus, "");

    if (!mounted) return;
    Navigator.of(context).maybePop();

    if (ok) {
      CustomToast.show(
        context,
        message: "Berhasil memindahkan ${ids.length} pesanan ke $nextStatus",
      );
      setState(() {
        _selectedTrxIds.clear();
        _isManualSelectionMode = false;
      });
    } else {
      CustomToast.show(
        context,
        message: "Gagal memperbarui pesanan",
        isError: true,
      );
    }
  }

  void _handleCardTap(String id) {
    if (_isManualSelectionMode || _selectedTrxIds.isNotEmpty) {
      setState(() {
        if (_selectedTrxIds.contains(id)) {
          _selectedTrxIds.remove(id);
        } else {
          _selectedTrxIds.add(id);
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPesananScreen(transactionId: id),
        ),
      );
    }
  }

  Future<void> _handleQrScan() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (result == null || result.isEmpty || !mounted) return;

    _searchController.text = result;
    setState(() {});

    context.read<StatusProvider>().handleQrScan(result, (res) {
      if (!mounted) return;

      // Pindah tab sesuai status pesanan yang di-scan
      if (res.isNotEmpty) {
        final scannedStatus = res.first.statusOrder;
        final tabIndex = _statuses.indexOf(scannedStatus);
        if (tabIndex != -1) {
          // Hapus listener sementara agar _onTabChanged tidak trigger fetch
          _tabController!.removeListener(_onTabChanged);
          _tabController!.animateTo(tabIndex);
          // Pasang listener kembali setelah frame selesai
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tabController?.addListener(_onTabChanged);
          });
        }
      }

      setState(() => _searchResults = res);
    });
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty) {
      setState(() => _searchResults = null);
      return;
    }
    context.read<StatusProvider>().searchQueue(value, (res) {
      if (mounted) setState(() => _searchResults = res);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchResults = null);
    // Fetch ulang tab yang aktif sekarang
    context.read<StatusProvider>().fetchQueue(_statuses[_tabController!.index]);
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<StatusProvider>();

    if (_tabController == null) {
      return const AppScaffold(body: SafeArea(child: StatusListSkeleton()));
    }

    final bool isSelectionModeActive =
        _isManualSelectionMode || _selectedTrxIds.isNotEmpty;
    final bool skipProses =
        context.watch<AppProvider>().outlet?.skipProses == 1;
    final bool supportsBulkProses = skipProses
        ? _statuses[_tabController!.index] == "Antrian"
        : _tabController!.index == 0 || _tabController!.index == 1;
    final double bottomHeight = prov.startDate != null ? 175 : 140;

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
        actions: _buildAppBarActions(),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(bottomHeight),
          child: ResponsiveCenter(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSearchBar(prov),
                if (prov.startDate != null) _buildFilterChip(prov),
                _buildTabBarView(prov),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _handleRefresh,
            color: AppPalette.primary,
            edgeOffset: 10,
            child: _searchResults != null
                ? _buildSearchResultsList(isSelectionModeActive)
                : TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: _statuses
                        .map(
                          (s) => StatusTabBarView(
                            status: s,
                            allStatuses: _statuses,
                            selectedTrxIds: _selectedTrxIds,
                            isSelectionMode: isSelectionModeActive,
                            onCardTap: _handleCardTap,
                            onCardLongPress: (id) {},
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (isSelectionModeActive)
            BulkActionBarWidget(
              selectedCount: _selectedTrxIds.length,
              showProcessButton: supportsBulkProses,
              onCancel: () {
                setState(() {
                  _selectedTrxIds.clear();
                  _isManualSelectionMode = false;
                });
              },
              onProcess: _handleBulkAction,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBarView(StatusProvider prov) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 8),
      child: TabBar(
        controller: _tabController,
        tabAlignment: TabAlignment.start,
        isScrollable: true,
        padding: const EdgeInsets.only(bottom: 12, left: 18, right: 16),
        onTap: (_) => setState(() {}),
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppPalette.primary,
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.black87,
        tabs: List.generate(
          _statuses.length,
          (i) =>
              _buildCustomTab(_statuses[i], prov.counts[_statuses[i]] ?? 0, i),
        ),
      ),
    );
  }

  Widget _buildCustomTab(String label, int count, int index) {
    final bool isActive = _tabController?.index == index;
    final bool hideCount = label == "Selesai" || label == "Batal";

    return Tab(
      child: Container(
        constraints: const BoxConstraints(minWidth: 90),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0 && !hideCount) ...[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : AppPalette.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 99 ? "99+" : "$count",
                  style: TextStyle(
                    color: isActive ? AppPalette.primary : Colors.white,
                    fontSize: 10,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? AppFont.w700 : AppFont.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(StatusProvider prov) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: AppSearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              hintText: "Cari Nama/ID INV",
              onClear: _clearSearch,
            ),
          ),
          const SizedBox(width: 12),
          _buildFilterIcon(prov),
        ],
      ),
    );
  }

  Widget _buildFilterIcon(StatusProvider prov) {
    final bool skipProses = context.read<AppProvider>().outlet?.skipProses == 1;
    final bool supportsBulkProses = skipProses
        ? _statuses[_tabController!.index] == "Antrian"
        : _tabController!.index == 0 || _tabController!.index == 1;

    return GestureDetector(
      onTap: () =>
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => FilterDateBottomSheet(
              currentStatus: _statuses[_tabController!.index],
              showSelectionOptions: supportsBulkProses,
              onSelectAll: (ids) {
                setState(() {
                  _selectedTrxIds
                    ..clear()
                    ..addAll(ids);
                  _isManualSelectionMode = false;
                });
              },
              onEnableSelection: () {
                setState(() => _isManualSelectionMode = true);
              },
            ),
          ).then((_) {
            if (mounted) prov.fetchInitialData(_statuses);
          }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: prov.startDate != null ? AppPalette.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: prov.startDate != null
                ? AppPalette.primary
                : Colors.grey[300]!,
          ),
        ),
        child: Icon(
          Icons.tune,
          color: prov.startDate != null ? Colors.white : Colors.black,
          size: 20,
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "SCAN",
              style: TextStyle(
                color: Colors.black,
                fontSize: 11,
                fontWeight: AppFont.w700,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.qr_code_scanner,
                color: Colors.black,
                size: 20,
              ),
              onPressed: _handleQrScan,
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildFilterChip(StatusProvider prov) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          label: Text(
            prov.filterLabel,
            style: const TextStyle(color: AppPalette.primary, fontSize: 14),
          ),
          backgroundColor: AppPalette.primary.withValues(alpha: 0.1),
          onDeleted: () {
            prov.setDateFilter(start: null, end: null);
            prov.fetchInitialData(_statuses);
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSearchResultsList(bool isSelectionModeActive) {
    if (_searchResults!.isEmpty) {
      return EmptyStateWidget(
        title: "Tidak Ditemukan",
        message: "Tidak ada hasil untuk \"${_searchController.text}\"",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: _searchResults!.length,
      itemBuilder: (context, index) => TransactionCardWidget(
        trx: _searchResults![index],
        isSelected: _selectedTrxIds.contains(_searchResults![index].id),
        isSelectionMode: isSelectionModeActive,
        onTap: () => _handleCardTap(_searchResults![index].id),
      ),
    );
  }
}

class _BulkConfirmationDialogContent extends StatelessWidget {
  final int count;
  final String currentStatus;
  final String nextStatus;
  final String nextStatusIcon;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _BulkConfirmationDialogContent({
    required this.count,
    required this.currentStatus,
    required this.nextStatus,
    required this.nextStatusIcon,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AppAssetImage(nextStatusIcon, width: 32, height: 32),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Konfirmasi Update Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: AppFont.w700,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: 'Apakah kamu yakin ingin mengubah status ',
                ),
                TextSpan(
                  text: '$count pesanan ',
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    color: Colors.black87,
                  ),
                ),
                const TextSpan(text: 'dari '),
                TextSpan(
                  text: currentStatus,
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: ' menjadi '),
                TextSpan(
                  text: nextStatus,
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    color: AppColors.primary,
                  ),
                ),
                const TextSpan(text: '?'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey.shade600,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontSize: 14, fontWeight: AppFont.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Ya, Lanjutkan',
                    style: TextStyle(fontSize: 14, fontWeight: AppFont.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
