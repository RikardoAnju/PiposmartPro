import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/screens/operational/employee/attendance/widgets/time_input.dart';
import 'package:flutter/material.dart';

class DigitalTimeDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  const DigitalTimeDialog({super.key, required this.initialTime});
  @override
  State<DigitalTimeDialog> createState() => _DigitalTimeDialogState();
}

class _DigitalTimeDialogState extends State<DigitalTimeDialog> {
  late final TextEditingController _hour, _minute;
  String? _error;
  @override
  void initState() {
    super.initState();
    _hour = TextEditingController(
      text: widget.initialTime.hour.toString().padLeft(2, '0'),
    );
    _minute = TextEditingController(
      text: widget.initialTime.minute.toString().padLeft(2, '0'),
    );
  }

  @override
  void dispose() {
    _hour.dispose();
    _minute.dispose();
    super.dispose();
  }

  void _save() {
    final h = int.tryParse(_hour.text), m = int.tryParse(_minute.text);
    if (h == null || m == null || h > 23 || m > 59) {
      setState(() => _error = 'Masukkan waktu yang valid.');
      return;
    }
    Navigator.pop(context, TimeOfDay(hour: h, minute: m));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    title: const Text(
      'Masukkan waktu',
      style: TextStyle(fontSize: 16, fontWeight: AppFont.w700),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TimeInput(controller: _hour, label: 'Jam'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(':', style: TextStyle(fontSize: 24)),
            ),
            TimeInput(controller: _minute, label: 'Menit'),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: AppPalette.danger, fontSize: 12),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: _save, child: const Text('Simpan')),
    ],
  );
}
