part of '../leave_approval_screen.dart';

/// Bottom sheet minta alasan penolakan izin. Null bila dibatalkan.
Future<String?> showRejectReasonSheet(BuildContext context) {
  final controller = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Alasan Penolakan',
            style: TextStyle(
              color: AppPalette.ink,
              fontSize: 15,
              fontWeight: AppFont.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Beri tahu karyawan kenapa izinnya ditolak.',
            style: TextStyle(color: AppPalette.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'mis. Kekurangan personil di outlet pada tanggal itu',
              hintStyle: const TextStyle(fontSize: 12, color: AppPalette.muted),
              filled: true,
              fillColor: AppPalette.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppPalette.primary,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: Color(0xFFD7DCE3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) return;
                    Navigator.pop(sheetContext, text);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.danger,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Tolak Izin'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
