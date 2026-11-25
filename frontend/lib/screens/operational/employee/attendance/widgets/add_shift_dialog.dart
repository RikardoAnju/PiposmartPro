import 'package:ayocucinew/screens/operational/employee/attendance/attendance_configuration.dart';
import 'package:flutter/material.dart';

class AddShiftDialog extends StatefulWidget {
  const AddShiftDialog({super.key});
  @override
  State<AddShiftDialog> createState() => _AddShiftDialogState();
}

class _AddShiftDialogState extends State<AddShiftDialog> {
  String? _shiftName;
  void _save() {
    if (_shiftName == null) {
      setState(() {});
      return;
    }
    Navigator.pop(context, AttendanceShift(name: _shiftName!));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    title: const Text('Tambah Shift'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          onSelected: (value) => setState(() => _shiftName = value),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'Shift Pagi', child: Text('Shift Pagi')),
            PopupMenuItem(value: 'Shift Malam', child: Text('Shift Malam')),
          ],
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Pilih shift'),
            child: Row(
              children: [
                Expanded(child: Text(_shiftName ?? 'Pagi atau malam')),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Jam shift mengikuti jam operasional yang telah dipilih.',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(onPressed: _save, child: const Text('Tambah')),
    ],
  );
}
