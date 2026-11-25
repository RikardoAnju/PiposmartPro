import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../providers/koin_provider.dart';
import '../../../data/models/koin_model.dart';
import 'detail_history_koin.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';

class HistoryKoinScreen extends StatefulWidget {
  const HistoryKoinScreen({super.key});

  @override
  State<HistoryKoinScreen> createState() => _HistoryKoinScreenState();
}

class _HistoryKoinScreenState extends State<HistoryKoinScreen> {
  int _activeTab = 0;
  int? _selectedMonth;
  int? _selectedYear;
  final Set<String> _expandedMonths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KoinProvider>().fetchHistoryKoin();
    });
  }

  bool _isMasuk(HistoryKoinModel item) {
    final jenis = item.jenis.toLowerCase().trim();
    return jenis == 'masuk' || jenis == 'topup' || jenis == 'top_up';
  }

  bool _isKeluar(HistoryKoinModel item) {
    final jenis = item.jenis.toLowerCase().trim();
    return jenis == 'keluar' || jenis == 'pemakaian';
  }

  List<HistoryKoinModel> _applyFilter(List<HistoryKoinModel> data) {
    var result = List<HistoryKoinModel>.from(data);

    if (_activeTab == 1) {
      result = result.where(_isMasuk).toList();
    } else if (_activeTab == 2) {
      result = result.where(_isKeluar).toList();
    }

    if (_selectedMonth != null) {
      result = result
          .where((item) => item.createdAt.month == _selectedMonth)
          .toList();
    }

    if (_selectedYear != null) {
      result = result
          .where((item) => item.createdAt.year == _selectedYear)
          .toList();
    }

    result.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            backgroundColor: const Color(0xFFF8F9FA),
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.black,
                size: 14,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        title: const Text(
          "Mutasi Terakhir",
          style: TextStyle(
            color: Colors.black,
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.black),
            onPressed: () => _showFilterModal(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _buildTabs(),
          Expanded(
            child: Consumer<KoinProvider>(
              builder: (context, prov, _) {
                if (prov.isLoading && prov.history.isEmpty) {
                  return const KoinHistorySkeleton();
                }

                final filteredList = _applyFilter(prov.history);

                if (filteredList.isEmpty) {
                  return _buildEmptyState();
                }

                final Map<String, List<HistoryKoinModel>> grouped = {};
                for (final item in filteredList) {
                  final key = DateFormat(
                    'MMMM yyyy',
                    'id_ID',
                  ).format(item.createdAt);
                  grouped.putIfAbsent(key, () => []);
                  grouped[key]!.add(item);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 120),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, index) {
                    final monthKey = grouped.keys.elementAt(index);
                    final items = grouped[monthKey]!;
                    final isExpanded = _expandedMonths.contains(monthKey);

                    final totalKeluar = items
                        .where(_isKeluar)
                        .fold<int>(
                          0,
                          (sum, item) =>
                              sum + (int.tryParse(item.jumlah.toString()) ?? 0),
                        );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () {
                            setState(() {
                              if (isExpanded) {
                                _expandedMonths.remove(monthKey);
                              } else {
                                _expandedMonths.add(monthKey);
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      monthKey,
                                      style: const TextStyle(
                                        fontWeight: AppFont.w900,
                                        fontSize: 13,
                                        color: Color(0xFF2D3436),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F3F5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        "${items.length} transaksi",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: AppFont.w700,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (totalKeluar > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF5F5),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppPalette.primaryBorderStrong,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      "-$totalKeluar Koin",
                                      style: const TextStyle(
                                        color: Color(0xFFC92A2A),
                                        fontWeight: AppFont.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          firstChild: const SizedBox.shrink(),
                          secondChild: Column(
                            children: items
                                .map((item) => _buildMutationRow(item))
                                .toList(),
                          ),
                          crossFadeState: isExpanded
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          duration: const Duration(milliseconds: 250),
                          sizeCurve: Curves.easeInOut,
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                      ],
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

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _buildTabItem(0, "Semua"),
            _buildTabItem(1, "Top Up"),
            _buildTabItem(2, "Pemakaian"),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isActive = _activeTab == index;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isActive ? AppFont.w800 : AppFont.w600,
              color: isActive ? AppPalette.primary : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMutationRow(HistoryKoinModel item) {
    final isMasuk = _isMasuk(item);
    String title = item.keterangan;

    final lowerTitle = title.toLowerCase();

    if (lowerTitle.contains("laundry") ||
        lowerTitle.contains("trx/") ||
        lowerTitle.contains("pemakaian koin")) {
      title = "Transaksi Laundry";
    } else if (lowerTitle.contains("referral")) {
      title = "Bonus Referral";
    } else if (lowerTitle.contains("outlet baru")) {
      title = "Bonus Outlet";
    } else if (lowerTitle.contains("top up") || lowerTitle.contains("topup")) {
      title = "Top Up";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetailHistoryKoinScreen(item: item),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFF1F3F5), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isMasuk
                      ? const Color(0xFFE6FCF5)
                      : const Color(0xFFFFF5F5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMasuk
                      ? Icons.add_circle_outline_rounded
                      : Icons.local_laundry_service_rounded,
                  color: isMasuk
                      ? const Color(0xFF087F5B)
                      : const Color(0xFFC92A2A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 14,
                        color: Color(0xFF2D3436),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF636E72),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat(
                        'dd MMMM yyyy, HH:mm',
                        'id_ID',
                      ).format(item.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w600,
                        color: Colors.grey.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 82,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        "${isMasuk ? '+' : '-'}${item.jumlah} Koin",
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: AppFont.w900,
                          fontSize: 14,
                          color: isMasuk
                              ? const Color(0xFF087F5B)
                              : const Color(0xFFC92A2A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Sukses",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFont.w800,
                        color: isMasuk
                            ? const Color(0xFF087F5B)
                            : const Color(0xFFC92A2A),
                      ),
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

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "Tidak ada riwayat mutasi",
        style: TextStyle(color: Colors.grey, fontWeight: AppFont.w700),
      ),
    );
  }

  void _showFilterModal(BuildContext context) {
    int? tempMonth = _selectedMonth;
    int? tempYear = _selectedYear;

    final currentYear = DateTime.now().year;
    final years = List.generate(8, (index) => currentYear - index);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9ECEF),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            modalSetState(() {
                              tempMonth = null;
                              tempYear = null;
                            });
                            setState(() {
                              _selectedMonth = null;
                              _selectedYear = null;
                            });
                          },
                          child: const Text(
                            "Reset",
                            style: TextStyle(
                              color: AppPalette.primary,
                              fontWeight: AppFont.w800,
                            ),
                          ),
                        ),
                        const Text(
                          "Filters",
                          style: TextStyle(
                            fontWeight: AppFont.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 58),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Filter Berdasarkan",
                      style: TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDropdown<int>(
                            value: tempMonth,
                            hint: "Bulan",
                            items: List.generate(12, (index) => index + 1),
                            labelBuilder: (month) {
                              return DateFormat.MMMM(
                                'id_ID',
                              ).format(DateTime(2026, month));
                            },
                            onChanged: (value) {
                              modalSetState(() {
                                tempMonth = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdown<int>(
                            value: tempYear,
                            hint: "Tahun",
                            items: years,
                            labelBuilder: (year) => year.toString(),
                            onChanged: (value) {
                              modalSetState(() {
                                tempYear = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedMonth = tempMonth;
                          _selectedYear = tempYear;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppPalette.primaryWarm,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        "Terapkan",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: AppFont.w900,
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

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T value) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey,
          ),
          hint: Text(
            hint,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: AppFont.w700,
              fontSize: 13,
            ),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(
                labelBuilder(item),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2D3436),
                  fontWeight: AppFont.w700,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
