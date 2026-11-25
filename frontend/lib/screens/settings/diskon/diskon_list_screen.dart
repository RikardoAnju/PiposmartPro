import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/diskon_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/diskon_model.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/currency_formatter.dart';
import './diskon_form_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

enum _DiskonAction { edit, delete }

class DiskonListScreen extends StatefulWidget {
  const DiskonListScreen({super.key});

  @override
  State<DiskonListScreen> createState() => _DiskonListScreenState();
}

class _DiskonListScreenState extends State<DiskonListScreen> {
  bool _isGlobalFeatureLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DiskonProvider>().fetchDiscounts();
      }
    });
  }

  Future<void> _toggleGlobalFeature(bool value) async {
    setState(() => _isGlobalFeatureLoading = true);

    final res = await context.read<AppProvider>().updateOutletProfile(
      isFiturDiskon: value ? 1 : 0,
    );

    if (mounted) {
      setState(() => _isGlobalFeatureLoading = false);
      if (res['success']) {
        CustomToast.show(
          context,
          message: "Fitur diskon ${value ? 'diaktifkan' : 'dinonaktifkan'}",
        );
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DiskonProvider>();
    final appProv = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final canCreate = auth.canAccess('diskon', 'create');
    final canUpdate = auth.canAccess('diskon', 'update');
    final canDelete = auth.canAccess('diskon', 'delete');

    // MENGGUNAKAN MODEL OUTLET BARU: Ambil dari getter outlet
    final bool isFeatureActive = appProv.outlet?.isFiturDiskon == 1;

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
                onRefresh: () => provider.fetchDiscounts(),
                color: AppPalette.primary,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    140,
                  ),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Fitur Diskon",
                        style: TextStyle(
                          fontWeight: AppFont.w900,
                          fontSize: 22,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Fitur Diskon Akan Muncul dalam menu transaksi",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      _buildGlobalToggle(isFeatureActive, canUpdate),
                      const SizedBox(height: 32),
                      const Text(
                        "Diskon Saat Ini",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: AppFont.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const Text(
                        "Diskon yang tersedia saat ini",
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),

                      if (provider.isLoading && provider.discounts.isEmpty)
                        const ManagementListSkeleton(
                          showSearch: false,
                          itemCount: 4,
                        )
                      else if (provider.discounts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              "Belum ada data diskon",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: AppFont.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.discounts.length,
                          itemBuilder: (context, index) => _buildDiskonCard(
                            provider.discounts[index],
                            canUpdate: canUpdate,
                            canDelete: canDelete,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

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

  Widget _buildGlobalToggle(bool isActive, bool canUpdate) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isActive ? "FITUR DISKON AKTIF" : "FITUR DISKON NON-AKTIF",
            style: TextStyle(
              fontSize: 12,
              fontWeight: AppFont.w900,
              color: isActive ? Colors.green[800] : Colors.red[800],
              letterSpacing: 0.5,
            ),
          ),
          _isGlobalFeatureLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: AppCircularLoader(
                    strokeWidth: 2.5,
                    color: AppPalette.primary,
                  ),
                )
              : Switch(
                  value: isActive,
                  onChanged: canUpdate ? _toggleGlobalFeature : null,
                  activeThumbColor: AppPalette.primary,
                ),
        ],
      ),
    );
  }

  Widget _buildDiskonCard(
    Diskon item, {
    required bool canUpdate,
    required bool canDelete,
  }) {
    final DateFormat formatter = DateFormat('dd MMM yyyy');
    final String jadwalUtama = item.isRecurring
        ? 'Setiap: ${item.hariText}'
        : formatter.format(item.tanggalMulai);
    final String? jadwalLanjutan = item.isRecurring
        ? 'Sampai: ${formatter.format(item.tanggalAkhir)}'
        : item.tanggalMulai == item.tanggalAkhir
        ? null
        : 'Sampai: ${formatter.format(item.tanggalAkhir)}';

    String displayNilai = item.nilai.toString().replaceAll(RegExp(r'\.0$'), '');
    String potongan = item.tipe == "persen"
        ? "$displayNilai%"
        : CurrencyFormatter.formatToRupiah(item.nilai);

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.isActive ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.isActive ? "AKTIF" : "NON-AKTIF",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: AppFont.w900,
                        color: item.isActive ? Colors.green : Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  item.nama.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    fontSize: 15,
                    color: Color(0xFF2C3E50),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Potongan : $potongan",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: AppFont.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        Icons.calendar_month_rounded,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            jadwalUtama,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: AppFont.w500,
                            ),
                          ),
                          if (jadwalLanjutan != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              jadwalLanjutan,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: AppFont.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canUpdate || canDelete)
            _buildActionMenu(item, canUpdate: canUpdate, canDelete: canDelete),
        ],
      ),
    );
  }

  Widget _buildActionMenu(
    Diskon item, {
    required bool canUpdate,
    required bool canDelete,
  }) {
    return PopupMenuButton<_DiskonAction>(
      tooltip: 'Aksi diskon',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (action) {
        HapticFeedback.lightImpact();
        switch (action) {
          case _DiskonAction.edit:
            _showModalForm(existing: item);
          case _DiskonAction.delete:
            _confirmDelete(item.id);
        }
      },
      itemBuilder: (_) => [
        if (canUpdate)
          const PopupMenuItem(
            value: _DiskonAction.edit,
            child: Row(
              children: [
                Icon(Icons.edit_rounded, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Text('Edit diskon', style: TextStyle(fontWeight: AppFont.w600)),
              ],
            ),
          ),
        if (canDelete)
          const PopupMenuItem(
            value: _DiskonAction.delete,
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  color: AppPalette.danger,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(
                  'Hapus diskon',
                  style: TextStyle(
                    color: AppPalette.danger,
                    fontWeight: AppFont.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8FA),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.more_vert_rounded,
          color: Color(0xFF7D8790),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 50),
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
                  "TAMBAH DISKON",
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

  void _showModalForm({Diskon? existing}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DiskonFormScreen(existing: existing),
      ),
    );
  }

  void _confirmDelete(String id) {
    HapticFeedback.heavyImpact();
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Hapus Diskon?",
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: const Text(
          "Diskon yang sudah digunakan dalam transaksi tidak dapat dihapus.",
        ),
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
              final provider = scaffoldContext.read<DiskonProvider>();
              Navigator.pop(dContext);
              final res = await provider.deleteDiscount(id);
              if (!mounted) return;
              if (res['success']) {
                CustomToast.show(
                  scaffoldContext,
                  message: "Diskon berhasil dihapus",
                );
              } else {
                CustomToast.show(
                  scaffoldContext,
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
