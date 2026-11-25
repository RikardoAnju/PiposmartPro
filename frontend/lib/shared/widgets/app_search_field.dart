import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final Widget? suffixIcon;
  final bool showClear;
  final double height;
  final EdgeInsetsGeometry margin;

  const AppSearchField({
    super.key,
    this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.suffixIcon,
    this.showClear = false,
    this.height = 46,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = showClear || controller?.text.isNotEmpty == true;

    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontSize: 14,
          color: AppPalette.ink,
          fontWeight: AppFont.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 13.5,
            color: AppPalette.muted,
            fontWeight: AppFont.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppPalette.muted,
            size: 20,
          ),
          suffixIcon:
              suffixIcon ??
              (hasText && onClear != null
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppPalette.muted,
                      ),
                      onPressed: onClear,
                    )
                  : null),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppPalette.primary, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
