import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'package:ayocucinew/screens/settings/aktivasi/widgets/detail_addon_trx_screen.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../providers/koin_provider.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../data/models/addon_model.dart';
import '../../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'transfer_submitted_success_screen.dart';

class TransferUploadScreen extends StatefulWidget {
  final String trxId; // ha_id dari transaksi addon atau PRO

  const TransferUploadScreen({super.key, required this.trxId});

  @override
  State<TransferUploadScreen> createState() => _TransferUploadScreenState();
}

class _TransferUploadScreenState extends State<TransferUploadScreen> {
  File? _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // ✅ AUTO SYNC: Ambil info bank berdasarkan bank_id di transaksi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBankInfo();
    });
  }

  Future<void> _initBankInfo() async {
    if (!mounted) return;
    final koinProv = context.read<KoinProvider>();
    final addonProv = context.read<AddonProvider>();

    // 1. Pastikan list bank tersedia di provider
    if (koinProv.bankAccounts.isEmpty) {
      await koinProv.fetchBankAccounts();
    }

    // 2. Cari transaksi ini di provider (Cek di pending dulu, baru history)
    TransaksiAddon? trx;
    try {
      trx = addonProv.pendingOrders.firstWhere((t) => t.id == widget.trxId);
    } catch (_) {
      try {
        trx = addonProv.fullHistory.firstWhere((t) => t.id == widget.trxId);
      } catch (_) {}
    }

    // 3. Jika ketemu bankId-nya, paksa KoinProvider pilih bank itu buat ditampilin di UI
    if (trx != null && trx.bankId != null) {
      final targetBank = koinProv.bankAccounts.firstWhere(
        (b) => b['id'].toString() == trx!.bankId.toString(),
        orElse: () => null,
      );
      if (targetBank != null) {
        koinProv.selectBank(targetBank);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Kompres biar gak kegedean
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  void _handleUpload() async {
    if (_imageFile == null) return;
    setState(() => _isUploading = true);

    final addonProv = context.read<AddonProvider>();

    final res = await addonProv.uploadBuktiTransferAddon(
      widget.trxId,
      _imageFile!,
    );

    if (mounted) {
      setState(() => _isUploading = false);
      if (res['success']) {
        CustomToast.show(context, message: "Bukti transfer berhasil dikirim!");

        // 1. Ambil objek transaksi terbaru dari provider buat dikirim ke screen detail
        // Karena tadi sudah fetchPendingOrders di layar sebelumnya, datanya pasti ada
        final updatedTrx = addonProv.pendingOrders.firstWhere(
          (t) => t.id == widget.trxId,
        );

        // 2. Ganti halaman Upload ini dengan Detail
        // Pakai pushReplacement biar kalau user klik back di detail, nggak balik ke form upload lagi
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => TransferSubmittedSuccessScreen(
              nextBuilder: (_) => DetailAddonTrxScreen(transaction: updatedTrx),
            ),
          ),
        );
      } else {
        CustomToast.show(
          context,
          message: res['message'] ?? "Gagal upload",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();
    final bank = koinProv.selectedBank;
    final trx = _resolveTransaction(context.read<AddonProvider>());
    final totalBayar = trx?.total ?? 0;

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
          'Upload Struk',
          style: TextStyle(
            color: Color(0xFF243041),
            fontSize: 16,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 176),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('NOMINAL YANG DITRANSFER'),
            const SizedBox(height: 12),
            _buildNominalCard(totalBayar),
            const SizedBox(height: 28),
            _buildSectionTitle("REKENING TUJUAN"),
            const SizedBox(height: 12),
            if (bank != null)
              _buildBankDetail(bank)
            else
              _buildBankPlaceholder(),
            const SizedBox(height: 28),
            _buildUploadHeader(),
            const SizedBox(height: 12),
            _buildUploadSection(),
            const SizedBox(height: 18),
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
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton.icon(
              onPressed: (_imageFile != null && !_isUploading)
                  ? _handleUpload
                  : null,
              icon: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
              label: Text(
                _isUploading ? 'Mengirim...' : 'Kirim Struk',
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
        ),
      ),
    );
  }

  TransaksiAddon? _resolveTransaction(AddonProvider addonProv) {
    try {
      return addonProv.pendingOrders.firstWhere((t) => t.id == widget.trxId);
    } catch (_) {
      try {
        return addonProv.fullHistory.firstWhere((t) => t.id == widget.trxId);
      } catch (_) {
        return null;
      }
    }
  }

  // --- UI COMPONENTS ---

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 12,
      color: Color(0xFF6E7B8B),
      letterSpacing: 0.8,
    ),
  );

  Widget _buildNominalCard(double total) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppPalette.primarySoft.withValues(alpha: 0.95),
          Colors.white,
        ],
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppPalette.primary.withValues(alpha: 0.10)),
    ),
    child: Column(
      children: [
        const Text(
          'Nominal transfer',
          style: TextStyle(fontSize: 10.5, color: Color(0xFF7C8896)),
        ),
        const SizedBox(height: 8),
        Text(
          NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(total),
          style: const TextStyle(
            fontSize: 30,
            color: AppPalette.primaryDeep,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Nominal transfer harus sama persis dengan tagihan yang sudah dibuat.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            color: Color(0xFF7C8896),
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _buildBankDetail(Map<String, dynamic> bank) => Container(
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
        _rowDetail("BANK", bank['bank_name']?.toString() ?? "-"),
        const SizedBox(height: 14),
        _rowDetail("PENERIMA", bank['account_name']?.toString() ?? "-"),
        const SizedBox(height: 14),
        _rowDetail("NO. REK", bank['account_number']?.toString() ?? "-"),
      ],
    ),
  );

  Widget _buildBankPlaceholder() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFF1F3F5)),
    ),
    child: const Column(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: AppCircularLoader(strokeWidth: 2, color: Colors.grey),
        ),
        SizedBox(height: 12),
        Text(
          'Informasi rekening sedang dimuat. Jika tetap kosong, kembali lalu pilih bank lagi.',
          style: TextStyle(fontSize: 12, color: Color(0xFF7C8896), height: 1.45),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Widget _buildUploadHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _buildSectionTitle("UPLOAD BUKTI TRANSFER"),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF243041).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "ID: ${widget.trxId}",
          style: const TextStyle(
            fontSize: 9,
            color: Color(0xFF243041),
          ),
        ),
      ),
    ],
  );

  Widget _buildUploadSection() => GestureDetector(
    onTap: _isUploading ? null : _pickImage,
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
                        onPressed: _pickImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );

  Widget _buildUploadHint() => const Text(
    'Pastikan nama pengirim, nominal, dan waktu transfer terlihat jelas agar proses verifikasi lebih cepat.',
    style: TextStyle(
      fontSize: 10.5,
      color: Color(0xFF7C8896),
      height: 1.45,
    ),
  );

  Widget _rowDetail(String label, String value) => Row(
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
      Text(
        value,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF314156),
        ),
      ),
    ],
  );
}
