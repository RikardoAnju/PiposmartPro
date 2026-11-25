import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final bool isPassword;
  final bool isPasswordVisible;
  final bool isRequired;
  final bool isLoading;
  final VoidCallback? onTogglePassword;
  final String? Function(String?)? validator;
  final int maxLines;
  final Function(String)? onChanged;
  final bool? enabled;
  final bool readOnly; // Parameter baru
  final Color? fillColor;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autofocus;
  final void Function(PointerDownEvent)? onTapOutside;
  final VoidCallback?
  onTap; // Tambahan: berguna kalau readOnly buat buka DatePicker

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.isPassword = false,
    this.isPasswordVisible = false,
    this.isRequired = false,
    this.isLoading = false,
    this.readOnly = false, // Default false
    this.onTogglePassword,
    this.validator,
    this.onChanged,
    this.enabled,
    this.onTap,
    this.maxLines = 1,
    this.fillColor,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.focusNode,
    this.autofocus = false,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Row(
              children: [
                if (isRequired)
                  const Text(
                    '*',
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontWeight: AppFont.w700,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(width: 4),
                Text(
                  labelText!,
                  style: const TextStyle(
                    color: Color(0xFF2C3E50),
                    fontWeight: AppFont.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.cardSoft,
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLines: isPassword ? 1 : maxLines,
            obscureText: isPassword && !isPasswordVisible,
            keyboardType: keyboardType,
            autofocus: autofocus,
            enabled: enabled ?? !isLoading,
            readOnly: readOnly, // Implementasi parameter baru
            onTap: onTap,
            onTapOutside: onTapOutside,
            onChanged: onChanged,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontSize: 14,
              fontWeight: AppFont.w500,
              // Jika readOnly, warna teks agak diredam sedikit agar user tahu bedanya
              color: readOnly ? Colors.grey[600] : const Color(0xFF2C3E50),
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              filled: true,
              // Background otomatis abu-abu tipis jika readOnly agar lebih intuitif secara UI
              fillColor:
                  fillColor ?? (readOnly ? Colors.grey[50] : Colors.white),
              prefixIcon: prefixIcon,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: onTogglePassword,
                    )
                  : suffixIcon,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: readOnly ? Colors.grey[200]! : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  // Jika readOnly, border fokus tetap warna biasa, bukan orange
                  color: readOnly ? Colors.grey[300]! : AppPalette.primary,
                  width: readOnly ? 1 : 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppPalette.primary,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppPalette.primary,
                  width: 1.5,
                ),
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
