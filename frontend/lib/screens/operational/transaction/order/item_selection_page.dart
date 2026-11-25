import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/item_model.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../providers/item_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';

class ItemSelectionPage extends StatefulWidget {
  final String? serviceName;

  const ItemSelectionPage({super.key, this.serviceName});

  @override
  State<ItemSelectionPage> createState() => _ItemSelectionPageState();
}

class _ItemSelectionPageState extends State<ItemSelectionPage> {
  static const _primary = AppPalette.primary;
  static const _bg = Color(0xFFF8F9FA);
  static const _card = Colors.white;
  static const _textDark = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);

  final TextEditingController _searchController = TextEditingController();
  List<ItemLaundry> _allItems = [];
  List<ItemLaundry> _filteredItems = [];
  Set<String> _selectedItems = {};
  bool _isLoading = false;
  bool get _isServiceScoped => widget.serviceName != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadItems();
    });
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    final itemProvider = context.read<ItemProvider>();
    await itemProvider.fetchItems();
    if (mounted) {
      final trxProvider = context.read<TransactionProvider>();
      setState(() {
        _allItems = itemProvider.activeItems;
        _filteredItems = _allItems;
        final selectedItems = _isServiceScoped
            ? trxProvider.getOptionalItemsForService(widget.serviceName!)
            : trxProvider.globalOptionalItems;
        _selectedItems = Set.from(selectedItems.map((e) => e.id));
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems
            .where(
              (item) => item.nama.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      bool isAllFilteredSelected = _filteredItems.every(
        (item) => _selectedItems.contains(item.id),
      );
      if (isAllFilteredSelected) {
        for (var item in _filteredItems) {
          _selectedItems.remove(item.id);
        }
      } else {
        for (var item in _filteredItems) {
          _selectedItems.add(item.id);
        }
      }
    });
  }

  void _toggleItem(ItemLaundry item) {
    setState(() {
      if (_selectedItems.contains(item.id)) {
        _selectedItems.remove(item.id);
      } else {
        _selectedItems.add(item.id);
      }
    });
  }

  void _saveSelection() {
    final trxProvider = context.read<TransactionProvider>();
    if (_isServiceScoped) {
      final existingById = {
        for (final item in trxProvider.getOptionalItemsForService(
          widget.serviceName!,
        ))
          item.id: item,
      };
      trxProvider.setOptionalItemsForService(
        widget.serviceName!,
        _allItems
            .where((item) => _selectedItems.contains(item.id))
            .map(
              (item) => {
                'id': item.id,
                'name': item.nama,
                'qty': existingById[item.id]?.qty ?? 1,
                'keterangan': existingById[item.id]?.keterangan ?? '',
              },
            )
            .toList(),
      );
    } else {
      trxProvider.replaceGlobalOptionalItemSelection(
        _allItems
            .where((item) => _selectedItems.contains(item.id))
            .map((item) => {'id': item.id, 'name': item.nama})
            .toList(),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isAllSelected =
        _filteredItems.isNotEmpty &&
        _filteredItems.every((item) => _selectedItems.contains(item.id));
    final selectedCount = _selectedItems.length;

    return AppScaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isServiceScoped ? widget.serviceName! : "Pilih Item Cuci",
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
        centerTitle: true,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saveSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 10,
                shadowColor: _primary.withValues(alpha: 0.28),
              ),
              child: Text(
                selectedCount > 0 ? "Simpan $selectedCount Item" : "Simpan",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: AppFont.w800,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const ManagementListSkeleton(showSearch: false, itemCount: 6)
          : Column(
              children: [
                _buildTopPanel(isAllSelected, selectedCount),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final isSelected = _selectedItems.contains(item.id);
                            return _buildItemCard(item, isSelected);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildTopPanel(bool isAllSelected, int selectedCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          AppSearchField(
            controller: _searchController,
            onChanged: _filterItems,
            hintText: "Cari Item (Baju, Celana...)",
            height: 48,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _toggleSelectAll,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isAllSelected ? _primary : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isAllSelected
                                  ? _primary
                                  : Colors.grey.shade400,
                              width: 1.6,
                            ),
                          ),
                          child: isAllSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedCount > 0
                                ? "Pilih Semua Item ($selectedCount dipilih)"
                                : "Pilih Semua Item",
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: AppFont.w600,
                              color: _textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _showAddItemSheet,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 18,
                  color: _primary,
                ),
                label: const Text(
                  "Tambah Item",
                  style: TextStyle(
                    color: _primary,
                    fontWeight: AppFont.w800,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ItemLaundry item, bool isSelected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? _primary.withValues(alpha: 0.4)
              : Colors.grey.shade100,
          width: 1.5,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleItem(item),
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primary.withValues(alpha: 0.1)
                        : const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.checkroom_rounded,
                    color: isSelected ? _primary : const Color(0xFF7BC7BE),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Nama Item",
                        style: TextStyle(
                          fontSize: 11,
                          color: _textMuted,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _toTitle(item.nama),
                        style: TextStyle(
                          fontSize: 16,
                          color: _textDark,
                          fontWeight: isSelected ? AppFont.w800 : AppFont.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSelected ? _primary : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? _primary : Colors.grey.shade300,
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    isSelected ? Icons.check_rounded : Icons.add_rounded,
                    size: 18,
                    color: isSelected ? Colors.white : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: _primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              "Item tidak ditemukan",
              style: TextStyle(
                fontSize: 17,
                fontWeight: AppFont.w800,
                color: _textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Coba kata kunci lain atau tambahkan item baru agar bisa langsung dipakai.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  String _toTitle(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  void _showAddItemSheet() {
    final TextEditingController nameController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 32),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    const Text(
                      "Tambah Item Baru",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFont.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Input nama
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: "Nama Item",
                        hintText: "Contoh: JAS",
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade200),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: AppPalette.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (nameController.text.trim().isEmpty) return;
                                setDialogState(() => isLoading = true);
                                final itemProvider = dialogContext
                                    .read<ItemProvider>();
                                final navigator = Navigator.of(dialogContext);
                                final res = await itemProvider.saveItem(
                                  nama: nameController.text.trim(),
                                );
                                if (!context.mounted) return;

                                if (res['success']) {
                                  if (dialogContext.mounted) {
                                    navigator.pop();
                                  }
                                  CustomToast.show(
                                    context,
                                    message:
                                        res['message'] ??
                                        'Item berhasil ditambahkan',
                                  );
                                  _loadItems();
                                } else {
                                  CustomToast.show(
                                    context,
                                    message:
                                        res['message'] ??
                                        'Gagal menambahkan item',
                                    isError: true,
                                  );
                                }
                                if (dialogContext.mounted) {
                                  setDialogState(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppPalette.primary
                              .withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: AppCircularLoader(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "TAMBAH ITEM",
                                style: TextStyle(
                                  fontWeight: AppFont.w900,
                                  fontSize: 14,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
