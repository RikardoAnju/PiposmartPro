import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/models/addon_model.dart';
import '../../../../core/utils/api_client.dart';
import '../../../../shared/widgets/app_cached_network_image.dart';
import '../../../../shared/widgets/custom_toast.dart';
import 'addon_success_screen.dart';
import 'outlet_pro_success_screen.dart';
import 'transfer_upload_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class DetailAddonTrxScreen extends StatefulWidget {
  final TransaksiAddon transaction;
  final bool autoLaunchSnapUrl;

  const DetailAddonTrxScreen({
    super.key,
    required this.transaction,
    this.autoLaunchSnapUrl = false,
  });

  @override
  State<DetailAddonTrxScreen> createState() => _DetailAddonTrxScreenState();
}

class _DetailAddonTrxScreenState extends State<DetailAddonTrxScreen>
    with WidgetsBindingObserver {
  late String _trxId;
  bool _isManualSyncing = false;
  bool _isCanceling = false;
  String? _lastKnownStatus;
  bool _hasShownSuccessCeremony = false;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _trxId = widget.transaction.id;
    _lastKnownStatus = widget.transaction.status.toLowerCase();
    WidgetsBinding.instance.addObserver(this);
    _startStatusPolling();
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _manualSync();
    }
  }

  Future<void> _manualSync() async {
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    await context.read<AddonProvider>().fetchPendingOrders();
    await context.read<AddonProvider>().fetchFullHistory();
    if (!mounted) return;
    setState(() => _isManualSyncing = false);
    _checkSuccessTransition();
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;

      final addonProv = context.read<AddonProvider>();
      TransaksiAddon currentTrx = widget.transaction;
      try {
        currentTrx = addonProv.pendingOrders.firstWhere((t) => t.id == _trxId);
      } catch (_) {
        try {
          currentTrx = addonProv.fullHistory.firstWhere((t) => t.id == _trxId);
        } catch (_) {}
      }

      final status = currentTrx.status.toLowerCase();
      final isFinal =
          status == 'success' || status == 'failed' || status == 'canceled';

      if (isFinal) {
        _statusPollTimer?.cancel();
        _checkSuccessTransition();
        return;
      }

      _manualSync();
    });
  }

  AddonSuccessKind _resolveAddonSuccessKindFromName(String itemNames) {
    final lower = itemNames.toLowerCase();
    if (lower.contains('perpanjang') ||
        lower.contains('renew') ||
        lower.contains('lanjutan')) {
      return AddonSuccessKind.renewed;
    }
    if (lower.contains('upgrade') || lower.contains('update')) {
      return AddonSuccessKind.updated;
    }
    return AddonSuccessKind.firstActivation;
  }

  bool _isProActivationTransaction(TransaksiAddon trx) {
    final id = trx.id.toUpperCase();
    final itemNames = trx.itemNames?.toLowerCase() ?? '';
    return id.startsWith('PRO-') ||
        itemNames.contains('aktivasi lisensi outlet pro') ||
        itemNames.contains('outlet pro');
  }

  void _checkSuccessTransition() {
    final addonProv = context.read<AddonProvider>();
    TransaksiAddon currentTrx = widget.transaction;
    try {
      currentTrx = addonProv.pendingOrders.firstWhere((t) => t.id == _trxId);
    } catch (_) {
      try {
        currentTrx = addonProv.fullHistory.firstWhere((t) => t.id == _trxId);
      } catch (_) {}
    }

    final currentStatus = currentTrx.status.toLowerCase();
    final didJustActivate =
        _lastKnownStatus != 'success' &&
        currentStatus == 'success' &&
        !_hasShownSuccessCeremony;

    _lastKnownStatus = currentStatus;
    if (!didJustActivate || !mounted) return;

    _hasShownSuccessCeremony = true;
    context.read<AppProvider>().fetchAppData(force: true);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _isProActivationTransaction(currentTrx)
            ? const OutletProSuccessScreen()
            : AddonSuccessScreen(
                kind: _resolveAddonSuccessKindFromName(
                  currentTrx.itemNames ?? 'Fitur Aktif',
                ),
                featureName: currentTrx.itemNames,
                featureNames: currentTrx.itemNames == null
                    ? const []
                    : currentTrx.itemNames!
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                onPrimary: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  '/aktivasi-akun',
                  (route) => route.isFirst,
                ),
              ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Batalkan Pesanan",
          style: TextStyle( fontSize: 16),
        ),
        content: const Text(
          "Apakah Anda yakin ingin membatalkan tagihan ini?",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("TIDAK", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "YA, BATALKAN",
              style: TextStyle(color: Colors.red,),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isCanceling = true);
      final res = await context.read<AddonProvider>().cancelOrder(_trxId);
      setState(() => _isCanceling = false);

      if (res['success']) {
        CustomToast.show(context, message: "Pesanan berhasil dibatalkan");
        // Navigator.pop(context); // Opsional: Tutup detail setelah batal
      } else {
        CustomToast.show(
          context,
          message: res['message'] ?? "Gagal membatalkan pesanan",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final addonProv = context.watch<AddonProvider>();

    TransaksiAddon? currentTrx;
    try {
      currentTrx = addonProv.pendingOrders.firstWhere((t) => t.id == _trxId);
    } catch (_) {
      try {
        currentTrx = addonProv.fullHistory.firstWhere((t) => t.id == _trxId);
      } catch (_) {
        currentTrx = widget.transaction;
      }
    }

    final String status = currentTrx.status.toLowerCase();
    final String metode = currentTrx.metodeBayar.toUpperCase();
    final String? buktiTf = currentTrx.bukti;
    final bool isSuccess = status == 'success';
    final DateTime displayTimestamp =
        isSuccess && currentTrx.tanggalValidasi != null
        ? currentTrx.tanggalValidasi!
        : currentTrx.createdAt;
    final String timestampLabel = isSuccess
        ? 'Tanggal Aktivasi'
        : 'Tanggal Pesan';

    if (status == 'success' &&
        _lastKnownStatus != 'success' &&
        !_hasShownSuccessCeremony) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkSuccessTransition();
      });
    } else {
      _lastKnownStatus = status;
    }

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF2C3E50),
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "DETAIL PEMBELIAN FITUR",
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
        actions: [
          if (_isManualSyncing || _isCanceling)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: AppCircularLoader(
                    strokeWidth: 2,
                    color: AppPalette.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(currentTrx.total, metode),
            const SizedBox(height: 32),
            _buildSectionTitle("INFO TRANSAKSI"),
            _buildInfoTile("Nomor Referensi", currentTrx.id, canCopy: true),
            _buildInfoTile(
              "Nama Layanan",
              currentTrx.itemNames ?? "Aktivasi Fitur",
            ),
            _buildInfoTile("Metode Pembayaran", metode),
            _buildInfoTile(
              timestampLabel,
              DateFormat(
                'dd MMM yyyy, HH:mm',
                'id_ID',
              ).format(displayTimestamp),
            ),
            _buildInfoTile(
              "Status",
              status.toUpperCase().replaceAll('_', ' '),
              isStatus: true,
            ),
            if (metode == 'TRANSFER' &&
                buktiTf != null &&
                buktiTf.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildCompactBukti(buktiTf),
            ],
            const SizedBox(height: 32),
            _buildDynamicAction(
              context,
              currentTrx,
              status,
              metode,
              buktiTf,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(double total, String metode) {
    // Addon dibeli dengan koin, jadi nilainya adalah jumlah koin — bukan Rupiah.
    // Metode transfer (legacy) tetap ditampilkan dalam Rupiah.
    final bool isKoin = metode.toUpperCase() == 'KOIN';
    final String totalLabel = isKoin ? "TOTAL KOIN" : "TOTAL TAGIHAN";
    final String totalValue = isKoin
        ? "${NumberFormat.decimalPattern('id_ID').format(total)} Koin"
        : NumberFormat.currency(
            locale: 'id_ID',
            symbol: 'Rp ',
            decimalDigits: 0,
          ).format(total);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            totalLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            totalValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicAction(
    BuildContext context,
    TransaksiAddon trx,
    String status,
    String metode,
    String? bukti,
  ) {
    // 1. STATUS SUCCESS
    if (status == 'success') {
      return _buildStatusBox(
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        title: "TRANSAKSI BERHASIL",
        message:
            "Fitur telah diaktifkan ke outlet kamu. Silakan restart aplikasi jika fitur belum muncul.",
      );
    }

    // 2. STATUS CANCELED (Keputusan Final User)
    if (status == 'canceled') {
      return _buildStatusBox(
        icon: Icons.cancel_rounded,
        color: Colors.red,
        title: "PESANAN DIBATALKAN",
        message:
            "Tagihan ini telah dibatalkan. Silakan lakukan pemesanan ulang di katalog fitur.",
      );
    }

    // 3. LOGIC UNTUK METODE TRANSFER
    if (metode == 'TRANSFER') {
      // ✅ JIKA FAILED (REJECTED BY ADMIN): Kasih Opsi Retry ATAU Cancel
      if (status == 'failed') {
        return Column(
          children: [
            _buildActionButton(
              label: "UPLOAD ULANG BUKTI",
              icon: Icons.cloud_upload_outlined,
              color: AppPalette.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TransferUploadScreen(trxId: trx.id),
                ),
              ),
              subText:
                  "Bukti ditolak admin. Harap perbaiki dan kirim ulang struk asli.",
            ),
            const SizedBox(height: 12),
            _buildCancelButton(),
          ],
        );
      }

      // Menunggu Validasi (Bukti sudah ada)
      if (bukti != null && bukti.isNotEmpty) {
        return _buildStatusBox(
          icon: Icons.hourglass_top_rounded,
          color: Colors.blue,
          title: "MENUNGGU VALIDASI",
          message:
              "Bukti transfer sudah kami terima. Admin sedang melakukan verifikasi manual. Mohon tunggu sejenak.",
        );
      }

      // Belum Upload (Status Pending)
      return Column(
        children: [
          _buildActionButton(
            label: "UPLOAD BUKTI TRANSFER",
            icon: Icons.upload_file_rounded,
            color: const Color(0xFF2C3E50),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TransferUploadScreen(trxId: trx.id),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildCancelButton(),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isCanceling ? null : _handleCancel,
        icon: const Icon(Icons.close_rounded, size: 18),
        label: const Text(
          "BATALKAN PESANAN",
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBox({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 15,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blueGrey[700],
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? subText,
  }) {
    return Column(
      children: [
        if (subText != null) ...[
          Text(
            subText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: 20),
            label: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactBukti(String path) {
    final String imageUrl = ApiClient.resolveImageVariantUrl(
      path,
      width: 1600,
      quality: 85,
    );
    final String thumbnailUrl = ApiClient.resolveImageVariantUrl(
      path,
      width: 180,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("BUKTI TRANSFER SAYA"),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _showFullImage(imageUrl),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F3F5)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppCachedNetworkImage(
                    imageUrl: thumbnailUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(
                      Icons.image_not_supported_rounded,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bukti_Pembayaran.jpg",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      Text(
                        "Klik untuk memperbesar struk",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.zoom_in_rounded, color: AppPalette.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFullImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: AppCachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                memCacheWidth: 1600,
                maxWidthDiskCache: 1600,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.blueGrey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildInfoTile(
    String label,
    String value, {
    bool isStatus = false,
    bool canCopy = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFF8F9FA), width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: InkWell(
              onTap: canCopy
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      CustomToast.show(context, message: "$label disalin!");
                    }
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        color: isStatus
                            ? AppPalette.primary
                            : const Color(0xFF2C3E50),
                      ),
                    ),
                  ),
                  if (canCopy) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: Colors.blue,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
