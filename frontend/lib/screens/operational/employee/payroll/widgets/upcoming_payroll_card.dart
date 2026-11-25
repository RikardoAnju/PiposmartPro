part of '../../payroll_screen.dart';

class _UpcomingPayrollCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _UpcomingPayrollCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['pegawai_nama']?.toString() ?? '-';
    final role = item['role_nama']?.toString() ?? '-';
    final amount = PayrollProvider.formatCurrency(
      PayrollProvider.toNum(item['net_amount']),
    );
    final dueLabel = PayrollProvider.formatDueLabel(
      item['due_date']?.toString(),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEFF3)),
            boxShadow: AppShadows.cardSoft,
          ),
          child: Row(
            children: [
              Expanded(child: _UpcomingPayrollEmployee(name: name, role: role)),
              const SizedBox(width: 10),
              _UpcomingPayrollSummary(dueLabel: dueLabel, amount: amount),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingPayrollEmployee extends StatelessWidget {
  final String name;
  final String role;

  const _UpcomingPayrollEmployee({required this.name, required this.role});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppPalette.ink,
          fontSize: 14,
          fontWeight: AppFont.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        role,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppPalette.muted,
          fontSize: 11.5,
          fontWeight: AppFont.w600,
        ),
      ),
    ],
  );
}

class _UpcomingPayrollSummary extends StatelessWidget {
  final String dueLabel;
  final String amount;

  const _UpcomingPayrollSummary({required this.dueLabel, required this.amount});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          dueLabel,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 11.5,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        amount,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppPalette.success,
          fontSize: 13.5,
          fontWeight: AppFont.w900,
        ),
      ),
      const SizedBox(height: 2),
      const Text(
        'Estimasi berjalan',
        style: TextStyle(
          color: AppPalette.muted,
          fontSize: 9.5,
          fontWeight: AppFont.w600,
        ),
      ),
    ],
  );
}
