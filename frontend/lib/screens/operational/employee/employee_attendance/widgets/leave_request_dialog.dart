part of '../../employee_attendance_screen.dart';

Future<void> _showLeaveDialog(BuildContext context) async {
  final reason = TextEditingController();
  final durationDays = TextEditingController(text: '2');
  var leaveType = 'IZIN';
  var duration = '1 Hari';
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setModalState) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
            mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Formulir Izin',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: AppFont.w800,
                          color: Color(0xFF34495E),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tipe izin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.w700,
                            color: Color(0xFF526273),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: leaveType,
                          items: const [
                            DropdownMenuItem(
                              value: 'IZIN',
                              child: Text('Izin'),
                            ),
                            DropdownMenuItem(
                              value: 'SAKIT',
                              child: Text('Sakit'),
                            ),
                            DropdownMenuItem(
                              value: 'KEPERLUAN KELUARGA',
                              child: Text('Keperluan Keluarga'),
                            ),
                            DropdownMenuItem(
                              value: 'LAINNYA',
                              child: Text('Lainnya'),
                            ),
                          ],
                          onChanged: (value) =>
                              setModalState(() => leaveType = value ?? 'IZIN'),
                          borderRadius: BorderRadius.circular(16),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3E8EE),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3E8EE),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppPalette.primary,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (duration == 'Lebih 1 Hari') ...[
                          TextField(
                            controller: durationDays,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah hari',
                              hintText: 'Contoh: 3',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'Durasi izin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.w700,
                            color: Color(0xFF526273),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: ['Jam', '1 Hari', 'Lebih 1 Hari']
                              .map(
                                (item) => ChoiceChip(
                                  label: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: duration == item
                                          ? Colors.white
                                          : const Color(0xFF526273),
                                    ),
                                  ),
                                  selected: duration == item,
                                  selectedColor: AppPalette.primary,
                                  backgroundColor: const Color(0xFFF2F4F7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide.none,
                                  ),
                                  onSelected: (_) =>
                                      setModalState(() => duration = item),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Alasan izin',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: AppFont.w700,
                            color: Color(0xFF526273),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: reason,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: 'Tulis alasan izin Anda...',
                            hintStyle: const TextStyle(
                              color: Color(0xFF9AA5B1),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.all(14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3E8EE),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3E8EE),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppPalette.primary,
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          dialogContext,
                          '$leaveType|$duration|${reason.text.trim()}',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Kirim', textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 250));
  reason.dispose();
  final selectedDuration = durationDays.text.trim();
  durationDays.dispose();
  if (!context.mounted || result == null || result.isEmpty) return;
  final parts = result.split('|');
  if (parts.length < 3 || parts[2].trim().isEmpty) return;
  final response = await context.read<AttendanceProvider>().submitLeaveRequest(
    leaveType: parts[0],
    duration: parts[1] == 'Lebih 1 Hari' ? selectedDuration : '1',
    reason: parts[2],
  );
  if (!context.mounted) return;
  CustomToast.show(
    context,
    message: response['message'].toString(),
    isError: response['success'] != true,
  );
}
