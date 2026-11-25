import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/unit_label.dart';
import 'package:ayocucinew/data/models/transaction_model.dart';
import 'package:ayocucinew/providers/item_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/setting_nota_provider.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/providers/nobu_payment_provider.dart';
import 'package:ayocucinew/screens/operational/transaction/order/order_screen.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/payment_page.dart';
import 'package:ayocucinew/screens/operational/transaction/payment/nobu_qris_payment_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ayocucinew/screens/status/detail/constants/app_colors.dart';
import 'package:ayocucinew/screens/status/detail/widgets/detail_bottom_nav_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/detail_layanan_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/history_pesanan_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/item_cuci_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/metode_pembayaran_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/rincian_order_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/section_card_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/status_pembayaran_widget.dart';
import 'package:ayocucinew/screens/status/detail/widgets/status_stepper_widget.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/screens/operational/transaction/widgets/modal_succes_order.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DetailPesananScreen extends StatefulWidget {
  final String transactionId;
  final bool readOnly;

  const DetailPesananScreen({
    super.key,
    required this.transactionId,
    this.readOnly = false,
  });

  @override
  State<DetailPesananScreen> createState() => _DetailPesananScreenState();
}

class _DetailPesananScreenState extends State<DetailPesananScreen> {
  bool _readyPickupPromptShown = false;
  // True bila masih ada QR Nobu aktif (menunggu pembayaran) untuk order ini,
  // sehingga tombol yang ditampilkan adalah "Lanjutkan Pembayaran QRIS"
  // (memakai ulang QR yang sama) alih-alih "Bayar Sekarang" generik.
  bool _hasActiveNobuQr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _onKirimNotif(TransactionModel trx, {String? statusLabel}) async {
    final phone = trx.customer?.phone;
    if (phone == null || phone.trim().isEmpty) return;

    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (!p.startsWith('62')) p = '62$p';

    final notifiedStatus = statusLabel ?? _getNextStatus(trx.orderStatus);
    if (notifiedStatus == null) return;

    final nota = context.read<NotaSettingsProvider>().notaSettings;
    final namaLaundry = nota?.cnNamaOutlet ?? 'Laundry';
    final alamat = nota?.cnAlamat ?? '';
    final totalFormatted = CurrencyFormatter.formatToRupiah(trx.totalPrice);

    final pesan = Uri.encodeComponent(
      'Hai ${trx.customer?.name ?? 'Kak'}, Pesananmu\n'
      'telah $notifiedStatus\n\n'
      '============================\n\n'
      'Laundry : $namaLaundry\n'
      'Alamat  : $alamat\n'
      'Kasir   : ${trx.kasirName ?? '-'}\n\n'
      '============================\n\n'
      'Kode Struk : ${trx.invoiceNumber ?? trx.id ?? '-'}\n'
      'Total Pembayaran : $totalFormatted\n'
      'Status Pembayaran : ${trx.paymentStatus}',
    );

    final url = 'https://wa.me/$p?text=$pesan';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final itemProvider = context.read<ItemProvider>();
    if (itemProvider.items.isEmpty) await itemProvider.fetchItems();
    if (!mounted) return;

    final notaProvider = context.read<NotaSettingsProvider>();
    if (notaProvider.notaSettings == null) {
      await notaProvider.fetchNotaSettings();
    }
    if (!mounted) return;

    final transactionProvider = context.read<TransactionProvider>();
    await transactionProvider.fetchTransactionById(widget.transactionId);
    if (!mounted) return;

    final trx = transactionProvider.currentDetail;
    if (trx != null) {
      _maybeShowReadyPickupNotificationPrompt(trx);
      await _refreshNobuQrState(trx);
    }
  }

  // Cek apakah ada QR Nobu yang masih menunggu pembayaran untuk order ini.
  // Hanya relevan bila nota belum lunas; QR yang sudah kedaluwarsa/gagal/
  // dibatalkan tidak dianggap aktif.
  Future<void> _refreshNobuQrState(TransactionModel trx) async {
    final belumLunas =
        trx.paymentStatus != 'Lunas' && trx.orderStatus != 'Batal';
    if (!belumLunas) {
      if (_hasActiveNobuQr && mounted) setState(() => _hasActiveNobuQr = false);
      return;
    }
    final orderId = trx.id?.toString() ?? widget.transactionId;
    final result = await context.read<NobuPaymentProvider>().refreshStatus(
      orderId,
    );
    if (!mounted) return;
    final active = result?.isWaiting == true;
    if (active != _hasActiveNobuQr) setState(() => _hasActiveNobuQr = active);
  }

  Future<void> _onLanjutkanQris(TransactionModel trx) async {
    final orderId = trx.id?.toString() ?? widget.transactionId;
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NobuQrisPaymentScreen(orderId: orderId),
      ),
    );
    if (!mounted) return;
    await context.read<TransactionProvider>().fetchTransactionById(
      widget.transactionId,
    );
    if (!mounted) return;
    final updated = context.read<TransactionProvider>().currentDetail;
    if (updated != null) await _refreshNobuQrState(updated);
    if (paid == true && mounted) {
      CustomToast.show(context, message: 'Pembayaran QRIS berhasil!');
    }
  }

  void _maybeShowReadyPickupNotificationPrompt(TransactionModel trx) {
    final skipProses = context.read<AppProvider>().outlet?.skipProses == 1;
    if (_readyPickupPromptShown ||
        skipProses ||
        trx.orderStatus != 'Siap Ambil') {
      return;
    }

    _readyPickupPromptShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final latestTrx = context.read<TransactionProvider>().currentDetail;
      final latestSkipProses =
          context.read<AppProvider>().outlet?.skipProses == 1;

      if (latestSkipProses ||
          latestTrx == null ||
          latestTrx.id.toString() != trx.id.toString() ||
          latestTrx.orderStatus != 'Siap Ambil') {
        return;
      }

      await _showKirimNotifDialog(latestTrx, statusLabel: 'Siap Ambil');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final trx = provider.currentDetail;

        if (provider.isLoading ||
            (trx == null && provider.errorMessage == null)) {
          return _buildSkeletonDetail();
        }

        if (trx == null) {
          return AppScaffold(
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.errorMessage ?? 'Pesanan tidak ditemukan',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return AppScaffold(
          backgroundColor: AppColors.background,
          appBar: _DetailAppBar(trx: trx),
          body: _buildBody(provider, trx),
          bottomNavigationBar: _buildBottomNav(trx),
        );
      },
    );
  }

  Widget _buildBody(TransactionProvider provider, TransactionModel trx) {
    final isBatal = trx.orderStatus == 'Batal';
    final canCancel = trx.orderStatus == 'Antrian';
    final belumLunas = trx.paymentStatus != 'Lunas' && !isBatal;
    final skipProses = context.watch<AppProvider>().outlet?.skipProses == 1;

    return ListView(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      children: [
        StatusStepperWidget(
          currentStatus: trx.orderStatus,
          createdBy: trx.kasirName,
          skipProses: skipProses,
          onLanjutkan: widget.readOnly
              ? null
              : () => _onLanjutkan(provider, trx),
        ),
        const SizedBox(height: 12),
        _CustomerSection(trx: trx),
        const SizedBox(height: 12),
        if (trx.items.isNotEmpty) _DetailLayananCard(trx: trx),
        if (trx.optionalItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          const ItemCuciWidget(),
        ],
        const SizedBox(height: 12),
        const RincianOrderWidget(),
        const SizedBox(height: 12),
        const StatusPembayaranWidget(),
        const SizedBox(height: 12),
        const MetodePembayaranWidget(),
        const SizedBox(height: 12),
        if (belumLunas)
          _hasActiveNobuQr
              ? _BayarButton(
                  label: 'Lanjutkan Pembayaran QRIS',
                  onBayar: () => _onLanjutkanQris(trx),
                )
              : _BayarButton(onBayar: () => _onBayar(provider, trx)),
        const SizedBox(height: 12),
        const HistoryPesananWidget(),
        const SizedBox(height: 10),
        if (canCancel && !widget.readOnly)
          _BatalButton(onBatal: () => _showBatalDialog(provider, trx)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildBottomNav(TransactionModel trx) {
    return DetailBottomNavWidget(
      orderStatus: trx.orderStatus,
      onEdit: widget.readOnly ? null : () => _onEdit(trx),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _onEdit(TransactionModel trx) {
    final provider = context.read<TransactionProvider>();
    provider.startNewOrder();
    if (trx.customer != null) provider.setCustomer(trx.customer!);
    provider.loadCartFromEdit(trx);
    provider.setNotes(trx.notes);

    // 4. Navigasi ke OrderScreen dengan mode Edit
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderScreen(editTransactionId: trx.id.toString()),
      ),
    );
  }

  Future<void> _onBayar(
    TransactionProvider provider,
    TransactionModel trx,
  ) async {
    provider.setPendingOrderFromDetail(trx);
    final paid = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const PaymentPage()),
    );

    if (!mounted || paid != true) return;

    await context.read<TransactionProvider>().fetchTransactionById(
      widget.transactionId,
    );
  }

  Future<void> _showKirimNotifDialog(
    TransactionModel trx, {
    String? statusLabel,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Kirim Notifikasi?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 17, fontWeight: AppFont.w800),
          ),
          content: const Text(
            '\nApakah Anda ingin mengirim notifikasi ke pelanggan?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Tidak',
                      style: TextStyle(fontWeight: AppFont.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ya, Kirim',
                      style: TextStyle(fontWeight: AppFont.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _onKirimNotif(trx, statusLabel: statusLabel);
    }
  }

  Future<void> _onLanjutkan(
    TransactionProvider provider,
    TransactionModel trx,
  ) async {
    final nextStatus = _getNextStatus(trx.orderStatus);
    if (nextStatus == null) return;

    if (nextStatus == 'Selesai' && trx.paymentStatus != 'Lunas') {
      CustomToast.show(
        context,
        message:
            'Selesaikan pembayaran terlebih dahulu sebelum mengubah status ke Selesai.',
        isError: true,
      );
      return;
    }

    final result = await provider.updateTransactionStatus(
      trx.id.toString(),
      nextStatus,
    );

    if (!mounted) return;

    final success = result['success'] == true;

    CustomToast.show(
      context,
      message: result['message'] ?? '',
      isError: !success,
    );

    if (success && nextStatus == 'Siap Ambil') {
      _readyPickupPromptShown = true;
      await _showKirimNotifDialog(trx, statusLabel: nextStatus);
    }
  }

  // ─── Dialogs ────────────────────────────────────────────────────────────────

  void _showBatalDialog(TransactionProvider provider, TransactionModel trx) {
    final alasanController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
        title: const Text(
          'Apakah Anda Yakin Membatalkan Transaksi?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: AppFont.w700,
            fontSize: 15,
            height: 1.25,
          ),
        ),
        content: TextField(
          controller: alasanController,
          decoration: InputDecoration(
            hintText: 'Tulis alasan membatalkan pesanan',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          maxLines: 2,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('TUTUP'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _konfirmasiBatal(
                      provider,
                      trx,
                      alasan: alasanController.text.trim(),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text(
                    'YA',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _konfirmasiBatal(
    TransactionProvider provider,
    TransactionModel trx, {
    String alasan = '',
  }) async {
    final result = await provider.updateTransactionStatus(
      trx.id.toString(),
      'Batal',
      alasan: alasan,
    );
    if (!mounted) return;
    CustomToast.show(
      context,
      message: result['message'] ?? '',
      isError: result['success'] != true,
    );
  }

  String? _getNextStatus(String current) {
    final skipProses = context.read<AppProvider>().outlet?.skipProses == 1;
    final flow = skipProses
        ? const ['Antrian', 'Selesai']
        : const ['Antrian', 'Proses', 'Siap Ambil', 'Selesai'];
    final index = flow.indexOf(current);
    if (index == -1 || index == flow.length - 1) return null;
    return flow[index + 1];
  }

  Widget _buildSkeletonDetail() {
    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
      ),
      body: const StatusDetailSkeleton(),
    );
  }
}

// ─── Helper Classes ──────────────────────────────────────────────────────────

enum _DetailMenuAction { summary, copy }

class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TransactionModel trx;
  const _DetailAppBar({required this.trx});

  @override
  Size get preferredSize => const Size.fromHeight(80);

  PopupMenuItem<_DetailMenuAction> _menuItem(
    _DetailMenuAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem<_DetailMenuAction>(
      value: value,
      height: 46,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w600,
              color: Color(0xFF243041),
            ),
          ),
        ],
      ),
    );
  }

  void _copyInvoice(BuildContext context) {
    Clipboard.setData(ClipboardData(text: trx.invoiceNumber ?? trx.id ?? ""));
    CustomToast.show(context, message: "Nomor Invoice disalin ke clipboard");
  }

  void _openOrderSuccessModal(BuildContext context) {
    final entryDate = trx.createdAt != null
        ? DateFormat('dd/MM/yyyy | HH:mm').format(trx.createdAt!)
        : '-';

    final readyAt = trx.items
        .map((item) => item.readyAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, dt) => latest == null || dt.isAfter(latest) ? dt : latest,
        );
    final estimatedDate = readyAt != null
        ? DateFormat('dd/MM/yyyy | HH:mm').format(readyAt)
        : '-';

    final orderDetail = trx.items
        .map((e) {
          final qty = e.qty % 1 == 0
              ? e.qty.toInt().toString()
              : e.qty
                    .toStringAsFixed(2)
                    .replaceAll(RegExp(r'0+$'), '')
                    .replaceAll(RegExp(r'\.$'), '');
          String name = e.categoryName;
          if (e.duration > 0) {
            name += ' (${e.duration} ${e.durationUnit})';
          } else if (e.serviceName.isNotEmpty) {
            name += ' (${e.serviceName})';
          }
          return '$qty ${displayUnitLabel(e.unit)} x ${CurrencyFormatter.formatToRupiah(e.price)} | $name';
        })
        .join('\n');

    final double jemputBiaya = trx.jemputBiaya;
    final double antarBiaya = trx.antarBiaya;
    final double subtotalItems = trx.totalKotor - jemputBiaya - antarBiaya;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderSuccessModal(
          parentContext: context,
          snapshot: trx.toJson(),
          customer: trx.customer,
          notaText: '',
          customerId: trx.customer?.kode ?? '-',
          customerName: trx.customer?.name ?? '-',
          orderDetail: orderDetail,
          perfume: trx.parfum?.nama ?? '-',
          entryDate: entryDate,
          estimatedDate: estimatedDate,
          paymentStatus: trx.paymentStatus,
          paymentMethod: trx.paymentMethod?.name ?? '-',
          totalOrder: subtotalItems,
          nominalDP: trx.dpAmount,
          discount: trx.potonganDiskon,
          roundingAmount: trx.roundingAmount,
          total: trx.totalPrice,
          sisaBayar: trx.sisaBayar ?? (trx.totalPrice - trx.dpAmount),
          fromDetail: true,
          jemputBiaya: jemputBiaya,
          antarBiaya: antarBiaya,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 80,
      leading: const SizedBox.shrink(),
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              const SizedBox(width: 12),
              _BackButton(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Invoice:',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: AppFont.w600,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        trx.invoiceNumber ?? trx.id ?? '-',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: AppFont.w800,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<_DetailMenuAction>(
                tooltip: 'Menu',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                color: Colors.white,
                elevation: 4,
                shadowColor: Colors.black.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _DetailMenuAction.summary:
                      _openOrderSuccessModal(context);
                      break;
                    case _DetailMenuAction.copy:
                      _copyInvoice(context);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  _menuItem(
                    _DetailMenuAction.summary,
                    Icons.check_circle_outline_rounded,
                    'Ringkasan Pesanan',
                  ),
                  _menuItem(
                    _DetailMenuAction.copy,
                    Icons.content_copy_rounded,
                    'Salin No. Invoice',
                  ),
                ],
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.more_vert_rounded, size: 20),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
    );
  }
}

class _DetailLayananCard extends StatefulWidget {
  final TransactionModel trx;
  const _DetailLayananCard({required this.trx});

  @override
  State<_DetailLayananCard> createState() => _DetailLayananCardState();
}

class _DetailLayananCardState extends State<_DetailLayananCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return SectionCardWidget(
      title: 'Detail Layanan',
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: widget.trx.items
              .map((item) => DetailLayananTile(item: item))
              .toList(),
        ),
      ),
    );
  }
}

class _BayarButton extends StatelessWidget {
  final VoidCallback onBayar;
  final String label;
  const _BayarButton({required this.onBayar, this.label = 'Bayar Sekarang'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: onBayar,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: AppFont.w700),
        ),
      ),
    );
  }
}

class _BatalButton extends StatelessWidget {
  final VoidCallback onBatal;
  const _BatalButton({required this.onBatal});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton(
        onPressed: onBatal,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 2),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'BATALKAN PESANAN',
          style: TextStyle(fontWeight: AppFont.w700),
        ),
      ),
    );
  }
}

class _CustomerSection extends StatefulWidget {
  final TransactionModel trx;
  const _CustomerSection({required this.trx});

  @override
  State<_CustomerSection> createState() => _CustomerSectionState();
}

class _CustomerSectionState extends State<_CustomerSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final customer = widget.trx.customer;
    if (customer == null) return const SizedBox.shrink();

    return SectionCardWidget(
      title: 'Pelanggan',
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w700,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    customer.phone.trim().isEmpty
                        ? 'No. WA belum diisi'
                        : customer.formattedPhone,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _launchWhatsApp(customer.phone),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  color: Color(0xFF25D366),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchWhatsApp(String phone) async {
    String p = phone.replaceAll(RegExp(r'\D'), '');
    if (p.startsWith('0')) p = '62${p.substring(1)}';
    if (!p.startsWith('62')) p = '62$p';

    // Tanpa nomor, biarkan WhatsApp meminta pengguna memilih kontak tujuan.
    final url = p.isEmpty ? 'https://wa.me/?text=' : 'https://wa.me/$p';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
