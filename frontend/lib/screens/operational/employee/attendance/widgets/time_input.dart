import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';

class TimeInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const TimeInput({super.key, required this.controller, required this.label});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppPalette.ink,
            fontSize: 10,
            fontWeight: AppFont.w700,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLength: 2,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: AppFont.w700),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    ),
  );
}
