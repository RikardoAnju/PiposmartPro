part of '../../payroll_screen.dart';

class _PayrollHero extends StatelessWidget {
  final String periodLabel;
  final double totalAmount;
  final String title;
  final String amountLabel;

  const _PayrollHero({
    required this.periodLabel,
    required this.totalAmount,
    required this.title,
    required this.amountLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.colored(AppPalette.primaryDeep),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppPalette.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              child: _buildContent(isCompact),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: AppFont.w800,
                      fontSize: isCompact ? 14 : 16,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'PERIODE',
                  style: TextStyle(
                    color: Color(0xFFFFE8DF),
                    fontSize: 10,
                    fontWeight: AppFont.w700,
                  ),
                ),
                Text(
                  periodLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: AppFont.w800,
                    fontSize: isCompact ? 11 : 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          amountLabel,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          PayrollProvider.formatCurrency(totalAmount),
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? 22 : 26,
            fontWeight: AppFont.w900,
          ),
        ),
      ],
    );
  }
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SmallStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: AppFont.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
          style: TextStyle(
              color: AppPalette.muted,
              fontSize: 11,
              fontWeight: AppFont.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEDEFF3)),
            boxShadow: AppShadows.cardSoft,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppPalette.primary),
              ),
              const SizedBox(width: 14),
              const Expanded(child: _ActionText()),
              const Icon(Icons.chevron_right_rounded, color: AppPalette.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionText extends StatelessWidget {
  const _ActionText();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pengaturan Gaji Pegawai',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w700,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Atur skema gaji per pegawai',
          style: TextStyle(color: AppPalette.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _TabBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TabItem(
            label: 'Aktif',
            selected: index == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TabItem(
            label: 'Riwayat',
            selected: index == 1,
            onTap: () => onChanged(1),
          ),
        ),
      ],
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppPalette.primaryPale : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppPalette.primary : const Color(0xFFE3E7EE),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppPalette.primary : AppPalette.muted,
            fontWeight: AppFont.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
