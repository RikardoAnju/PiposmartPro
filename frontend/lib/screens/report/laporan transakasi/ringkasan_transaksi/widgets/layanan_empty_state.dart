import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';

class LayananEmptyState extends StatelessWidget {
  const LayananEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: EmptyStateWidget.laporan(
        title: 'Belum ada data layanan',
        message: 'Data layanan akan muncul setelah terdapat transaksi pada periode ini.',
        imageWidth: 170,
      ),
    );
  }
}
