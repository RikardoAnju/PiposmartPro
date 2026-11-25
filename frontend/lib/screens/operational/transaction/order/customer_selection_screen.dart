import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:provider/provider.dart';
import '../../../../providers/customer_provider.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../report/widgets/report_error_view.dart';
import '../../../../data/models/customer_model.dart';
import '../../customer/manage_customer_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/customer_deposit_balance_panel.dart';

class CustomerSelectionScreen extends StatefulWidget {
  const CustomerSelectionScreen({super.key});

  @override
  State<CustomerSelectionScreen> createState() =>
      _CustomerSelectionScreenState();
}

class _CustomerSelectionScreenState extends State<CustomerSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchCustomers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = context.watch<CustomerProvider>();
    final trxProvider = context.read<TransactionProvider>();
    final filteredCustomers = customerProvider.customers.where((c) {
      return c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.phone.contains(_searchQuery);
    }).toList();

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Pilih Customer',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Bar Pencarian
          Padding(
            padding: const EdgeInsets.all(20),
            child: AppSearchField(
              controller: _searchController,
              hintText: "Cari Nama Customer",
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          if (_searchQuery.trim().isEmpty)
            _buildRecentChips(customerProvider, trxProvider),

          Expanded(
            child: customerProvider.isLoading && !customerProvider.hasLoaded
                ? const CustomerListSkeleton()
                : customerProvider.errorMessage != null &&
                      !customerProvider.hasLoaded
                ? ReportErrorView(
                    message: customerProvider.errorMessage!,
                    onRetry: customerProvider.fetchCustomers,
                    color: AppPalette.primary,
                  )
                : filteredCustomers.isEmpty
                ? const EmptyStateWidget(message: "Customer tidak ditemukan")
                : Column(
                    children: [
                      if (customerProvider.isLoading)
                        const LinearProgressIndicator(
                          minHeight: 2,
                          color: AppPalette.primary,
                          backgroundColor: AppPalette.primaryPale,
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppPalette.primary,
                          onRefresh: customerProvider.fetchCustomers,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 20,
                              right: 20,
                              bottom: 20,
                            ),
                            itemCount: filteredCustomers.length,
                            itemBuilder: (context, index) {
                              final customer = filteredCustomers[index];
                              return _buildCustomerCard(customer, trxProvider);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      // Tombol Tambah Customer Baru
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Center(
            heightFactor: 1,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              child: ElevatedButton(
                onPressed: () => _goToAddCustomer(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  "TAMBAH CUSTOMER",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chip pelanggan yang terakhir dilayani (berdasarkan last_transaction_at dari
  /// backend), agar kasir tak perlu mengetik untuk pelanggan langganan.
  Widget _buildRecentChips(
    CustomerProvider customerProvider,
    TransactionProvider trxProvider,
  ) {
    final recents =
        customerProvider.customers
            .where((c) => c.lastTransactionAt != null)
            .toList()
          ..sort(
            (a, b) => b.lastTransactionAt!.compareTo(a.lastTransactionAt!),
          );

    if (recents.isEmpty) return const SizedBox.shrink();
    final top = recents.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Icon(
                Icons.history_rounded,
                size: 15,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Terakhir Dilayani',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: AppFont.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: top.map((c) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      trxProvider.setCustomer(c);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppPalette.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            size: 14,
                            color: AppPalette.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            c.name,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: AppFont.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(
    Customer customer,
    TransactionProvider trxProvider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          onTap: () {
            trxProvider.setCustomer(customer);
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFE5DD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppPalette.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: AppFont.w700,
                              fontSize: 16,
                              color: AppPalette.ink,
                            ),
                          ),
                          Text(
                            'ID #${customer.kode}',
                            style: const TextStyle(
                              color: AppPalette.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_iphone_rounded,
                                size: 13,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  customer.phone.trim().isEmpty
                                      ? 'No. WA belum diisi'
                                      : customer.formattedPhone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppPalette.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: () {
                          trxProvider.setCustomer(customer);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: AppPalette.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 13),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Pilih',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                CustomerDepositBalancePanel(customer: customer),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goToAddCustomer() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ManageCustomerScreen()),
    );

    if (result != null && result is Customer && mounted) {
      context.read<TransactionProvider>().setCustomer(result);
      Navigator.pop(context);
    }
  }
}
