import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/screens/inventory/models/inventory_category.dart';
import 'package:flutter/material.dart';

class InventoryCategoryEditorSheet extends StatefulWidget {
  const InventoryCategoryEditorSheet({
    super.key,
    required this.categories,
    required this.onSave,
    this.category,
  });

  final List<InventoryCategory> categories;
  final Future<bool> Function(String name, String iconKey) onSave;
  final InventoryCategory? category;

  static Future<void> show(
    BuildContext context, {
    required List<InventoryCategory> categories,
    required Future<bool> Function(String name, String iconKey) onSave,
    InventoryCategory? category,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: InventoryCategoryEditorSheet(
        categories: categories,
        onSave: onSave,
        category: category,
      ),
    ),
  );

  @override
  State<InventoryCategoryEditorSheet> createState() =>
      _InventoryCategoryEditorSheetState();
}

class _InventoryCategoryEditorSheetState
    extends State<InventoryCategoryEditorSheet> {
  late final TextEditingController _nameController;
  int _selectedIndex = 0;
  bool _isSaving = false;

  static final _iconOptions = List.generate(
    21,
    (index) => _IconOption(
      'category_icon_${(index + 1).toString().padLeft(2, '0')}.webp',
    ),
  );

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    final index = _iconOptions.indexWhere(
      (option) => option.assetName == widget.category?.iconKey,
    );
    if (index >= 0) _selectedIndex = index;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _iconOptions[_selectedIndex];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                widget.category == null ? 'Tambah Kategori' : 'Edit Kategori',
                style: const TextStyle(fontSize: 18, fontWeight: AppFont.w800),
              ),
              const Spacer(),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          SizedBox(
            width: 72,
            height: 72,
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.asset(
                'assets/icons/inventory/category_options/${selected.assetName}',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Kategori',
              hintText: 'Contoh: Bahan Pencucian',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pilih ikon',
              style: TextStyle(fontWeight: AppFont.w700, color: AppPalette.ink),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 6,
              childAspectRatio: 1,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
            ),
            itemCount: _iconOptions.length,
            itemBuilder: (context, index) {
              final option = _iconOptions[index];
              final selected = index == _selectedIndex;
              return InkWell(
                onTap: () => setState(() => _selectedIndex = index),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: selected
                        ? Border.all(color: const Color(0xFF168C86), width: 2)
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF168C86,
                              ).withValues(alpha: .28),
                              blurRadius: 7,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      'assets/icons/inventory/category_options/${option.assetName}',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('SIMPAN'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    final saved = await widget.onSave(
      name,
      _iconOptions[_selectedIndex].assetName,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (saved) Navigator.pop(context);
  }
}

class _IconOption {
  const _IconOption(this.assetName);

  final String assetName;
}
