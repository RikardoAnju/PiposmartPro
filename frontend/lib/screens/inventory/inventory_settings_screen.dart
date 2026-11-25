import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/screens/inventory/models/inventory_category.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_category_editor_sheet.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_category_settings_card.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_settings_header.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_settings_section_header.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_settings_tip_card.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_stock_reminder_card.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/providers/inventory_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InventorySettingsScreen extends StatefulWidget {
  const InventorySettingsScreen({super.key});

  @override
  State<InventorySettingsScreen> createState() =>
      _InventorySettingsScreenState();
}

class _InventorySettingsScreenState extends State<InventorySettingsScreen> {
  bool _reminderEnabled = true;
  String _frequency = 'Mingguan';
  String _schedule = 'Setiap Senin, 09.00';

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();
    Future.microtask(inventory.fetchOverview);
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Builder(
        builder: (context) {
          final categories = context
              .watch<InventoryProvider>()
              .categories
              .map(_fromApiCategory)
              .toList();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InventorySettingsHeader(onBack: () => Navigator.pop(context)),
                const SizedBox(height: 24),
                InventorySettingsSectionHeader(
                  title: 'Kategori Barang',
                  actionLabel: 'Tambah',
                  onAction: () => _addCategory(categories),
                ),
                const SizedBox(height: 10),
                InventoryCategorySettingsCard(
                  categories: categories,
                  onEdit: _editCategory,
                  onDelete: _deleteCategory,
                ),
                const SizedBox(height: 26),
                const InventorySettingsSectionHeader(title: 'Sesuaikan Stok'),
                const SizedBox(height: 10),
                InventoryStockReminderCard(
                  enabled: _reminderEnabled,
                  frequency: _frequency,
                  schedule: _schedule,
                  onEnabledChanged: (value) =>
                      setState(() => _reminderEnabled = value),
                  onFrequencyChanged: (value) =>
                      setState(() => _frequency = value),
                  onScheduleChanged: (value) =>
                      setState(() => _schedule = value),
                ),
                const SizedBox(height: 10),
                const InventorySettingsTipCard(),
              ],
            ),
          );
        },
      ),
    ),
  );

  InventoryCategory _fromApiCategory(Map<String, dynamic> category) {
    final name = category['name'] as String? ?? '-';
    if (name.toLowerCase().contains('packag')) {
      return InventoryCategory(
        id: category['id'] as String? ?? '',
        name: name,
        iconAsset: '03_icon_packaging_pink.webp',
        iconKey: category['icon_key'] as String? ?? '',
        backgroundColor: const Color(0xFFFFE4F1),
      );
    }
    if (name.toLowerCase().contains('pewangi') ||
        name.toLowerCase().contains('pelembut')) {
      return InventoryCategory(
        id: category['id'] as String? ?? '',
        name: name,
        iconAsset: '04_icon_pewangi_pelembut_kuning.webp',
        iconKey: category['icon_key'] as String? ?? '',
        backgroundColor: const Color(0xFFFFF3CC),
      );
    }
    if (name.toLowerCase().contains('perlengkapan')) {
      return InventoryCategory(
        id: category['id'] as String? ?? '',
        name: name,
        iconAsset: '05_icon_perlengkapan_hijau.webp',
        iconKey: category['icon_key'] as String? ?? '',
        backgroundColor: const Color(0xFFE2F9E9),
      );
    }
    return InventoryCategory(
      id: category['id'] as String? ?? '',
      name: name,
      iconAsset: '02_icon_bahan_pencucian_biru.webp',
      iconKey: category['icon_key'] as String? ?? '',
      backgroundColor: const Color(0xFFE0F6FF),
    );
  }

  void _addCategory(List<InventoryCategory> categories) =>
      InventoryCategoryEditorSheet.show(
        context,
        categories: categories,
        onSave: (name, iconKey) => _saveCategory(name: name, iconKey: iconKey),
      );

  void _editCategory(InventoryCategory category) =>
      InventoryCategoryEditorSheet.show(
        context,
        categories: context
            .read<InventoryProvider>()
            .categories
            .map(_fromApiCategory)
            .toList(),
        category: category,
        onSave: (name, iconKey) =>
            _saveCategory(id: category.id, name: name, iconKey: iconKey),
      );

  Future<bool> _saveCategory({
    String? id,
    required String name,
    required String iconKey,
  }) async {
    final provider = context.read<InventoryProvider>();
    final saved = await provider.saveCategory(
      id: id,
      name: name,
      iconKey: iconKey,
    );
    if (!saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Kategori gagal disimpan'),
          backgroundColor: AppPalette.danger,
        ),
      );
    }
    return saved;
  }

  Future<void> _deleteCategory(InventoryCategory category) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus kategori?'),
        content: Text(
          'Kategori ${category.name} akan dihapus dari pengaturan inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppPalette.danger),
            ),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      await context.read<InventoryProvider>().deleteCategory(category.id);
    }
  }
}
