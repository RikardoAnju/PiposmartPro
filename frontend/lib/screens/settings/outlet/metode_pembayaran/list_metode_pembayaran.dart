import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import '../../../../providers/metode_pembayaran_provider.dart';

import '../../../../data/models/metode_pembayaran_model.dart';
import '../../../../shared/widgets/custom_toast.dart';
import './widgets/modal_add_metode_pembayaran.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PaymentMethodPage extends StatefulWidget {
  final String outletId;
  const PaymentMethodPage({super.key, required this.outletId});

  @override
  State<PaymentMethodPage> createState() => _PaymentMethodPageState();
}

class _PaymentMethodPageState extends State<PaymentMethodPage> {
  bool _isGlobalFeatureLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentMethodProvider>().fetchMethods();
    });
  }

  Future<void> _toggleGlobalFeature(bool value) async {
    setState(() => _isGlobalFeatureLoading = true);
    final res = await context.read<AppProvider>().updateOutletProfile(
      isMetodePembayaran: value ? 1 : 0,
    );
    setState(() => _isGlobalFeatureLoading = false);

    if (!mounted) return;
    if (res['success']) {
      CustomToast.show(
        context,
        message:
            "Fitur metode pembayaran ${value ? 'diaktifkan' : 'dinonaktifkan'}",
      );
    } else {
      CustomToast.show(context, message: res['message'], isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payProvider = context.watch<PaymentMethodProvider>();
    final outletProfile = context
        .watch<AppProvider>()
        .outlet; // Ambil data outlet langsung dari model Outlet di AppProvider

    final bool isFeatureActive = outletProfile?.isMetodePembayaran == 1;

    final activeMethods = payProvider.paymentMethods
        .where((m) => m.status == 1)
        .toList();
    final inactiveMethods = payProvider.paymentMethods
        .where((m) => m.status == 0)
        .toList();

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
            fontSize: 17,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth > 600
              ? constraints.maxWidth * 0.15
              : 20;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => payProvider.fetchMethods(),
                  color: AppPalette.primary,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 10,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Fitur Metode Pembayaran",
                          style: TextStyle(
                            fontWeight: AppFont.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Pilihan Metode Pembayaran Akan Muncul Saat Proses Pembayaran",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        _buildGlobalToggle(isFeatureActive),
                        const SizedBox(height: 24),
                        _buildExpansionSection(
                          title: "Metode Pembayaran Aktif",
                          methods: activeMethods,
                          isLoading: payProvider.isLoading,
                        ),
                        const Divider(height: 1, color: Color(0xFFEEEEEE)),
                        _buildExpansionSection(
                          title: "Metode Pembayaran Tidak Aktif",
                          methods: inactiveMethods,
                          isLoading: payProvider.isLoading,
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
              _buildAddButton(horizontalPadding),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlobalToggle(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isActive ? "Aktif" : "Tidak Aktif",
            style: TextStyle(
              fontSize: 15,
              fontWeight: AppFont.w700,
              color: isActive ? Colors.green[700] : Colors.red[700],
            ),
          ),
          _isGlobalFeatureLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: AppCircularLoader(strokeWidth: 2),
                )
              : Switch(
                  value: isActive,
                  onChanged: _toggleGlobalFeature,
                  activeColor: AppPalette.primary,
                ),
        ],
      ),
    );
  }

  Widget _buildExpansionSection({
    required String title,
    required List<PaymentMethod> methods,
    required bool isLoading,
  }) {
    return Theme(
      data: ThemeData(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: true,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: AppFont.w700,
            color: Colors.black87,
          ),
        ),
        children: isLoading && methods.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: AppCircularLoader(),
                ),
              ]
            : methods.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "Tidak ada metode pembayaran",
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ),
              ]
            : methods.map((m) => _buildPaymentItem(m)).toList(),
      ),
    );
  }

  Widget _buildPaymentItem(PaymentMethod item) {
    String displayName = item.name;
    String infoUtama = "";
    String infoPemilik = item.accountHolder ?? "";

    if (item.category.toLowerCase() == 'cash') {
      displayName = "TUNAI / CASH";
      infoUtama = "Pembayaran Tunai";
      infoPemilik = "";
    } else if (item.category.toLowerCase() == 'transfer') {
      displayName = item.name.toUpperCase();
      infoUtama = "${item.bankName ?? 'Bank'} • ${item.accountNumber ?? '-'}";
      infoPemilik = item.accountHolder ?? "";
    } else if (item.category.toLowerCase() == 'e-wallet') {
      displayName = item.name.toUpperCase();
      infoUtama =
          "${item.ewalletProvider ?? 'E-Wallet'} • ${item.phoneNumber ?? '-'}";
      infoPemilik = item.accountHolder ?? "";
    } else if (item.category.toLowerCase() == 'qris') {
      displayName = item.isNobu ? "QRIS NOBU" : "QRIS OUTLET";
      infoUtama = item.isNobu
          ? "Pembayaran QRIS otomatis via Nobu"
          : "Scan QR outlet · Konfirmasi manual";
      infoPemilik = item.accountHolder ?? "";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIcon(item.category),
              color: AppPalette.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: AppFont.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  infoUtama,
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                ),
                if (infoPemilik.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    infoPemilik,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          if (item.category.toLowerCase() != "cash")
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconActionButton(
                  icon: Icons.edit_outlined,
                  color: Colors.green,
                  onTap: () => _showModalForm(existing: item),
                ),
                const SizedBox(width: 8),
                _buildIconActionButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppPalette.primary,
                  onTap: () => _confirmDelete(item.id),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildAddButton(double padding) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(padding, 0, padding, 20),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => _showModalForm(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              "TAMBAH METODE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: AppFont.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return Icons.payments_rounded;
      case 'transfer':
        return Icons.account_balance_rounded;
      case 'e-wallet':
        return Icons.qr_code_scanner_rounded;
      case 'qris':
        return Icons.qr_code_2_rounded;
      default:
        return Icons.credit_card_rounded;
    }
  }

  void _showModalForm({PaymentMethod? existing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ModalAddPayment(existing: existing),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Hapus Metode?",
          style: TextStyle(fontWeight: AppFont.w700, fontSize: 16),
        ),
        content: const Text(
          "Metode yang sudah memiliki riwayat transaksi tidak dapat dihapus.",
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "BATAL",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final safeContext = context;
              Navigator.pop(safeContext);
              final res = await safeContext
                  .read<PaymentMethodProvider>()
                  .deleteMethod(id);
              if (!mounted || !safeContext.mounted) return;
              if (!res['success']) {
                CustomToast.show(
                  safeContext,
                  message: res['message'],
                  isError: true,
                );
              } else {
                CustomToast.show(
                  safeContext,
                  message: "Metode berhasil dihapus",
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "HAPUS",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
