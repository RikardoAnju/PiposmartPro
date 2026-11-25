import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/payment_asset_util.dart';
import 'package:ayocucinew/data/models/metode_pembayaran_model.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/metode_pembayaran_provider.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/screens/settings/outlet/metode_pembayaran/widgets/modal_add_metode_pembayaran.dart';

import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/providers/customer_deposit_provider.dart';
import 'package:ayocucinew/providers/customer_provider.dart';
import 'package:ayocucinew/screens/operational/customer/customer_deposit_topup_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:intl/intl.dart';

class PaymentMethodModal extends StatelessWidget {
  final Function(String category)? onCategorySelected;

  // ✅ Tambah callback untuk reset category dari luar
  final VoidCallback? onCategoryReset;
  final VoidCallback? onManageMethods;

  const PaymentMethodModal({
    super.key,
    this.onCategorySelected,
    this.onCategoryReset,
    this.onManageMethods,
  });

  Future<void> _openAddMethodForm(BuildContext context) async {
    await showDialog(context: context, builder: (_) => const ModalAddPayment());

    if (context.mounted) {
      await context.read<PaymentMethodProvider>().fetchPaymentMethods();
    }
  }

  Future<void> _openDepositTopUp(BuildContext context) async {
    final customer = context.read<TransactionProvider>().selectedCustomer;
    if (customer == null) return;
    final navigator = Navigator.of(context);
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => CustomerDepositTopupScreen(customer: customer),
      ),
    );
    if (!context.mounted) return;
    await Future.wait([
      context.read<CustomerDepositProvider>().fetch(customer.id),
      context.read<CustomerProvider>().fetchCustomers(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandleBar(),
          _buildHeader(context),
          const Divider(height: 1),
          Flexible(
            child: Consumer2<PaymentMethodProvider, TransactionProvider>(
              builder: (context, paymentProvider, transactionProvider, child) {
                final bool isPaymentFeatureActive =
                    context.watch<AppProvider>().outlet?.isMetodePembayaran ==
                    1;
                final depositProvider = context
                    .watch<CustomerDepositProvider>();

                if (paymentProvider.isLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: AppCircularLoader(),
                    ),
                  );
                }

                final allMethods = <PaymentMethod>[
                  ...(isPaymentFeatureActive
                      ? paymentProvider.getActivePaymentMethods()
                      : [
                          if (paymentProvider.getCashPaymentMethod() != null)
                            paymentProvider.getCashPaymentMethod()!,
                        ]),
                ];
                final deposit = depositProvider.balance;
                if (!transactionProvider.payWithDP &&
                    deposit != null &&
                    (deposit.balanceRupiah > 0 || deposit.balanceKg > 0)) {
                  allMethods.add(
                    PaymentMethod(
                      id: 'DEPOSIT',
                      outletId: deposit.outletId,
                      name: 'Deposit',
                      description: 'Pilih saldo Rupiah atau Kg',
                      category: 'Deposit',
                      status: 1,
                    ),
                  );
                }
                final groupedMethods = _groupByCategory(allMethods);
                final categories = groupedMethods.keys.toList();

                if (categories.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payment_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tidak ada metode pembayaran tersedia',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (!isPaymentFeatureActive)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Fitur metode pembayaran nonaktif. Transaksi hanya memakai Cash.',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => _openAddMethodForm(context),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Tambah Metode'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppPalette.primary,
                              side: const BorderSide(
                                color: AppPalette.primaryBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: categories.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        final methods = groupedMethods[category]!;
                        return _buildCategoryTile(
                          context,
                          category,
                          methods,
                          transactionProvider,
                        );
                      },
                    ),
                    if (depositProvider.loading)
                      const Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: AppPalette.primary,
                          backgroundColor: AppPalette.primaryPale,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    String category,
    List<PaymentMethod> methods,
    TransactionProvider transactionProvider,
  ) {
    final selected = transactionProvider.selectedPaymentMethod;
    final isSelected = selected?.category == category;

    if (category.toLowerCase() == 'qris' && methods.length > 1) {
      return _buildQrisChoices(context, methods, selected, transactionProvider);
    }

    if (category.toLowerCase() == 'deposit') {
      return _buildDepositChoices(context, transactionProvider);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FocusScope.of(context).unfocus();
          if (methods.length == 1) {
            // ✅ Single method (Cash, QRIS): set method, reset category, tutup modal
            transactionProvider.setPaymentMethod(methods.first);
            // Reset cash jika bukan cash
            if (methods.first.category.toLowerCase() != 'cash') {
              transactionProvider.setCashReceived(0);
            }
            // ✅ Trigger reset _selectedCategory di PaymentMethodSection
            onCategoryReset?.call();
            Navigator.pop(context);
          } else {
            // Multi method (Transfer, E-Wallet): hanya pilih kategori, jangan set method
            transactionProvider.clearPaymentMethod();
            transactionProvider.setCashReceived(0);
            Navigator.pop(context);
            if (onCategorySelected != null) {
              onCategorySelected!(category);
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.orange.shade400 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _buildLeadingIcon(category, isSelected, selected),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDisplayName(category),
                        style: const TextStyle(
                          fontWeight: AppFont.w600,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (isSelected && selected != null)
                        _buildSelectedSubtitle(selected)
                      else
                        Text(
                          _getCategorySubtitle(category, methods.length),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (methods.length > 1)
                  Icon(
                    Icons.chevron_right,
                    color: Colors.grey.shade400,
                    size: 20,
                  )
                else if (isSelected)
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange.shade600,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.orange.shade600,
                          shape: BoxShape.circle,
                        ),
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

  Widget _buildDepositChoices(
    BuildContext context,
    TransactionProvider transactionProvider,
  ) {
    final deposit = context.watch<CustomerDepositProvider>().balance;
    if (deposit == null) return const SizedBox.shrink();
    final cart = transactionProvider.displayCartItems;
    final totalKg = cart.fold<double>(0, (sum, item) => sum + item.qty);
    final allItemsKg =
        cart.isNotEmpty &&
        cart.every((item) => item.unit.trim().toLowerCase() == 'kg');
    final hasDelivery =
        transactionProvider.jemputAntar.jemputEnabled ||
        transactionProvider.jemputAntar.antarEnabled;
    final isKiloTransaction = allItemsKg;
    const deliveryUnavailableReason =
        'Deposit hanya untuk cucian, tanpa antar/jemput';
    final kiloUnavailableReason = hasDelivery
        ? deliveryUnavailableReason
        : !allItemsKg
        ? 'Tidak tersedia · Campuran Kg & Pcs'
        : 'Saldo tidak cukup';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih Saldo Deposit',
            style: TextStyle(fontWeight: AppFont.w600, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pilih satu saldo untuk transaksi ini.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 12),
          _depositChoice(
            context,
            transactionProvider,
            id: 'DEPOSIT_RUPIAH',
            title: 'Deposit Rupiah',
            detail: hasDelivery
                ? deliveryUnavailableReason
                : deposit.balanceRupiah >= transactionProvider.totalToPay
                ? 'Saldo ${_formatRupiah(deposit.balanceRupiah)}'
                : 'Tersedia ${_formatRupiah(deposit.balanceRupiah)} · butuh ${_formatRupiah(transactionProvider.totalToPay)} · kurang ${_formatRupiah(transactionProvider.totalToPay - deposit.balanceRupiah)}',
            enabled:
                !hasDelivery &&
                deposit.balanceRupiah >= transactionProvider.totalToPay,
          ),
          const SizedBox(height: 8),
          _depositChoice(
            context,
            transactionProvider,
            id: 'DEPOSIT_KG',
            title: 'Deposit Kg',
            detail: isKiloTransaction
                ? deposit.balanceKg >= totalKg
                      ? 'Tersedia ${formatCompactQuantity(deposit.balanceKg)} Kg · butuh ${formatCompactQuantity(totalKg)} Kg'
                      : 'Tersedia ${formatCompactQuantity(deposit.balanceKg)} Kg · butuh ${formatCompactQuantity(totalKg)} Kg · kurang ${formatCompactQuantity(totalKg - deposit.balanceKg)} Kg'
                : kiloUnavailableReason,
            enabled:
                isKiloTransaction &&
                deposit.balanceKg >= totalKg &&
                totalKg > 0,
          ),
          if (transactionProvider.selectedCustomer != null &&
              !hasDelivery &&
              (deposit.balanceRupiah < transactionProvider.totalToPay ||
                  (isKiloTransaction && deposit.balanceKg < totalKg))) ...[
            const SizedBox(height: 12),
            const Text(
              'Saldo deposit kurang? Pilih metode lain atau top up pelanggan ini.',
              style: TextStyle(color: AppPalette.muted, fontSize: 12),
            ),
            TextButton.icon(
              onPressed: () => _openDepositTopUp(context),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Top Up Deposit'),
            ),
          ],
        ],
      ),
    );
  }

  String _formatRupiah(double amount) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    ).format(amount);
  }

  Widget _depositChoice(
    BuildContext context,
    TransactionProvider transactionProvider, {
    required String id,
    required String title,
    required String detail,
    required bool enabled,
  }) {
    final selected = transactionProvider.selectedPaymentMethod?.id == id;
    return InkWell(
      onTap: enabled
          ? () {
              transactionProvider.setPaymentMethod(
                PaymentMethod(
                  id: id,
                  outletId: '',
                  name: title,
                  description: detail,
                  category: 'Deposit',
                  status: 1,
                ),
              );
              transactionProvider.setCashReceived(0);
              onCategoryReset?.call();
              Navigator.pop(context);
            }
          : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: enabled
              ? (selected ? Colors.orange.shade50 : Colors.white)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? Colors.orange.shade400 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              id == 'DEPOSIT_KG'
                  ? Icons.scale_outlined
                  : Icons.account_balance_wallet_outlined,
              color: enabled ? AppPalette.primary : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: enabled ? Colors.black87 : Colors.grey,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: enabled
                          ? Colors.grey.shade600
                          : Colors.red.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrisChoices(
    BuildContext context,
    List<PaymentMethod> methods,
    PaymentMethod? selected,
    TransactionProvider transactionProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pilih QRIS',
            style: TextStyle(fontWeight: AppFont.w600, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            'Pilih cara pembayaran QRIS',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          ...methods.map((method) {
            final isSelected = selected?.id == method.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  transactionProvider.setPaymentMethod(method);
                  transactionProvider.setCashReceived(0);
                  onCategoryReset?.call();
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.orange.shade400
                          : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildLeadingIcon('QRIS', isSelected, method),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              method.isNobu ? 'QRIS Nobu' : 'QRIS Outlet',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: AppFont.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              method.isNobu
                                  ? 'QR dinamis · Otomatis'
                                  : 'Scan QR · Manual',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Nobu: QR dibuat sesuai nominal.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedSubtitle(PaymentMethod method) {
    final methodCategory = method.category.toLowerCase();

    if (methodCategory == 'transfer') {
      String bankLabel = '';
      if (method.bankName != null && method.bankName!.isNotEmpty) {
        final fullBankName = _getFullBankName(method.bankName!);
        bankLabel = fullBankName != method.bankName!
            ? '$fullBankName (${method.bankName})'
            : method.bankName!;
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bankLabel.isNotEmpty)
            Text(
              bankLabel,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (method.accountHolder != null && method.accountHolder!.isNotEmpty)
            Text(
              method.accountHolder!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (method.accountNumber != null && method.accountNumber!.isNotEmpty)
            Text(
              method.accountNumber!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    } else if (methodCategory == 'e-wallet') {
      final providerName = method.ewalletProvider != null
          ? _getEwalletDisplayName(method.ewalletProvider!)
          : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (providerName.isNotEmpty)
            Text(
              providerName,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (method.accountHolder != null && method.accountHolder!.isNotEmpty)
            Text(
              method.accountHolder!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (method.accountNumber != null && method.accountNumber!.isNotEmpty)
            Text(
              method.accountNumber!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    return Text(
      'Terpilih',
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }

  Widget _buildLeadingIcon(
    String category,
    bool isSelected,
    PaymentMethod? selected,
  ) {
    String iconPath;
    if (isSelected && selected != null) {
      final selectedCategory = selected.category.toLowerCase();
      if (selectedCategory == 'transfer' && selected.bankName != null) {
        iconPath =
            PaymentAssetUtil.getBankLogo(selected.bankName!) ??
            PaymentAssetUtil.getCategoryImage(category);
      } else if (selectedCategory == 'e-wallet' &&
          selected.ewalletProvider != null) {
        iconPath =
            PaymentAssetUtil.getEwalletLogo(selected.ewalletProvider!) ??
            PaymentAssetUtil.getCategoryImage(category);
      } else {
        iconPath = PaymentAssetUtil.getCategoryImage(category);
      }
    } else {
      iconPath = PaymentAssetUtil.getCategoryImage(category);
    }

    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _getIconBackgroundColor(category),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Image.asset(
        iconPath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            _getFallbackIcon(category),
            size: 24,
            color: _getIconColor(category),
          );
        },
      ),
    );
  }

  Color _getIconBackgroundColor(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return const Color(0xFFE8F5E9);
      case 'transfer':
        return const Color(0xFFE3F2FD);
      case 'e-wallet':
        return const Color(0xFFF3E5F5);
      case 'qris':
        return const Color(0xFFFFF3E0);
      case 'deposit':
        return const Color(0xFFFFF0E8);
      default:
        return Colors.grey.shade100;
    }
  }

  Color _getIconColor(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return const Color(0xFF4CAF50);
      case 'transfer':
        return const Color(0xFF2196F3);
      case 'e-wallet':
        return const Color(0xFF9C27B0);
      case 'qris':
        return AppPalette.warning;
      case 'deposit':
        return AppPalette.primary;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _getFallbackIcon(String category) {
    switch (category.toLowerCase()) {
      case 'cash':
        return Icons.account_balance_wallet;
      case 'transfer':
        return Icons.account_balance;
      case 'e-wallet':
        return Icons.phone_android;
      case 'qris':
        return Icons.qr_code_scanner;
      case 'deposit':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.payment;
    }
  }

  Map<String, List<PaymentMethod>> _groupByCategory(
    List<PaymentMethod> methods,
  ) {
    final Map<String, List<PaymentMethod>> grouped = {};
    for (var method in methods.where((e) => e.isActive)) {
      final category = _canonicalCategory(method.category);
      grouped.putIfAbsent(category, () => []).add(method);
    }
    final order = ['Cash', 'Transfer', 'E-Wallet', 'QRIS', 'Deposit'];
    return {
      for (var key in order)
        if (grouped.containsKey(key)) key: grouped[key]!,
    };
  }

  String _canonicalCategory(String category) {
    switch (category.trim().toLowerCase()) {
      case 'cash':
      case 'tunai':
        return 'Cash';
      case 'transfer':
        return 'Transfer';
      case 'e-wallet':
      case 'ewallet':
      case 'e_wallet':
        return 'E-Wallet';
      case 'qris':
        return 'QRIS';
      default:
        return category;
    }
  }

  String _getDisplayName(String category) {
    const displayNames = {
      'Transfer': 'Transfer Bank',
      'Cash': 'Cash',
      'E-Wallet': 'E-wallet',
      'QRIS': 'QRIS',
      'Deposit': 'Saldo Deposit',
    };
    return displayNames[category] ?? category;
  }

  String _getEwalletDisplayName(String provider) {
    final Map<String, String> ewalletNames = {
      'gopay': 'GoPay',
      'ovo': 'OVO',
      'dana': 'DANA',
      'shopeepay': 'ShopeePay',
      'linkaja': 'LinkAja',
      'jenius': 'Jenius',
    };
    final lowerProvider = provider.toLowerCase();
    for (var entry in ewalletNames.entries) {
      if (entry.key == lowerProvider) return entry.value;
    }
    return provider.substring(0, 1).toUpperCase() + provider.substring(1);
  }

  String _getFullBankName(String bankName) {
    final Map<String, String> shortToFullNames = {
      'BCA': 'Bank Central Asia',
      'BNI': 'Bank Negara Indonesia',
      'BRI': 'Bank Rakyat Indonesia',
      'Mandiri': 'Bank Mandiri',
      'CIMB': 'CIMB Niaga',
      'BSI': 'Bank Syariah Indonesia',
      'Permata': 'Bank Permata',
      'Danamon': 'Bank Danamon',
      'BTPN': 'Bank BTPN',
      'Mega': 'Bank Mega',
      'OCBC NISP': 'Bank OCBC NISP',
      'Panin': 'Bank Panin',
      'UOB': 'Bank UOB Indonesia',
    };
    if (shortToFullNames.containsKey(bankName)) {
      return shortToFullNames[bankName]!;
    }
    final upperBankName = bankName.toUpperCase();
    for (var entry in shortToFullNames.entries) {
      if (entry.key.toUpperCase() == upperBankName) {
        return entry.value;
      }
    }
    return bankName;
  }

  String _getCategorySubtitle(String category, int count) {
    switch (category.toLowerCase()) {
      case 'cash':
        return 'Bayar di tempat';
      case 'transfer':
        return 'BCA, Mandiri, BNI, BRI..';
      case 'e-wallet':
        return 'GoPay, OVO, Dana, ShopeePay..';
      case 'qris':
        return 'Scan QR untuk bayar';
      default:
        if (count > 1) return '$count pilihan tersedia';
        return 'Bayar via ${_getDisplayName(category)}';
    }
  }

  Widget _buildHandleBar() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool isPaymentFeatureActive =
        context.watch<AppProvider>().outlet?.isMetodePembayaran == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Pilih Metode Pembayaran',
            style: TextStyle(fontSize: 18, fontWeight: AppFont.w700),
          ),
          if (isPaymentFeatureActive)
            TextButton.icon(
              onPressed: onManageMethods ?? () => _openAddMethodForm(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Tambah',
                style: TextStyle(fontWeight: AppFont.w700),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppPalette.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}
