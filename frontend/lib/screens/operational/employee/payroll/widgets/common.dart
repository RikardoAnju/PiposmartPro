part of '../../payroll_screen.dart';

class _TinyChip extends StatelessWidget {
  final String label;
  final Color color;

  const _TinyChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: AppFont.w900),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

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

class _SelectField<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _SelectField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  DropdownMenuItem<T>? get _currentItem {
    for (final it in items) {
      if (it.value == value) return it;
    }
    return items.isNotEmpty ? items.first : null;
  }

  // (kelas _ChipOption & _ChipSelect didefinisikan di bawah file)

  Future<void> _openMenu(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final Offset topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final Offset bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    // Menu muncul tepat di bawah field, rata kiri; lebarnya mengikuti konten
    // (tidak full-width).
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
      items: items
          .map((it) => PopupMenuItem<T>(value: it.value, child: it.child))
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
              child: DefaultTextStyle.merge(
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 15,
                  fontWeight: AppFont.w700,
                ),
                child: _currentItem?.child ?? const SizedBox.shrink(),
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

class _ChipOption {
  final String value;
  final String label;
  const _ChipOption(this.value, this.label);
}

/// Pilihan berupa chip (semua opsi tampil sekaligus). Dipakai bila opsinya
/// sedikit (2-3) sehingga lebih enak daripada dropdown.
class _ChipSelect extends StatelessWidget {
  final String value;
  final List<_ChipOption> options;
  final ValueChanged<String> onChanged;

  const _ChipSelect({
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

class _DateSelectField extends StatelessWidget {
  final String valueText;
  final VoidCallback onTap;

  const _DateSelectField({required this.valueText, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                  fontSize: 15,
                  color: AppPalette.ink,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF98A2B3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    // Batasi panjang (maks 15 digit) supaya int.parse tidak overflow/error
    // saat menempel angka sangat panjang.
    if (digits.length > 15) {
      digits = digits.substring(0, 15);
    }
    final value = int.tryParse(digits);
    if (value == null) return oldValue;
    final formatted = PayrollProvider.formatInputCurrency(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
