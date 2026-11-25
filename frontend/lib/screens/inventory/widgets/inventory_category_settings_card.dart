import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/screens/inventory/models/inventory_category.dart';
import 'package:flutter/material.dart';

class InventoryCategorySettingsCard extends StatelessWidget {
  const InventoryCategorySettingsCard({
    super.key,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  final List<InventoryCategory> categories;
  final ValueChanged<InventoryCategory> onEdit;
  final ValueChanged<InventoryCategory> onDelete;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF0E8E4)),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Column(
      children: categories.asMap().entries.map((entry) {
        final category = entry.value;
        return Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 4,
              ),
              leading: SizedBox(
                width: 42,
                height: 42,
                child: Image.asset(
                  category.iconKey.isNotEmpty
                      ? 'assets/icons/inventory/category_options/${category.iconKey}'
                      : 'assets/icons/inventory/${category.iconAsset}',
                  fit: BoxFit.contain,
                ),
              ),
              title: Text(
                category.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w600,
                  color: AppPalette.ink,
                ),
              ),
              trailing: PopupMenuButton<_CategoryAction>(
                tooltip: 'Aksi kategori',
                icon: const Icon(
                  Icons.more_horiz_rounded,
                  color: AppPalette.muted,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                onSelected: (action) {
                  if (action == _CategoryAction.edit) {
                    onEdit(category);
                  } else {
                    onDelete(category);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _CategoryAction.edit,
                    child: ListTile(
                      leading: Icon(
                        Icons.edit_rounded,
                        color: AppPalette.primary,
                      ),
                      title: Text('Edit Kategori'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _CategoryAction.delete,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: AppPalette.danger,
                      ),
                      title: Text(
                        'Hapus Kategori',
                        style: TextStyle(color: AppPalette.danger),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (entry.key != categories.length - 1)
              const Divider(
                height: 1,
                indent: 67,
                endIndent: 14,
                color: Color(0xFFF2F3F5),
              ),
          ],
        );
      }).toList(),
    ),
  );
}

enum _CategoryAction { edit, delete }
