import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/finance_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TransactionSummaryModal extends StatefulWidget {
  final List<OmsetDetail> transactions;
  final DateTime startDate;
  final DateTime endDate;

  const TransactionSummaryModal({
    super.key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
  });

  static Future<void> show(
    BuildContext context, {
    required List<OmsetDetail> transactions,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TransactionSummaryModal(
        transactions: transactions,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  @override
  State<TransactionSummaryModal> createState() =>
      _TransactionSummaryModalState();
}

class _TransactionSummaryModalState extends State<TransactionSummaryModal> {
  int _activeTab = 0;

  static const Color _primary = AppPalette.primary;
  static const Color _textDark = Color(0xFF241815);
  static const Color _textSoft = Color(0xFF8C6E66);

  String _normalizeStatus(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll('_', ' ')
        .replaceAll('-', ' ');
    if (normalized.contains('siap') && normalized.contains('ambil')) {
      return 'siap ambil';
    }
    if (normalized.contains('antrian')) {
      return 'antrian';
    }
    if (normalized.contains('proses')) {
      return 'proses';
    }
    if (normalized.contains('selesai')) {
      return 'selesai';
    }
    return normalized;
  }

  int _countStatus(String statusKey) {
    return widget.transactions
        .where((item) => _normalizeStatus(item.statusOrder) == statusKey)
        .length;
  }

  String _buildPeriodLabel() {
    final fmt = DateFormat('d MMM yyyy', 'id_ID');
    final sameDay =
        widget.startDate.year == widget.endDate.year &&
        widget.startDate.month == widget.endDate.month &&
        widget.startDate.day == widget.endDate.day;
    if (sameDay) return fmt.format(widget.startDate);
    return '${fmt.format(widget.startDate)} - ${fmt.format(widget.endDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final totalTransaksi = widget.transactions.length;
    final antrian = _countStatus('antrian');
    final proses = _countStatus('proses');
    final siapAmbil = _countStatus('siap ambil');
    final selesai = _countStatus('selesai');

    final totalDiskon = widget.transactions.fold(
      0.0,
      (sum, item) => sum + item.potonganDiskon,
    );
    final totalAntarJemput = widget.transactions.fold(
      0.0,
      (sum, item) => sum + (item.jemputBiaya ?? 0) + (item.antarBiaya ?? 0),
    );

    final cards = [
      _StatusSummaryItem(
        label: 'Semua Pesanan',
        helper: 'Total seluruh transaksi.',
        total: totalTransaksi,
        accent: _primary,
        icon: Icons.receipt_long_rounded,
      ),
      _StatusSummaryItem(
        label: 'Antrian',
        helper: 'Menunggu mulai dikerjakan.',
        total: antrian,
        accent: const Color(0xFFFF8A5B),
        icon: Icons.schedule_rounded,
      ),
      _StatusSummaryItem(
        label: 'Proses',
        helper: 'Sedang dicuci atau disetrika.',
        total: proses,
        accent: const Color(0xFFF6A93B),
        icon: Icons.local_laundry_service_rounded,
      ),
      _StatusSummaryItem(
        label: 'Siap Ambil',
        helper: 'Siap diinformasikan ke pelanggan.',
        total: siapAmbil,
        accent: const Color(0xFF2DBE7F),
        icon: Icons.inventory_2_rounded,
      ),
      _StatusSummaryItem(
        label: 'Selesai',
        helper: 'Pesanan sudah diambil pelanggan.',
        total: selesai,
        accent: const Color(0xFF4B8BFF),
        icon: Icons.check_circle_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBDDD8),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
              const Text(
                'Ringkasan Transaksi',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: AppFont.w800,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2EC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFF6D7CC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: _primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _buildPeriodLabel(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w700,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Custom Tab Bar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'Status Pesanan',
                        isActive: _activeTab == 0,
                        onTap: () => setState(() => _activeTab = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        label: 'Lainnya',
                        isActive: _activeTab == 1,
                        onTap: () => setState(() => _activeTab = 1),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              if (_activeTab == 0) ...[
                const Text(
                  'Ikhtisar jumlah pesanan berdasarkan status pada data yang sedang ditampilkan.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: _textSoft,
                    fontWeight: AppFont.w500,
                  ),
                ),
                const SizedBox(height: 18),
                const SizedBox(height: 16),
                GridView.builder(
                  itemCount: cards.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.08,
                  ),
                  itemBuilder: (context, index) =>
                      _StatusSummaryCard(item: cards[index]),
                ),
              ] else ...[
                const Text(
                  'Ikhtisar tambahan untuk total diskon dan biaya layanan antar jemput.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: _textSoft,
                    fontWeight: AppFont.w500,
                  ),
                ),
                const SizedBox(height: 18),
                _AmountCard(
                  title: 'Total Diskon Terpakai',
                  amount: totalDiskon,
                  icon: Icons.local_offer_rounded,
                  color: const Color(0xFFE53935),
                ),
                _AmountCard(
                  title: 'Biaya Antar & Jemput',
                  amount: totalAntarJemput,
                  icon: Icons.local_shipping_rounded,
                  color: const Color(0xFF3B82F6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isActive ? AppFont.w800 : AppFont.w600,
              color: isActive ? AppPalette.primary : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _AmountCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w700,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  NumberFormat.currency(
                    locale: 'id_ID',
                    symbol: 'Rp ',
                    decimalDigits: 0,
                  ).format(amount),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: AppFont.w900,
                    color: color,
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

class _StatusSummaryItem {
  final String label;
  final String helper;
  final int total;
  final Color accent;
  final IconData icon;

  const _StatusSummaryItem({
    required this.label,
    required this.helper,
    required this.total,
    required this.accent,
    required this.icon,
  });
}

class _StatusSummaryCard extends StatelessWidget {
  final _StatusSummaryItem item;

  const _StatusSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5D7CF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 18, color: item.accent),
              ),
              const Spacer(),
              Text(
                item.total.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: AppFont.w900,
                  color: item.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.18,
              fontWeight: AppFont.w800,
              color: Color(0xFF241815),
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.helper,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Color(0xFF8C6E66),
              fontWeight: AppFont.w500,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
