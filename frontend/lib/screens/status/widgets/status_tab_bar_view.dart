import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import '../../../providers/status_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import 'transaction_card_widget.dart';

class StatusTabBarView extends StatelessWidget {
  final String status;
  final List<String> allStatuses;
  final List<String> selectedTrxIds;
  final bool isSelectionMode;
  final Function(String) onCardTap;
  final Function(String) onCardLongPress;

  const StatusTabBarView({
    super.key,
    required this.status,
    required this.allStatuses,
    required this.selectedTrxIds,
    required this.isSelectionMode,
    required this.onCardTap,
    required this.onCardLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<StatusProvider>();
    final items = prov.getItemsByStatus(status);

    if (prov.isLoading && items.isEmpty) {
      return const StatusListSkeleton();
    }

    if (items.isEmpty) {
      return const EmptyStateWidget(message: 'Belum ada pesanan');
    }

    return RefreshIndicator(
      onRefresh: () => prov.fetchInitialData(allStatuses),
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >=
                  scrollInfo.metrics.maxScrollExtent - 300 &&
              prov.hasMore(status) &&
              !prov.isLoading) {
            prov.fetchQueue(status);
          }
          return true;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 150),
          itemCount: items.length + (prov.isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index < items.length) {
              final trx = items[index];
              return TransactionCardWidget(
                trx: trx,
                isSelected: selectedTrxIds.contains(trx.id),
                isSelectionMode: isSelectionMode,
                onTap: () => onCardTap(trx.id),
              );
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: AppCircularLoader(strokeWidth: 2)),
            );
          },
        ),
      ),
    );
  }
}
