import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/laporan%20transakasi/data_transaksi/widgets/transaction_card.dart';
import 'package:ayocucinew/screens/report/omset/widgets/omset_detail_widget.dart';
import 'package:ayocucinew/screens/report/widgets/report_error_view.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class OmsetDetailPage extends StatefulWidget {
  final String dateLabel;
  final String date;
  final String token;
  final String? statusPembayaran;

  const OmsetDetailPage({
    super.key,
    required this.dateLabel,
    required this.date,
    required this.token,
    this.statusPembayaran,
  });

  @override
  State<OmsetDetailPage> createState() => _OmsetDetailPageState();
}

class _OmsetDetailPageState extends State<OmsetDetailPage> {
  static const Color kBg = Color(0xFFFBFBFB);

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentStatus;
  String _currentSort = 'Terbaru';
  String? _currentDate;
  bool _hasActiveFilter = false;

  String get currentDate => _currentDate ?? widget.date;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
    _currentStatus = widget.statusPembayaran;
    _searchController.addListener(() => setState(() {}));
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchData());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final provider = Provider.of<LaporanProvider>(context, listen: false);
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300 &&
        provider.hasMoreOmset &&
        !provider.isLoadingMore &&
        !provider.isLoading) {
      provider.loadMoreOmsetDetail();
    }
  }

  void _fetchData() {
    final report = Provider.of<LaporanProvider>(context, listen: false);
    report.fetchOmsetDetail(
      widget.token,
      date: currentDate,
      statusPembayaran: _currentStatus,
    );
  }

  Future<void> _openFilter() async {
    final result = await Navigator.push<Map<String, String?>>(
      context,
      MaterialPageRoute(
        builder: (_) => OmsetFilterSheet(
          currentStatus: _currentStatus,
          currentDate: currentDate,
          currentSort: _currentSort,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _currentStatus = result['status'];
        _currentSort = result['sortBy'] ?? 'Terbaru';
        final newDate = result['date'];
        if (newDate != null) _currentDate = newDate;
        _hasActiveFilter =
            (_currentStatus != null && _currentStatus!.isNotEmpty) ||
            currentDate != widget.date ||
            _currentSort != 'Terbaru';
      });
      _fetchData();
    }
  }

  List<OmsetDetail> _getProcessedList(List<OmsetDetail> rawList) {
    List<OmsetDetail> list = List.from(rawList);
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where(
            (item) =>
                item.namaPelanggan.toLowerCase().contains(query) ||
                item.nomorNota.toLowerCase().contains(query),
          )
          .toList();
    }

    switch (_currentSort) {
      case 'Terlama':
        list.sort((a, b) => a.tanggalMasuk.compareTo(b.tanggalMasuk));
        break;
      case 'Nominal Tertinggi':
        list.sort((a, b) => b.totalHarga.compareTo(a.totalHarga));
        break;
      case 'Nominal Terendah':
        list.sort((a, b) => a.totalHarga.compareTo(b.totalHarga));
        break;
      case 'Terbaru':
      default:
        list.sort((a, b) => b.tanggalMasuk.compareTo(a.tanggalMasuk));
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LaporanProvider>(context);
    final transactions = _getProcessedList(provider.omsetDetail);

    String displayDate = '';
    try {
      final parsed = parseReportDate(currentDate);
      displayDate = parsed == null
          ? currentDate
          : DateFormat('dd MMMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      displayDate = currentDate;
    }

    // Pakai agregat server (seluruh data terfilter untuk hari ini) agar total
    // tidak bertambah saat scroll memuat halaman berikutnya. Saat ada pencarian
    // teks (murni sisi-klien), jatuh kembali ke hitung lokal.
    final detailHeader = provider.omsetDetailHeader;
    final bool useServerTotals =
        detailHeader != null && _searchController.text.trim().isEmpty;
    final total = useServerTotals
        ? detailHeader.totalNominal
        : transactions.fold<double>(0, (sum, item) => sum + item.totalHarga);
    final totalTransaksi = useServerTotals
        ? detailHeader.totalTransaksi
        : transactions.length;

    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Penjualan',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              minHeight: 250,
              maxHeight: 250,
              child: (shrinkOffset) => Container(
                color: kBg,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    OmsetTotalCard(
                      total: total,
                      totalTransaksi: totalTransaksi,
                      dateLabel: displayDate,
                    ),
                    const SizedBox(height: 16),
                    OmsetSearchFilterRow(
                      searchController: _searchController,
                      onSearchChanged: (val) {}, // State updated via listener
                      onFilterTap: _openFilter,
                      hasActiveFilter: _hasActiveFilter,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (provider.isLoading)
            const ReportTransactionSliverSkeleton()
          else if (provider.errorMessage != null)
            SliverFillRemaining(
              child: ReportErrorView(
                message: provider.errorMessage!,
                onRetry: _fetchData,
              ),
            )
          else if (transactions.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'Belum ada transaksi',
                  style: TextStyle(color: Colors.black45, fontSize: 14),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: TransactionCard(
                      item: transactions[index],
                      onDetail: _fetchData,
                    ),
                  ),
                  childCount: transactions.length,
                ),
              ),
            ),
          if (provider.isLoadingMore)
            const SliverToBoxAdapter(child: ReportLoadMoreTileSkeleton()),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget Function(double shrinkOffset) child;
  final double minHeight;
  final double maxHeight;

  _StickyHeaderDelegate({
    required this.child,
    required this.minHeight,
    required this.maxHeight,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child(shrinkOffset));

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(_StickyHeaderDelegate old) =>
      maxHeight != old.maxHeight ||
      minHeight != old.minHeight ||
      child != old.child;
}
