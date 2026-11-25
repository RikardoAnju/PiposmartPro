import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../providers/koin_provider.dart';
import '../../../core/utils/api_client.dart';
import '../../../shared/widgets/app_cached_network_image.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../shared/widgets/midtrans_snap_webview_screen.dart';
import 'transfer_upload_screen.dart';
import 'koin_topup_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class DetailTopupScreen extends StatefulWidget {
  final Map<String, dynamic> topup;
  final bool autoLaunchSnapUrl;

  const DetailTopupScreen({
    super.key,
    required this.topup,
    this.autoLaunchSnapUrl = false,
  });

  @override
  State<DetailTopupScreen> createState() => _DetailTopupScreenState();
}

class _DetailTopupScreenState extends State<DetailTopupScreen>
    with WidgetsBindingObserver {
  late String _topupId;
  bool _isManualSyncing = false;
  String? _lastKnownStatus;
  bool _hasShownSuccessCeremony = false;
  bool _hasAttemptedAutoLaunchSnap = false;
  bool _isCanceling = false;

  @override
  void initState() {
    super.initState();
    _topupId = widget.topup['tk_id'];
    _lastKnownStatus = widget.topup['tk_status']?.toString().toLowerCase();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoLaunchSnapUrl) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoLaunchMidtransIfNeeded();
      });
    }
  }

  @override
  void dispose() {
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
    await context.read<KoinProvider>().fetchAllTopupRequests();
    if (!mounted) return;
    setState(() => _isManualSyncing = false);
    _checkSuccessTransition();
  }

  Future<void> _handleCancelTopup() async {
    final koinProv = context.read<KoinProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Batalkan Tagihan", style: TextStyle(fontSize: 16)),
        content: const Text(
          "Apakah Anda yakin ingin membatalkan tagihan top up ini?",
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
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _isCanceling = true);
    final res = await koinProv.cancelTopup(_topupId);
    if (!mounted) return;
    setState(() => _isCanceling = false);

    if (res['success'] == true) {
      CustomToast.show(context, message: "Tagihan berhasil dibatalkan");
      await koinProv.fetchAllTopupRequests();
      await koinProv.fetchActiveTopups();
    } else {
      CustomToast.show(
        context,
        message: res['message'] ?? "Gagal membatalkan tagihan",
        isError: true,
      );
    }
  }

  Map<String, dynamic> _resolveCurrentTopupData(KoinProvider koinProv) {
    return koinProv.allTopups.firstWhere(
      (t) => t['tk_id'] == _topupId,
      orElse: () => widget.topup,
    );
  }

  void _checkSuccessTransition() {
    final koinProv = context.read<KoinProvider>();
    final currentData = _resolveCurrentTopupData(koinProv);
    final currentStatus = currentData['tk_status'].toString().toLowerCase();
    final didJustSucceed =
        _lastKnownStatus != 'success' &&
        currentStatus == 'success' &&
        !_hasShownSuccessCeremony;

    _lastKnownStatus = currentStatus;
    if (!didJustSucceed || !mounted) return;

    _hasShownSuccessCeremony = true;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoinTopupSuccessScreen(
          kind: KoinTopupSuccessKind.completed,
          onPrimary: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _autoLaunchMidtransIfNeeded() async {
    if (_hasAttemptedAutoLaunchSnap || !mounted) return;

    final koinProv = context.read<KoinProvider>();
    final currentData = _resolveCurrentTopupData(koinProv);
    final metode = currentData['tk_metode_bayar'].toString().toLowerCase();
    final status = currentData['tk_status'].toString().toLowerCase();
    final snapUrl = currentData['tk_snap_url']?.toString();

    if (metode != 'midtrans' ||
        status == 'success' ||
        status == 'failed' ||
        status == 'cancel' ||
        status == 'deny' ||
        status == 'expire' ||
        snapUrl == null ||
        snapUrl.isEmpty) {
      return;
    }

    _hasAttemptedAutoLaunchSnap = true;
    await _launchURL(context, snapUrl);
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 REAKTIF: Listen perubahan status via Socket/Provider
    final koinProv = context.watch<KoinProvider>();
    final Map<String, dynamic> currentData = _resolveCurrentTopupData(koinProv);

    final String metode = currentData['tk_metode_bayar']
        .toString()
        .toLowerCase();
    final String status = currentData['tk_status'].toString().toLowerCase();
    final String? buktiTf = currentData['tk_bukti'];
    final String? snapUrl = currentData['tk_snap_url'];
    final DateTime? expiredAt = currentData['tk_expired_at'] != null
        ? DateTime.tryParse(currentData['tk_expired_at'].toString())
        : null;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

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
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "DETAIL TAGIHAN",
          style: TextStyle(color: Colors.black, fontSize: 14),
        ),
        centerTitle: true,
        actions: [
          if (_isManualSyncing)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: AppCircularLoader(strokeWidth: 2),
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
            _buildHeaderCard(
              currencyFormat.format(currentData['tk_total']),
              expiredAt: expiredAt,
            ),
            const SizedBox(height: 32),
            _buildInfoTile(
              "Nomor Referensi",
              currentData['tk_id'] ?? "-",
              canCopy: true,
            ),
            _buildInfoTile("Jumlah Koin", "${currentData['tk_jumlah']} KOIN"),
            _buildInfoTile("Metode Pembayaran", metode.toUpperCase()),
            _buildInfoTile(
              "Status Transaksi",
              _formatTopupStatusLabel(status),
              isStatus: true,
            ),

            if (metode == 'transfer' &&
                buktiTf != null &&
                buktiTf.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildCompactBukti(buktiTf),
            ],

            const SizedBox(height: 25),

            // --- DYNAMIC ACTION / STATUS BOX ---
            _buildDynamicAction(
              context,
              currentData,
              metode,
              status,
              buktiTf,
              snapUrl,
              expiredAt,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatTopupStatusLabel(String status) {
    switch (status) {
      case 'success':
        return 'Sukses';
      case 'pending':
        return 'Menunggu Pembayaran';
      case 'challenge':
        return 'Menunggu Konfirmasi';
      case 'cancel':
        return 'Dibatalkan';
      case 'expire':
        return 'Kedaluwarsa';
      case 'deny':
      case 'failed':
        return 'Ditolak';
      default:
        return status.isEmpty
            ? '-'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  Widget _buildHeaderCard(
    String total, {
    DateTime? expiredAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
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
            color: AppPalette.primaryDeep.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "TOTAL TAGIHAN",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total,
            style: const TextStyle(color: Colors.white, fontSize: 32),
          ),
          if (expiredAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Batas bayar ${DateFormat("dd MMM yyyy, HH:mm").format(expiredAt.toLocal())}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
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
        const Text(
          "BUKTI TRANSFER SAYA",
          style: TextStyle(
            fontSize: 11,
            color: Colors.blueGrey,
            letterSpacing: 0.5,
          ),
        ),
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
                    errorWidget: const Icon(Icons.image),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Struk_Pembayaran.jpg",
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        "Klik untuk memperbesar",
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.zoom_in_rounded,
                  color: AppPalette.primaryDeep,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicAction(
    BuildContext context,
    Map<String, dynamic> data,
    String metode,
    String status,
    String? bukti,
    String? snapUrl,
    DateTime? expiredAt,
  ) {
    final canCancel =
        status == 'pending' || status == 'challenge' || status == 'failed';

    // 🚀 STATE: SUKSES (Biar nggak kosong pas udah lunas)
    if (status == 'success') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              "PEMBAYARAN BERHASIL",
              style: TextStyle(color: Colors.green, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              "Koin sejumlah ${data['tk_jumlah']} telah ditambahkan ke saldo outlet kamu. Terima kasih!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // 🚀 LOGIC UNTUK METODE TRANSFER
    if (metode == 'transfer') {
      if (status == 'failed') {
        return Column(
          children: [
            _buildButton(
              label: "UPLOAD ULANG STRUK",
              icon: Icons.cloud_upload_outlined,
              color: AppPalette.primaryDeep,
              onTap: () => _navigateToUpload(context, data['tk_id']),
              subText: "Tagihan ditolak admin. Silakan perbaiki struk.",
            ),
            const SizedBox(height: 12),
            if (canCancel)
              _buildSecondaryCancelButton(
                onTap: _isCanceling ? null : _handleCancelTopup,
              ),
          ],
        );
      }

      if (status == 'cancel') {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: const Column(
            children: [
              Icon(Icons.cancel_rounded, color: Colors.grey, size: 44),
              SizedBox(height: 16),
              Text(
                "TAGIHAN DITOLAK",
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                "Struk top up ditolak admin. Silakan upload ulang atau buat tagihan baru jika masih ingin top up.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      if (status == 'expire') {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
          ),
          child: const Column(
            children: [
              Icon(Icons.schedule_rounded, color: Colors.red, size: 44),
              SizedBox(height: 16),
              Text(
                "TAGIHAN KEDALUWARSA",
                style: TextStyle(color: Colors.red, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                "Tagihan ini sudah melewati batas pembayaran 24 jam. Buat tagihan baru untuk lanjut top up.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      if (bukti != null && bukti.isNotEmpty) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(Icons.hourglass_empty_rounded, color: Colors.blue, size: 40),
              SizedBox(height: 16),
              Text(
                "MENUNGGU KONFIRMASI",
                style: TextStyle(color: Colors.blue, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                "Admin sedang memvalidasi struk kamu. Koin akan otomatis bertambah setelah disetujui.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      return Column(
        children: [
          _buildButton(
            label: "UPLOAD STRUK PEMBAYARAN",
            icon: Icons.upload_file_rounded,
            color: const Color.fromARGB(255, 242, 65, 0),
            onTap: () => _navigateToUpload(context, data['tk_id']),
          ),
          const SizedBox(height: 12),
          if (canCancel)
            _buildSecondaryCancelButton(
              onTap: _isCanceling ? null : _handleCancelTopup,
            ),
        ],
      );
    }

    // 🚀 LOGIC UNTUK METODE MIDTRANS
    if (metode == 'midtrans') {
      if (status == 'cancel') {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
          ),
          child: const Column(
            children: [
              Icon(Icons.cancel_rounded, color: Colors.grey, size: 44),
              SizedBox(height: 16),
              Text(
                "TAGIHAN DIBATALKAN",
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              SizedBox(height: 6),
              Text(
                "Transaksi ini sudah dibatalkan. Buat tagihan baru jika masih ingin top up.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      if (status == 'expire' || status == 'failed') {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: 40,
              ),
              const SizedBox(height: 16),
              const Text(
                "TAGIHAN KADALUWARSA",
                style: TextStyle(color: Colors.red, fontSize: 15),
              ),
              const SizedBox(height: 6),
              const Text(
                "Tagihan kamu telah kadaluwarsa. Silakan buat permintaan Top Up baru di menu utama.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, fontSize: 12),
              ),
            ],
          ),
        );
      }

      if (status != 'pending' && status != 'challenge') {
        return const SizedBox();
      }

      return Column(
        children: [
          _buildButton(
            label: snapUrl != null ? "BAYAR SEKARANG" : "BUAT LINK PEMBAYARAN",
            icon: Icons.payment_rounded,
            color: const Color.fromARGB(255, 242, 65, 0),
            onTap: () => _handleMidtransPayment(context, data, snapUrl),
          ),
          const SizedBox(height: 12),
          if (canCancel)
            _buildSecondaryCancelButton(
              onTap: _isCanceling ? null : _handleCancelTopup,
            ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildButton({
    required String label,
    IconData? icon,
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
            style: const TextStyle(fontSize: 10, color: Colors.red),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: icon != null
                ? Icon(icon, color: Colors.white)
                : const SizedBox.shrink(),
            label: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 13),
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

  Widget _buildSecondaryCancelButton({required VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text("Batal Tagihan"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
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
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToUpload(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransferUploadScreen(topupId: id)),
    );
  }

  Future<void> _handleMidtransPayment(
    BuildContext context,
    Map<String, dynamic> data,
    String? url,
  ) async {
    final koinProv = context.read<KoinProvider>();
    final String status = data['tk_status'].toString().toLowerCase();

    // Jika sudah failed, kita sarankan pop keluar atau info expired
    if (status == 'failed') {
      CustomToast.show(context, message: "Tagihan ini sudah kadaluwarsa.");
      return;
    }

    if (url == null || url.isEmpty) {
      CustomToast.show(context, message: "Link pembayaran tidak ditemukan.");
      // Opsional: Langsung cancel di sini jika URL memang null dari awal
      await koinProv.cancelTopup(_topupId);
      return;
    }

    // Eksekusi buka link
    await _launchURL(context, url);
  }

  Future<void> _launchURL(BuildContext context, String url) async {
    final koinProv = context.read<KoinProvider>();

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MidtransSnapWebViewScreen(
            initialUrl: url,
            title: 'Pembayaran',
          ),
        ),
      );
    } catch (e) {
      // 🚩 CRITICAL: Jika error (expired/invalid), paksa transaksi jadi FAILED di backend
      debugPrint("⛔ Midtrans Error: $e. Auto-cancelling transaction...");

      if (context.mounted) {
        CustomToast.show(context, message: "Link sudah kadaluwarsa.");
      }

      // Tembak API cancel agar status di DB berubah & UI reaktif
      await koinProv.cancelTopup(_topupId);
    }
  }

  Widget _buildInfoTile(
    String label,
    String value, {
    bool isStatus = false,
    bool canCopy = false, // 🚀 Parameter baru
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F3F5), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(
            width: 20,
          ), // Memberi jarak agar label tidak mepet value
          Expanded(
            child: InkWell(
              onTap: canCopy
                  ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      CustomToast.show(
                        context,
                        message: "$label berhasil disalin!",
                      );
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
                        color: isStatus ? AppPalette.primaryDeep : Colors.black,
                      ),
                    ),
                  ),
                  if (canCopy) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: Colors.blue.shade600,
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
