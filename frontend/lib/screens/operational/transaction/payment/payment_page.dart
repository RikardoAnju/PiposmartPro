import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/providers/metode_pembayaran_provider.dart';
import 'package:ayocucinew/screens/operational/transaction/order/antar_jemput.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/discount_section.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/payment_method.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/payment_button.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/payment_info_section.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/payment_status_section.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/price_rounding.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/transaction_summary_section.dart';
import 'package:ayocucinew/shared/orange_spinner.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/transaction_provider.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final GlobalKey _paymentMethodKey = GlobalKey();
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TransactionProvider>();
      final paymentMethodProvider = context.read<PaymentMethodProvider>();
      final isPaymentFeatureActive =
          context.read<AppProvider>().outlet?.isMetodePembayaran == 1;

      context.read<KoinProvider>().fetchEconomyConfig();

      paymentMethodProvider.fetchPaymentMethods().then((_) {
        if (!mounted || isPaymentFeatureActive) return;

        final cashMethod = paymentMethodProvider.getCashPaymentMethod();
        if (cashMethod != null) {
          provider.setPaymentMethod(cashMethod);
        }
      });

      if (!provider.isLunasMode) {
        if (provider.selectedCustomer != null) {
          provider.setPayWithDP(false);
          provider.clearPaymentMethod();
          provider.setRoundingMode(RoundingMode.none);
          provider.setPendingOrder(dpAmount: 0.0, isPaid: false);
        }
      } else {
        provider.setRoundingMode(RoundingMode.none);
        // FIX: prefill data jemput/antar dari nota yang sudah ada
        provider.prefillJemputAntarFromPendingOrder();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final bool isPelunasan = provider.isLunasMode;
        final appProvider = context.watch<AppProvider>();
        final authProvider = context.watch<AuthProvider>();
        final bool isDiskonEnabled = appProvider.outlet?.isFiturDiskon == 1;
        final bool isPaymentFeatureActive =
            appProvider.outlet?.isMetodePembayaran == 1;

        bool showRounding = false;

        if (!isPelunasan) {
          showRounding = true;
        } else {
          showRounding = provider.canRoundInPelunasan;
        }

        return Stack(
          children: [
            AppScaffold(
              backgroundColor: Colors.grey.shade100,
              appBar: AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                    size: 20,
                  ),
                  onPressed: provider.isLoading
                      ? null
                      : () => Navigator.pop(context),
                ),
                title: Text(
                  isPelunasan ? 'Pelunasan Nota' : 'Pembayaran',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ),
              body: IgnorePointer(
                ignoring: provider.isLoading,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Status pembayaran hanya di mode transaksi baru
                      if (!isPelunasan) const PaymentStatusSection(),

                      // Diskon hanya di mode transaksi baru
                      if (!isPelunasan && isDiskonEnabled)
                        const DiscountSection(),

                      // Ringkasan item
                      TransactionSummarySection(
                        cartItems: provider.displayCartItems,
                      ),

                      // FIX: Widget Jemput & Antar tampil di kedua mode
                      // - Mode baru: untuk input jemput/antar baru
                      // - Mode pelunasan: menampilkan data dari nota (sudah di-prefill),
                      //   kasir bisa ubah jika ada koreksi biaya
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: JemputAntarWidget(
                          initialData: provider.jemputAntar,
                          lockDeliveryFee:
                              isPelunasan && !authProvider.canUpdateDeliveryFee,
                          onUnauthorizedFeeEdit: () {
                            CustomToast.show(
                              context,
                              message:
                                  'Anda tidak memiliki izin untuk mengubah biaya antar/jemput.',
                              isError: true,
                            );
                          },
                          startExpanded: isPelunasan ? false : null,
                          onChanged: provider.setJemputAntar,
                        ),
                      ),

                      // Informasi pembayaran (subtotal, diskon, dll)
                      const PaymentInfoSection(),

                      // Pembulatan
                      if (showRounding) const RoundingSelector(),

                      // Metode pembayaran
                      if (provider.canShowPaymentMethod ||
                          !isPaymentFeatureActive)
                        PaymentMethodSection(key: _paymentMethodKey),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
              bottomNavigationBar: IgnorePointer(
                ignoring: provider.isLoading,
                child: PaymentBottomButton(
                  provider: provider,
                  paymentMethodKey: _paymentMethodKey,
                ),
              ),
            ),

            // Loading overlay
            if (provider.isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OrangeSpinner(size: 80),
                        SizedBox(height: 16),
                        Text(
                          'Memproses pembayaran...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: AppFont.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
