import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/queue_item_model.dart';
import 'package:ayocucinew/providers/summary_provider.dart';
import 'package:ayocucinew/screens/ringkasan/widgets/queue_card.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class SummaryDetailScreen extends StatefulWidget {
  final String category;
  const SummaryDetailScreen({super.key, required this.category});

  @override
  State<SummaryDetailScreen> createState() => _SummaryDetailScreenState();
}

class _SummaryDetailScreenState extends State<SummaryDetailScreen> {
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  String? _filterLabel;

  static const _primaryColor = AppPalette.primary;

  static const _quickFilters = [
    ('Hari Ini', 0),
    ('Kemarin', 1),
    ('Minggu Ini', 7),
    ('Bulan Ini', 30),
  ];

  bool get _hasActiveFilter =>
      _filterStartDate != null && _filterEndDate != null;

  List<QueueItem> _applyDateFilter(List<QueueItem> items) {
    if (widget.category != "Pesanan Terlambat") return items;
    if (!_hasActiveFilter) return items;
    return items.where((item) {
      final date = item.tglMasuk;
      final start = DateTime(
        _filterStartDate!.year,
        _filterStartDate!.month,
        _filterStartDate!.day,
      );
      final end = DateTime(
        _filterEndDate!.year,
        _filterEndDate!.month,
        _filterEndDate!.day,
        23,
        59,
        59,
      );
      return !date.isBefore(start) && !date.isAfter(end);
    }).toList();
  }

  void _showFilterSheet() {
    DateTime? tempStart = _filterStartDate;
    DateTime? tempEnd = _filterEndDate;
    String? tempLabel = _filterLabel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void setQuickFilter(String label, int days) {
              setModalState(() {
                tempLabel = label;
                final now = DateTime.now();
                if (label == 'Kemarin') {
                  final yesterday = now.subtract(const Duration(days: 1));
                  tempStart = yesterday;
                  tempEnd = yesterday;
                } else {
                  tempStart = now.subtract(Duration(days: days));
                  tempEnd = now;
                }
              });
            }

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(35)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 15),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Filter Transaksi',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: AppFont.w900,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Pilihan Cepat',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _quickFilters.map((f) {
                                final isActive = tempLabel == f.$1;
                                final width =
                                    (MediaQuery.of(context).size.width - 68) /
                                    2;
                                return GestureDetector(
                                  onTap: () => setQuickFilter(f.$1, f.$2),
                                  child: Container(
                                    width: width,
                                    height: 45,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? _primaryColor.withValues(
                                              alpha: 0.05,
                                            )
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isActive
                                            ? _primaryColor
                                            : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      f.$1,
                                      style: TextStyle(
                                        color: isActive
                                            ? _primaryColor
                                            : Colors.black,
                                        fontWeight: isActive
                                            ? AppFont.w900
                                            : AppFont.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Pilih Rentang Tanggal',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDatePickerField(
                                    context: context,
                                    label: 'Tanggal Mulai',
                                    value: tempStart,
                                    onPick: (d) => setModalState(() {
                                      tempStart = d;
                                      tempLabel = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDatePickerField(
                                    context: context,
                                    label: 'Tanggal Akhir',
                                    value: tempEnd,
                                    onPick: (d) => setModalState(() {
                                      tempEnd = d;
                                      tempLabel = null;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setState(() {
                                        _filterStartDate = null;
                                        _filterEndDate = null;
                                        _filterLabel = null;
                                      });
                                      Navigator.pop(context);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Reset',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontWeight: AppFont.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (tempStart == null ||
                                          tempEnd == null) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Pilih rentang tanggal',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      final fmt = DateFormat('dd/MM/yyyy');
                                      setState(() {
                                        _filterStartDate = tempStart;
                                        _filterEndDate = tempEnd;
                                        _filterLabel =
                                            tempLabel ??
                                            '${fmt.format(tempStart!)} - ${fmt.format(tempEnd!)}';
                                      });
                                      Navigator.pop(context);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Terapkan',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: AppFont.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required Function(DateTime) onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: AppFont.w700,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              initialDate: value ?? DateTime.now(),
              builder: (context, child) => Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: _primaryColor),
                ),
                child: child!,
              ),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    value == null
                        ? 'dd/mm/yyyy'
                        : DateFormat('dd/MM/yyyy').format(value),
                    style: TextStyle(
                      color: value == null ? Colors.grey : Colors.black,
                      fontSize: 12,
                      fontWeight: AppFont.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.calendar_month, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: Text(
          widget.category,
          style: const TextStyle(fontWeight: AppFont.w800),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    hintText: "Cari transaksi",
                  ),
                ),
                if (widget.category == "Pesanan Terlambat") ...[
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showFilterSheet,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _hasActiveFilter
                            ? _primaryColor
                            : Colors.orange.shade800,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.colored(
                          _hasActiveFilter
                              ? _primaryColor
                              : Colors.orange.shade800,
                        ),
                      ),
                      child: const Icon(
                        Icons.tune,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_hasActiveFilter && widget.category == "Pesanan Terlambat")
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 14, color: _primaryColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _filterLabel ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _filterStartDate = null;
                      _filterEndDate = null;
                      _filterLabel = null;
                    }),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: _primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          Consumer<SummaryProvider>(
            builder: (context, provider, child) {
              List<QueueItem> items = provider.getItemsByCategory(
                widget.category,
              );
              items = _applyDateFilter(items);

              if (_searchQuery.isNotEmpty) {
                items = items
                    .where(
                      (item) =>
                          item.pelangganNama.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          item.id.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ),
                    )
                    .toList();
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: _buildCategoryHeader(widget.category, items.length),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Consumer<SummaryProvider>(
              builder: (context, provider, child) {
                List<QueueItem> items = provider.getItemsByCategory(
                  widget.category,
                );
                items = _applyDateFilter(items);

                if (_searchQuery.isNotEmpty) {
                  items = items
                      .where(
                        (item) =>
                            item.pelangganNama.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ) ||
                            item.id.toLowerCase().contains(
                              _searchQuery.toLowerCase(),
                            ),
                      )
                      .toList();
                }

                if (items.isEmpty) {
                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      MediaQuery.paddingOf(context).bottom + 72,
                    ),
                    children: [_buildNoDataView()],
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    MediaQuery.paddingOf(context).bottom + 72,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return QueueCard(
                      item: item,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              DetailPesananScreen(transactionId: item.id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(String category, int count) {
    Color bgColor;
    IconData icon;

    switch (category) {
      case "Pesanan Terlambat":
        bgColor = Colors.red.shade800;
        icon = Icons.warning_amber_rounded;
        break;
      case "Harus Selesai":
        bgColor = Colors.orange.shade600;
        icon = Icons.hourglass_empty_rounded;
        break;
      case "Baru Masuk":
        bgColor = Colors.lightBlue.shade600;
        icon = Icons.local_laundry_service_outlined;
        break;
      case "Selesai":
        bgColor = Colors.green.shade600;
        icon = Icons.check_circle_outline_rounded;
        break;
      default:
        bgColor = Colors.deepOrange.shade800;
        icon = Icons.list_alt_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppShadows.colored(bgColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Total $category",
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                "$count Transaksi",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: AppFont.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataView() {
    return const Padding(
      padding: EdgeInsets.only(top: 60),
      child: EmptyStateWidget.ringkasan(
        title: "Tidak Ada Data",
        message: "Saat ini belum ada data yang dapat ditampilkan",
      ),
    );
  }
}
