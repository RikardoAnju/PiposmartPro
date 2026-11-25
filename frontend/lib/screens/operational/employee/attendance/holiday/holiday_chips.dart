part of '../attendance_holiday_screen.dart';

class _DayChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _DayChip({required this.label, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      constraints: const BoxConstraints(minWidth: 78, minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: active ? AppPalette.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active
              ? AppPalette.primaryBorderStrong
              : const Color(0xFFE2E8F0),
          width: 1.3,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: active ? AppPalette.primary : AppPalette.muted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w700,
              color: active ? AppPalette.primaryDeep : AppPalette.ink,
            ),
          ),
        ],
      ),
    ),
  );
}

class _AddButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddButton({this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: AppPalette.primarySoft,
    borderRadius: BorderRadius.circular(9),
    child: InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 15, color: AppPalette.primary),
            SizedBox(width: 4),
            Text(
              'Tambah',
              style: TextStyle(
                fontSize: 11,
                fontWeight: AppFont.w800,
                color: AppPalette.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
