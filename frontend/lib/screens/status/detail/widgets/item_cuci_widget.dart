import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/item_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'section_card_widget.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ItemCuciWidget extends StatefulWidget {
  const ItemCuciWidget({super.key});

  @override
  State<ItemCuciWidget> createState() => _ItemCuciWidgetState();
}

class _ItemCuciWidgetState extends State<ItemCuciWidget> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, ItemProvider>(
      builder: (context, provider, itemProvider, _) {
        final items = provider.currentDetail?.optionalItems ?? [];
        if (items.isEmpty) return const SizedBox.shrink();
        final groupedItems = _groupItemsByService(items);

        return SectionCardWidget(
          title: 'Item yang dicuci',
          expanded: _expanded,
          onToggle: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: groupedItems.entries.map((entry) {
                final serviceName = entry.key;
                final serviceItems = entry.value;
                final showServiceName = serviceName.isNotEmpty;

                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  decoration: BoxDecoration(
                    color: showServiceName
                        ? AppPalette.primaryPale
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: showServiceName
                          ? AppColors.primary.withValues(alpha: 0.16)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showServiceName)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppPalette.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: AppFont.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ...serviceItems.asMap().entries.map((e) {
                        final index = e.key;
                        final item = e.value;
                        final itemId = (item['item_id'] ?? '')
                            .toString()
                            .trim();
                        final itemName = _resolveItemName(item, itemProvider);

                        return Column(
                          children: [
                            if (index > 0)
                              const Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                showServiceName ? 8 : 4,
                                9,
                                0,
                                9,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      itemName.isNotEmpty ? itemName : itemId,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: AppFont.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${item['qty'] ?? 1} pcs',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: AppFont.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupItemsByService(
    List<Map<String, dynamic>> items,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final serviceName = item['service_name']?.toString().trim() ?? '';
      grouped.putIfAbsent(serviceName, () => []).add(item);
    }
    return grouped;
  }

  String _resolveItemName(Map<String, dynamic> item, ItemProvider provider) {
    final itemId = (item['item_id'] ?? '').toString().trim();
    final rawName = (item['name'] ?? '').toString().trim();
    final shouldLookup =
        rawName.isEmpty ||
        rawName == itemId ||
        rawName.toLowerCase() == itemId.toLowerCase();

    if (!shouldLookup) return rawName;

    final normalizedItemId = itemId.toLowerCase();
    final master = provider.items.where((masterItem) {
      return masterItem.id.trim().toLowerCase() == normalizedItemId;
    }).toList();

    if (master.isNotEmpty && master.first.nama.trim().isNotEmpty) {
      return master.first.nama.trim();
    }

    return rawName.isNotEmpty ? rawName : itemId;
  }
}
