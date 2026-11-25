import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';

class TransactionEmptyState extends StatelessWidget {
  const TransactionEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget.laporan(
      title: 'Belum ada transaksi',
      message: 'Transaksi pada tab ini akan muncul di sini.',
      imageWidth: 170,
    );
  }
}
