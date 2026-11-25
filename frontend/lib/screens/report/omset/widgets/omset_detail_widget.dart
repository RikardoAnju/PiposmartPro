import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/status/detail/detail_orderan_sereen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';

final _currFmt = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

class OmsetSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const OmsetSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => AppSearchField(
    controller: controller,
    onChanged: onChanged,
    hintText: 'Cari nota atau pelanggan',
    height: 48,
  );
}

class OmsetFilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveFilter;

  const OmsetFilterButton({
    super.key,
    required this.onTap,
    this.hasActiveFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppPalette.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: hasActiveFilter ? primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasActiveFilter
                ? primaryColor
                : Colors.black.withValues(alpha: 0.06),
          ),
          boxShadow: [
            if (hasActiveFilter)
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Icon(
          Icons.tune_rounded,
          size: 22,
          color: hasActiveFilter ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class OmsetSearchFilterRow extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final bool hasActiveFilter;

  const OmsetSearchFilterRow({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    this.hasActiveFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OmsetSearchField(
            controller: searchController,
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 10),
        OmsetFilterButton(onTap: onFilterTap, hasActiveFilter: hasActiveFilter),
      ],
    );
  }
}

class OmsetTotalCard extends StatelessWidget {
  final double total;
  final int totalTransaksi;
  final String? dateLabel;

  const OmsetTotalCard({
    super.key,
    required this.total,
    required this.totalTransaksi,
    this.dateLabel,
  });

  String _formatRupiah(double value) => _currFmt.format(value);

  String _getDateLabel() {
    if (dateLabel != null && dateLabel!.isNotEmpty) return dateLabel!;
    return DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
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
                colors: [AppPalette.primary, AppPalette.primaryWarm],
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
                Icons.wallet_rounded,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Penjualan',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatRupiah(total),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: AppFont.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                              fontSize: 18,
                              fontWeight: AppFont.w900,
                            ),
                          ),
                          const Text(
                            'Transaksi',
                            style: TextStyle(
                              color: AppPalette.primary,
                              fontSize: 8,
                              fontWeight: AppFont.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _getDateLabel(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: AppFont.w700,
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
    );
  }
}

class OmsetTransactionCard extends StatelessWidget {
  final OmsetDetail detail;

  const OmsetTransactionCard({super.key, required this.detail});

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailPesananScreen(transactionId: detail.nomorNota),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLunas = detail.statusPembayaran.toLowerCase() == 'lunas';
    const primaryColor = AppPalette.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _openDetail(context),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        detail.namaPelanggan,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: AppFont.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _currFmt.format(detail.totalHarga),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w900,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (detail.metodePembayaran != null &&
                        detail.metodePembayaran!.isNotEmpty)
                      _StatusBadge(
                        label: detail.metodePembayaran!.toUpperCase(),
                        color: const Color(0xFF3B82F6),
                        bgColor: const Color(0xFFEFF6FF),
                      ),
                    _StatusBadge(
                      label: isLunas ? 'LUNAS' : 'BELUM LUNAS',
                      color: isLunas
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                      bgColor: isLunas
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.radio_button_unchecked_rounded,
                            size: 14,
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Masuk: ${detail.tanggalMasuk}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.5),
                                fontWeight: AppFont.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Colors.black.withValues(alpha: 0.25),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Est: ${detail.tanggalSelesai}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black.withValues(alpha: 0.5),
                                fontWeight: AppFont.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F1F1),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      detail.nomorNota,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w800,
                        color: Colors.black.withValues(alpha: 0.3),
                        letterSpacing: 0.2,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Detail',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFont.w800,
                            color: Colors.black.withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                      ],
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
}

class OmsetCountDateRow extends StatelessWidget {
  final int count;
  final String dateLabel;

  const OmsetCountDateRow({
    super.key,
    required this.count,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          dateLabel,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: AppFont.w600,
            color: Colors.black54,
          ),
        ),
        Text(
          '$count Transaksi',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: AppFont.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 9,
        fontWeight: AppFont.w900,
        color: color,
        letterSpacing: 0.5,
      ),
    ),
  );
}

class OmsetBottomBar extends StatelessWidget {
  final VoidCallback onFilter;
  final bool hasActiveFilter;

  const OmsetBottomBar({
    super.key,
    required this.onFilter,
    this.hasActiveFilter = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onFilter,
            icon: Icon(
              Icons.tune_rounded,
              size: 16,
              color: hasActiveFilter ? AppPalette.primary : Colors.black87,
            ),
            label: Text(
              hasActiveFilter ? 'Filter Aktif' : 'Filter',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w600,
                color: hasActiveFilter ? AppPalette.primary : Colors.black87,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: hasActiveFilter
                    ? AppPalette.primary
                    : const Color(0xFFEEEEEE),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: hasActiveFilter
                  ? AppPalette.primary.withValues(alpha: 0.1)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class OmsetFilterSheet extends StatefulWidget {
  final String? currentStatus;
  final String? currentDate;
  final String? currentSort;

  const OmsetFilterSheet({
    super.key,
    this.currentStatus,
    this.currentDate,
    this.currentSort,
  });

  @override
  State<OmsetFilterSheet> createState() => _OmsetFilterSheetState();
}

class _OmsetFilterSheetState extends State<OmsetFilterSheet> {
  static const Color kPrimary = AppPalette.primary;

  late String _status;
  late DateTime _selectedDate;
  late String _sortBy;

  @override
  void initState() {
    super.initState();
    _status = widget.currentStatus ?? '';
    _selectedDate =
        DateTime.tryParse(widget.currentDate ?? '') ?? DateTime.now();
    _sortBy = widget.currentSort ?? 'Terbaru';
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDate = DateTime(now.year - 2, 1, 1);
    final initialDate = _selectedDate.isBefore(firstDate)
        ? firstDate
        : (_selectedDate.isAfter(today) ? today : _selectedDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: today,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimary,
            onPrimary: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFFBFBFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Filter Laporan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: AppFont.w800,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pilih Tanggal',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: kPrimary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_right_rounded,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Status Pembayaran',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _status.isEmpty ? null : _status,
                  hint: const Text(
                    'Semua Status',
                    style: TextStyle(fontSize: 13),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Semua Status')),
                    DropdownMenuItem(
                      value: 'Belum Lunas',
                      child: Text('Belum Lunas'),
                    ),
                    DropdownMenuItem(value: 'Lunas', child: Text('Lunas')),
                    DropdownMenuItem(value: 'DP', child: Text('DP')),
                  ],
                  onChanged: (val) => setState(() => _status = val ?? ''),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Urutkan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: AppFont.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _sortBy,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Terbaru',
                      child: Text('Waktu Terbaru'),
                    ),
                    DropdownMenuItem(
                      value: 'Terlama',
                      child: Text('Waktu Terlama'),
                    ),
                    DropdownMenuItem(
                      value: 'Nominal Tertinggi',
                      child: Text('Nominal Tertinggi'),
                    ),
                    DropdownMenuItem(
                      value: 'Nominal Terendah',
                      child: Text('Nominal Terendah'),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _sortBy = val ?? 'Terbaru'),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, {
              'status': _status,
              'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
              'sortBy': _sortBy,
            }),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Terapkan Filter',
              style: TextStyle(fontSize: 15, fontWeight: AppFont.w900),
            ),
          ),
        ),
      ),
    );
  }
}

class OmsetExportDialog extends StatelessWidget {
  const OmsetExportDialog({super.key});

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    backgroundColor: Colors.white,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              color: AppPalette.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Export Laporan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: AppFont.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih format export laporan',
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 22),
          _ExportButton(
            label: 'Export Excel (.xlsx)',
            icon: Icons.table_chart_outlined,
            iconColor: const Color(0xFF10B981),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 10),
          _ExportButton(
            label: 'Export PDF',
            icon: Icons.picture_as_pdf_outlined,
            iconColor: AppPalette.primary,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 50,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: iconColor),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: AppFont.w600,
          color: Colors.black87,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFEEEEEE)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.center,
      ),
    ),
  );
}
