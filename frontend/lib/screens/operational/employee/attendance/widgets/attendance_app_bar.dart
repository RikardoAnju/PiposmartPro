import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';

class AttendanceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool centerTitle;
  const AttendanceAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.centerTitle = true,
  });
  @override
  Size get preferredSize => const Size.fromHeight(56);
  @override
  Widget build(BuildContext context) {
    final balancedActions = actions ?? const [SizedBox(width: 56)];
    return AppBar(
    backgroundColor: Colors.white,
    scrolledUnderElevation: 0,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
      onPressed: onBack ?? () => Navigator.pop(context),
    ),
    titleSpacing: 0,
    title: Center(
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 17,
          fontWeight: AppFont.w800,
        ),
      ),
    ),
    centerTitle: centerTitle,
    actions: balancedActions,
    );
  }
}
