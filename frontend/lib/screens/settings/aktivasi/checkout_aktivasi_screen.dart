import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../providers/iap_provider.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../core/events/app_events.dart';
import 'ringkasan_pesanan_screen.dart';
import 'widgets/outlet_pro_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class CheckoutAktivasiScreen extends StatefulWidget {
  final double hargaNormal;
  final double diskonPersen;
  final double hargaFinal;

  const CheckoutAktivasiScreen({
    super.key,
    required this.hargaNormal,
    required this.diskonPersen,
    required this.hargaFinal,
  });

  @override
  State<CheckoutAktivasiScreen> createState() => _CheckoutAktivasiScreenState();
}

class _CheckoutAktivasiScreenState extends State<CheckoutAktivasiScreen> {
  bool _isProcessing = false;
  bool _isPopped = false; // ✅ Flag untuk cegah double pop
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();

    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<IapProvider>().initializeIosTopupProducts();
      });
    }

    // 1. Dengerin sinyal WebSocket (Hanya pop jika Outlet benar-benar aktif/Success)
    _eventSub = appEventBus.stream.listen((event) {
      if (event is OutletActivated) {
        if (_isPopped) return;
        _isPopped = true;
        debugPrint(
          "🎯 CheckoutAktivasi: Sinyal PRO Sukses, menampilkan success screen...",
        );
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OutletProSuccessScreen()),
          );
        }
      }
    });

    // 2. Cek awal: Jika sudah ada pending, jangan biarkan user di sini
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _guardPendingTransaction();
    });
  }

  // ✅ Fungsi Guard untuk mencegah double order
  void _guardPendingTransaction() {
    final addonProv = context.read<AddonProvider>();
    final appProv = context.read<AppProvider>();

    // Jika sudah PRO
    if (appProv.outlet?.activatedAt != null) {
      Navigator.pop(context);
      return;
    }

    // Jika ada tagihan gantung
    final bool hasPendingPRO = addonProv.pendingOrders.any(
      (o) =>
          o.id.startsWith("PRO-") &&
          (o.status == "PENDING" || o.status == "PENDING_VALIDATION"),
    );

    if (hasPendingPRO) {
      debugPrint(
        "🛡️ CheckoutAktivasi: Terdeteksi Pending PRO, Tendang Balik.",
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // 🚩 HAPUS didChangeDependencies yang ada Navigator.pop nya biar gak bentrok stack!

  String _formatRupiah(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }

  void _executeAktivasi() async {
    final addonProv = context.read<AddonProvider>();
    final appProv = context.read<AppProvider>();

    await addonProv.fetchPendingOrders();
    if (!mounted) return;

    final bool hasPendingPRO = addonProv.pendingOrders.any(
      (o) =>
          o.id.startsWith("PRO-") &&
          (o.status == "PENDING" || o.status == "PENDING_VALIDATION"),
    );

    if (appProv.outlet?.activatedAt != null) {
      CustomToast.show(
        context,
        message: "Outlet ini sudah aktif sebagai PRO.",
        isError: true,
      );
      return;
    }

    if (hasPendingPRO) {
      CustomToast.show(
        context,
        message: "Masih ada transaksi aktivasi yang sedang diproses.",
        isError: true,
      );
      Navigator.pop(context);
      return;
    }

    if (Platform.isIOS) {
      final outlet = appProv.outlet;
      if (outlet == null) {
        CustomToast.show(
          context,
          message: "Outlet aktif belum tersedia.",
          isError: true,
        );
        return;
      }

      setState(() => _isProcessing = true);
      final res = await context.read<IapProvider>().purchaseOutletPro(
        outletId: outlet.id,
      );
      if (!mounted) return;
      if (res['success'] != true) {
        CustomToast.show(context, message: res['message'], isError: true);
      } else {
        CustomToast.show(context, message: res['message']);
        await appProv.fetchAppData(force: true);
      }
      if (mounted) setState(() => _isProcessing = false);
    }
    else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RingkasanPesananScreen(
            items: [
              {
                'id': 'OUTLET_ACTIVATION',
                'name': 'Aktivasi Lisensi Outlet PRO',
                'price': widget.hargaNormal.toInt(),
              },
            ],
            total: widget.hargaFinal.toInt(),
            isAktivasiOnly: true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasDiskon = widget.diskonPersen > 0;

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Konfirmasi Aktivasi",
          style: TextStyle(color: Color(0xFF2C3E50), fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    "Aktivasi Outlet PRO",
                    style: TextStyle(fontSize: 22, color: Color(0xFF2C3E50)),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Satu langkah lagi untuk membuat outlet Anda aktif selamanya dan menikmati ekosistem AyoCuci.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildPriceCard(hasDiskon),
                  const SizedBox(height: 18),
                  _buildPlatformNote(),
                  const SizedBox(height: 32),
                  _buildBenefitItem(
                    Icons.verified_user_rounded,
                    "Lisensi Penggunaan Outlet Permanen",
                  ),
                  _buildBenefitItem(
                    Icons.shopping_bag_rounded,
                    "Buka Akses Belanja Add-on Eceran",
                  ),
                  _buildBenefitItem(
                    Icons.cloud_done_rounded,
                    "Penyimpanan Data Transaksi Cloud",
                  ),
                  _buildBenefitItem(
                    Icons.update_rounded,
                    "Gratis Update Fitur Sistem Selamanya",
                  ),
                ],
              ),
            ),
          ),
          _buildActionButton(),
        ],
      ),
    );
  }

  Widget _buildPriceCard(bool hasDiskon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF2F2F2), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            "TOTAL INVESTASI AKTIVASI",
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          if (hasDiskon) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatRupiah(widget.hargaNormal),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "PROMO ${widget.diskonPersen.toInt()}%",
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(
            _formatRupiah(widget.hargaFinal),
            style: const TextStyle(
              fontSize: 34,
              color: AppPalette.primary,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Sekali Bayar, Aktif Selamanya",
            style: TextStyle(fontSize: 12, color: Color(0xFF27AE60)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE9DA)),
      ),
      child: Text(
        Platform.isIOS
            ? "Pembayaran akan dilanjutkan melalui App Store."
            : "Pembayaran dilanjutkan melalui transfer bank dan verifikasi bukti transfer.",
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF9A4D00),
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : _executeAktivasi,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 255, 108, 78),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: AppCircularLoader(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    Platform.isIOS
                        ? "LANJUTKAN VIA APP STORE"
                        : "LANJUT PEMBAYARAN",
                    style: const TextStyle(fontSize: 15, letterSpacing: 0.5),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppPalette.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppPalette.primary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
