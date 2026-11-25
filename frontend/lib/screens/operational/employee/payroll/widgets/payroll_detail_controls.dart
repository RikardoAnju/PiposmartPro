part of '../../payroll_screen.dart';

class _PayrollDetailHeader extends StatelessWidget {
  final String name;
  final String salaryType;
  final String status;

  const _PayrollDetailHeader({
    required this.name,
    required this.salaryType,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = PayrollProvider.isPaidPayrollStatus(status);
    final badgeBg = isPaid ? const Color(0xFFEAF8F0) : AppPalette.primarySoft;
    final badgeFg = isPaid ? AppPalette.success : AppPalette.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppPalette.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.person_rounded, color: AppPalette.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 15,
                    fontWeight: AppFont.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        salaryType,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: badgeFg.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        isPaid ? 'SUDAH DIBAYAR' : 'BELUM DIBAYAR',
                        style: TextStyle(
                          color: badgeFg,
                          fontSize: 10,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _DetailActionVariant { primary, secondary }

class _DetailActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final _DetailActionVariant variant;

  const _DetailActionButton({
    required this.label,
    required this.onTap,
    required this.variant,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == _DetailActionVariant.primary;
    return SizedBox(
      height: 44,
      child: Material(
        color: isPrimary ? AppPalette.primary : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPrimary ? AppPalette.primary : const Color(0xFFE1E5EB),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: isPrimary ? Colors.white : AppPalette.ink,
                  fontWeight: AppFont.w900,
                  fontSize: 12.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
