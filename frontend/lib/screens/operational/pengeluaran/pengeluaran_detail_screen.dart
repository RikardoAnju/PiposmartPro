import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/pengeluaran/pengeluaran_detail_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/pengeluaran_model.dart';
import '../../../../providers/pengeluaran_provider.dart';
import '../../../../shared/widgets/currency_formatter.dart';
import 'pengeluaran_item_detail_screen.dart';

class PengeluaranDetailScreen extends StatefulWidget {
  final String date;

  const PengeluaranDetailScreen({super.key, required this.date});

  @override
  State<PengeluaranDetailScreen> createState() =>
      _PengeluaranDetailScreenState();
}

class _PengeluaranDetailScreenState extends State<PengeluaranDetailScreen> {
  String _selectedCategory = "Semua";

  @override
  Widget build(BuildContext context) {
    final allExpenses = context.watch<PengeluaranProvider>().expenses;

    List<Pengeluaran> currentItems = allExpenses.where((e) {
      String itemDate = DateFormat('dd MMMM yyyy', 'id').format(e.tanggal);
      return itemDate == widget.date;
    }).toList();

    List<Pengeluaran> filteredItems = currentItems.where((item) {
      if (_selectedCategory == "Semua") return true;
      return (item.kategoriNama) == _selectedCategory;
    }).toList();

    filteredItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    List<String> dynamicCategories = [
      "Semua",
      ...currentItems.map((e) => e.kategoriNama).toSet(),
    ];

    double dynamicTotalDay = currentItems.fold(
      0.0,
      (sum, item) => sum + item.total,
    );

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Detail Pengeluaran",
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSummaryCard(dynamicTotalDay, currentItems.length),

          // --- FILTER KATEGORI ---
          Container(
            height: 75,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: dynamicCategories.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedCategory == dynamicCategories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    label: Text(dynamicCategories[index]),
                    selected: isSelected,
                    onSelected: (val) => setState(
                      () => _selectedCategory = dynamicCategories[index],
                    ),
                    selectedColor: AppPalette.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? AppFont.w900 : AppFont.w700,
                      fontSize: 13,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.shade200,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          // --- LIST TRANSAKSI ---
          Expanded(
            child: filteredItems.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      return _buildModernTransactionCard(context, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "Data tidak ditemukan",
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: AppFont.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTransactionCard(BuildContext context, Pengeluaran item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PengeluaranItemDetailScreen(item: item),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shortExpenseDescription(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: AppFont.w600,
                          color: Colors.blueGrey.shade300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Text(
                        DateFormat('HH:mm').format(item.createdAt.toLocal()),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: AppFont.w900,
                          color: AppPalette.primary.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.kategoriNama,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: AppFont.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.formatToRupiah(item.total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w900,
                        color: AppPalette.danger,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Color(0xFFB7BDC5),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _shortExpenseDescription(Pengeluaran item) {
    final text = item.keterangan.trim();
    if (text.isEmpty) return 'Tanpa keterangan';
    if (item.isPayrollSource &&
        text.toLowerCase().startsWith('pembayaran gaji ')) {
      return text
          .replaceFirst(
            RegExp(r'^Pembayaran gaji ', caseSensitive: false),
            'Gaji ',
          )
          .replaceFirst(' - ', ' • ');
    }
    return text;
  }

  Widget _buildSummaryCard(double total, int totalTransaksi) {
    return Container(
      width: double.infinity,
      height: 136,
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: AppPalette.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            right: -15,
            bottom: -15,
            child: Opacity(
              opacity: 0.1,
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.date.toUpperCase(),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$totalTransaksi',
                            style: const TextStyle(
                              color: AppPalette.primary,
                              fontSize: 15,
                              fontWeight: AppFont.w900,
                            ),
                          ),
                          const Text(
                            'Transaksi',
                            style: TextStyle(
                              color: AppPalette.primary,
                              fontSize: 7,
                              fontWeight: AppFont.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatToRupiah(total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: AppFont.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
