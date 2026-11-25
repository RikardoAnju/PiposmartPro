part of '../../payroll_screen.dart';

class _PayrollSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PayrollSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFEDEFF3)),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 12,
            fontWeight: AppFont.w900,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}
