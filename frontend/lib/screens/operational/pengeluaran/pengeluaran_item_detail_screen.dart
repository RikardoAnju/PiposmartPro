import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/pengeluaran/pengeluaran_item_detail_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/operational/pengeluaran/pengeluaran_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../data/models/pengeluaran_model.dart';
import '../../../../providers/pengeluaran_provider.dart';
import '../../../../providers/payroll_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/currency_formatter.dart';
import '../../../../shared/widgets/custom_toast.dart';

class PengeluaranItemDetailScreen extends StatelessWidget {
  final Pengeluaran item;

  const PengeluaranItemDetailScreen({super.key, required this.item});

  static const _primary = AppPalette.primary;
  static const _ink = AppPalette.ink;
  static const _muted = AppPalette.muted;
  static const _surface = AppPalette.surface;

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.9),
              ),
            ),
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: AppCachedNetworkImage(
                imageUrl: ApiClient.resolveImageVariantUrl(
                  imageUrl,
                  width: 1600,
                  quality: 85,
                ),
                fit: BoxFit.contain,
                memCacheWidth: 1600,
                maxWidthDiskCache: 1600,
                errorWidget: const Icon(
                  Icons.broken_image,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final allExpenses = context.watch<PengeluaranProvider>().expenses;

    final currentItem = allExpenses.firstWhere(
      (e) => e.id == item.id,
      orElse: () => item,
    );

    return AppScaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Detail Pengeluaran",
          style: TextStyle(color: _ink, fontWeight: AppFont.w800, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: currentItem.isPayrollSource
            ? [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Payroll',
                    style: TextStyle(
                      color: AppPalette.primary,
                      fontSize: 11,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ),
              ]
            : [
                IconButton(
                  onPressed: () {
                    if (auth.hasAccess('pengeluaran', 'delete')) {
                      _showDeleteConfirm(context, currentItem);
                    } else {
                      CustomToast.show(
                        context,
                        message: "Akses ditolak. Hanya Admin/Owner.",
                        isError: true,
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppPalette.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
              ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 132),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(currentItem),
                const SizedBox(height: 22),
                _buildSectionLabel("Keterangan"),
                const SizedBox(height: 10),
                _buildNoteCard(currentItem.keterangan),
                const SizedBox(height: 22),
                _buildSectionLabel("Lampiran Bukti"),
                const SizedBox(height: 10),
                if (currentItem.bukti.isEmpty && currentItem.isPayrollSource)
                  _buildPayrollSlipAttachment(context, currentItem)
                else if (currentItem.bukti.isEmpty)
                  _buildNoImage()
                else
                  _buildCompactThumbnail(context, currentItem.bukti.first),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomAction(context, auth, currentItem),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(Pengeluaran currentItem) {
    final dateText = DateFormat(
      'EEEE, dd MMM yyyy, HH:mm',
      'id',
    ).format(currentItem.createdAt.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppPalette.brandGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentItem.kategoriNama,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: AppFont.w900,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatToRupiah(currentItem.total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: AppFont.w900,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    dateText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: AppFont.w900,
        fontSize: 13,
        color: _ink,
      ),
    );
  }

  Widget _buildNoteCard(String note) {
    final rawText = note.trim();
    final text = rawText.isEmpty
        ? "Tidak ada catatan tambahan"
        : rawText.startsWith('Pembayaran gaji ')
        ? rawText.replaceFirst(' - ', '\n')
        : rawText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF304050).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: note.trim().isEmpty ? _muted : _ink,
          height: 1.55,
          fontWeight: AppFont.w600,
        ),
      ),
    );
  }

  Widget _buildCompactThumbnail(BuildContext context, String path) {
    final String imageUrl = ApiClient.resolveImageVariantUrl(path, width: 720);
    final String previewUrl = ApiClient.resolveImageVariantUrl(
      path,
      width: 1600,
      quality: 85,
    );

    return GestureDetector(
      onTap: () => _showImagePreview(context, previewUrl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF304050).withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1.18,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppCachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 720,
                  maxWidthDiskCache: 720,
                  errorWidget: Container(
                    color: _surface,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: _muted),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 28, 14, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.zoom_in_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Ketuk untuk melihat bukti",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: AppFont.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoImage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFF3F8)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: Colors.grey,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            "Tidak ada lampiran bukti",
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: AppFont.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollSlipAttachment(
    BuildContext context,
    Pengeluaran expense,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: context.read<PayrollProvider>().fetchItemDetail(expense.sourceId),
      builder: (context, snapshot) {
        final detail = snapshot.data?['success'] == true
            ? Map<String, dynamic>.from(snapshot.data?['data'] as Map)
            : <String, dynamic>{};
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final base = PayrollProvider.toNum(detail['base_amount']).toDouble();
        final bonus = PayrollProvider.toNum(detail['bonus_amount']).toDouble();
        final deduction = PayrollProvider.toNum(
          detail['deduction_amount'],
        ).toDouble();
        final net = PayrollProvider.toNum(detail['net_amount']) == 0
            ? expense.total
            : PayrollProvider.toNum(detail['net_amount']).toDouble();
        return _buildInlineSlip(detail, expense, base, bonus, deduction, net);
      },
    );
  }

  Widget _buildInlineSlip(
    Map<String, dynamic> detail,
    Pengeluaran expense,
    double base,
    double bonus,
    double deduction,
    double net,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFE1D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppPalette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Slip Gaji ${detail['pegawai_nama'] ?? ''}'.trim(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.verified_rounded,
                size: 18,
                color: AppPalette.success,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total gaji bersih',
                style: TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: AppFont.w700,
                ),
              ),
              Text(
                CurrencyFormatter.formatToRupiah(net),
                style: const TextStyle(
                  color: AppPalette.success,
                  fontSize: 16,
                  fontWeight: AppFont.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _slipLine('Gaji pokok', CurrencyFormatter.formatToRupiah(base)),
          _slipLine(
            'Hadir / Alfa',
            '${detail['work_days'] ?? 0} hari / ${detail['alfa_days'] ?? 0} hari',
          ),
          _slipLine('Bonus & lembur', CurrencyFormatter.formatToRupiah(bonus)),
          _slipLine(
            'Potongan',
            '- ${CurrencyFormatter.formatToRupiah(deduction)}',
          ),
          const SizedBox(height: 6),
          Text(
            'Dibayar ${DateFormat('dd MMM yyyy, HH:mm', 'id').format(expense.createdAt.toLocal())}',
            style: const TextStyle(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _slipLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
        Text(
          value,
          style: const TextStyle(
            color: _ink,
            fontSize: 11,
            fontWeight: AppFont.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildBottomAction(
    BuildContext context,
    AuthProvider auth,
    Pengeluaran currentItem,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _surface.withValues(alpha: 0),
            _surface.withValues(alpha: 0.96),
            _surface,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              if (currentItem.isPayrollSource) {
                Navigator.pushNamed(context, '/pegawai-gaji');
                return;
              }
              if (auth.hasAccess('pengeluaran', 'update')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PengeluaranFormScreen(item: currentItem),
                  ),
                ).then((shouldToast) {
                  if (shouldToast == true && context.mounted) {
                    CustomToast.show(
                      context,
                      message: "Data berhasil diperbarui",
                    );
                  }
                });
              } else {
                CustomToast.show(
                  context,
                  message: "Akses ditolak. Hubungi Admin.",
                  isError: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: _primary.withValues(alpha: 0.32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  currentItem.isPayrollSource
                      ? Icons.payments_rounded
                      : Icons.edit_note_rounded,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  currentItem.isPayrollSource
                      ? "Buka Penggajian"
                      : "Perbarui Data",
                  style: const TextStyle(
                    fontWeight: AppFont.w900,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Pengeluaran currentItem) {
    if (currentItem.isPayrollSource) {
      CustomToast.show(
        context,
        message:
            'Pengeluaran dari Penggajian tidak bisa dihapus dari menu Pengeluaran.',
        isError: true,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Hapus Pengeluaran?",
          style: TextStyle(fontWeight: AppFont.w900),
        ),
        content: const Text("Data ini akan dihapus permanen dari sistem."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              "Batal",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w700),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final res = await context
                  .read<PengeluaranProvider>()
                  .deleteExpense(currentItem.id);
              if (res['success']) {
                if (context.mounted) {
                  CustomToast.show(context, message: "Berhasil dihapus");
                  Navigator.pop(context, true);
                }
              } else {
                if (context.mounted) {
                  CustomToast.show(
                    context,
                    message: res['message'] ?? "Gagal hapus",
                    isError: true,
                  );
                }
              }
            },
            child: const Text(
              "Hapus",
              style: TextStyle(
                color: AppPalette.danger,
                fontWeight: AppFont.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
