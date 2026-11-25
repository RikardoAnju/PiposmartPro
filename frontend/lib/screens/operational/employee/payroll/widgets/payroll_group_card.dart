part of '../../payroll_screen.dart';

class _PayrollGroupCard extends StatefulWidget {
  final Map<String, dynamic> group;
  final void Function(Map<String, dynamic> item) onTapItem;
  final bool compact;
  final bool showPeriod;

  const _PayrollGroupCard({
    required this.group,
    required this.onTapItem,
    this.compact = false,
    this.showPeriod = false,
  });

  @override
  State<_PayrollGroupCard> createState() => _PayrollGroupCardState();
}

class _PayrollGroupCardState extends State<_PayrollGroupCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final items =
        (widget.group['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    _expanded = !widget.compact && items.length == 1;
  }

  @override
  void didUpdateWidget(covariant _PayrollGroupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldItems =
        (oldWidget.group['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final newItems =
        (widget.group['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    if (widget.compact) {
      _expanded = false;
      return;
    }
    if (!widget.compact && oldItems.length != newItems.length && newItems.length == 1) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final name = group['pegawai_nama']?.toString() ?? '-';
    final items =
        (group['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];
    final first = items.isNotEmpty ? items.last : const <String, dynamic>{};
    final totalBase = items.fold<double>(
      0,
      (total, item) => total + PayrollProvider.toNum(item['base_amount']),
    );
    final totalBonus = items.fold<double>(
      0,
      (total, item) => total + PayrollProvider.toNum(item['bonus_amount']),
    );
    final totalDeduction = items.fold<double>(
      0,
      (total, item) => total + PayrollProvider.toNum(item['deduction_amount']),
    );

    final totalAmount = (totalBase + totalBonus - totalDeduction).clamp(
      0,
      double.infinity,
    );
    final detailItem = <String, dynamic>{
      ...first,
      'base_amount': totalBase,
      'bonus_amount': totalBonus,
      'deduction_amount': totalDeduction,
      'net_amount': totalAmount,
      'work_days': items.fold<int>(
        0,
        (total, item) => total + PayrollProvider.toNum(item['work_days']).toInt(),
      ),
      'alfa_days': items.fold<int>(
        0,
        (total, item) => total + PayrollProvider.toNum(item['alfa_days']).toInt(),
      ),
      'overtime_minutes': items.fold<int>(
        0,
        (total, item) => total + PayrollProvider.toNum(item['overtime_minutes']).toInt(),
      ),
      '_item_ids': (first['_item_ids'] is List &&
              (first['_item_ids'] as List).isNotEmpty)
          ? List<String>.from(
              (first['_item_ids'] as List).map((e) => e.toString()),
            )
          : items
              .map((item) => item['id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList(),
      '_combined': first['_combined'] == true || items.length > 1,
    };
    final totalLabel = PayrollProvider.formatCurrency(totalAmount);
    final statusLabel = PayrollProvider.payrollStatusLabel(first);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEDEFF3)),
          boxShadow: AppShadows.cardSoft,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: items.isEmpty
                    ? null
                    : () => widget.onTapItem(detailItem),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppPalette.ink,
                                      fontWeight: AppFont.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _StatusBadge(status: statusLabel),
                              ],
                            ),
                            if (widget.showPeriod && items.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                PayrollProvider.formatPeriodLong(first),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppPalette.muted,
                                  fontSize: 10.5,
                                  fontWeight: AppFont.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total Gaji',
                          style: const TextStyle(
                            color: AppPalette.muted,
                            fontSize: 11,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        totalLabel,
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppPalette.success,
                          fontSize: 15,
                          height: 1.0,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.compact && items.isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => widget.onTapItem(detailItem),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEDEFF3)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lihat rincian penggajian',
                            style: TextStyle(
                              color: AppPalette.ink,
                              fontSize: 12,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (items.isNotEmpty && !widget.compact)
                AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _expanded
                    ? Padding(
                        key: const ValueKey('expanded'),
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: [
                            ...items.asMap().entries.map(
                              (entry) => Padding(
                                padding: EdgeInsets.only(
                                  bottom: entry.key == items.length - 1
                                      ? 0
                                      : 10,
                                ),
                                child: _PayrollStackItemTile(
                                  item: entry.value,
                                  showAmount: items.length > 1,
                                  onTap: () => widget.onTapItem(entry.value),
                                ),
                              ),
                            ),
                            if (items.length > 1) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () =>
                                      setState(() => _expanded = false),
                                  label: const Text('Sembunyikan'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppPalette.primary,
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: AppFont.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : Padding(
                        key: const ValueKey('collapsed'),
                        padding: const EdgeInsets.only(top: 12),
                        child: _CollapsedPayrollPreview(
                          items: items,
                          onToggle: items.length > 1
                              ? (widget.compact
                                    ? null
                                    : () => setState(() => _expanded = true))
                              : null,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollapsedPayrollPreview extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback? onToggle;

  const _CollapsedPayrollPreview({required this.items, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final dueDates = items
        .map((e) => PayrollProvider.formatDate(e['due_date']))
        .where((v) => v.isNotEmpty && v != '-')
        .toList();
    final dueText = dueDates.isEmpty
        ? '-'
        : dueDates.length == 1
        ? dueDates.first
        : '${dueDates.first} - ${dueDates.last}';
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEDEFF3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jadwal $dueText',
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 12.5,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Ketuk untuk melihat detail item payroll',
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayrollStackItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  /// Tampilkan nominal per-item. Untuk grup 1 item, nominal sudah ada di
  /// "Total Gaji" sehingga tidak diulang di tile.
  final bool showAmount;

  const _PayrollStackItemTile({
    required this.item,
    required this.onTap,
    this.showAmount = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = PayrollProvider.payrollStatusText(item);
    final isPaid = PayrollProvider.isPaidPayrollStatus(status);
    final due = PayrollProvider.formatDate(item['due_date']);
    final title = due.isNotEmpty && due != '-'
        ? due
        : PayrollProvider.formatPeriod(item);
    final salaryType = PayrollProvider.salaryTypeLabel(
      item['salary_type']?.toString(),
    );
    final amount = PayrollProvider.formatCurrency(
      PayrollProvider.toNum(item['net_amount']),
    );

    return Material(
      color: const Color(0xFFF9FAFC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEDEFF3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 12.5,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      salaryType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (showAmount)
                    Text(
                      amount,
                  style: TextStyle(
                    color: isPaid ? AppPalette.success : AppPalette.primary,
                    fontSize: 13,
                    fontWeight: AppFont.w900,
                  ),
                )
              else
                Text(
                  isPaid ? 'Lihat riwayat' : 'Lihat detail',
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontSize: 11.5,
                    fontWeight: AppFont.w800,
                  ),
                ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }
}


class _PayrollPeriodSection extends StatelessWidget {
  final Map<String, dynamic> period;
  final void Function(Map<String, dynamic> item) onTapItem;

  const _PayrollPeriodSection({required this.period, required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    final sample =
        (period['sample'] as Map?)?.cast<String, dynamic>() ?? const {};
    final label = PayrollProvider.formatPeriodLong(sample);
    final items =
        (period['items'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.event_note_rounded,
              size: 18,
              color: AppPalette.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 15,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${items.length} pembayaran',
              style: const TextStyle(
                color: AppPalette.muted,
                fontSize: 11,
                fontWeight: AppFont.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == items.length - 1 ? 0 : 10,
            ),
            child: _PayrollGroupCard(
              // Riwayat memakai item pembayaran asli agar slip tiap
              // pembayaran tidak tercampur dengan pembayaran lain.
              group: {
                'pegawai_id': items[i]['pegawai_id'],
                'pegawai_nama': items[i]['pegawai_nama'],
                'role_nama': items[i]['role_nama'],
                'salary_type': items[i]['salary_type'],
                'items': <Map<String, dynamic>>[items[i]],
              },
              onTapItem: onTapItem,
              compact: true,
              showPeriod: false,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isPaid = PayrollProvider.isPaidPayrollStatus(status);
    final bg = isPaid ? const Color(0xFFEAF8F0) : AppPalette.primarySoft;
    final fg = isPaid ? AppPalette.success : AppPalette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.12)),
      ),
      child: Text(
        isPaid ? 'SUDAH DIBAYAR' : 'BELUM DIBAYAR',
        style: TextStyle(color: fg, fontSize: 10, fontWeight: AppFont.w900),
      ),
    );
  }
}


class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: EmptyStateWidget(
        title: title,
        message: subtitle,
        imagePath: 'assets/no-data/no data menu laporan.webp',
        imageWidth: 250,
        actionLabel: actionLabel,
        onAction: onAction,
        actionButtonStyle: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(220, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 4,
          shadowColor: AppPalette.primary.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
    );
  }
}
