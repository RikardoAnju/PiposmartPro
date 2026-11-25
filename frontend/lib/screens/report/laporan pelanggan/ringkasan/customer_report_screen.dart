import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/customer_report_skeleton.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/customer_filter_sheet.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/customer_growth_section.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/customer_header_card.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/customer_info_note.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/customer_tab_selector.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/growth_detail_table.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/other_top_customers_list.dart';
import 'package:ayocucinew/screens/report/laporan%20pelanggan/ringkasan/widgets/top_customer_podium.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/addon_locked_placeholder.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/report_access_placeholder.dart';
import 'package:ayocucinew/shared/widgets/report_download_sheet.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

import 'package:ayocucinew/core/utils/report_export_builder.dart';
import 'package:ayocucinew/core/utils/report_export_service.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CustomerReportScreen extends StatefulWidget {
  const CustomerReportScreen({super.key});

  @override
  State<CustomerReportScreen> createState() => _CustomerReportScreenState();
}

class _CustomerReportScreenState extends State<CustomerReportScreen> {
  static const _surfaceColor = AppPalette.primaryPale;
  int _selectedTab = 0;
  bool _lastHasAddon = false;

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  bool _isExporting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_selectedTab == 1 && _scrollController.position.extentAfter < 240) {
        context.read<LaporanProvider>().loadMoreTopCustomer();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canRead = context.read<AuthProvider>().canReadReportAction(
      'read_customer',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_CUSTOMER_GROWTH',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );

    if (canRead && canAccessAddonFeature && !_lastHasAddon) {
      _lastHasAddon = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchData();
      });
    } else if (!canAccessAddonFeature) {
      _lastHasAddon = false;
    }
  }

  Future<void> _openAddonActivation() async {
    await Navigator.pushNamed(context, '/aktivasi-akun');
    if (!mounted) return;
    await context.read<AddonProvider>().fetchActiveAddons();
  }

  String _formatDateParam(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatPeriodLabel() {
    final now = DateTime.now();
    final start =
        _filterStartDate ?? DateTime.now().subtract(const Duration(days: 6));
    final end = _filterEndDate ?? now;
    return '${_formatShortDate(start)} - ${_formatShortDate(end)}';
  }

  String _formatShortDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _formatCompactRupiah(double value) {
    final abs = value.abs();
    if (abs >= 1000000000) {
      final amount = value / 1000000000;
      return 'Rp ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} M';
    }
    if (abs >= 1000000) {
      final amount = value / 1000000;
      return 'Rp ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} jt';
    }
    if (abs >= 1000) {
      final amount = value / 1000;
      return 'Rp ${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 1)} rb';
    }
    return ReportExportBuilder.formatRupiah(value);
  }

  void _fetchData() {
    final token = context.read<AuthProvider>().token ?? '';
    final now = DateTime.now();
    final startDate =
        _filterStartDate ?? DateTime.now().subtract(const Duration(days: 6));
    final endDate = _filterEndDate ?? now;

    context.read<LaporanProvider>().fetchCustomerGrowthReport(
      token,
      startDate: _formatDateParam(startDate),
      endDate: _formatDateParam(endDate),
    );
  }

  void _changeTab(int index) {
    if (_selectedTab == index) return;
    setState(() => _selectedTab = index);
  }

  Future<void> _openFilter() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerFilterSheet(
        startDate: _filterStartDate,
        endDate: _filterEndDate,
      ),
    );

    if (result == null) return;

    setState(() {
      _filterStartDate = result['startDate'] as DateTime?;
      _filterEndDate = result['endDate'] as DateTime?;
    });

    _fetchData();
  }

  Future<void> _showExportSheet(LaporanProvider provider) async {
    final hasData = _selectedTab == 0
        ? provider.customerGrowthTableRows.isNotEmpty
        : (provider.customerPodium.isNotEmpty ||
              provider.customerOthers.isNotEmpty);
    if (!hasData) {
      CustomToast.show(
        context,
        message: 'Belum ada data pelanggan untuk diunduh',
        isError: true,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ReportDownloadSheet(
        isExporting: _isExporting,
        description: 'Download laporan pelanggan sesuai tab yang sedang aktif.',
        onExportPdf: () {
          Navigator.of(sheetContext).pop();
          _exportPdf(provider);
        },
        onExportExcel: () {
          Navigator.of(sheetContext).pop();
          _exportExcel(provider);
        },
      ),
    );
  }

  ReportPdfDocument _buildExportDocument(
    LaporanProvider provider,
    Uint8List? logoBytes,
  ) {
    final isGrowthTab = _selectedTab == 0;
    final title = isGrowthTab ? 'Pelanggan Baru' : 'Top Pelanggan';
    final primaryValue = isGrowthTab
        ? '${provider.customerGrowthNewTotal}'
        : '${provider.customerTotalPelanggan}';
    final primaryCaption = isGrowthTab
        ? 'Pelanggan baru yang dibuat pada periode ini'
        : 'Pelanggan yang bertransaksi pada periode ini';
    final metrics = isGrowthTab
        ? [
            ReportPdfMetric(
              title: 'Pelanggan Aktif Transaksi',
              value: '${provider.customerTotalPelanggan}',
              background: PdfColor.fromHex(AppPalette.primaryPaleHex),
              accent: PdfColor.fromHex(AppPalette.primaryHex),
            ),
            ReportPdfMetric(
              title: 'Total Order',
              value: '${provider.customerTransactionOrder} order',
              background: PdfColor.fromHex('#F5F8FF'),
              accent: PdfColor.fromHex('#3B82F6'),
            ),
            ReportPdfMetric(
              title: 'Nilai Transaksi',
              value: _formatCompactRupiah(provider.customerTransactionNominal),
              background: PdfColor.fromHex('#F1FFF7'),
              accent: PdfColor.fromHex('#16A34A'),
            ),
          ]
        : [
            ReportPdfMetric(
              title: 'Total Order',
              value: '${provider.customerTransactionOrder} order',
              background: PdfColor.fromHex(AppPalette.primaryPaleHex),
              accent: PdfColor.fromHex(AppPalette.primaryHex),
            ),
            ReportPdfMetric(
              title: 'Nilai Transaksi',
              value: _formatCompactRupiah(provider.customerTransactionNominal),
              background: PdfColor.fromHex('#F5F8FF'),
              accent: PdfColor.fromHex('#3B82F6'),
            ),
            ReportPdfMetric(
              title: 'Pelanggan Baru',
              value: '${provider.customerGrowthNewTotal}',
              background: PdfColor.fromHex('#F1FFF7'),
              accent: PdfColor.fromHex('#16A34A'),
            ),
          ];
    final tables = isGrowthTab
        ? [
            ReportPdfTable(
              title: 'Pelanggan Baru',
              subtitle:
                  'Daftar pelanggan baru pada periode aktif beserta gender.',
              headers: const ['Tanggal', 'Nama', 'No HP', 'Gender'],
              rows: (provider.customerGrowthSummary?.newCustomers ?? const [])
                  .map(
                    (item) => [
                      item.tanggalFormatted,
                      ReportExportBuilder.sanitizeText(
                        item.nama,
                        fallback: 'Tanpa Nama',
                      ),
                      item.noHp,
                      item.genderLabel,
                    ],
                  )
                  .toList(),
            ),
          ]
        : [
            ReportPdfTable(
              title: 'Top Pelanggan',
              subtitle:
                  'Peringkat pelanggan berdasarkan total nilai transaksi pada periode aktif.',
              headers: const [
                'Nama',
                'No HP',
                'Gender',
                'Order',
                'Total Belanja',
              ],
              rows: [...provider.customerPodium, ...provider.customerOthers]
                  .map(
                    (item) => [
                      ReportExportBuilder.sanitizeText(
                        item.nama,
                        fallback: 'Tanpa Nama',
                      ),
                      item.noHp,
                      item.jenisKelamin,
                      '${item.totalOrder}',
                      ReportExportBuilder.formatRupiah(item.totalNominal),
                    ],
                  )
                  .toList(),
            ),
          ];

    return ReportPdfDocument(
      title: 'Laporan $title',
      subtitle: isGrowthTab
          ? 'Laporan pelanggan baru yang dibuat pada periode aktif.'
          : 'Laporan pelanggan dengan kontribusi transaksi tertinggi pada periode aktif.',
      periodLabel: _formatPeriodLabel(),
      rangeLabel: _formatPeriodLabel(),
      filterLabel: title,
      generatedAtLabel: ReportExportBuilder.formatGeneratedAt(),
      primaryValue: primaryValue,
      primaryCaption: primaryCaption,
      metrics: metrics,
      tables: tables,
      logoBytes: logoBytes,
    );
  }

  Future<void> _exportPdf(LaporanProvider provider) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      if (_selectedTab == 1) {
        while (provider.hasMoreTopCustomer) {
          await provider.loadMoreTopCustomer();
        }
      }
      final logoBytes = await ReportExportService.loadLogoBytes();
      final isGrowthTab = _selectedTab == 0;
      final title = isGrowthTab ? 'Pelanggan Baru' : 'Top Pelanggan';
      final document = _buildExportDocument(provider, logoBytes);
      if (!mounted) return;
      await ReportExportService.exportPdf(
        context: context,
        document: document,
        fileName:
            'ringkasan_pelanggan_${_selectedTab == 0 ? 'pertumbuhan' : 'top'}_${ReportExportBuilder.formatFileDate(_filterStartDate ?? DateTime.now())}_sd_${ReportExportBuilder.formatFileDate(_filterEndDate ?? DateTime.now())}.pdf',
        shareTitle: 'Laporan $title',
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal export laporan: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExcel(LaporanProvider provider) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      if (_selectedTab == 1) {
        while (provider.hasMoreTopCustomer) {
          await provider.loadMoreTopCustomer();
        }
      }
      final isGrowthTab = _selectedTab == 0;
      final title = isGrowthTab ? 'Pelanggan Baru' : 'Top Pelanggan';
      final document = _buildExportDocument(provider, null);
      if (!mounted) return;
      await ReportExportService.exportExcel(
        context: context,
        document: document,
        fileName:
            'ringkasan_pelanggan_${_selectedTab == 0 ? 'pertumbuhan' : 'top'}_${ReportExportBuilder.formatFileDate(_filterStartDate ?? DateTime.now())}_sd_${ReportExportBuilder.formatFileDate(_filterEndDate ?? DateTime.now())}.xlsx',
        shareTitle: 'Laporan $title',
      );
    } catch (e) {
      if (!mounted) return;
      CustomToast.show(
        context,
        message: 'Gagal export laporan: $e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRead = context.watch<AuthProvider>().canReadReportAction(
      'read_customer',
    );
    final hasAddon = context.watch<AddonProvider>().isFeatureActive(
      'REPORT_CUSTOMER_GROWTH',
    );
    final canAccessAddonFeature = hasAddonAccess(
      context: context,
      hasAddon: hasAddon,
    );
    return AppScaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        surfaceTintColor: Colors.white,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Pertumbuhan Pelanggan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          Consumer<LaporanProvider>(
            builder: (context, provider, _) => IconButton(
              onPressed: _isExporting ? null : () => _showExportSheet(provider),
              icon: _isExporting
                  ? const ReportExportIconSkeleton()
                  : Image.asset(
                      'assets/icons/ic_download.webp',
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.download_rounded,
                          size: 22,
                          color: Colors.black87,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      body: !canRead
          ? const SafeArea(
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 12),
                child: ReportAccessPlaceholder(
                  icon: Icons.people_outline_rounded,
                  title: 'Analisa Pertumbuhan Pelanggan Terkunci',
                  message:
                      'Akun ini belum punya izin untuk melihat laporan pelanggan.',
                  compact: true,
                ),
              ),
            )
          : !canAccessAddonFeature
          ? SafeArea(
              child: AddonLockedPlaceholder(
                title: 'Analisa pertumbuhan belum aktif',
                message:
                    'Aktifkan add-on untuk melihat tren pelanggan dan pertumbuhan per periode.',
                features: const [
                  'Tren pelanggan baru',
                  'Grafik pertumbuhan harian',
                  'Top pelanggan per periode',
                ],
                onActionTap: _openAddonActivation,
              ),
            )
          : Consumer<LaporanProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const CustomerReportSkeleton();
                }

                if (provider.errorMessage != null) {
                  return ReportErrorView(
                    message: provider.errorMessage!,
                    onRetry: _fetchData,
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _fetchData(),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _CustomerHeaderDelegate(
                          backgroundColor: _surfaceColor,
                          child: Column(
                            children: [
                              CustomerHeaderCard(
                                totalPelanggan: provider.customerTotalPelanggan,
                                totalOrder: provider.customerTransactionOrder,
                                totalNominal: _formatCompactRupiah(
                                  provider.customerTransactionNominal,
                                ),
                                periodLabel: _formatPeriodLabel(),
                                onPeriodTap: _openFilter,
                              ),
                              const SizedBox(height: 14),
                              CustomerTabSelector(
                                selectedIndex: _selectedTab,
                                onTabChanged: _changeTab,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            18,
                            16,
                            24 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  ...previousChildren,
                                  ?currentChild,
                                ],
                              );
                            },
                            transitionBuilder: (child, animation) {
                              final slideAnimation = Tween<Offset>(
                                begin: const Offset(0.04, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slideAnimation,
                                  child: child,
                                ),
                              );
                            },
                            child: _selectedTab == 0
                                ? _GrowthTabContent(
                                    key: const ValueKey('growth-tab'),
                                    tableRows: provider.customerGrowthTableRows,
                                    filterStartDate: _filterStartDate,
                                    filterEndDate: _filterEndDate,
                                  )
                                : _TopCustomerTabContent(
                                    key: const ValueKey('top-customer-tab'),
                                    podium: provider.customerPodium,
                                    others: provider.customerOthers,
                                  ),
                          ),
                        ),
                      ),
                      if (_selectedTab == 1 &&
                          provider.isLoadingMoreTopCustomer)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              children: [
                                ReportLoadMoreTileSkeleton(),
                                ReportLoadMoreTileSkeleton(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _CustomerHeaderDelegate extends SliverPersistentHeaderDelegate {
  static const double _height = 264;

  final Color backgroundColor;
  final Widget child;

  const _CustomerHeaderDelegate({
    required this.backgroundColor,
    required this.child,
  });

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CustomerHeaderDelegate oldDelegate) {
    return backgroundColor != oldDelegate.backgroundColor ||
        child != oldDelegate.child;
  }
}

class _GrowthTabContent extends StatelessWidget {
  final List<CustomerGrowthTableRow> tableRows;
  final DateTime? filterStartDate;
  final DateTime? filterEndDate;

  const _GrowthTabContent({
    super.key,
    required this.tableRows,
    this.filterStartDate,
    this.filterEndDate,
  });

  int get _pelangganBaruPeriode => tableRows.fold(0, (sum, r) => sum + r.total);

  String get _dateLabel {
    String fmt(DateTime dt) {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month';
    }

    if (filterStartDate != null && filterEndDate != null) {
      return '${fmt(filterStartDate!)} - ${fmt(filterEndDate!)}';
    } else if (filterStartDate != null) {
      return 'Dari ${fmt(filterStartDate!)}';
    } else if (filterEndDate != null) {
      return 'Sampai ${fmt(filterEndDate!)}';
    }
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    return '${fmt(start)} - ${fmt(now)}';
  }

  @override
  Widget build(BuildContext context) {
    final totalPeriode = tableRows.fold(0, (sum, r) => sum + r.total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomerGrowthSection(
          dateLabel: _dateLabel,
          pelangganHariIni: _pelangganBaruPeriode,
          trendLabel: '$totalPeriode baru',
          isTrendPositive: totalPeriode >= 0,
          chartData: tableRows.isNotEmpty
              ? tableRows
                    .map(
                      (r) => CustomerChartData(date: r.tanggal, value: r.total),
                    )
                    .toList()
              : [],
        ),
        const SizedBox(height: 16),
        GrowthDetailTable(
          rows: tableRows
              .map(
                (r) => GrowthTableRow(
                  tanggal: r.tanggalFormatted,
                  perempuan: r.perempuan,
                  lakiLaki: r.lakiLaki,
                  total: r.total,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _TopCustomerTabContent extends StatelessWidget {
  final List<TopCustomerItem> podium;
  final List<TopCustomerItem> others;

  const _TopCustomerTabContent({
    super.key,
    required this.podium,
    required this.others,
  });

  TopCustomerData _toData(TopCustomerItem item) => TopCustomerData(
    name: item.nama,
    totalTransaksi: item.totalNominal,
    jumlahTransaksi: item.totalOrder,
  );

  @override
  Widget build(BuildContext context) {
    if (podium.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: EmptyStateWidget.pelanggan(
          title: 'Belum ada data pelanggan',
          message:
              'Data pelanggan akan muncul setelah ada transaksi pada periode laporan ini.',
          imageWidth: 170,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TopCustomerPodium(
          first: _toData(podium[0]),
          second: podium.length > 1 ? _toData(podium[1]) : null,
          third: podium.length > 2 ? _toData(podium[2]) : null,
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 24),
          OtherTopCustomersList(
            customers: others.map(_toData).toList(),
            startRank: podium.length + 1,
          ),
        ],
        const SizedBox(height: 16),
        const CustomerInfoNote(),
      ],
    );
  }
}
