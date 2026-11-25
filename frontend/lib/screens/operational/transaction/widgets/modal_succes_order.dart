import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/diskon_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/providers/notaprint_provider.dart';
import 'package:ayocucinew/providers/permission_provider.dart';
import 'package:ayocucinew/screens/home/home_screen.dart';
import 'package:ayocucinew/screens/settings/printer/kelolah_permission.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OrderSuccessModal extends StatefulWidget {
  final BuildContext parentContext;
  final Customer? customer;
  final Map<String, dynamic> snapshot;
  final NotaSettings? nota;
  final String notaText;
  final String customerId;
  final String customerName;
  final String orderDetail;
  final String perfume;
  final String entryDate;
  final String estimatedDate;
  final String paymentStatus;
  final String paymentMethod;
  final double totalOrder;
  final double nominalDP;
  final double discount;
  final double total;
  final double sisaBayar;
  final bool fromDetail;
  final double jemputBiaya;
  final double antarBiaya;
  final double roundingAmount;

  const OrderSuccessModal({
    super.key,
    required this.parentContext,
    required this.snapshot,
    this.nota,
    this.customer,
    required this.notaText,
    required this.customerId,
    required this.customerName,
    required this.orderDetail,
    required this.perfume,
    required this.entryDate,
    required this.estimatedDate,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalOrder,
    required this.nominalDP,
    required this.discount,
    required this.total,
    required this.sisaBayar,
    this.fromDetail = false,
    this.jemputBiaya = 0.0,
    this.antarBiaya = 0.0,
    this.roundingAmount = 0.0,
  });

  @override
  State<OrderSuccessModal> createState() => _OrderSuccessModalState();
}

class _OrderSuccessModalState extends State<OrderSuccessModal> {
  late final AudioPlayer _audioPlayer;

  Diskon? get _selectedDiscount {
    final raw = widget.snapshot['diskon'];
    if (raw is Diskon) return raw;
    if (raw is Map<String, dynamic>) return Diskon.fromJson(raw);
    return null;
  }

  String get _discountLabel {
    final selectedDiscount = _selectedDiscount;
    if (selectedDiscount != null) return selectedDiscount.paymentLabel;
    final rawLabel = widget.snapshot['discount_label']?.toString().trim();
    if (rawLabel != null && rawLabel.isNotEmpty) return rawLabel;
    return 'Diskon';
  }

  bool get _isLunas => widget.paymentStatus.toLowerCase() == 'lunas';
  bool get _isBelumLunasWithoutDP => !_isLunas && widget.nominalDP <= 0;
  bool get _isDPBelumLunas => !_isLunas && widget.nominalDP > 0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    if (!widget.fromDetail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleMainFlow();
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _playSuccessSound();
    });
  }

  // ─── FLOW UTAMA ─────────────────────────────────────────────────────────────
  //
  // Printer TIDAK terhubung:
  //   → Dialog: "Apakah ingin mengirim struk?" → Ya = buka WA | Tidak = selesai
  //
  // Printer TERHUBUNG:
  //   1. Dialog: "Cetak nota?" → Ya/Lewati
  //   2. Dialog: "Apakah ingin mengirim struk?" → Ya = buka WA | Tidak = selesai
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _handleMainFlow() async {
    if (!mounted) return;

    final permProvider = context.read<PermissionProvider>();
    final isConnected = await permProvider.refreshConnectionStatus();
    if (!mounted) return;

    if (!isConnected) {
      // Print hanya dijalankan kalau printer benar-benar terhubung.
      // Kalau belum connected, langsung lanjut ke flow WhatsApp.
      await _askSendWhatsApp();
    } else {
      // ── Printer terhubung: flow cetak dulu, lalu tanya WA ──

      // Pastikan Bluetooth nyala
      final isBluetoothOn = await permProvider.checkBluetoothState();
      if (!mounted) return;

      if (!isBluetoothOn) {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const PermissionPage()));
        if (!mounted) return;

        final isNowOn = await permProvider.checkBluetoothState();
        if (!mounted) return;
        if (!isNowOn) {
          // Bluetooth tetap mati setelah dari halaman izin, tanya WA saja
          await _askSendWhatsApp();
          return;
        }
      }

      final cetakNota = await _showConfirmDialog(
        'Apakah Anda ingin mencetak nota?',
      );
      if (!mounted) return;
      if (cetakNota == true) {
        await _printStruk();
        if (!mounted) return;
      }

      // Step 2 – Tanya kirim WA
      await _askSendWhatsApp();
    }

    if (mounted) setState(() {});
  }

  Future<void> _playSuccessSound() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {},
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.stop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/success_warm.wav'));
    } catch (e) {
      debugPrint('🔇 Order success sound playback failed: $e');
    }
  }

  // ─── DIALOG KONFIRMASI GENERIK ───────────────────────────────────────────

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmDialog(message: message),
    );
  }

  // ─── TANYA KIRIM WA ──────────────────────────────────────────────────────

  Future<void> _askSendWhatsApp() async {
    if (!mounted) return;

    final kirimWa = await _showConfirmDialog(
      'Apakah Anda ingin mengirim struk ke WhatsApp customer?',
    );
    if (!mounted) return;

    if (kirimWa == true) {
      await _sendWhatsApp();
    }
  }

  // ─── KIRIM VIA WHATSAPP ──────────────────────────────────────────────────

  Future<void> _sendWhatsApp() async {
    final phoneRaw =
        widget.customer?.phone ??
        widget.snapshot['customer_phone']?.toString() ??
        '';

    // Bersihkan nomor: hilangkan non-digit, ganti awalan 0 → 62
    String phone = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';

    final text = Uri.encodeComponent(widget.notaText);
    final uri = phone.isNotEmpty
        ? Uri.parse('https://wa.me/$phone?text=$text')
        : Uri.parse('https://wa.me/?text=$text');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        CustomToast.show(
          context,
          message: 'Tidak dapat membuka WhatsApp',
          isError: true,
        );
      }
    }
  }

  // ─── CETAK STRUK ─────────────────────────────────────────────────────────

  Future<void> _printStruk() async {
    final permProvider = context.read<PermissionProvider>();

    final isConnected = await permProvider.refreshConnectionStatus();
    if (!mounted) return;

    if (!isConnected) {
      CustomToast.show(
        context,
        message: 'Printer belum terhubung. Sambungkan printer terlebih dahulu.',
        isError: true,
      );
      return;
    }

    final printProvider = context.read<NotaPrintProvider>();
    await printProvider.printMerchantOnly(
      context: context,
      snapshot: widget.snapshot,
      customer: widget.customer,
    );

    if (!mounted) return;

    final error = printProvider.lastError;
    if (error != null) {
      CustomToast.show(context, message: error, isError: true);
      printProvider.clearError();
    }
  }

  void _backToHome() {
    if (widget.fromDetail) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.fromDetail,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _backToHome();
      },
      child: AppScaffold(
        backgroundColor: const Color(0xFFF2F2F2),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF2F2F2),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Pesanan Berhasil',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
          child: Column(
            children: [
              _buildSuccessBanner(),
              const SizedBox(height: 16),
              _buildDetailRow(
                'Nama Customer',
                '#${widget.customerId.padLeft(3, '0')} | ${widget.customerName}',
              ),
              const SizedBox(height: 10),
              _buildDetailOrderRow('Detail Order', widget.orderDetail),
              const SizedBox(height: 10),
              _buildDetailRow('Parfume', widget.perfume),
              const SizedBox(height: 10),
              _buildDetailRow('Tgl Masuk', widget.entryDate),
              const SizedBox(height: 10),
              _buildDetailRow('Est Selesai', widget.estimatedDate),
              const SizedBox(height: 10),
              _buildDetailRow(
                'Status Pembayaran',
                widget.paymentStatus,
                valueColor: widget.paymentStatus.contains('Belum Lunas')
                    ? const Color(0xFFE53935)
                    : const Color(0xFF4CAF50),
              ),
              if (!_isBelumLunasWithoutDP) ...[
                const SizedBox(height: 10),
                _buildDetailRow('Metode Pembayaran', widget.paymentMethod),
              ],
              const SizedBox(height: 16),
              _buildPriceSummaryCard(),
              const SizedBox(height: 12),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          width: double.infinity,
          height: 56,
          child: FloatingActionButton.extended(
            onPressed: _backToHome,
            elevation: 4,
            backgroundColor: AppPalette.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            label: const Text(
              'Kembali ke Beranda',
              style: TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppPalette.primaryBorder,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.primary, width: 1),
      ),
      child: Column(
        children: [
          Image.asset('assets/icons/icon_succes.webp', width: 60, height: 60),
          const SizedBox(height: 10),
          const Text(
            'Berhasil Membuat Pesanan',
            style: TextStyle(fontSize: 15, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.primaryBorder,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.primary, width: 1),
      ),
      child: Column(
        children: [
          _buildPriceRow('Total Pesanan', widget.totalOrder),
          if (widget.jemputBiaya > 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow('Biaya Jemput', widget.jemputBiaya),
          ],
          if (widget.antarBiaya > 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow('Biaya Antar', widget.antarBiaya),
          ],
          if (widget.discount > 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow(_discountLabel, widget.discount, isDiscount: true),
          ],
          if (widget.roundingAmount != 0) ...[
            const SizedBox(height: 10),
            _buildPriceRow(
              'Pembulatan',
              widget.roundingAmount,
              isRounding: true,
            ),
          ],
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: AppPalette.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
              Text(
                CurrencyFormatter.formatToRupiah(widget.total),
                style: const TextStyle(fontSize: 14, color: AppPalette.primary),
              ),
            ],
          ),
          if (_isDPBelumLunas) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              color: AppPalette.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            _buildPriceRow('Nominal DP:', widget.nominalDP),
            const SizedBox(height: 10),
            _buildPriceRow('Sisa Bayar:', widget.sisaBayar, isSisa: true),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: valueColor ?? Colors.black87),
            textAlign: TextAlign.right,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailOrderRow(String label, String value) {
    final items = value.split('\n');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: items.map((item) {
              final parts = item.split(' | ');
              if (parts.length >= 2) {
                final qtyPrice = parts[0].trim();
                final serviceName = parts.sublist(1).join(' | ').trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        qtyPrice,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                        softWrap: true,
                      ),
                      Text(
                        serviceName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                        ),
                        textAlign: TextAlign.right,
                        softWrap: true,
                      ),
                    ],
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item.trim(),
                  style: const TextStyle(fontSize: 13, color: Colors.black87),
                  textAlign: TextAlign.right,
                  softWrap: true,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isSisa = false,
    bool isRounding = false,
  }) {
    final formattedAmount = isDiscount && amount > 0
        ? CurrencyFormatter.formatToRupiah(amount).replaceAll('Rp ', '')
        : CurrencyFormatter.formatToRupiah(amount);

    final displayAmount = isRounding
        ? '${amount >= 0 ? '+' : '-'}${formattedAmount.replaceFirst('-', '').trim()}'
        : formattedAmount;

    final amountColor = isRounding
        ? const Color(0xFF5C6B7A)
        : AppPalette.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            softWrap: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: Text(
            displayAmount,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, color: amountColor),
            softWrap: true,
          ),
        ),
      ],
    );
  }
}

// ─── DIALOG KONFIRMASI (Ya / Tidak) ─────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String message;

  const _ConfirmDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Tidak', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Ya', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
