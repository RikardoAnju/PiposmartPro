import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/item_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'item_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OptionalItemsNotesWidget extends StatefulWidget {
  final bool showItems;
  final bool showNotes;

  const OptionalItemsNotesWidget({
    super.key,
    this.showItems = true,
    this.showNotes = true,
  });

  @override
  State<OptionalItemsNotesWidget> createState() =>
      _OptionalItemsNotesWidgetState();
}

class _OptionalItemsNotesWidgetState extends State<OptionalItemsNotesWidget> {
  static const _primary = AppPalette.primary;
  static const _primaryLight = AppPalette.primarySoft;
  static const _textDark = Color(0xFF1F2937);
  static const _textMuted = Color(0xFF6B7280);

  final TextEditingController _notesController = TextEditingController();
  final Map<String, TextEditingController> _qtyControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final trxProvider = context.read<TransactionProvider>();
      _notesController.text = trxProvider.notes;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _qtyControllerKey(String serviceName, String id) =>
      '$serviceName::$id';

  TextEditingController _getQtyController(
    String serviceName,
    String id,
    int qty,
  ) {
    final key = _qtyControllerKey(serviceName, id);
    if (!_qtyControllers.containsKey(key)) {
      _qtyControllers[key] = TextEditingController(text: '$qty');
    }
    return _qtyControllers[key]!;
  }

  void _disposeScopeControllers(String serviceName) {
    final prefix = '$serviceName::';
    final keys = _qtyControllers.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keys) {
      _qtyControllers.remove(key)?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trxProvider = context.watch<TransactionProvider>();
    final itemProvider = context.watch<ItemProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showItems) _buildItemSection(trxProvider, itemProvider),
        if (widget.showItems && widget.showNotes) const SizedBox(height: 24),
        if (widget.showNotes) _buildNotesSection(trxProvider),
      ],
    );
  }

  Widget _buildItemSection(
    TransactionProvider provider,
    ItemProvider itemProvider,
  ) {
    final itemsByService = provider.optionalItemsByService;
    final allEmpty =
        itemsByService.isEmpty ||
        itemsByService.values.every((list) => list.isEmpty);
    final totalItems = itemsByService.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    final Widget itemContent = allEmpty
        ? Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFF1E7E4), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.checkroom_rounded,
                      size: 30,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "Belum ada item yang ditambahkan",
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 14,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Tambahkan item cucian agar detail pesanan lebih jelas.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...itemsByService.entries.map((entry) {
                final serviceName = entry.key;
                final items = entry.value;
                if (items.isEmpty) return const SizedBox.shrink();

                final isGlobal = serviceName == '__global__';
                final showLabel = serviceName != '__edit__';
                final labelText = isGlobal ? 'Item Tambahan' : serviceName;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showLabel) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 10, top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppPalette.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isGlobal
                                        ? Icons.add_circle_outline_rounded
                                        : Icons.local_laundry_service_rounded,
                                    size: 13,
                                    color: _primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    labelText,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: AppFont.w700,
                                      color: _primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildScopeActionButton(
                                  icon: Icons.delete_outline_rounded,
                                  onTap: () {
                                    _disposeScopeControllers(serviceName);
                                    if (isGlobal) {
                                      provider.clearGlobalOptionalItems();
                                    } else {
                                      provider.clearOptionalItemsForService(
                                        serviceName,
                                      );
                                    }
                                  },
                                ),
                                if (!isGlobal) ...[
                                  const SizedBox(width: 8),
                                  _buildScopeActionButton(
                                    icon: Icons.add_rounded,
                                    onTap: () => _showItemSelectionPage(
                                      context,
                                      serviceName: serviceName,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    ...items.map(
                      (item) => _buildItemCard(
                        provider,
                        itemProvider,
                        serviceName,
                        item.id,
                        item.name,
                        item.qty,
                      ),
                    ),
                  ],
                );
              }),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.checkroom_rounded,
                size: 16,
                color: _primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Item yang dicuci ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: AppFont.w600,
                        color: Colors.black87,
                      ),
                    ),
                    TextSpan(
                      text: '(optional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w400,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!allEmpty)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$totalItems',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: AppFont.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showItemSelectionPage(context),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _primaryLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppPalette.primaryBorder),
                ),
                child: const Icon(Icons.add_rounded, color: _primary, size: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        itemContent,
      ],
    );
  }

  Widget _buildScopeActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _primaryLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppPalette.primaryBorder),
        ),
        child: Icon(icon, color: _primary, size: 15),
      ),
    );
  }

  Widget _buildItemCard(
    TransactionProvider provider,
    ItemProvider itemProvider,
    String serviceName,
    String id,
    String name,
    int qty,
  ) {
    final resolvedName = _resolveItemName(id, name, itemProvider);
    final controllerKey = _qtyControllerKey(serviceName, id);
    final TextEditingController qtyController = _getQtyController(
      serviceName,
      id,
      qty,
    );

    if (!qtyController.value.composing.isValid &&
        qtyController.text != '$qty') {
      final currentText = qtyController.text;
      final parsed = int.tryParse(currentText);
      if (parsed == null || parsed <= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          qtyController.text = '$qty';
          qtyController.selection = TextSelection.collapsed(
            offset: '$qty'.length,
          );
        });
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E4E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3FBFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.checkroom_rounded,
              color: Color(0xFF7BC7BE),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Nama Item",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: AppFont.w600,
                    color: _textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _toTitle(resolvedName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: AppFont.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBFA),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF0D7D1), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    if (qty > 1) {
                      provider.decrementOptionalItemQuantity(
                        id,
                        serviceName: serviceName,
                      );
                      qtyController.text = '${qty - 1}';
                      qtyController.selection = TextSelection.collapsed(
                        offset: '${qty - 1}'.length,
                      );
                    }
                  },
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                  child: Container(
                    width: 32,
                    height: 36,
                    decoration: BoxDecoration(
                      color: qty > 1
                          ? AppPalette.primary.withValues(alpha: 0.1)
                          : Colors.grey.shade100,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                    ),
                    child: Icon(
                      Icons.remove,
                      size: 18,
                      color: qty > 1
                          ? AppPalette.primary
                          : Colors.grey.shade400,
                    ),
                  ),
                ),
                Container(
                  width: 46,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w600,
                      color: Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed != null && parsed > 0) {
                        provider.updateOptionalItemQuantity(
                          id,
                          parsed,
                          serviceName: serviceName,
                        );
                      }
                    },
                    onSubmitted: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed <= 0) {
                        qtyController.text = '$qty';
                        qtyController.selection = TextSelection.collapsed(
                          offset: '$qty'.length,
                        );
                      }
                    },
                  ),
                ),
                InkWell(
                  onTap: () {
                    provider.incrementOptionalItemQuantity(
                      id,
                      serviceName: serviceName,
                    );
                    qtyController.text = '${qty + 1}';
                    qtyController.selection = TextSelection.collapsed(
                      offset: '${qty + 1}'.length,
                    );
                  },
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: Container(
                    width: 32,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppPalette.primary.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 18,
                      color: AppPalette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              _qtyControllers.remove(controllerKey)?.dispose();
              provider.removeOptionalItem(id, serviceName: serviceName);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_outline,
                size: 18,
                color: Colors.red.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(TransactionProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'Keterangan ',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: AppFont.w600,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: '(optional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w400,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: "Contoh: Celana Merah Luntur",
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              counterText: '',
            ),
            maxLength: 200,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            onChanged: (value) {
              provider.setNotes(value);
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_notesController.text.length}/200 karakter',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  void _showItemSelectionPage(BuildContext context, {String? serviceName}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemSelectionPage(serviceName: serviceName),
      ),
    );
  }

  String _resolveItemName(String id, String rawName, ItemProvider provider) {
    final itemId = id.trim();
    final name = rawName.trim();
    final shouldLookup =
        name.isEmpty ||
        name == itemId ||
        name.toLowerCase() == itemId.toLowerCase();

    if (!shouldLookup) return name;

    final normalizedItemId = itemId.toLowerCase();
    final master = provider.items.where((masterItem) {
      return masterItem.id.trim().toLowerCase() == normalizedItemId;
    }).toList();

    if (master.isNotEmpty && master.first.nama.trim().isNotEmpty) {
      return master.first.nama.trim();
    }

    return name.isNotEmpty ? name : itemId;
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
}
