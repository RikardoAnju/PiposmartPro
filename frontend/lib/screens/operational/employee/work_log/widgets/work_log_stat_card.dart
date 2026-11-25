import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class WorkLogStatCard extends StatelessWidget {
  const WorkLogStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.icon,
    this.unit,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.14),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color.withValues(alpha: 0.75), size: 15),
                ),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: AppPalette.ink.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppPalette.primary,
                          fontSize: 22,
                          fontWeight: AppFont.w800,
                          height: 1.0,
                        ),
                      ),
                    ),
                    if (unit != null) ...[
                      const SizedBox(width: 2),
                      Text(
                        unit!,
                        style: const TextStyle(
                          color: AppPalette.muted,
                          fontSize: 10,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
