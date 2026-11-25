import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'dart:math';

import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'transfer_upload_screen.dart';

class TransferInstructionScreen extends StatefulWidget {
  const TransferInstructionScreen({
    super.key,
    required this.jumlahKoin,
    required this.totalBayar,
    this.kodeVoucher,
  });

  final int jumlahKoin;
  final double totalBayar;
  final String? kodeVoucher;

  @override
  State<TransferInstructionScreen> createState() =>
      _TransferInstructionScreenState();
}

class _TransferInstructionScreenState extends State<TransferInstructionScreen> {
  // Kode unik 3-digit di-generate di app tiap layar dibuka, lalu dikirim ke
  // backend saat "Buat Tagihan". Backend tetap menghitung ulang nominal dasar,
  // kode unik hanya mengisi 3 digit terakhir dari total.
  late final int _kodeUnik;

  @override
  void initState() {
    super.initState();
    _kodeUnik = 100 + Random().nextInt(900); // 100 - 999
  }

  /// Nominal dasar dibulatkan ke ribuan agar kode unik mengisi 3 digit terakhir
  /// tanpa carry — harus konsisten dengan perhitungan backend.
  double get _nominalDasar {
    final rounded = (widget.totalBayar / 1000).round() * 1000;
    return rounded < 20000 ? 20000 : rounded.toDouble();
  }

  double get _totalTransfer => _nominalDasar + _kodeUnik;

  Future<void> _handleConfirmTransfer(BuildContext context) async {
    final koinProv = context.read<KoinProvider>();

    final res = await koinProv.requestTopup(
      jumlahKoin: widget.jumlahKoin,
      nominalBayar: widget.totalBayar,
      metodeBayar: 'transfer',
      bankId: koinProv.selectedBank?['id'],
      kodeVoucher: widget.kodeVoucher,
      kodeUnik: _kodeUnik,
    );

    if (!context.mounted) return;

    if (res['success']) {
      final String newId = res['data']['topup_data']['tk_id'];

      Navigator.of(context).pop();
      Navigator.of(context).pop();
      Navigator.of(context).pop();

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransferUploadScreen(topupId: newId)),
      );

      CustomToast.show(
        context,
        message: "Tagihan berhasil dibuat. Lanjut upload bukti transfer.",
      );
      return;
    }

    CustomToast.show(context, message: res['message']);
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();
    final bank = koinProv.selectedBank;

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
          'Ringkasan Top Up',
          style: TextStyle(color: Color(0xFF243041), fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 170),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('NOMINAL YANG DITRANSFER'),
            const SizedBox(height: 12),
            _buildNominalCard(_totalTransfer),
            const SizedBox(height: 28),
            _buildSectionTitle('RINCIAN TOP UP'),
            const SizedBox(height: 12),
            if (bank != null)
              _buildDetailCard(bank['bank_name']?.toString() ?? '-')
            else
              _buildBankErrorState(),
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
                  onPressed: () => _handleConfirmTransfer(context),
                  icon: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Buat Tagihan',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primaryDeep,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Transfer tepat sampai 3 digit terakhir agar tagihan cepat diverifikasi.',
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
          _buildAmountWithCode(total),
          const SizedBox(height: 12),
          Text(
            'Transfer pas sampai angka $_kodeUnik biar tagihanmu langsung dikenali.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7C8896),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Menampilkan nominal dengan 3 angka terakhir (kode unik) di-highlight,
  /// menegaskan bahwa transfer harus pas tanpa perlu label "#kode" terpisah.
  Widget _buildAmountWithCode(double total) {
    final formatted = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(total);

    // Total transfer selalu berakhir dengan kode unik 3 digit.
    final splitAt = formatted.length - 3;
    final prefix = formatted.substring(0, splitAt);
    final codePart = formatted.substring(splitAt);

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 30,
          color: AppPalette.primaryDeep,
          letterSpacing: -0.5,
          height: 1.1,
        ),
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: codePart,
            style: TextStyle(
              color: AppPalette.primary,
              backgroundColor: AppPalette.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String bankName) {
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
          _rowDetail('JUMLAH KOIN', '${widget.jumlahKoin} Koin'),
          const SizedBox(height: 14),
          _rowDetail('BANK TUJUAN', bankName),
        ],
      ),
    );
  }

  Widget _buildBankErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: const Text(
        'Informasi rekening belum tersedia. Kembali lalu pilih bank tujuan lagi.',
        style: TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.4),
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
