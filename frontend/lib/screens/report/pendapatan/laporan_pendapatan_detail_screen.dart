import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/income_detail_model.dart';
import 'package:ayocucinew/providers/laporan_provider.dart';
import 'package:ayocucinew/screens/report/widgets/report_loading_skeletons.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:ayocucinew/screens/operational/customer/customer_deposit_history_screen.dart';
import 'package:ayocucinew/data/models/customer_deposit_model.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/providers/customer_deposit_provider.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'widgets/total_pendapatan_card.dart';
import 'package:ayocucinew/core/utils/payment_asset_util.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';

class LaporanPendapatanDetailScreen extends StatefulWidget {
  final String metodeNama;
  final String startDate;
  final String endDate;
  final String token;

  const LaporanPendapatanDetailScreen({
    super.key,
    required this.metodeNama,
    required this.startDate,
    required this.endDate,
    required this.token,
  });

  @override
  State<LaporanPendapatanDetailScreen> createState() =>
      _LaporanPendapatanDetailScreenState();
}

class _LaporanPendapatanDetailScreenState
    extends State<LaporanPendapatanDetailScreen> {
  static const Color kPrimary = AppPalette.primary; // AyoCuci Orange
  static const Color kBg = Color(0xFFF8F9FA);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  String _searchQuery = '';

  final _fmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchData();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchData({bool isLoadMore = false}) {
    if (isLoadMore) {
      _page++;
    } else {
      _page = 1;
    }
    context.read<LaporanProvider>().fetchIncomeDetail(
      widget.token,
      startDate: widget.startDate,
      endDate: widget.endDate,
      metodeNama: widget.metodeNama,
      page: _page,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<LaporanProvider>();
      if (!provider.isLoading && provider.hasMoreIncomeDetail) {
        _fetchData(isLoadMore: true);
      }
    }
  }

  Map<String, List<IncomeDetailTransaction>> _groupTransactions(
    List<IncomeDetailTransaction> list,
  ) {
    final Map<String, List<IncomeDetailTransaction>> grouped = {};
    for (final tx in list) {
      final key = DateFormat('yyyy-MM-dd').format(tx.tanggalPembayaran);
      if (grouped[key] == null) {
        grouped[key] = [];
      }
      grouped[key]!.add(tx);
    }
    return grouped;
  }

  String _formatHeaderDate(String dateStr) {
    try {
      final parsed = DateTime.parse(dateStr);
      final today = DateTime.now();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      if (DateFormat('yyyy-MM-dd').format(parsed) ==
          DateFormat('yyyy-MM-dd').format(today)) {
        return 'Hari Ini';
      }
      if (DateFormat('yyyy-MM-dd').format(parsed) ==
          DateFormat('yyyy-MM-dd').format(yesterday)) {
        return 'Kemarin';
      }
      return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(parsed);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LaporanProvider>();
    final allTransactions = provider.incomeDetailList;
    final transactions = _filterTransactions(allTransactions);
    final grouped = _groupTransactions(transactions);
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order

    // Pakai agregat server (seluruh data terfilter) agar total tidak bertambah
    // saat scroll memuat halaman berikutnya. Saat ada pencarian teks (murni
    // sisi-klien), jatuh kembali ke hitung lokal atas hasil yang tersaring.
    final detailHeader = provider.incomeDetailHeader;
    final bool useServerTotals =
        detailHeader != null && _searchQuery.trim().isEmpty;
    final double totalAccumulated = useServerTotals
        ? detailHeader.totalNominal
        : transactions.fold<double>(0, (sum, item) => sum + item.nominalBayar);
    final int totalTransaksiCount = useServerTotals
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
        title: Text(
          widget.metodeNama.trim().isEmpty
              ? 'RINCIAN PENDAPATAN'
              : widget.metodeNama.toUpperCase(),
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchData(),
        color: kPrimary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyHeaderDelegate(
                minHeight: 174,
                maxHeight: 174,
                child: (shrinkOffset) => Container(
                  color: kBg,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: TotalPendapatanCard(
                    totalPendapatan: totalAccumulated,
                    percentageChange: 0,
                    periodLabel:
                        'Periode: ${DateFormat('dd MMM', 'id_ID').format(DateTime.parse(widget.startDate))} s/d ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(widget.endDate))}',
                    totalTransaksi: totalTransaksiCount,
                  ),
                ),
              ),
            ),
            if (allTransactions.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: _IncomeSearchField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                ),
              ),

            if (provider.isLoading && allTransactions.isEmpty)
              const ReportTransactionSliverSkeleton()
            else if (transactions.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: EmptyStateWidget.laporan(
                    title: _searchQuery.trim().isEmpty
                        ? 'Belum ada transaksi'
                        : 'Transaksi tidak ditemukan',
                    message: _searchQuery.trim().isEmpty
                        ? 'Tidak ada pembayaran yang tercatat di kategori ini.'
                        : 'Coba gunakan nama pelanggan, kode transaksi, atau metode pembayaran lain.',
                    imageWidth: 150,
                  ),
                ),
              )
            else
              ...List.generate(sortedKeys.length, (index) {
                final dateKey = sortedKeys[index];
                final dayTxs = grouped[dateKey]!;

                return SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatHeaderDate(dateKey),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: AppFont.w800,
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                            ),
                            Text(
                              '${dayTxs.length} Transaksi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: AppFont.w600,
                                color: Colors.black.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, idx) {
                          final tx = dayTxs[idx];
                          return _buildTransactionCard(tx);
                        }, childCount: dayTxs.length),
                      ),
                    ),
                  ],
                );
              }),

            if (provider.isLoadingMore)
              const SliverToBoxAdapter(child: ReportLoadMoreTileSkeleton()),

            // Ruang gulir akhir mengikuti pola laporan lain agar kartu terakhir
            // dapat melewati area navigation bar Android, termasuk mode 3 tombol.
            SliverToBoxAdapter(
              child: SizedBox(
                height: 24 + MediaQuery.paddingOf(context).bottom,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<IncomeDetailTransaction> _filterTransactions(
    List<IncomeDetailTransaction> list,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return list;
    return list.where((tx) {
      return tx.pelangganNama.toLowerCase().contains(query) ||
          tx.transactionId.toLowerCase().contains(query) ||
          tx.metodeNama.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildTransactionCard(IncomeDetailTransaction tx) {
    Color typeColor;
    Color typeBgColor;
    final isDeposit = _isDepositTransaction(tx);
    switch (tx.paymentType.toLowerCase()) {
      case 'top up deposit':
        typeColor = const Color(0xFF16A765);
        typeBgColor = const Color(0xFFECFDF5);
        break;
      case 'lunas':
        typeColor = const Color(0xFF10B981); // Green
        typeBgColor = const Color(0xFFECFDF5);
        break;
      case 'dp':
        typeColor = const Color(0xFF8B5CF6); // Purple
        typeBgColor = const Color(0xFFF3E8FF);
        break;
      case 'pelunasan':
      default:
        typeColor = const Color(0xFF3B82F6); // Blue
        typeBgColor = const Color(0xFFEFF6FF);
        break;
    }

    final String category = _detectKategori(tx.metodeNama);
    final String assetPath = _resolveAsset(tx.metodeNama, category);
    final String activityLabel = switch (tx.paymentType.toLowerCase()) {
      'koreksi deposit' => 'Koreksi',
      'refund deposit' => 'Refund',
      _ => 'Top Up',
    };
    final String paymentDate = DateFormat(
      'dd MMM yyyy',
    ).format(tx.tanggalPembayaran);
    final String transactionDate = DateFormat(
      'dd MMM yyyy',
    ).format(tx.tanggalTransaksi);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _openTransaction(tx);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        tx.pelangganNama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: AppFont.w800,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmt.format(tx.nominalBayar),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w800,
                        color: kPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _IncomeChip(
                      label: tx.paymentType.toUpperCase(),
                      color: typeColor,
                      bgColor: typeBgColor,
                    ),
                    const SizedBox(width: 6),
                    _PaymentMethodChip(
                      label: tx.metodeNama,
                      assetPath: assetPath,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _IncomeInfoLine(
                        icon: Icons.calendar_today_rounded,
                        text: isDeposit
                            ? '$activityLabel $paymentDate'
                            : 'Dibayar $paymentDate',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _IncomeInfoLine(
                        icon: Icons.receipt_long_rounded,
                        text: isDeposit
                            ? 'Deposit ${tx.depositType.toUpperCase() == 'KG' ? 'Kiloan' : 'Rupiah'}'
                            : 'TRX $transactionDate',
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF2E8E4)),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isDeposit ? tx.paymentType : tx.transactionId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: AppFont.w700,
                          color: Color(0xFFAAA09B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDeposit
                          ? 'Saldo: ${_depositBalance(tx)}'
                          : 'Nota: ${_fmt.format(tx.totalAkhir)}',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w800,
                        color: Color(0xFF9B908B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFFAAA09B),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTransaction(IncomeDetailTransaction tx) async {
    final isDeposit = _isDepositTransaction(tx);
    if (!isDeposit) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailPesananScreen(transactionId: tx.transactionId),
        ),
      );
      if (mounted) _fetchData();
      return;
    }

    if (tx.customerId.isEmpty) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Detail top up belum memiliki referensi',
          isError: true,
        );
      }
      return;
    }

    final depositProvider = context.read<CustomerDepositProvider>();
    try {
      await depositProvider.fetch(tx.customerId);
      if (!mounted) return;
      CustomerDepositLedgerEntry? entry;
      for (final item in depositProvider.ledger) {
        if (tx.referenceId.isNotEmpty && item.referenceId == tx.referenceId) {
          entry = item;
          break;
        }
      }
      // Support top-ups created before the ledger reference was persisted.
      // Prefer the closest matching amount/type so older report rows remain
      // openable while new rows use the exact top-up reference above.
      if (entry == null) {
        final candidates = depositProvider.ledger.where((item) {
          return item.entryType.toUpperCase() == 'TOP_UP' &&
              (tx.depositType.isEmpty ||
                  item.depositType.toUpperCase() ==
                      tx.depositType.toUpperCase()) &&
              ((item.amount - tx.nominalBayar).abs() < 0.01 ||
                  (item.amount - tx.totalAkhir).abs() < 0.01);
        }).toList();
        if (candidates.isNotEmpty) {
          candidates.sort((a, b) {
            final aDistance = a.createdAt == null
                ? double.maxFinite
                : a.createdAt!
                      .difference(tx.tanggalPembayaran)
                      .abs()
                      .inSeconds
                      .toDouble();
            final bDistance = b.createdAt == null
                ? double.maxFinite
                : b.createdAt!
                      .difference(tx.tanggalPembayaran)
                      .abs()
                      .inSeconds
                      .toDouble();
            return aDistance.compareTo(bDistance);
          });
          entry = candidates.first;
        }
      }
      if (entry == null) {
        final candidates = depositProvider.ledger.where((item) {
          return item.entryType.toUpperCase() == 'TOP_UP' &&
              (tx.depositType.isEmpty ||
                  item.depositType.toUpperCase() ==
                      tx.depositType.toUpperCase());
        }).toList();
        if (candidates.isNotEmpty) {
          candidates.sort((a, b) {
            final aDistance = a.createdAt == null
                ? double.maxFinite
                : a.createdAt!
                      .difference(tx.tanggalPembayaran)
                      .abs()
                      .inSeconds
                      .toDouble();
            final bDistance = b.createdAt == null
                ? double.maxFinite
                : b.createdAt!
                      .difference(tx.tanggalPembayaran)
                      .abs()
                      .inSeconds
                      .toDouble();
            return aDistance.compareTo(bDistance);
          });
          entry = candidates.first;
        }
      }
      if (entry == null) {
        CustomToast.show(
          context,
          message: 'Detail top up tidak ditemukan',
          isError: true,
        );
        return;
      }
      final customer = Customer(
        id: tx.customerId,
        outletId: '',
        kode: '',
        name: tx.pelangganNama,
        phone: '',
        gender: '',
        address: '',
        status: 1,
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CustomerDepositDetailScreen(customer: customer, entry: entry!),
        ),
      );
    } catch (_) {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Gagal memuat detail top up',
          isError: true,
        );
      }
    }
  }

  bool _isDepositTransaction(IncomeDetailTransaction tx) =>
      tx.sourceType.toUpperCase() == 'DEPOSIT_TOP_UP' ||
      tx.paymentType.toLowerCase() == 'top up deposit' ||
      (tx.transactionId.isEmpty && tx.referenceId.isNotEmpty);

  String _depositBalance(IncomeDetailTransaction tx) =>
      tx.depositType.toUpperCase() == 'KG'
      ? '${formatCompactQuantity(tx.balanceAfter)} Kg'
      : _fmt.format(tx.balanceAfter);

  String _detectKategori(String nama) {
    final n = nama.toLowerCase();
    if (n.contains('qris')) return 'QRIS';
    if (n.contains('transfer') ||
        n.contains('bank') ||
        n.contains('bca') ||
        n.contains('bni') ||
        n.contains('bri')) {
      return 'Transfer';
    }
    if (n.contains('gopay') || n.contains('ovo') || n.contains('dana')) {
      return 'E-Wallet';
    }
    return 'Cash';
  }

  String _resolveAsset(String nama, String kategori) {
    String? path;
    if (kategori == 'Transfer') {
      path = PaymentAssetUtil.getBankLogo(nama);
    } else if (kategori == 'E-Wallet') {
      path = PaymentAssetUtil.getEwalletLogo(nama);
    }
    return path ?? PaymentAssetUtil.getCategoryImage(kategori);
  }
}

class _IncomeSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _IncomeSearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) => AppSearchField(
    controller: controller,
    onChanged: onChanged,
    onClear: () {
      controller.clear();
      onChanged('');
    },
    hintText: 'Cari nota atau pelanggan',
    height: 48,
  );
}

class _IncomeChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _IncomeChip({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: TextStyle(fontSize: 9.2, fontWeight: AppFont.w900, color: color),
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final String assetPath;

  const _PaymentMethodChip({required this.label, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFECEFF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            assetPath,
            width: 12,
            height: 12,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.payment_rounded,
              size: 11,
              color: Color(0xFF9AA1AA),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: AppFont.w800,
                color: Color(0xFF6D747D),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IncomeInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12, color: const Color(0xFFB9AEA9)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF8E817B),
              fontWeight: AppFont.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget Function(double shrinkOffset) child;

  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;
  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child(shrinkOffset);

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.minHeight != minHeight ||
      oldDelegate.maxHeight != maxHeight ||
      oldDelegate.child != child;
}
