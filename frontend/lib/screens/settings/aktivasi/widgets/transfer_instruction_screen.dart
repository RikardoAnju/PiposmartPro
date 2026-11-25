import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:io';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/data/models/addon_model.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'detail_addon_trx_screen.dart';
import 'transfer_submitted_success_screen.dart';

/// Layar transfer aktivasi/addon yang sudah disederhanakan: pilih bank,
/// lihat nominal + rekening, dan upload bukti — semuanya dalam satu layar.
/// Satu tombol membuat tagihan lalu mengunggah bukti sekaligus.
class TransferInstructionScreen extends StatefulWidget {
  final double totalBayar;
  final List<String>? addonIds;
  final Map<String, String>? targetIds;
  final bool isAktivasiOnly;
  final String? voucherCode;

  const TransferInstructionScreen({
    super.key,
    required this.totalBayar,
    this.addonIds,
    this.targetIds,
    this.isAktivasiOnly = false,
    this.voucherCode,
  });

  @override
  State<TransferInstructionScreen> createState() =>
      _TransferInstructionScreenState();
}

class _TransferInstructionScreenState extends State<TransferInstructionScreen> {
  File? _imageFile;
  bool _isSubmitting = false;

  // Kalau tagihan sudah terlanjur dibuat (mis. upload gagal), simpan id-nya
  // supaya percobaan ulang tidak membuat tagihan ganda.
  String? _createdTrxId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBanks());
  }

  Future<void> _initBanks() async {
    if (!mounted) return;
    final koinProv = context.read<KoinProvider>();
    if (koinProv.bankAccounts.isEmpty) {
      await koinProv.fetchBankAccounts();
    }
    if (!mounted) return;
    // Auto-pilih bank pertama bila belum ada yang terpilih / pilihan lama tak
    // ada di daftar (mis. sisa dari flow koin).
    final banks = koinProv.bankAccounts;
    final selected = koinProv.selectedBank;
    final stillValid = selected != null &&
        banks.any((b) => b['id'].toString() == selected['id'].toString());
    if (!stillValid && banks.isNotEmpty) {
      koinProv.selectBank(banks.first);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _handleSubmit() async {
    final koinProv = context.read<KoinProvider>();
    final addonProv = context.read<AddonProvider>();

    if (koinProv.selectedBank == null) {
      CustomToast.show(context, message: "Pilih bank tujuan dulu", isError: true);
      return;
    }
    if (_imageFile == null) {
      CustomToast.show(
        context,
        message: "Pilih foto bukti transfer dulu",
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // 1. Buat tagihan (sekali saja — reuse id kalau retry).
    String? trxId = _createdTrxId;
    if (trxId == null || trxId.isEmpty) {
      Map<String, dynamic> res;
      if (widget.isAktivasiOnly) {
        res = await addonProv.activateOutlet(
          'TRANSFER',
          bankId: koinProv.selectedBank!['id'],
          voucherCode: widget.voucherCode,
        );
      } else {
        res = await addonProv.checkoutAddons(
          addonIds: widget.addonIds ?? [],
          metode: 'TRANSFER',
          targetIds: widget.targetIds,
          bankId: koinProv.selectedBank!['id'],
          voucherCode: widget.voucherCode,
        );
      }

      if (!mounted) return;
      if (res['success'] != true) {
        setState(() => _isSubmitting = false);
        CustomToast.show(
          context,
          message: res['message'] ?? "Gagal memproses pesanan",
          isError: true,
        );
        return;
      }
      trxId = res['data']?['ha_id']?.toString() ?? "";
      _createdTrxId = trxId;
      await addonProv.fetchPendingOrders();
      if (!mounted) return;
    }

    // 2. Upload bukti transfer.
    final uploadRes = await addonProv.uploadBuktiTransferAddon(
      trxId,
      _imageFile!,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (uploadRes['success'] == true) {
      await addonProv.fetchPendingOrders();
      if (!mounted) return;
      final updatedTrx = _resolveTransaction(addonProv, trxId);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransferSubmittedSuccessScreen(
            nextBuilder: (_) => updatedTrx != null
                ? DetailAddonTrxScreen(transaction: updatedTrx)
                : const SizedBox.shrink(),
          ),
        ),
      );
      return;
    }

    // Tagihan sudah dibuat tapi upload gagal — id disimpan, jadi tombol yang
    // sama bisa dipakai untuk coba upload ulang tanpa bikin tagihan baru.
    CustomToast.show(
      context,
      message: uploadRes['message'] ??
          "Tagihan dibuat, tapi bukti gagal diunggah. Coba kirim lagi.",
      isError: true,
    );
  }

  TransaksiAddon? _resolveTransaction(AddonProvider addonProv, String trxId) {
    try {
      return addonProv.pendingOrders.firstWhere((t) => t.id == trxId);
    } catch (_) {
      try {
        return addonProv.fullHistory.firstWhere((t) => t.id == trxId);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();
    final banks = koinProv.bankAccounts;
    final bank = koinProv.selectedBank;
    final isLoadingBanks = koinProv.isLoading && banks.isEmpty;

    return AppScaffold(
      backgroundColor: const Color(0xFFFFFBF8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFBF8),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF243041),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Bayar via Transfer',
          style: TextStyle(color: Color(0xFF243041), fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 176),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('NOMINAL TRANSFER'),
            const SizedBox(height: 12),
            _buildNominalCard(widget.totalBayar),
            const SizedBox(height: 28),
            _buildSectionTitle('REKENING TUJUAN'),
            const SizedBox(height: 12),
            if (isLoadingBanks)
              _buildBankLoading()
            else if (banks.isEmpty)
              _buildBankErrorState()
            else ...[
              if (banks.length > 1) ...[
                _buildBankChooser(koinProv, banks, bank),
                const SizedBox(height: 14),
              ],
              if (bank != null) _buildBankDetail(context, bank),
            ],
            const SizedBox(height: 28),
            _buildSectionTitle('UPLOAD BUKTI TRANSFER'),
            const SizedBox(height: 12),
            _buildUploadSection(),
            const SizedBox(height: 16),
            _buildUploadHint(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: (bank != null && _imageFile != null && !_isSubmitting)
                      ? _handleSubmit
                      : null,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                  label: Text(
                    _isSubmitting ? 'Mengirim...' : 'Kirim Bukti Transfer',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primaryDeep,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Transfer sesuai nominal, lalu unggah buktinya. Tagihan dibuat otomatis saat bukti dikirim.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF7C8896),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF6E7B8B),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildNominalCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppPalette.primarySoft.withValues(alpha: 0.95),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppPalette.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          const Text(
            'Total yang harus ditransfer',
            style: TextStyle(fontSize: 10.5, color: Color(0xFF7C8896)),
          ),
          const SizedBox(height: 10),
          Text(
            NumberFormat.currency(
              locale: 'id_ID',
              symbol: 'Rp ',
              decimalDigits: 0,
            ).format(total),
            style: const TextStyle(
              fontSize: 34,
              color: AppPalette.primaryDeep,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Transfer tepat sesuai nominal agar verifikasi berjalan lancar.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10.5, color: Color(0xFF7C8896)),
          ),
        ],
      ),
    );
  }

  Widget _buildBankChooser(
    KoinProvider koinProv,
    List<dynamic> banks,
    Map<String, dynamic>? selected,
  ) {
    return Column(
      children: banks.map<Widget>((b) {
        final isSelected = selected != null &&
            b['id'].toString() == selected['id'].toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => koinProv.selectBank(b),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected
                        ? AppPalette.primary
                        : const Color(0xFFECEFF2),
                    width: isSelected ? 1.6 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_rounded,
                      size: 20,
                      color: isSelected
                          ? AppPalette.primaryDeep
                          : const Color(0xFF9AA6B2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        b['bank_name']?.toString() ?? '-',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: AppFont.w700,
                          color: isSelected
                              ? const Color(0xFF243041)
                              : const Color(0xFF5B6675),
                        ),
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: isSelected
                          ? AppPalette.primary
                          : const Color(0xFFC6CDD5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBankDetail(BuildContext context, Map<String, dynamic> bank) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F3F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _rowDetail('BANK', bank['bank_name']?.toString() ?? '-'),
          const Divider(height: 24),
          _rowDetail('PENERIMA', bank['account_name']?.toString() ?? '-'),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NO. REKENING',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      bank['account_number']?.toString() ?? '-',
                      style: const TextStyle(
                        fontSize: 17,
                        letterSpacing: 0.4,
                        color: Color(0xFF314156),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: bank['account_number']?.toString() ?? "",
                    ),
                  );
                  CustomToast.show(context, message: "Nomor rekening disalin");
                },
                icon: const Icon(Icons.copy_rounded, color: AppPalette.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankLoading() {
    return Container(
      width: double.infinity,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: const AppCircularLoader(strokeWidth: 2, color: Colors.grey),
    );
  }

  Widget _buildBankErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: const Text(
        'Informasi rekening belum tersedia. Coba kembali lalu ulangi.',
        style: TextStyle(fontSize: 12, color: Color(0xFF7C8896), height: 1.45),
      ),
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _isSubmitting ? null : _pickImage,
      child: Container(
        height: 240,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _imageFile == null
                ? const Color(0xFFDEE2E6)
                : AppPalette.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: _imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    color: Colors.grey[400],
                    size: 54,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "TAP UNTUK PILIH FOTO STRUK",
                    style: TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 11,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_imageFile!, fit: BoxFit.cover),
                    Positioned(
                      right: 15,
                      top: 15,
                      child: CircleAvatar(
                        backgroundColor: Colors.black54,
                        child: IconButton(
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: _isSubmitting ? null : _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildUploadHint() {
    return const Text(
      'Pastikan nama pengirim, nominal, dan waktu transfer terlihat jelas agar verifikasi lebih cepat.',
      style: TextStyle(fontSize: 10.5, color: Color(0xFF7C8896), height: 1.45),
    );
  }

  Widget _rowDetail(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            letterSpacing: 0.3,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 15, color: Color(0xFF314156)),
          ),
        ),
      ],
    );
  }
}
