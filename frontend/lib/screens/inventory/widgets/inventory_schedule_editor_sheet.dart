import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InventoryScheduleEditorSheet extends StatefulWidget {
  const InventoryScheduleEditorSheet({super.key, required this.onSave});

  final ValueChanged<String> onSave;

  static Future<void> show(
    BuildContext context, {
    required ValueChanged<String> onSave,
  }) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => InventoryScheduleEditorSheet(onSave: onSave),
  );

  @override
  State<InventoryScheduleEditorSheet> createState() =>
      _InventoryScheduleEditorSheetState();
}

class _InventoryScheduleEditorSheetState
    extends State<InventoryScheduleEditorSheet> {
  final _hourController = TextEditingController(text: '00');
  final _minuteController = TextEditingController(text: '00');
  String _selectedDay = 'Senin';

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE4E7EB),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Atur Jadwal Pengingat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: AppFont.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text(
                  'Jam pengingat',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: AppFont.w700,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 48,
                      child: TextField(
                        controller: _hourController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '09',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE6EAF0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE6EAF0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        ':',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: AppFont.w700,
                          color: AppPalette.muted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      height: 48,
                      child: TextField(
                        controller: _minuteController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 2,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.zero,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE6EAF0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE6EAF0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Hari pengingat',
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFont.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 9),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              'Senin',
              'Selasa',
              'Rabu',
              'Kamis',
              'Jumat',
              'Sabtu',
              'Minggu',
            ].map(_dayChoice).toList(),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('SIMPAN JADWAL'),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _dayChoice(String day) {
    final selected = _selectedDay == day;
    return InkWell(
      onTap: () => setState(() => _selectedDay = day),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFFE3D8) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppPalette.primary : const Color(0xFFE6EAF0),
          ),
        ),
        child: Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? AppFont.w700 : AppFont.w500,
            color: selected ? AppPalette.primary : AppPalette.ink,
          ),
        ),
      ),
    );
  }

  void _save() {
    final hour = int.tryParse(_hourController.text);
    final minute = int.tryParse(_minuteController.text);
    if (hour == null || minute == null || hour > 23 || minute > 59) return;
    widget.onSave(
      'Setiap $_selectedDay, ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    );
    Navigator.pop(context);
  }
}
