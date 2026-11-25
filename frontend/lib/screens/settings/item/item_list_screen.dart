import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/item_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../data/models/item_model.dart';
import './widgets/modal_add_item.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ItemListScreen extends StatefulWidget {
  const ItemListScreen({super.key});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ItemProvider>().fetchItems();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ItemProvider>();
    final auth = context.watch<AuthProvider>();
    final canCreate = auth.canAccess('item', 'create');
    final canUpdate = auth.canAccess('item', 'update');
    final canDelete = auth.canAccess('item', 'delete');

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
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth > 600
              ? constraints.maxWidth * 0.15
              : 20;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => provider.fetchItems(),
                color: AppPalette.primary,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),

                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    140,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderRow(provider.items.length),
                      const SizedBox(height: 20),
                      if (provider.isLoading && provider.items.isEmpty)
                        const ManagementListSkeleton(
                          showSearch: false,
                          itemCount: 5,
                        )
                      else if (provider.items.isEmpty)
                        _buildEmptyState()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.items.length,
                          itemBuilder: (context, index) {
                            return _buildItemCard(
                              provider.items[index],
                              canUpdate: canUpdate,
                              canDelete: canDelete,
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),

              // TOMBOL AKSI MODERN (Floating Style - Centered)
              if (canCreate)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildFloatingAddButton(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderRow(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Daftar Item",
          style: TextStyle(
            fontSize: 18,
            fontWeight: AppFont.w900,
            color: Color(0xFF2C3E50),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Total : $total",
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 12,
              fontWeight: AppFont.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(
    ItemLaundry item, {
    required bool canUpdate,
    required bool canDelete,
  }) {
    bool isActive = item.status == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(
          color: isActive
              ? const Color(0xFFF2F2F2)
              : Colors.red.withValues(alpha: 0.1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nama.toUpperCase(),
                    style: TextStyle(
                      fontWeight: AppFont.w700,
                      fontSize: 15,
                      color: isActive ? const Color(0xFF2C3E50) : Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? "Aktif" : "Non-Aktif",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFont.w600,
                          color: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (canUpdate || canDelete)
              Row(
                children: [
                  if (canUpdate)
                    _buildIconButton(
                      icon: Icons.edit_rounded,
                      color: Colors.green,
                      onTap: () => _showModalForm(existing: item),
                    ),
                  if (canUpdate && canDelete) const SizedBox(width: 8),
                  if (canDelete)
                    _buildIconButton(
                      icon: Icons.delete_rounded,
                      color: AppPalette.primary,
                      onTap: () => _confirmDelete(item.id),
                    ),
                ],
              ),
          ],
        ),
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
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Color(0xFFE0E0E0),
            ),
            SizedBox(height: 16),
            Text(
              "Belum ada data item",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 30,
        ), // Posisi dinaikkan agar lebih ke tengah bawah
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showModalForm();
            },
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
                SizedBox(width: 10),
                Text(
                  "TAMBAH ITEM",
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

  void _showModalForm({ItemLaundry? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModalAddItem(existing: existing),
    );
  }

  void _confirmDelete(String id) {
    HapticFeedback.heavyImpact();
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Hapus Item?",
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: const Text(
          "Item yang sudah memiliki riwayat transaksi tidak dapat dihapus, disarankan non-aktifkan saja.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "BATAL",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = scaffoldContext.read<ItemProvider>();
              Navigator.pop(dialogContext);
              final res = await provider.deleteItem(id);
              if (!mounted) return;
              if (res['success']) {
                CustomToast.show(context, message: "Item berhasil dihapus");
              } else {
                CustomToast.show(
                  context,
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
              elevation: 0,
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
