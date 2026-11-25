import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/settings/keuangan/kategori_pengeluaran/kategori_list.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/kategori_pengeluaran_provider.dart';
import '../../../../data/models/kategori_pengeluaran_model.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/custom_toast.dart';
import 'widgets/modal_add_kategori_pengeluaran.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class KategoriPengeluaranListScreen extends StatefulWidget {
  const KategoriPengeluaranListScreen({super.key});

  @override
  State<KategoriPengeluaranListScreen> createState() =>
      _KategoriPengeluaranListScreenState();
}

class _KategoriPengeluaranListScreenState
    extends State<KategoriPengeluaranListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KategoriPengeluaranProvider>().fetchKategoriPengeluaran();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<KategoriPengeluaranProvider>();

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Kembali",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => provider.fetchKategoriPengeluaran(),
            color: AppPalette.primary,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Kategori Pengeluaran",
                    style: TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 22,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Kelola kategori pengeluaran untuk mempermudah pemantauan arus kas outlet Anda.",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (provider.isLoading && provider.kategoriList.isEmpty)
                    const ManagementListSkeleton(
                      showSearch: false,
                      itemCount: 5,
                    )
                  else if (provider.kategoriList.isEmpty)
                    const EmptyStateWidget(
                      title: "Belum ada kategori",
                      message:
                          "Silahkan tambahkan kategori pengeluaran baru untuk memulai pencatatan",
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.kategoriList.length,
                      itemBuilder: (context, index) =>
                          _buildKategoriCard(provider.kategoriList[index]),
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildFloatingAddButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildKategoriCard(KategoriPengeluaran item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFF2F2F2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.category_rounded,
              color: AppPalette.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item.kategori,
              style: const TextStyle(
                fontWeight: AppFont.w700,
                fontSize: 15,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
          Row(
            children: [
              _buildIconButton(
                icon: Icons.edit_rounded,
                color: Colors.green,
                onTap: () => _showModalForm(existing: item),
              ),
              const SizedBox(width: 8),
              _buildIconButton(
                icon: Icons.delete_rounded, // Menggunakan delete_rounded
                color: AppPalette.primary,
                onTap: () => _confirmDelete(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: 54,
          child: ElevatedButton(
            onPressed: () => _showModalForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 10,
              shadowColor: AppPalette.primary.withValues(alpha: 0.4),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline_rounded, size: 20),
                const SizedBox(width: 10),
                Text(
                  "TAMBAH KATEGORI",
                  style: TextStyle(
                    fontWeight: AppFont.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showModalForm({KategoriPengeluaran? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModalAddKategoriPengeluaran(existing: existing),
    );
  }

  void _confirmDelete(KategoriPengeluaran item) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (dContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Hapus Kategori?",
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: Text("Yakin ingin menghapus kategori '${item.kategori}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dContext),
            child: const Text(
              "BATAL",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final safeContext = context;
              final safeDialogContext = dContext;
              Navigator.pop(safeDialogContext);
              final res = await safeContext
                  .read<KategoriPengeluaranProvider>()
                  .deleteKategoriPengeluaran(item.id);
              if (!mounted || !safeContext.mounted) return;
              if (res['success']) {
                CustomToast.show(
                  safeContext,
                  message: "Kategori berhasil dihapus",
                );
              } else {
                CustomToast.show(
                  safeContext,
                  message: res['message'],
                  isError: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "HAPUS",
              style: TextStyle(color: Colors.white, fontWeight: AppFont.w700),
            ),
          ),
        ],
      ),
    );
  }
}
