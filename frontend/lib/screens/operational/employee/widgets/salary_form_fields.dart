import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

/// Widget field untuk form Pengaturan Gaji — dipakai bersama di layar
/// Penggajian dan form Tambah/Edit Pegawai agar tampilannya konsisten.

class SalaryFieldLabel extends StatelessWidget {
  final String text;

  const SalaryFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppPalette.ink,
        fontSize: 12,
        fontWeight: AppFont.w800,
      ),
    );
  }
}

class SalaryChipOption {
  final String value;
  final String label;
  const SalaryChipOption(this.value, this.label);
}

/// Pilihan berupa chip (semua opsi tampil sekaligus). Dipakai bila opsinya
/// sedikit (2-3) sehingga lebih enak daripada dropdown.
class SalaryChipSelect extends StatelessWidget {
  final String value;
  final List<SalaryChipOption> options;
  final ValueChanged<String> onChanged;

  const SalaryChipSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final bool selected = opt.value == value;
        return GestureDetector(
          onTap: () => onChanged(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppPalette.primarySoft : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppPalette.primary : const Color(0xFFE3E7EE),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Text(
              opt.label,
              style: TextStyle(
                color: selected ? AppPalette.primary : AppPalette.ink,
                fontSize: 14,
                fontWeight: selected ? AppFont.w800 : AppFont.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SalarySelectOption<T> {
  final T value;
  final String label;
  const SalarySelectOption(this.value, this.label);
}

/// Field pilihan (tap → menu muncul di bawah field). Radius 14, tinggi min 52.
class SalarySelectField<T> extends StatelessWidget {
  final T value;
  final List<SalarySelectOption<T>> options;
  final ValueChanged<T> onChanged;

  const SalarySelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  SalarySelectOption<T>? get _currentItem {
    for (final it in options) {
      if (it.value == value) return it;
    }
    return options.isNotEmpty ? options.first : null;
  }

  Future<void> _openMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final RelativeRect position = RelativeRect.fromLTRB(
      topLeft.dx,
      bottomRight.dy + 4,
      overlay.size.width - bottomRight.dx,
      overlay.size.height,
    );
    final selected = await showMenu<T>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      constraints: const BoxConstraints(minWidth: 140),
      items: options
          .map((it) => PopupMenuItem<T>(value: it.value, child: Text(it.label)))
          .toList(),
    );
    if (selected != null && selected != value) {
      onChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _openMenu(context),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _currentItem?.label ?? '',
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  fontWeight: AppFont.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppPalette.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Field tanggal (tap → buka picker). Tampilan sama dengan [SalarySelectField].
class SalaryDateSelectField extends StatelessWidget {
  final String valueText;
  final VoidCallback onTap;

  const SalaryDateSelectField({
    super.key,
    required this.valueText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE3E7EE)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_month_rounded,
              color: AppPalette.primary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valueText,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  fontWeight: AppFont.w700,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppPalette.muted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Field nominal gaji (Rp). Tampilan sama dengan di layar Penggajian.
class SalaryAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const SalaryAmountField({
    super.key,
    required this.controller,
    this.hintText = 'Rp 0',
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [SalaryRupiahInputFormatter()],
      style: const TextStyle(
        color: AppPalette.ink,
        fontSize: 15,
        fontWeight: AppFont.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE3E7EE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppPalette.primary),
        ),
      ),
    );
  }
}

/// Formatter Rupiah dengan pemisah ribuan (contoh: 50000 → "Rp 50.000").
class SalaryRupiahInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final limitedDigits = digits.length > _maxDigits
        ? digits.substring(0, _maxDigits)
        : digits;
    final number = int.parse(limitedDigits);
    final formatted = _thousands(number);
    final text = 'Rp $formatted';
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  String _thousands(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
