import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';

import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'detail_topup_screen.dart';
import 'koin_topup_success_screen.dart';

class TransferUploadScreen extends StatefulWidget {
  const TransferUploadScreen({super.key, required this.topupId});

  final String topupId;

  @override
  State<TransferUploadScreen> createState() => _TransferUploadScreenState();
}

class _TransferUploadScreenState extends State<TransferUploadScreen> {
  File? _imageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final koinProv = context.read<KoinProvider>();
      if (koinProv.bankAccounts.isEmpty) {
        await koinProv.fetchBankAccounts();
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _handleUpload() async {
    if (_imageFile == null) return;

    setState(() => _isUploading = true);
    final res = await context.read<KoinProvider>().uploadBuktiTransfer(
      widget.topupId,
      _imageFile!,
    );

    if (!mounted) return;
    setState(() => _isUploading = false);

    if (res['success']) {
      final koinProvider = context.read<KoinProvider>();
      await koinProvider.fetchAllTopupRequests();
      if (!mounted) return;

      final latestTopup = koinProvider.allTopups.firstWhere(
        (t) => t['tk_id'] == widget.topupId,
        orElse: () => {'tk_id': widget.topupId},
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (successContext) => KoinTopupSuccessScreen(
            onPrimary: () => Navigator.of(successContext).pushReplacement(
              MaterialPageRoute(
                builder: (_) => DetailTopupScreen(topup: latestTopup),
              ),
            ),
          ),
        ),
      );
      return;
    }

    CustomToast.show(context, message: res['message']);
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();

    final topupData = koinProv.allTopups.firstWhere(
      (t) => t['tk_id'] == widget.topupId,
      orElse: () => {},
    );
    final totalBayar =
        double.tryParse(topupData['tk_total']?.toString() ?? '0') ?? 0;
    final bank = _resolveBank(koinProv, topupData);

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
          style: TextStyle(color: Color(0xFF243041), fontSize: 16),
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
            _buildSectionTitle('REKENING TUJUAN'),
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

  Map<String, dynamic>? _resolveBank(
    KoinProvider koinProv,
    Map<String, dynamic> topupData,
  ) {
    final selectedBank = koinProv.selectedBank;
    if (selectedBank != null) return selectedBank;

    final bankId = topupData['tk_bank_id']?.toString();
    if (bankId == null || bankId.isEmpty) return null;

    for (final bank in koinProv.bankAccounts) {
      final candidateId = bank['id']?.toString();
      if (candidateId == bankId) return bank;
    }
    return null;
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
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _copyToClipboard(total.round().toString(), 'Nominal'),
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: const Text('Salin Nominal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppPalette.primaryDeep,
              side: BorderSide(color: AppPalette.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: AppFont.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBankDetail(Map<String, dynamic> bank) {
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
          const SizedBox(height: 14),
          _rowDetail('PENERIMA', bank['account_name']?.toString() ?? '-'),
          const SizedBox(height: 14),
          _rowDetailCopy(
            'NO. REK',
            bank['account_number']?.toString() ?? '-',
            'Nomor rekening',
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String value, String label) {
    if (value.isEmpty || value == '-') return;
    Clipboard.setData(ClipboardData(text: value));
    CustomToast.show(context, message: '$label disalin');
  }

  Widget _rowDetailCopy(String label, String value, String copyLabel) {
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 7,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475467),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _copyToClipboard(value, copyLabel),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBankPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: const Text(
        'Informasi rekening sedang dimuat. Jika tetap kosong, kembali lalu pilih bank lagi.',
        style: TextStyle(fontSize: 12, color: Color(0xFF7C8896), height: 1.45),
      ),
    );
  }

  Widget _buildUploadHeader() {
    return Row(
      children: [
        Expanded(child: _buildSectionTitle('UPLOAD BUKTI TRANSFER')),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppPalette.primarySoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'ID: ${widget.topupId}',
            style: const TextStyle(fontSize: 9, color: AppPalette.primaryDeep),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickImage,
      child: Container(
        height: 236,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _imageFile == null
                ? const Color(0xFFE7D6CF)
                : AppPalette.primary.withValues(alpha: 0.35),
            width: 1.8,
          ),
        ),
        child: _imageFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: AppPalette.primarySoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppPalette.primaryDeep,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih foto struk transfer',
                    style: TextStyle(fontSize: 14, color: Color(0xFF243041)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Bisa dari galeri atau screenshot mobile banking',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF7C8896)),
                  ),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_imageFile!, fit: BoxFit.cover),
                    Positioned(
                      right: 14,
                      top: 14,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: _isUploading ? null : _pickImage,
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF3E1D9)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            size: 18,
            color: AppPalette.primaryDeep,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pastikan nominal dan rekening tujuan terlihat jelas.',
              style: TextStyle(
                fontSize: 10.5,
                color: Color(0xFF6E7B8B),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowDetail(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF98A2B3)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 7,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF475467),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
