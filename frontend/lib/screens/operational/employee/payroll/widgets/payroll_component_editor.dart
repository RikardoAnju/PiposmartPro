part of '../../payroll_screen.dart';

class _ComponentRow extends StatelessWidget {
  final String name;
  final String amount;
  final Color amountColor;
  final VoidCallback? onDelete;

  const _ComponentRow({
    required this.name,
    required this.amount,
    required this.amountColor,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEDEFF3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              color: amountColor,
              fontSize: 12.5,
              fontWeight: AppFont.w800,
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: AppPalette.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final double valueFontSize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueFontSize = 12.5,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppPalette.muted, fontSize: 12),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppPalette.ink,
            fontSize: valueFontSize,
            fontWeight: AppFont.w800,
          ),
        ),
      ],
    );
  }
}

class _ComponentEditorSheet extends StatelessWidget {
  final String type;
  final TextEditingController nameController;
  final TextEditingController amountController;
  final VoidCallback onSave;

  const _ComponentEditorSheet({
    required this.type,
    required this.nameController,
    required this.amountController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final title = type == 'deduction' ? 'Tambah Potongan' : 'Tambah Bonus';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E7EE),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppPalette.ink,
                fontSize: 18,
                fontWeight: AppFont.w800,
              ),
            ),
            const SizedBox(height: 16),
            _FieldLabel('Nama Komponen'),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: _salaryDecoration(
                type == 'deduction' ? 'Kasbon' : 'Lembur',
              ),
            ),
            const SizedBox(height: 12),
            _FieldLabel('Nominal'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              decoration: _salaryDecoration('Rp 0'),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'SIMPAN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: AppFont.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _salaryDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }
}
