part of '../../payroll_screen.dart';

class _PrimaryComponentCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;

  const _PrimaryComponentCard({
    required this.title,
    required this.value,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFEDEFF3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AppPalette.muted,
            fontSize: 11,
            fontWeight: AppFont.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 18,
            fontWeight: AppFont.w900,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppPalette.muted,
              fontSize: 12,
              fontWeight: AppFont.w600,
            ),
          ),
        ],
      ],
    ),
  );
}
