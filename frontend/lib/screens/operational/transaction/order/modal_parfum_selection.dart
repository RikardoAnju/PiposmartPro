import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import '../../../../providers/parfum_provider.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../data/models/parfum_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ParfumSelectionBottomSheet extends StatelessWidget {
  final ParfumProvider parfumProvider;
  final TransactionProvider trxProvider;

  const ParfumSelectionBottomSheet({
    super.key,
    required this.parfumProvider,
    required this.trxProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(
                  Icons.opacity_rounded,
                  color: AppPalette.primary,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  "Pilih Aroma Parfum",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFont.w800,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Loading state
          if (parfumProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: AppCircularLoader(color: AppPalette.primary),
            )
          else
            Flexible(
              child: Builder(
                builder: (context) {
                  final activeParfums = parfumProvider.parfums
                      .where(
                        (p) =>
                            p.status == 1 &&
                            p.nama.toLowerCase() != "tanpa parfum",
                      )
                      .toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 12,
                      bottom: 40,
                    ),
                    itemCount: activeParfums.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildParfumRow(
                          context,
                          parfum: null,
                          isSelected: trxProvider.selectedParfumId == null,
                        );
                      }
                      final p = activeParfums[index - 1];
                      return _buildParfumRow(
                        context,
                        parfum: p,
                        isSelected: trxProvider.selectedParfumId == p.id,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParfumRow(
    BuildContext context, {
    required Parfum? parfum,
    required bool isSelected,
  }) {
    final bool isNone = parfum == null;
    final String name = parfum?.nama ?? "Tanpa Parfum";

    return InkWell(
      onTap: () {
        trxProvider.setSelectedParfum(parfum?.id);
        trxProvider.selectParfum(parfum);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppPalette.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppPalette.primary : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppPalette.primary
                    : const Color(0xFFF8F9FA),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNone ? Icons.block_rounded : Icons.water_drop_rounded,
                color: isSelected ? Colors.white : AppPalette.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? AppFont.w700 : AppFont.w600,
                  color: isSelected ? AppPalette.primary : Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppPalette.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
