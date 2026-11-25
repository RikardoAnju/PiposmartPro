import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/operational/transaction/order/antar_jemput.dart';
import 'package:ayocucinew/screens/operational/transaction/order/modal_parfum_selection.dart';
import 'package:ayocucinew/screens/operational/transaction/order/optional_item_note_widget.dart';
import 'package:ayocucinew/screens/settings/parfum/widgets/modal_add_parfum.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/service_usage_tracker.dart';
import '../../../../data/models/customer_model.dart';
import '../../../../data/models/service_model.dart';
import '../../../../data/models/transaction_model.dart';
import '../../../../data/models/parfum_model.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/parfum_provider.dart';
import '../../../../providers/service_provider.dart';
import '../../../../providers/transaction_provider.dart';
import 'customer_selection_screen.dart';
import 'service_selection_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/responsive_center.dart';

class OrderScreen extends StatefulWidget {
  final String? editTransactionId;

  const OrderScreen({super.key, this.editTransactionId});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  static const double _maxQty = 999999.9999;
  static const int _maxIntegerDigits = 6;
  static const int _maxDecimalDigits = 4;

  final _currencyFormatter = NumberFormat.currency(
    locale: 'id',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  Map<String, int> _usageCounts = {};
  bool _isRepeating = false;

  bool get _isEditMode => widget.editTransactionId != null;
  bool get _isPaidEditMode =>
      _isEditMode &&
      context.read<TransactionProvider>().currentDetail?.paymentStatus ==
          'Lunas';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScreen();
    });
  }

  Future<void> _initializeScreen() async {
    final trxProvider = context.read<TransactionProvider>();
    final parfumProvider = context.read<ParfumProvider>();
    final serviceProvider = context.read<ServiceProvider>();

    await parfumProvider.fetchParfums();
    if (!mounted) return;

    // Untuk fitur "Tambah Cepat": pastikan daftar layanan tersedia & muat
    // riwayat pemakaian lokal untuk pengurutan chip.
    if (serviceProvider.categories.isEmpty) {
      await serviceProvider.fetchServices();
    }
    // Ranking global se-outlet (dari backend) untuk urutan chip "Tambah Cepat".
    serviceProvider.fetchPopularServices();
    final counts = await ServiceUsageTracker.getCounts();
    if (!mounted) return;
    setState(() => _usageCounts = counts);

    if (_isEditMode) {
      if (trxProvider.currentDetail == null ||
          trxProvider.currentDetail!.id != widget.editTransactionId) {
        await trxProvider.fetchTransactionById(widget.editTransactionId!);
        if (!mounted) return;
      }

      final detail = trxProvider.currentDetail;
      if (detail != null) {
        trxProvider.loadCartFromEdit(detail);
        trxProvider.syncSelectedParfumFromList(parfumProvider.parfums);
        if (detail.customer != null) trxProvider.setCustomer(detail.customer!);
        trxProvider.setNotes(detail.notes);
      }
    } else {
      if (!trxProvider.isOrderActive) {
        trxProvider.startNewOrder();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final trxProvider = context.watch<TransactionProvider>();
    final parfumProvider = context.watch<ParfumProvider>();
    final authProvider = context.watch<AuthProvider>();
    final customer = trxProvider.selectedCustomer;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(trxProvider),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveCenter(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    _buildCustomerSection(customer),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_isEditMode && customer != null) ...[
                            if ((customer.lastTransactionId ?? '').isNotEmpty)
                              _buildRepeatOrderButton(customer, trxProvider),
                            _buildQuickAddSection(trxProvider),
                          ],
                          _buildDetailOrderCard(trxProvider, customer),
                          const SizedBox(height: 20),
                          const OptionalItemsNotesWidget(showNotes: false),
                          const SizedBox(height: 20),
                          _buildParfumSection(parfumProvider, trxProvider),
                          const SizedBox(height: 20),
                          const OptionalItemsNotesWidget(showItems: false),
                          const SizedBox(height: 20),
                          if (_isEditMode) ...[
                            JemputAntarWidget(
                              initialData: trxProvider.jemputAntar,
                              lockDeliveryFee:
                                  !authProvider.canUpdateDeliveryFee,
                              onUnauthorizedFeeEdit: () {
                                CustomToast.show(
                                  context,
                                  message:
                                      'Anda tidak memiliki izin untuk mengubah biaya antar/jemput.',
                                  isError: true,
                                );
                              },
                              onChanged: (data) {
                                context
                                    .read<TransactionProvider>()
                                    .setJemputAntar(data);
                              },
                            ),
                            const SizedBox(height: 20),
                          ],
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ResponsiveCenter(child: _buildBottomAction(trxProvider)),
        ],
      ),
    );
  }

  AppBar _buildAppBar(TransactionProvider provider) {
    return AppBar(
      title: Text(
        _isEditMode ? 'Edit Pesanan' : 'Kembali',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: AppFont.w800,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
          size: 20,
        ),
        onPressed: () {
          provider.endOrder();
          Navigator.pop(context);
        },
      ),
      backgroundColor: Colors.white,
      elevation: 0,
    );
  }

  Widget _buildCustomerSection(Customer? customer) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer == null
                      ? 'Pilih Customer'
                      : '#${customer.kode} | ${customer.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: AppFont.w600,
                    fontSize: 14,
                    color: customer == null ? Colors.grey : Colors.black,
                  ),
                ),
                if (customer?.hasDeposit == true) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 14,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Deposit ${customer!.depositSummary}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFont.w700,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (customer?.isBirthdayToday == true) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Text('🎂', style: TextStyle(fontSize: 13)),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Hari ini ulang tahun pelanggan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: AppFont.w700,
                            color: Color(0xFFE87924),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!_isEditMode)
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerSelectionScreen(),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              child: Text(
                customer == null ? 'CARI' : 'GANTI',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: AppFont.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Tombol "Ulangi order terakhir": salin item order terakhir pelanggan ke
  /// keranjang dalam 1 tap.
  Widget _buildRepeatOrderButton(
    Customer customer,
    TransactionProvider trxProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _isRepeating
              ? null
              : () => _handleRepeatOrder(customer, trxProvider),
          icon: _isRepeating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppPalette.primary,
                    ),
                  ),
                )
              : const Icon(
                  Icons.replay_rounded,
                  size: 18,
                  color: AppPalette.primary,
                ),
          label: Text(
            _isRepeating ? 'Memuat order terakhir...' : 'Ulangi Order Terakhir',
            style: const TextStyle(
              color: AppPalette.primary,
              fontWeight: AppFont.w700,
              fontSize: 13,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppPalette.primary.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleRepeatOrder(
    Customer customer,
    TransactionProvider trxProvider,
  ) async {
    final trxId = customer.lastTransactionId;
    if (trxId == null || trxId.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _isRepeating = true);
    final ok = await trxProvider.repeatLastOrder(trxId);
    if (!mounted) return;
    setState(() => _isRepeating = false);
    CustomToast.show(
      context,
      message: ok
          ? 'Order terakhir dimuat. Silakan cek & lanjut bayar.'
          : 'Gagal memuat order terakhir',
      isError: !ok,
    );
  }

  /// Chip "Tambah Cepat": layanan tersering (ranking global se-outlet dari
  /// backend, fallback ke pemakaian lokal & prioritas) — tambah 1 tap tanpa
  /// masuk ke layar Pilih Layanan.
  Widget _buildQuickAddSection(TransactionProvider trxProvider) {
    final serviceProvider = context.watch<ServiceProvider>();

    final pairs = <MapEntry<ServiceCategory, ServiceProduct>>[];
    for (final cat in serviceProvider.categories) {
      for (final product in cat.products) {
        pairs.add(MapEntry(cat, product));
      }
    }
    if (pairs.isEmpty) return const SizedBox.shrink();

    final popularity = serviceProvider.popularity;
    pairs.sort((a, b) {
      // 1. Tersering se-outlet (data transaksi nyata dari backend).
      final pa = popularity[a.value.id] ?? 0;
      final pb = popularity[b.value.id] ?? 0;
      if (pa != pb) return pb.compareTo(pa);
      // 2. Fallback: frekuensi pemakaian lokal perangkat ini.
      final ua = _usageCounts[a.value.id] ?? 0;
      final ub = _usageCounts[b.value.id] ?? 0;
      if (ua != ub) return ub.compareTo(ua);
      // 3. Fallback terakhir: prioritas layanan.
      return b.value.priority.compareTo(a.value.priority);
    });

    final top = pairs.take(8).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Tambah Cepat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w700,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: top
                  .map((e) => _buildQuickAddChip(trxProvider, e.key, e.value))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddChip(
    TransactionProvider trxProvider,
    ServiceCategory category,
    ServiceProduct product,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleQuickAdd(trxProvider, category, product),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: AppPalette.primary,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: AppFont.w700,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currencyFormatter.format(product.price)} / ${TransactionProvider.displayUnit(product.unit)}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuickAdd(
    TransactionProvider trxProvider,
    ServiceCategory category,
    ServiceProduct product,
  ) async {
    HapticFeedback.selectionClick();
    final defaultQty =
        (product.minimalOrder != null && product.minimalOrder! > 0)
        ? product.minimalOrder!
        : 1.0;
    try {
      trxProvider.addServiceToCart(
        categoryName: category.name,
        serviceName: product.name,
        price: product.price,
        qty: defaultQty,
        duration: product.duration,
        durationUnit: product.durationUnit,
        unit: product.unit,
        iconPath: product.iconPath,
        minimalOrder: product.minimalOrder,
        productId: product.id,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      CustomToast.show(context, message: e.message.toString(), isError: true);
      return;
    }

    await ServiceUsageTracker.record(product.id);
    if (!mounted) return;
    setState(() {
      _usageCounts[product.id] = (_usageCounts[product.id] ?? 0) + 1;
    });
    CustomToast.show(context, message: '${product.name} ditambahkan');
  }

  Widget _buildDetailOrderCard(TransactionProvider trxProvider, customer) {
    return _buildSectionCard(
      title: 'Detail Order',
      action: _isPaidEditMode
          ? null
          : ElevatedButton(
              onPressed: customer == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ServiceSelectionScreen(),
                      ),
                    ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppPalette.primary,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                elevation: 0,
              ),
              child: const Text(
                'TAMBAH LAYANAN',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: AppFont.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
      child: trxProvider.cartItems.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Text(
                  'Silahkan Tambah Layanan Terlebih Dahulu',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          : Column(
              children: trxProvider.cartItems
                  .asMap()
                  .entries
                  .map(
                    (entry) =>
                        _buildCartItem(entry.value, entry.key, trxProvider),
                  )
                  .toList(),
            ),
    );
  }

  // ── FIX: handle asset lokal & URL network ──
  Widget _buildItemImage(String iconPath) {
    final isNetwork =
        iconPath.startsWith('http://') || iconPath.startsWith('https://');

    if (isNetwork) {
      return AppCachedNetworkImage(
        imageUrl: iconPath,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorWidget: const Icon(
          Icons.local_laundry_service,
          size: 28,
          color: AppPalette.primary,
        ),
      );
    }

    return Image.asset(
      iconPath,
      width: 28,
      height: 28,
      errorBuilder: (_, _, _) => const Icon(
        Icons.local_laundry_service,
        size: 28,
        color: AppPalette.primary,
      ),
    );
  }

  Widget _buildCartItem(
    CartItem item,
    int index,
    TransactionProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            // ── DIUBAH: pakai _buildItemImage ──
            child: _buildItemImage(item.iconPath),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.categoryName,
                  style: const TextStyle(
                    fontWeight: AppFont.w600,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.serviceName,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: AppFont.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${TransactionProvider.formatServiceQty(item.qty)} ${TransactionProvider.displayUnit(item.unit)} x ${_currencyFormatter.format(item.price)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  _currencyFormatter.format(item.subtotal),
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    fontSize: 13,
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
          ),
          if (!_isPaidEditMode) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: () => _showEditQtyBottomSheet(item, index, provider),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppPalette.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showEditQtyBottomSheet(
    CartItem item,
    int index,
    TransactionProvider provider,
  ) async {
    final isWholeNumberUnit = TransactionProvider.isWholeNumberUnit(item.unit);
    final controller = TextEditingController(
      text: _formatQtyValue(item.qty, isWholeNumberUnit),
    );
    var currentQty = item.qty;

    final result = await showGeneralDialog<double>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Qty',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, _) => MediaQuery.removeViewInsets(
        removeBottom: true,
        context: dialogContext,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            void syncQty(double value) {
              final steppedDelta = isWholeNumberUnit ? value.sign : value;
              final maxQty = isWholeNumberUnit
                  ? _maxQty.floorToDouble()
                  : _maxQty;
              final rawNewVal = (currentQty + steppedDelta)
                  .clamp(0, maxQty)
                  .toDouble();
              currentQty = isWholeNumberUnit
                  ? rawNewVal.roundToDouble()
                  : rawNewVal;
              controller.text = _formatQtyValue(currentQty, isWholeNumberUnit);
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
              setModalState(() {});
            }

            return Material(
              color: Colors.transparent,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.serviceName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: AppFont.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Atur qty layanan dalam satuan ${TransactionProvider.displayUnit(item.unit)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            InkWell(
                              onTap: () => Navigator.pop(dialogContext),
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 20,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildQtyActionButton(
                              icon: Icons.remove,
                              onTap: currentQty > 0 ? () => syncQty(-1) : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  TextInputFormatter.withFunction((
                                    oldValue,
                                    newValue,
                                  ) {
                                    final normalized = _normalizeDecimalInput(
                                      newValue.text,
                                    );
                                    if (!_isValidQtyText(
                                      normalized,
                                      isWholeNumberUnit,
                                    )) {
                                      return oldValue;
                                    }
                                    if (normalized == newValue.text) {
                                      return newValue;
                                    }
                                    return TextEditingValue(
                                      text: normalized,
                                      selection: TextSelection.collapsed(
                                        offset: normalized.length,
                                      ),
                                    );
                                  }),
                                ],
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  labelText: 'Qty',
                                  suffixText: TransactionProvider.displayUnit(
                                    item.unit,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onChanged: (value) {
                                  final normalized = _normalizeDecimalInput(
                                    value,
                                  );
                                  final parsed = double.tryParse(normalized);
                                  if (parsed != null && parsed > 0) {
                                    currentQty = isWholeNumberUnit
                                        ? parsed.roundToDouble()
                                        : parsed;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildQtyActionButton(
                              icon: Icons.add,
                              onTap: () => syncQty(1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  _showDeleteDialog(item, index, provider);
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                ),
                                child: const Text(
                                  'HAPUS',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 15,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  final normalized = _normalizeDecimalInput(
                                    controller.text.trim(),
                                  );
                                  final parsed = double.tryParse(normalized);
                                  Navigator.pop(dialogContext, parsed);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.primary,
                                  minimumSize: const Size.fromHeight(56),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'SIMPAN',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: AppFont.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (!mounted || result == null) return;
    _handleQtyAdjustment(
      item: item,
      index: index,
      provider: provider,
      nextQty: result,
      fromInput: true,
    );
  }

  String _normalizeDecimalInput(String text) {
    return text.replaceAll(',', '.');
  }

  String _formatQtyValue(double value, bool isWholeNumberUnit) {
    if (isWholeNumberUnit) return value.round().toString();
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(_maxDecimalDigits)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  bool _isValidQtyText(String text, bool isWholeNumberUnit) {
    if (text.isEmpty) return true;
    final normalized = _normalizeDecimalInput(text);
    if (isWholeNumberUnit) {
      return RegExp('^\\d{0,$_maxIntegerDigits}\$').hasMatch(normalized);
    }
    return RegExp(
      '^\\d{0,$_maxIntegerDigits}(\\.\\d{0,$_maxDecimalDigits})?\$',
    ).hasMatch(normalized);
  }

  Widget _buildQtyActionButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey.shade100 : AppPalette.primarySoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap == null
                ? Colors.grey.shade200
                : AppPalette.primaryBorder,
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: onTap == null ? Colors.grey.shade400 : AppPalette.primary,
        ),
      ),
    );
  }

  void _handleQtyAdjustment({
    required CartItem item,
    required int index,
    required TransactionProvider provider,
    required double nextQty,
    bool fromInput = false,
  }) {
    if (nextQty <= 0) {
      _showDeleteDialog(item, index, provider);
      return;
    }

    try {
      provider.updateCartItemQuantity(index, nextQty);
    } catch (e) {
      CustomToast.show(context, message: e.toString(), isError: true);
      return;
    }

    if (fromInput) {
      CustomToast.show(context, message: 'Qty layanan diperbarui');
    }
  }

  Widget _buildParfumSection(
    ParfumProvider parfumProvider,
    TransactionProvider trxProvider,
  ) {
    final selectedParfum = _resolveSelectedParfum(parfumProvider, trxProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: 'Pilih Parfum ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFont.w600,
                      color: Colors.black87,
                    ),
                  ),
                  TextSpan(
                    text: '(optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: AppFont.w400,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _showAddParfumModal,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppPalette.primaryBorder),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppPalette.primary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => _showParfumBottomSheet(parfumProvider, trxProvider),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedParfum?.nama ?? 'Pilih Parfum',
                    style: TextStyle(
                      color: selectedParfum == null
                          ? Colors.grey
                          : Colors.black87,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Parfum? _resolveSelectedParfum(
    ParfumProvider parfumProvider,
    TransactionProvider trxProvider,
  ) {
    final selectedId = trxProvider.selectedParfumId?.trim();
    final selectedName = trxProvider.selectedParfum?.nama.trim().toLowerCase();

    return parfumProvider.parfums.where((parfum) {
      final idMatches =
          selectedId != null &&
          selectedId.isNotEmpty &&
          parfum.id == selectedId;
      final nameMatches =
          selectedName != null &&
          selectedName.isNotEmpty &&
          parfum.nama.trim().toLowerCase() == selectedName;
      return idMatches || nameMatches;
    }).firstOrNull;
  }

  Widget _buildBottomAction(TransactionProvider provider) {
    final hasCustomer = provider.selectedCustomer != null;
    final hasItems = provider.cartItems.isNotEmpty;
    final estimasiTotal = _isEditMode
        ? provider.grandTotal
        : provider.subtotalRaw;
    final buttonLabel = _resolveBottomButtonLabel(
      hasCustomer: hasCustomer,
      hasItems: hasItems,
    );
    final totalLabel = hasItems ? 'Estimasi Total' : 'Total Pesanan';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totalLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: AppFont.w500,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  _currencyFormatter.format(estimasiTotal),
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    fontSize: 18,
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _handleBottomAction(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: AppFont.w700,
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveBottomButtonLabel({
    required bool hasCustomer,
    required bool hasItems,
  }) {
    if (_isEditMode) return 'SIMPAN PERUBAHAN';
    if (!hasCustomer) return 'PILIH PELANGGAN';
    if (!hasItems) return 'TAMBAH LAYANAN';
    return 'LANJUTKAN PEMBAYARAN';
  }

  void _handleBottomAction(TransactionProvider provider) {
    if (_isEditMode) {
      _onSimpanPerubahan(provider);
      return;
    }

    if (provider.selectedCustomer == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomerSelectionScreen()),
      );
      return;
    }

    if (provider.cartItems.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
      );
      return;
    }

    _onLanjutkanPembayaran(provider);
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: AppFont.w700, fontSize: 14),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }

  void _onLanjutkanPembayaran(TransactionProvider provider) {
    final validationError = provider.validateOrderData();
    if (validationError != null) {
      CustomToast.show(context, message: validationError, isError: true);
      return;
    }

    provider.resetPaymentDraft();
    provider.setPendingOrder(dpAmount: 0.0, isPaid: false);
    Navigator.pushNamed(context, '/payment');
  }

  Future<void> _onSimpanPerubahan(TransactionProvider provider) async {
    final validationError = provider.validateOrderData();
    if (validationError != null) {
      CustomToast.show(context, message: validationError, isError: true);
      return;
    }

    final isLunas = provider.currentDetail?.paymentStatus == 'Lunas';
    final result = await provider.updateTransaction(
      widget.editTransactionId!,
      isLunas: isLunas,
    );
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message'] ?? '',
      isError: result['success'] != true,
    );
    if (result['success'] == true) {
      provider.endOrder();
      Navigator.pop(context);
    }
  }

  void _showDeleteDialog(
    CartItem item,
    int index,
    TransactionProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Item'),
        content: Text(
          'Hapus ${item.categoryName} - ${item.serviceName} dari pesanan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () {
              provider.removeCartItem(index);
              Navigator.pop(context);
            },
            child: const Text('HAPUS', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showParfumBottomSheet(
    ParfumProvider parfumProvider,
    TransactionProvider trxProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ParfumSelectionBottomSheet(
        parfumProvider: parfumProvider,
        trxProvider: trxProvider,
      ),
    );
  }

  void _showAddParfumModal() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: Colors.transparent,
        child: const ModalAddParfum(),
      ),
    );
  }
}
