import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/quantity_formatter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_font.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/customer_deposit_model.dart';
import '../../../data/models/customer_model.dart';
import '../../../data/models/deposit_report_model.dart';
import '../../../providers/deposit_report_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/app_shimmer.dart';
import '../../../shared/widgets/app_page_bar.dart';
import '../widgets/report_error_view.dart';
import '../../operational/customer/customer_deposit_history_screen.dart';
import 'deposit_activity_history_screen.dart';
import 'deposit_analytics_screen.dart';
import 'widgets/deposit_activity_card.dart';

class DepositReportScreen extends StatefulWidget {
  const DepositReportScreen({super.key});

  @override
  State<DepositReportScreen> createState() => _DepositReportScreenState();
}

class _DepositReportScreenState extends State<DepositReportScreen>
    with WidgetsBindingObserver {
  // Dashboard hanya menampilkan aktivitas hari berjalan. Saldo pada header
  // tetap saldo aktif karena backend menghitungnya terpisah dari periode ledger.
  DateTime _reportDay = DateTime.now();
  DateTime get _start =>
      DateTime(_reportDay.year, _reportDay.month, _reportDay.day);
  DateTime get _end => _start;
  final _money = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isDifferentDay(DateTime.now())) {
      _load();
    }
  }

  bool _isDifferentDay(DateTime date) =>
      date.year != _reportDay.year ||
      date.month != _reportDay.month ||
      date.day != _reportDay.day;

  Future<void> _load() {
    _reportDay = DateTime.now();
    return context.read<DepositReportProvider>().fetch(
      startDate: _start,
      endDate: _end,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: const AppPageBar(title: 'Laporan Deposit'),
      body: Consumer<DepositReportProvider>(
        builder: (context, provider, _) => Column(
          children: [
            Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _buildHeader(provider.header),
            ),
            if (provider.isLoading && provider.hasLoaded)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppPalette.primary,
                backgroundColor: AppPalette.primaryPale,
              ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 12, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Aktivitas Hari Ini',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: AppFont.w700,
                            color: AppPalette.ink,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DepositActivityHistoryScreen(
                                  startDate: DateTime.now().subtract(
                                    const Duration(days: 6),
                                  ),
                                  endDate: DateTime.now(),
                                ),
                              ),
                            );
                            if (mounted) _load();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppPalette.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Lihat Semua',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: AppFont.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        MediaQuery.viewPaddingOf(context).bottom + 88,
                      ),
                      children: [
                        if (provider.isLoading && !provider.hasLoaded)
                          const _DepositActivityListSkeleton()
                        else if (provider.errorMessage != null &&
                            !provider.hasLoaded)
                          ReportErrorView(
                            message: provider.errorMessage!,
                            onRetry: _load,
                            color: AppPalette.primary,
                          )
                        else if (provider.entries.isEmpty)
                          const EmptyStateWidget.laporan(
                            title: 'Belum ada aktivitas hari ini',
                            message:
                                'Top up, pemakaian, atau pengembalian deposit hari ini akan muncul di sini.',
                            imagePath: 'assets/maskot/4 1.webp',
                            imageWidth: 150,
                          )
                        else
                          ...provider.entries
                              .take(5)
                              .map(
                                (entry) => DepositActivityCard(
                                  entry: entry,
                                  onTap: () => _openEntry(entry),
                                ),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DepositAnalyticsScreen()),
        ),
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.insights_outlined),
        label: const Text(
          'Analitik',
          style: TextStyle(fontWeight: AppFont.w700),
        ),
      ),
    );
  }

  Widget _buildHeader(DepositReportHeader h) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: .24),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Saldo Deposit Outlet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: AppFont.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Akumulasi saldo seluruh pelanggan',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _balance('Rupiah', _money.format(h.currentRupiah)),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: .32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _balance(
                  'Kiloan',
                  '${formatCompactQuantity(h.currentKg)} Kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.payments_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uang diterima hari ini',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .86),
                      fontSize: 12,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
                Text(
                  _money.format(h.totalPaidTopUpRupiah + h.totalPaidTopUpKg),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Diskon program deposit',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .86),
                      fontSize: 12,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
                Text(
                  _money.format(h.totalDiscountRupiah + h.totalDiscountKg),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balance(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: .8),
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: AppFont.w800,
        ),
      ),
    ],
  );

  // Kept temporarily as the visual specification for the activity-ledger summary.
  // ignore: unused_element
  Widget _buildActivitySummary(DepositReportHeader h) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Aktivitas dalam Periode',
          style: TextStyle(
            fontSize: 18,
            fontWeight: AppFont.w700,
            color: AppPalette.ink,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Mutasi deposit pada rentang yang dipilih',
          style: TextStyle(fontSize: 12, color: AppPalette.muted),
        ),
        const SizedBox(height: 10),
        _activityMetric(
          'Top Up',
          Icons.add_rounded,
          h.totalTopUpRupiah,
          h.totalTopUpKg,
          const Color(0xFF16A765),
        ),
        const SizedBox(height: 8),
        _activityMetric(
          'Pemakaian',
          Icons.shopping_bag_outlined,
          h.totalUsageRupiah,
          h.totalUsageKg,
          AppPalette.primary,
        ),
        const SizedBox(height: 8),
        _activityMetric(
          'Pengembalian',
          Icons.replay_rounded,
          h.totalRefundRupiah,
          h.totalRefundKg,
          const Color(0xFF5B7CFA),
        ),
      ],
    );
  }

  Widget _activityMetric(
    String label,
    IconData icon,
    double rupiah,
    double kg,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .14)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color.withValues(alpha: .1),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: AppFont.w800,
                  color: AppPalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _activityValue(
                  label: 'Rupiah',
                  value: _money.format(rupiah),
                  color: color,
                ),
              ),
              Container(width: 1, height: 30, color: const Color(0xFFE8EDF0)),
              Expanded(
                child: _activityValue(
                  label: 'Kiloan',
                  value: '${formatCompactQuantity(kg)} Kg',
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityValue({
    required String label,
    required String value,
    required Color color,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppPalette.muted),
      ),
      const SizedBox(height: 3),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: AppFont.w900,
            color: color,
          ),
        ),
      ),
    ],
  );

  // Kept temporarily while the shared card is rolled out to every deposit list.
  // ignore: unused_element
  Widget _buildEntry(DepositReportEntry item) {
    final type = item.activityType.toUpperCase();
    final isTopUp = type == 'TOP_UP';
    final isRefund = type == 'REFUND';
    final isUsage = type == 'USAGE';
    final isKnownActivity = isTopUp || isRefund || isUsage;
    final isPositive = isTopUp || isRefund;
    final color = isPositive
        ? const Color(0xFF16A765)
        : const Color(0xFFE65345);
    final label = isTopUp
        ? 'Top Up Deposit'
        : isRefund
        ? 'Pengembalian Deposit'
        : isUsage
        ? 'Pemakaian Deposit'
        : 'Aktivitas Deposit';
    final amount = !isKnownActivity
        ? 'Perlu dicek'
        : item.depositType.toUpperCase() == 'KG'
        ? '${isPositive ? '+' : '-'}${formatCompactQuantity(item.amount)} Kg'
        : '${isPositive ? '+' : '-'}${_money.format(item.amount)}';
    return InkWell(
      onTap: isKnownActivity ? () => _openEntry(item) : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.cardSoft,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: color.withValues(alpha: .1),
              child: Icon(
                type == 'TOP_UP'
                    ? Icons.add_rounded
                    : type == 'REFUND'
                    ? Icons.replay_rounded
                    : Icons.shopping_bag_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: AppFont.w700,
                            color: AppPalette.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        amount,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: AppFont.w800,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$label • ${item.depositType == 'KG' ? 'Deposit Kg' : 'Deposit Rupiah'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppPalette.muted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.createdAt == null
                            ? '-'
                            : DateFormat(
                                'dd MMM yyyy, HH:mm',
                                'id_ID',
                              ).format(item.createdAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppPalette.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: AppPalette.muted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Dibuat oleh ${item.createdByName.trim().isEmpty ? 'Sistem' : item.createdByName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppPalette.muted,
                          ),
                        ),
                      ),
                      if (isKnownActivity)
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 17,
                          color: AppPalette.muted,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEntry(DepositReportEntry item) async {
    if (item.customerId.isEmpty) return;
    final customer = Customer(
      id: item.customerId,
      outletId: '',
      kode: '',
      name: item.customerName,
      phone: '',
      gender: '',
      address: '',
      status: 1,
    );
    final entry = CustomerDepositLedgerEntry(
      entryType: item.activityType,
      depositType: item.depositType,
      referenceId: item.referenceId,
      note: item.note,
      paymentMethod: item.paymentMethod,
      createdBy: '',
      createdByName: item.createdByName,
      createdByType: '',
      amount: item.amount,
      paidAmount: item.paidAmount,
      discountAmount: item.discountAmount,
      balanceBefore: item.balanceBefore,
      balanceAfter: item.balanceAfter,
      createdAt: item.createdAt,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CustomerDepositDetailScreen(customer: customer, entry: entry),
      ),
    );
  }
}

class _DepositActivityListSkeleton extends StatelessWidget {
  const _DepositActivityListSkeleton();

  @override
  Widget build(BuildContext context) => AppShimmer(
    child: Column(
      children: List.generate(
        3,
        (_) => const AppSkeletonBox(
          height: 86,
          radius: 18,
          margin: EdgeInsets.only(bottom: 10),
        ),
      ),
    ),
  );
}

class DepositFilterSheet extends StatelessWidget {
  final String activity;
  final String depositType;
  final Customer? selectedCustomer;
  final List<Customer> customers;
  const DepositFilterSheet({
    super.key,
    required this.activity,
    required this.depositType,
    required this.selectedCustomer,
    required this.customers,
  });

  @override
  Widget build(BuildContext context) {
    String selectedActivity = activity;
    String selectedType = depositType;
    Customer? customer = selectedCustomer;
    return StatefulBuilder(
      builder: (context, setState) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Laporan Deposit',
                style: TextStyle(fontSize: 18, fontWeight: AppFont.w700),
              ),
              const SizedBox(height: 18),
              if (customers.isNotEmpty) ...[
                const Text(
                  'Pelanggan',
                  style: TextStyle(fontWeight: AppFont.w600),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked =
                        await showModalBottomSheet<DepositCustomerSelection>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => DepositCustomerPicker(
                            customers: customers,
                            selectedCustomer: customer,
                          ),
                        );
                    if (picked != null) {
                      setState(() => customer = picked.customer);
                    }
                  },
                  icon: const Icon(Icons.person_outline_rounded, size: 18),
                  label: Text(
                    customer?.name ?? 'Semua pelanggan',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppPalette.ink,
                    side: const BorderSide(color: Color(0xFFE4E9EE)),
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (customer != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => customer = null),
                      child: const Text('Hapus pilihan'),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
              const Text(
                'Aktivitas',
                style: TextStyle(fontWeight: AppFont.w600),
              ),
              Wrap(
                spacing: 8,
                children:
                    [
                          ('Semua', ''),
                          ('Top Up', 'TOP_UP'),
                          ('Koreksi', 'CORRECTION'),
                          ('Pemakaian', 'USAGE'),
                          ('Pengembalian', 'REFUND'),
                        ]
                        .map(
                          (item) => ChoiceChip(
                            label: Text(item.$1),
                            selected: selectedActivity == item.$2,
                            onSelected: (_) =>
                                setState(() => selectedActivity = item.$2),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
              const Text(
                'Jenis saldo',
                style: TextStyle(fontWeight: AppFont.w600),
              ),
              Wrap(
                spacing: 8,
                children: [('Semua', ''), ('Rupiah', 'RUPIAH'), ('Kg', 'KG')]
                    .map(
                      (item) => ChoiceChip(
                        label: Text(item.$1),
                        selected: selectedType == item.$2,
                        onSelected: (_) =>
                            setState(() => selectedType = item.$2),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    DepositFilterResult(
                      activity: selectedActivity,
                      depositType: selectedType,
                      customer: customer,
                    ),
                  ),
                  child: const Text('Terapkan Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DepositFilterResult {
  final String activity;
  final String depositType;
  final Customer? customer;

  const DepositFilterResult({
    required this.activity,
    required this.depositType,
    required this.customer,
  });
}

class DepositCustomerPicker extends StatefulWidget {
  final List<Customer> customers;
  final Customer? selectedCustomer;

  const DepositCustomerPicker({
    super.key,
    required this.customers,
    required this.selectedCustomer,
  });

  @override
  State<DepositCustomerPicker> createState() => _DepositCustomerPickerState();
}

class _DepositCustomerPickerState extends State<DepositCustomerPicker> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final customers = widget.customers.where((customer) {
      return query.isEmpty ||
          customer.name.toLowerCase().contains(query) ||
          customer.phone.toLowerCase().contains(query) ||
          customer.kode.toLowerCase().contains(query);
    }).toList();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * .72,
      padding: EdgeInsets.fromLTRB(20, 14, 20, 16 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD7DEE5),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pilih Pelanggan',
              style: TextStyle(fontSize: 18, fontWeight: AppFont.w700),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: 'Cari pelanggan atau nomor WA',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF7F9FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE4E9EE)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: customers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: AppPalette.primaryPale,
                      child: Icon(
                        Icons.people_outline_rounded,
                        color: AppPalette.primary,
                      ),
                    ),
                    title: const Text('Semua pelanggan'),
                    trailing: widget.selectedCustomer == null
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppPalette.primary,
                          )
                        : null,
                    onTap: () => Navigator.pop(
                      context,
                      const DepositCustomerSelection(customer: null),
                    ),
                  );
                }
                final customer = customers[index - 1];
                final isSelected = customer.id == widget.selectedCustomer?.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFE5DD),
                    child: Icon(
                      Icons.person_rounded,
                      color: AppPalette.primary,
                    ),
                  ),
                  title: Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    customer.phone.trim().isEmpty
                        ? 'No. WA belum diisi'
                        : customer.phone,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: AppPalette.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(
                    context,
                    DepositCustomerSelection(customer: customer),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DepositCustomerSelection {
  final Customer? customer;

  const DepositCustomerSelection({required this.customer});
}
