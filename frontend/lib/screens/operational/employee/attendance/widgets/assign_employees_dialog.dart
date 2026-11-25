import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:flutter/material.dart';

/// Dialog centang karyawan untuk sebuah shift.
/// Mengembalikan set id karyawan terpilih, atau null bila dibatalkan.
Future<Set<String>?> showAssignEmployeesDialog(
  BuildContext context, {
  required String shiftName,
  required List<Pegawai> available,
  required Set<String> initialSelected,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (dialogContext) {
      final selectedIds = Set<String>.from(initialSelected);
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Karyawan $shiftName'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SizedBox(
              width: double.maxFinite,
              child: available.isEmpty
                  ? const Text('Belum ada karyawan aktif yang tersedia.')
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: available.length,
                      itemBuilder: (_, index) {
                        final employee = available[index];
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: selectedIds.contains(employee.id),
                          title: Text(employee.nama),
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (checked) => setDialogState(() {
                            if (checked == true) {
                              selectedIds.add(employee.id);
                            } else {
                              selectedIds.remove(employee.id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selectedIds),
              child: const Text('Pilih'),
            ),
          ],
        ),
      );
    },
  );
}
