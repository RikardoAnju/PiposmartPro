import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/nobu_payment_model.dart';
import '../../../../providers/nobu_payment_provider.dart';
import '../../../status/detail/detail_orderan_sereen.dart';

/// Layar pembayaran QRIS Nobu.
///
/// Menampilkan kartu QRIS sesuai panduan tampilan ASPI (Buletin ASPI
/// No. 3/III/2021 — layout "Ringkas": logo QRIS + teks standar, logo GPN,
/// nama merchant, NMID, QR, dan atribusi acquirer "QRIS by NOBU"), lalu
/// beralih ke layar status (berhasil / kedaluwarsa / gagal) begitu status
/// final diterima dari polling.
class NobuQrisPaymentScreen extends StatefulWidget {
  final String orderId;
  const NobuQrisPaymentScreen({super.key, required this.orderId});

  @override
  State<NobuQrisPaymentScreen> createState() => _NobuQrisPaymentScreenState();
}

class _NobuQrisPaymentScreenState extends State<NobuQrisPaymentScreen> {
  static const _nobuRed = Color(0xFFE31E24);
  static const _qrisPath = 'assets/icons/qris';

  Timer? _ticker;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndPoll());
    // Ticker 1 detik hanya untuk memperbarui hitung mundur masa berlaku QR.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  /// Membuat QR (idempotent di backend — mengembalikan QR yang sama jika sudah
  /// ada) lalu memulai polling status. Dipakai saat masuk layar dan sebagai
  /// aksi "Coba Lagi" bila Nobu sedang sibuk (500/timeout).
  Future<void> _generateAndPoll() async {
    if (mounted) setState(() => _initializing = true);
    final provider = context.read<NobuPaymentProvider>();
    // Bersihkan sisa state order sebelumnya (provider bersifat app-scoped)
    // agar tidak sempat menampilkan status order lain.
    provider.clear();
    final result = await provider.generate(widget.orderId);
    if (!mounted) return;
    setState(() => _initializing = false);
    if (result != null) provider.startPolling(widget.orderId);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    context.read<NobuPaymentProvider>().stopPolling();
    super.dispose();
  }

  String _rupiah(double v) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(v);

  void _goToDetail() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => DetailPesananScreen(transactionId: widget.orderId),
      ),
      (route) => route.isFirst,
    );
  }

  // Ditangani agar tombol back (AppBar maupun sistem) selalu menuju tujuan yang
  // benar: bila sudah dibayar -> lanjut ke alur sukses (pop true), selain itu
  // -> ke detail transaksi. Mencegah kasir "nyangkut" di layar metode.
  void _handleBack() {
    final payment = context.read<NobuPaymentProvider>().payment;
    if (payment?.isPaid == true) {
      Navigator.of(context).pop(true);
    } else {
      _goToDetail();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppPalette.surface,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0.5,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBack,
          ),
          title: const Text('Pembayaran QRIS'),
        ),
        body: Consumer<NobuPaymentProvider>(
          builder: (context, provider, _) {
            final payment = provider.payment;
            if (_initializing || (payment == null && provider.isLoading)) {
              return const Center(child: CircularProgressIndicator());
            }
            if (payment == null) {
              return _ErrorState(
                message: provider.errorMessage ?? 'QRIS belum tersedia.',
                onRetry: _generateAndPoll,
              );
            }
            if (payment.isPaid) {
              final paidAt = payment.paidAtLocal;
              return _ResultState.success(
                amount: _rupiah(payment.amount),
                orderId: widget.orderId,
                paymentRef: payment.paymentReferenceNo,
                paidTime: paidAt == null
                    ? null
                    : DateFormat('dd MMM yyyy • HH:mm').format(paidAt),
                onDone: () => Navigator.of(context).pop(true),
              );
            }
            if (payment.isExpired) {
              return _ResultState.expired(
                amount: _rupiah(payment.amount),
                onRegenerate: provider.isLoading
                    ? null
                    : () async {
                        final ok = await provider.generate(widget.orderId);
                        if (ok != null && context.mounted) {
                          provider.startPolling(widget.orderId);
                        }
                      },
                onBack: _goToDetail,
              );
            }
            if (payment.isFailed) {
              return _ResultState.failed(onBack: _goToDetail);
            }
            return _buildWaiting(context, provider, payment);
          },
        ),
      ),
    );
  }

  Widget _buildWaiting(
    BuildContext context,
    NobuPaymentProvider provider,
    NobuPaymentModel payment,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
      child: Column(
        children: [
          const Text(
            'Scan QRIS untuk membayar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Order ${widget.orderId}',
            style: const TextStyle(fontSize: 12, color: AppPalette.muted),
          ),
          const SizedBox(height: 18),
          if (payment.qrContent.isNotEmpty) _buildAspiCard(payment),
          const SizedBox(height: 18),
          Text(
            _rupiah(payment.amount),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppPalette.ink,
            ),
          ),
          const SizedBox(height: 10),
          _expiryChip(payment),
          const SizedBox(height: 18),
          _waitingHint(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: provider.isLoading
                  ? null
                  : () => provider.refreshStatus(widget.orderId),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Cek Status Sekarang'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppPalette.ink,
                side: const BorderSide(color: Color(0xFFD5DCE5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppPalette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Menunggu konfirmasi pembayaran dari Nobu. Halaman ini otomatis '
              'diperbarui.',
              style: TextStyle(
                fontSize: 12,
                color: AppPalette.ink.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expiryChip(NobuPaymentModel payment) {
    final exp = payment.expiredAt;
    if (exp == null) return const SizedBox.shrink();
    final remaining = exp.difference(DateTime.now());
    if (remaining.isNegative) {
      return const Text(
        'QR sudah kedaluwarsa, tekan Cek Status.',
        style: TextStyle(fontSize: 12, color: AppPalette.danger),
      );
    }
    final mm = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.timer_outlined, size: 15, color: AppPalette.muted),
        const SizedBox(width: 6),
        Text(
          'Berlaku $mm:$ss',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppPalette.muted,
          ),
        ),
      ],
    );
  }

  /// Kartu QRIS mengikuti panduan tampilan ASPI (layout Ringkas).
  Widget _buildAspiCard(NobuPaymentModel payment) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EB)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        children: [
          // Header: logo QRIS + teks standar (kiri) & logo GPN (kanan).
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Image.asset(
                  '$_qrisPath/qris_standard_logo.webp',
                  height: 28,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const SizedBox(width: 10),
              Image.asset(
                '$_qrisPath/gpn_logo.webp',
                height: 30,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const Divider(height: 22, color: Color(0xFFEDEFF2)),
          // Nama merchant + NMID.
          if (payment.merchantName.isNotEmpty)
            Text(
              payment.merchantName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
                letterSpacing: 0.2,
              ),
            ),
          if (payment.nmid.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'NMID : ${payment.nmid}',
              style: const TextStyle(fontSize: 11.5, color: AppPalette.muted),
            ),
          ],
          const SizedBox(height: 14),
          // QR dengan quiet-zone putih agar mudah dipindai.
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: QrImageView(
              data: payment.qrContent,
              size: 240,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 12),
          if (payment.acquirerCode.isNotEmpty)
            Text(
              'Dicetak oleh : ${payment.acquirerCode}',
              style: const TextStyle(fontSize: 10.5, color: AppPalette.muted),
            ),
          const SizedBox(height: 12),
          // Atribusi acquirer: "QRIS by [logo Nobu]".
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'QRIS by ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Image.asset(
                '$_qrisPath/nobu_logo.webp',
                height: 18,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Text(
                  'NOBU',
                  style: TextStyle(
                    fontSize: 13,
                    color: _nobuRed,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// State error saat QR belum bisa dimuat sama sekali.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppPalette.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.qr_code_2_rounded,
                size: 46,
                color: AppPalette.warning,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'QRIS belum bisa dibuat',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppPalette.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Layar hasil akhir (berhasil / kedaluwarsa / gagal) dengan gaya seragam.
class _ResultState extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final String? amount;
  final List<MapEntry<String, String>> details;
  final List<Widget> actions;

  const _ResultState({
    required this.icon,
    required this.accent,
    required this.title,
    required this.actions,
    this.subtitle,
    this.amount,
    this.details = const [],
  });

  factory _ResultState.success({
    required String amount,
    required String orderId,
    String? paymentRef,
    String? paidTime,
    required VoidCallback onDone,
  }) {
    return _ResultState(
      icon: Icons.check_rounded,
      accent: AppPalette.success,
      title: 'Pembayaran Berhasil',
      subtitle: 'Pembayaran QRIS telah diterima dan tercatat lunas.',
      amount: amount,
      details: [
        MapEntry('Order', orderId),
        if (paymentRef != null && paymentRef.isNotEmpty)
          MapEntry('Ref. Pembayaran', paymentRef),
        if (paidTime != null && paidTime.isNotEmpty)
          MapEntry('Waktu Bayar', paidTime),
      ],
      actions: [
        _PrimaryButton(
          label: 'Selesai',
          color: AppPalette.success,
          onTap: onDone,
        ),
      ],
    );
  }

  factory _ResultState.expired({
    required String amount,
    required VoidCallback? onRegenerate,
    required VoidCallback onBack,
  }) {
    return _ResultState(
      icon: Icons.timer_off_rounded,
      accent: AppPalette.warning,
      title: 'QRIS Kedaluwarsa',
      subtitle: 'Batas waktu pembayaran habis. Buat QR baru untuk mengulang.',
      amount: amount,
      actions: [
        _PrimaryButton(
          label: 'Buat QR Baru',
          color: AppPalette.primary,
          onTap: onRegenerate,
        ),
        const SizedBox(height: 10),
        _TextButton(label: 'Kembali', onTap: onBack),
      ],
    );
  }

  factory _ResultState.failed({required VoidCallback onBack}) {
    return _ResultState(
      icon: Icons.close_rounded,
      accent: AppPalette.danger,
      title: 'Pembayaran Gagal',
      subtitle: 'Pembayaran ditolak atau gagal diproses oleh Nobu.',
      actions: [
        _PrimaryButton(
          label: 'Kembali',
          color: AppPalette.danger,
          onTap: onBack,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 54, color: accent),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppPalette.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppPalette.muted),
              ),
            ],
            if (amount != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE4E7EB)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Pembayaran',
                      style: TextStyle(fontSize: 12, color: AppPalette.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount!,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppPalette.ink,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(height: 1, color: Color(0xFFEDEFF2)),
                      const SizedBox(height: 12),
                      ...details.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.key,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppPalette.muted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  e.value,
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppPalette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            ...actions,
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 15),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TextButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: AppPalette.muted),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
