import 'dart:async';

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/payment_asset_util.dart';
import 'package:ayocucinew/data/models/metode_pembayaran_model.dart';
import 'package:ayocucinew/providers/metode_pembayaran_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/customer_deposit_provider.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/cash_calculator.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/widgets/modal_payment_method.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/core/utils/payment_colors.dart';
import 'package:ayocucinew/core/utils/payment_icon_helper.dart';
import 'package:ayocucinew/core/utils/payment_name_helper.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/screens/settings/outlet/metode_pembayaran/list_metode_pembayaran.dart';

class PaymentMethodSection extends StatefulWidget {
  const PaymentMethodSection({super.key});

  @override
  State<PaymentMethodSection> createState() => _PaymentMethodSectionState();
}

class _PaymentMethodSectionState extends State<PaymentMethodSection> {
  String? _selectedCategory;

  Future<void> _openModal(
    BuildContext context,
    PaymentMethodProvider paymentProvider,
  ) async {
    FocusScope.of(context).unfocus();
    final transactionProvider = context.read<TransactionProvider>();
    final depositProvider = context.read<CustomerDepositProvider>();
    final customer = transactionProvider.selectedCustomer;
    final pendingLoads = <Future<void>>[];
    if (paymentProvider.paymentMethods.isEmpty && !paymentProvider.isLoading) {
      pendingLoads.add(paymentProvider.fetchPaymentMethods());
    }
    if (customer != null) {
      pendingLoads.add(depositProvider.fetch(customer.id));
    }
    if (!mounted || !context.mounted) return;
    if (pendingLoads.isNotEmpty) {
      unawaited(Future.wait(pendingLoads));
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PaymentMethodModal(
        onCategorySelected: (category) {
          // User pilih kategori multi-method (Transfer / E-Wallet)
          if (mounted) setState(() => _selectedCategory = category);
        },
        // ✅ Reset _selectedCategory saat single method dipilih (Cash / QRIS)
        onCategoryReset: () {
          if (mounted) setState(() => _selectedCategory = null);
        },
        onManageMethods: () async {
          final outlet = context.read<AppProvider>().outlet;
          Navigator.of(sheetContext).pop();
          if (outlet == null || !mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PaymentMethodPage(outletId: outlet.id.toString()),
            ),
          );
          if (!mounted) return;
          await paymentProvider.fetchPaymentMethods();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TransactionProvider, PaymentMethodProvider>(
      builder: (context, transactionProvider, paymentProvider, child) {
        final selectedPaymentMethod = transactionProvider.selectedPaymentMethod;
        final bool hasPaymentMethod = selectedPaymentMethod != null;
        final bool isCashSelected =
            selectedPaymentMethod?.category.toLowerCase() == 'cash';
        final totalToPay = transactionProvider.totalToPay;

        final allMethods = paymentProvider.getActivePaymentMethods();
        final categoryMethods = _selectedCategory != null
            ? allMethods
                  .where(
                    (m) =>
                        _canonicalCategory(m.category) == _selectedCategory &&
                        m.isActive,
                  )
                  .toList()
            : <PaymentMethod>[];

        final bool showCategoryList =
            _selectedCategory != null && categoryMethods.isNotEmpty;

        // Header text
        final String headerTitle = hasPaymentMethod
            ? _getPaymentDisplayText(selectedPaymentMethod)
            : _selectedCategory != null
            ? PaymentNameHelper.getCategoryDisplayName(_selectedCategory!)
            : 'Pilih Metode Pembayaran';

        final String headerSubtitle = hasPaymentMethod
            ? ''
            : _selectedCategory != null
            ? 'Pilih ${PaymentNameHelper.getCategoryDisplayName(_selectedCategory!)}'
            : 'Pilih cara pembayaran Anda';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header — tap untuk buka modal
              InkWell(
                onTap: () => _openModal(context, paymentProvider),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    _buildPaymentIcon(selectedPaymentMethod, _selectedCategory),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            headerTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: AppFont.w600,
                              color:
                                  hasPaymentMethod || _selectedCategory != null
                                  ? Colors.black87
                                  : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (hasPaymentMethod)
                            _buildPaymentSubtitleWidget(selectedPaymentMethod)
                          else
                            Text(
                              headerSubtitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                  ],
                ),
              ),

              // Daftar metode dalam kategori (Transfer / E-Wallet)
              if (showCategoryList) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),
                Text(
                  'Pilih ${PaymentNameHelper.getCategoryDisplayName(_selectedCategory!)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFont.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                ...categoryMethods.map((method) {
                  final isSelected = selectedPaymentMethod?.id == method.id;
                  return _buildMethodTile(
                    method,
                    isSelected,
                    transactionProvider,
                  );
                }),
              ],

              // Cash calculator — hanya tampil jika Cash dipilih
              // dan TIDAK sedang tampil category list
              if (isCashSelected && !showCategoryList) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                CashCalculatorWidget(
                  key: ValueKey(totalToPay.round()),
                  grandTotal: totalToPay,
                  onCashChanged: (amount) =>
                      transactionProvider.setCashReceived(amount),
                ),
              ],
            ],
          ),
        );
      },
    );
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
      case 'deposit':
        return 'Deposit';
      default:
        return category;
    }
  }

  Widget _buildMethodTile(
    PaymentMethod method,
    bool isSelected,
    TransactionProvider transactionProvider,
  ) {
    final subtitleLines = _getMethodSubtitleLines(method);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          transactionProvider.setPaymentMethod(method);
          if (method.category.toLowerCase() != 'cash') {
            transactionProvider.setCashReceived(0);
          }
          // ✅ Reset category setelah memilih method dari list
          setState(() => _selectedCategory = null);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.orange.shade400 : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              _buildRadioIndicator(isSelected),
              const SizedBox(width: 12),
              _buildMethodIcon(method),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getMethodName(method),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: AppFont.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitleLines.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleLines[0],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitleLines.length > 1) ...[
                        Divider(
                          height: 8,
                          thickness: 0.5,
                          color: Colors.grey.shade300,
                        ),
                        Text(
                          subtitleLines[1],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadioIndicator(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? Colors.orange.shade600 : Colors.grey.shade400,
          width: 2,
        ),
      ),
      child: isSelected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildMethodIcon(PaymentMethod method) {
    final iconPath = _resolveIconPath(method);
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: AppAssetImage(
        iconPath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorWidget: Icon(
          PaymentIconHelper.getIcon(method.category),
          size: 18,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildPaymentIcon(PaymentMethod? method, String? selectedCategory) {
    String imagePath;
    Color bgColor;

    if (method != null) {
      imagePath = _resolveIconPath(method);
      bgColor = PaymentColors.getColor(method.category).withValues(alpha: 0.1);
    } else if (selectedCategory != null) {
      imagePath = PaymentAssetUtil.getCategoryImage(selectedCategory);
      bgColor = PaymentColors.getColor(selectedCategory).withValues(alpha: 0.1);
    } else {
      imagePath = 'assets/icons/icon_cash.webp';
      bgColor = Colors.grey.shade100;
    }

    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: AppAssetImage(
        imagePath,
        width: 32,
        height: 32,
        fit: BoxFit.contain,
        errorWidget: Icon(
          PaymentIconHelper.getIcon(method?.category ?? selectedCategory ?? ''),
          size: 22,
          color: method != null
              ? PaymentColors.getColor(method.category)
              : selectedCategory != null
              ? PaymentColors.getColor(selectedCategory)
              : Colors.grey.shade600,
        ),
      ),
    );
  }

  String _resolveIconPath(PaymentMethod method) {
    final category = method.category.toLowerCase();
    if (category == 'transfer' && method.bankName != null) {
      return PaymentAssetUtil.getBankLogo(method.bankName!) ??
          PaymentAssetUtil.getCategoryImage(method.category);
    }
    if (category == 'e-wallet' && method.ewalletProvider != null) {
      return PaymentAssetUtil.getEwalletLogo(method.ewalletProvider!) ??
          PaymentAssetUtil.getCategoryImage(method.category);
    }
    return PaymentAssetUtil.getCategoryImage(method.category);
  }

  String _getMethodName(PaymentMethod method) {
    switch (method.category.toLowerCase()) {
      case 'transfer':
        return PaymentNameHelper.getBankDisplayName(
          method.bankName ?? method.name,
        );
      case 'e-wallet':
        return PaymentNameHelper.getEwalletDisplayName(
          method.ewalletProvider ?? method.name,
        );
      default:
        return method.name;
    }
  }

  String _getPaymentDisplayText(PaymentMethod method) {
    switch (method.category.toLowerCase()) {
      case 'transfer':
        return PaymentNameHelper.getBankDisplayName(
          method.bankName ?? method.name,
        );
      case 'e-wallet':
        return PaymentNameHelper.getEwalletDisplayName(
          method.ewalletProvider ?? method.name,
        );
      case 'qris':
        return method.isNobu ? 'QRIS Nobu' : 'QRIS Outlet';
      case 'cash':
        return 'Cash';
      case 'deposit':
        return method.id == 'DEPOSIT_KG' ? 'Deposit Kg' : 'Deposit Rupiah';
      default:
        return method.name;
    }
  }

  List<String> _getMethodSubtitleLines(PaymentMethod method) {
    switch (method.category.toLowerCase()) {
      case 'transfer':
        return [
          if (method.accountHolder?.isNotEmpty == true) method.accountHolder!,
          if (method.accountNumber?.isNotEmpty == true) method.accountNumber!,
        ];
      case 'e-wallet':
        return [
          if (method.accountHolder?.isNotEmpty == true) method.accountHolder!,
          if (method.phoneNumber?.isNotEmpty == true) method.phoneNumber!,
        ];
      default:
        return [];
    }
  }

  Widget _buildPaymentSubtitleWidget(PaymentMethod method) {
    final lines = _getMethodSubtitleLines(method);
    if (lines.isEmpty) {
      final fallback = method.category.toLowerCase() == 'cash'
          ? 'Pembayaran Tunai'
          : method.category.toLowerCase() == 'qris'
          ? (method.isNobu
                ? 'QR dinamis · Terverifikasi otomatis'
                : 'Scan QR outlet · Konfirmasi manual')
          : method.category.toLowerCase() == 'deposit'
          ? method.description
          : PaymentNameHelper.getCategoryDescription(method.category);
      return Text(
        fallback,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines
          .map(
            (line) => Text(
              line,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          )
          .toList(),
    );
  }
}
