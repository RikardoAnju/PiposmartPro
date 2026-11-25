import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/data/models/customer_model.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/nobu_qris_payment_screen.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/modal_uang_kembalian.dart';
import 'package:ayocucinew/screens/operational/transaction/widgets/modal_succes_order.dart';
import 'package:ayocucinew/screens/settings/koin/topup_koin_screen.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/loading_scren.dart';
import 'package:ayocucinew/shared/widgets/nota_text_builder.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class PaymentBottomButton extends StatelessWidget {
  final TransactionProvider provider;
  final GlobalKey? paymentMethodKey;
  const PaymentBottomButton({
    super.key,
    required this.provider,
    this.paymentMethodKey,
  });

  bool _canProceed(bool isPaymentFeatureActive) {
    if (!provider.isLunasMode && provider.payWithDP && provider.dpAmount <= 0) {
      return false;
    }
    if (!provider.isLunasMode &&
        provider.payWithDP &&
        provider.dpAmount > provider.grandTotal) {
      return false;
    }
    if (!isPaymentFeatureActive) {
      return !provider.canShowPaymentMethod ||
          provider.selectedPaymentMethod != null;
    }
    if (provider.isLunasMode || provider.isPaidStatus) return true;
    if (!provider.isPaidStatus) {
      if (provider.payWithDP) {
        return provider.dpAmount > 0 && provider.selectedPaymentMethod != null;
      }
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isLunasMode = provider.isLunasMode;
    final double bottomAmount = provider.totalToPay;
    final appProvider = context.watch<AppProvider>();
    final bool isPaymentFeatureActive =
        appProvider.outlet?.isMetodePembayaran == 1;
    final koinProvider = context.watch<KoinProvider>();
    final saldoKoin = appProvider.outlet?.koin ?? 0;
    final biayaTransaksiKoin = koinProvider.coinPerTransaction;
    final isSaldoKoinKurang = !isLunasMode && saldoKoin < biayaTransaksiKoin;
    final canSubmit = _canProceed(isPaymentFeatureActive) && !isSaldoKoinKurang;

    final String bottomLabel;
    if (isLunasMode) {
      bottomLabel = 'Total Pelunasan';
    } else if (provider.payWithDP) {
      bottomLabel = 'DP Dibayar';
    } else {
      bottomLabel = 'Total Pesanan';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLunasMode) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE9EEF5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildInfoBlock(
                        label: 'Saldo Koin',
                        value:
                            '${NumberFormat.decimalPattern('id_ID').format(saldoKoin)} Koin',
                        valueColor: const Color(0xFF111827),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: const Color(0xFFE5E7EB),
                    ),
                    Expanded(
                      child: _buildInfoBlock(
                        label: 'Biaya Transaksi',
                        value:
                            '-${NumberFormat.decimalPattern('id_ID').format(biayaTransaksiKoin)} Koin',
                        valueColor: AppPalette.primary,
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSaldoKoinKurang) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD8D3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 18,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Saldo koin tidak cukup untuk membuat transaksi ini.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFont.w600,
                            color: Color(0xFF7A2E24),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TopupKoinScreen(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Top up Saldo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  bottomLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  currencyFormatter.format(bottomAmount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: AppFont.w900,
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LoadingButton(
              label:
                  (isLunasMode || provider.isPaidStatus) &&
                      provider.selectedPaymentMethod == null
                  ? 'Pilih Metode Pembayaran'
                  : (isLunasMode || provider.isPaidStatus)
                  ? 'Konfirmasi Pelunasan'
                  : 'Buat Pesanan',
              isLoading: false,
              isDisabled: !canSubmit,
              onPressed: () => _handlePayment(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBlock({
    required String label,
    required String value,
    required Color valueColor,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: AppFont.w500,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  bool _isCashPayment(String? category) {
    if (category == null) return false;
    return category.toLowerCase() == 'cash' ||
        category.toLowerCase() == 'tunai';
  }

  Future<void> _handlePayment(BuildContext context) async {
    final trxProvider = context.read<TransactionProvider>();
    final isPaymentFeatureActive =
        context.read<AppProvider>().outlet?.isMetodePembayaran == 1;
    final outletKoin = context.read<AppProvider>().outlet?.koin ?? 0;
    final biayaTransaksiKoin = context.read<KoinProvider>().coinPerTransaction;
    final selectedMethod = trxProvider.selectedPaymentMethod;
    if ((trxProvider.isLunasMode || trxProvider.isPaidStatus) &&
        selectedMethod == null) {
      final target = paymentMethodKey?.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          alignment: 0.2,
        );
      }
      return;
    }
    final bool isPiutangMurni =
        !trxProvider.isLunasMode &&
        !trxProvider.isPaidStatus &&
        !trxProvider.payWithDP;

    if (!trxProvider.isLunasMode && outletKoin < biayaTransaksiKoin) {
      CustomToast.show(
        context,
        message: 'Saldo koin tidak mencukupi, silakan top up',
        isError: true,
      );
      return;
    }

    if (isPaymentFeatureActive && !isPiutangMurni && selectedMethod == null) {
      CustomToast.show(
        context,
        message: 'Silakan pilih metode pembayaran!',
        isError: true,
      );
      return;
    }

    if (!trxProvider.isLunasMode &&
        trxProvider.payWithDP &&
        trxProvider.dpAmount <= 0) {
      CustomToast.show(
        context,
        message: 'Nominal DP wajib diisi',
        isError: true,
      );
      return;
    }

    final totalToPay = trxProvider.totalToPay;
    final isCash =
        selectedMethod != null && _isCashPayment(selectedMethod.category);

    if (isPiutangMurni || !isCash) {
      await _processPayment(context);
      return;
    }

    double cashReceived = trxProvider.cashReceived;
    if (cashReceived <= 0) {
      cashReceived = totalToPay;
      trxProvider.setCashReceived(totalToPay);
    }

    if (cashReceived < totalToPay - 0.01) {
      final fmt = NumberFormat.currency(
        locale: 'id',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      CustomToast.show(
        context,
        message: 'Uang kurang dari total (${fmt.format(totalToPay)})!',
        isError: true,
      );
      return;
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ChangeMoneyModal(
        cashReceived: cashReceived,
        totalAmount: totalToPay,
        onConfirm: () async => await _processPayment(context),
      ),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    final trxProvider = context.read<TransactionProvider>();
    final selectedMethodBeforeCreate = trxProvider.selectedPaymentMethod;
    final isNobuPayment = selectedMethodBeforeCreate?.isNobu == true;

    if (trxProvider.isLunasMode) {
      // Pelunasan via QRIS Nobu harus melalui pemindaian QR — jangan tandai
      // lunas manual lewat endpoint /payment. Rutekan ke layar QRIS (QR
      // idempoten di backend: bila masih ada QR aktif, dipakai ulang), dan
      // settlement mengalir dari callback/polling Nobu seperti transaksi baru.
      if (isNobuPayment) {
        final orderId = trxProvider.transactionIdFromDetail ?? '';
        if (orderId.isEmpty) {
          CustomToast.show(
            context,
            message: 'ID transaksi tidak ditemukan untuk QRIS',
            isError: true,
          );
          return;
        }
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => NobuQrisPaymentScreen(orderId: orderId),
          ),
        );
        if (paid == true && context.mounted) {
          CustomToast.show(context, message: 'Pelunasan QRIS berhasil!');
          Navigator.pop(context, true);
        }
        return;
      }
      final res = await trxProvider.processLunas();
      if (!context.mounted) return;
      if (res['success'] == true) {
        CustomToast.show(
          context,
          message: res['message'] ?? 'Pelunasan berhasil!',
        );
        Navigator.pop(context, true);
      } else {
        CustomToast.show(
          context,
          message: res['message'] ?? 'Gagal memproses pelunasan',
          isError: true,
        );
      }
      return;
    }

    final notaProvider = context.read<NotaSettingsProvider>();
    final res = await trxProvider.createTransaction(
      forcePending: isNobuPayment,
    );
    if (!context.mounted) return;

    if (res['success'] == true) {
      final snapshot = res['snapshot'] as Map<String, dynamic>;
      if (isNobuPayment) {
        final transaction = res['transaction'] as Map<String, dynamic>?;
        final orderId =
            '${transaction?['id'] ?? transaction?['tr_id'] ?? snapshot['tr_id'] ?? ''}';
        if (orderId.isEmpty) {
          CustomToast.show(
            context,
            message: 'ID transaksi tidak ditemukan untuk QRIS',
            isError: true,
          );
          return;
        }
        // Transaksi sudah dibuat (pending). Pembuatan QR + retry ditangani di
        // dalam NobuQrisPaymentScreen sehingga kegagalan sesaat dari Nobu
        // (500/timeout) tidak meninggalkan kasir di halaman pembayaran dengan
        // keranjang kosong.
        final paid = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => NobuQrisPaymentScreen(orderId: orderId),
          ),
        );
        if (paid == true && context.mounted) {
          // QRIS membayar penuh sisa tagihan; tandai snapshot lunas agar nota
          // dan struk yang dicetak akurat, lalu masuk ke alur sukses yang sama
          // dengan metode pembayaran lain (cetak/kirim nota).
          snapshot['payment_status'] = 'Lunas';
          snapshot['tr_status_pembayaran'] = 'Lunas';
          snapshot['payment_display'] =
              selectedMethodBeforeCreate?.name ??
              snapshot['payment_display'] ??
              'QRIS';
          await _showOrderSuccess(context, res, notaProvider);
        }
        return;
      }
      if (selectedMethodBeforeCreate != null) {
        snapshot['payment_display'] = selectedMethodBeforeCreate.isNobu
            ? 'QRIS Nobu'
            : selectedMethodBeforeCreate.category.toLowerCase() == 'qris'
            ? 'QRIS Outlet'
            : selectedMethodBeforeCreate.name;
      }
      await _showOrderSuccess(context, res, notaProvider);
    } else {
      CustomToast.show(
        context,
        message: res['message'] ?? 'Gagal membuat transaksi',
        isError: true,
      );
    }
  }

  /// Menampilkan layar sukses order (struk/nota) yang dipakai bersama oleh
  /// semua metode pembayaran, termasuk QRIS Nobu setelah pembayaran diterima.
  Future<void> _showOrderSuccess(
    BuildContext context,
    Map<String, dynamic> res,
    NotaSettingsProvider notaProvider,
  ) async {
    final snapshot = res['snapshot'] as Map<String, dynamic>;
    final customer = snapshot['customer'] as Customer?;
    NotaSettings? nota = notaProvider.notaSettings;
    if (nota == null) {
      await notaProvider.fetchNotaSettings();
      if (!context.mounted) return;
      nota = context.read<NotaSettingsProvider>().notaSettings;
    }

    // Perakitan pesan WA dipusatkan di NotaTextBuilder.buildWhatsAppMessage
    // supaya identik dengan jalur "kirim text" dari detail transaksi
    // (termasuk footer WhatsApp "Terima Kasih" yang sebelumnya hilang di sini).
    final notaTextWithLink = NotaTextBuilder.buildWhatsAppMessage(
      snapshot: snapshot,
      customer: customer,
      nota: nota,
    );

    final jemputAntar = snapshot['jemput_antar'] as Map<String, dynamic>?;
    final jemputBiaya =
        (jemputAntar?['jemput_biaya'] ?? snapshot['jemput_biaya'] ?? 0.0)
            .toDouble();
    final antarBiaya =
        (jemputAntar?['antar_biaya'] ?? snapshot['antar_biaya'] ?? 0.0)
            .toDouble();
    final double subtotalItems = (snapshot['subtotal'] ?? 0.0).toDouble();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => OrderSuccessModal(
          parentContext: context,
          snapshot: snapshot,
          nota: nota,
          customer: customer,
          notaText: notaTextWithLink,
          customerId: customer?.kode ?? '000',
          customerName: customer?.name ?? '-',
          orderDetail: snapshot['order_detail'] ?? '-',
          perfume: snapshot['parfum_nama'] ?? '-',
          entryDate: DateFormat(
            'dd/MM/yyyy | HH:mm',
          ).format(snapshot['created_at'] as DateTime? ?? DateTime.now()),
          estimatedDate: snapshot['estimated_date'] != null
              ? DateFormat(
                  'dd/MM/yyyy | HH:mm',
                ).format(snapshot['estimated_date'] as DateTime)
              : '-',
          paymentStatus: snapshot['payment_status'] ?? '-',
          paymentMethod: snapshot['payment_display'] ?? 'Bayar Nanti',
          totalOrder: subtotalItems,
          nominalDP: (snapshot['dp_amount'] ?? 0.0).toDouble(),
          discount: (snapshot['discount_amount'] ?? 0.0).toDouble(),
          roundingAmount:
              (snapshot['rounding_amount'] ?? snapshot['tr_rounding'] ?? 0.0)
                  .toDouble(),
          total: (snapshot['grand_total'] ?? 0.0).toDouble(),
          sisaBayar:
              ((snapshot['grand_total'] ?? 0.0) -
                      (snapshot['dp_amount'] ?? 0.0))
                  .toDouble(),
          jemputBiaya: jemputBiaya,
          antarBiaya: antarBiaya,
        ),
      ),
      (route) => false,
    );
  }
}
