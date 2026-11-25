import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'dart:async';

import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'widgets/outlet_pro_success_screen.dart';

class FreeAktivasiScreen extends StatefulWidget {
  const FreeAktivasiScreen({super.key});

  @override
  State<FreeAktivasiScreen> createState() => _FreeAktivasiScreenState();
}

class _FreeAktivasiScreenState extends State<FreeAktivasiScreen> {
  bool _isProcessing = false;
  bool _isPopped = false;
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _eventSub = appEventBus.stream.listen((event) {
      if (event is OutletActivated && mounted && !_isPopped) {
        _isPopped = true;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OutletProSuccessScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _activateNow() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    final res = await context.read<AddonProvider>().activateOutlet('TRANSFER');

    if (res['success'] == true) {
      await context.read<AppProvider>().fetchAppData(force: true);
      if (!mounted || _isPopped) return;
      _isPopped = true;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OutletProSuccessScreen()),
      );
      return;
    }

    if (mounted) {
      CustomToast.show(
        context,
        message: res['message'] ?? 'Gagal mengaktifkan outlet.',
        isError: true,
      );
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();
    final activationFee = koinProv.activationFee;

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
          'Aktivasi Gratis',
          style: TextStyle(color: Color(0xFF2C3E50), fontSize: 14),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4EE),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: AppAssetImage(
                        'assets/maskot/outlet_pro_mascot.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Aktivasi Outlet PRO Sedang Gratis',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Outlet bisa langsung diaktifkan tanpa masuk ke tahap pembayaran.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7C8896),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFFFE2C7)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _formatRupiah(activationFee),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF98A2B3),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'GRATIS',
                          style: TextStyle(
                            fontSize: 34,
                            color: AppPalette.primary,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Promo aktivasi sedang aktif untuk outlet Anda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF27AE60),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildBenefitItem(
                    Icons.verified_user_rounded,
                    'Lisensi outlet PRO aktif permanen',
                  ),
                  _buildBenefitItem(
                    Icons.shopping_bag_rounded,
                    'Akses pembelian add-on terbuka',
                  ),
                  _buildBenefitItem(
                    Icons.cloud_done_rounded,
                    'Data transaksi tetap sinkron di cloud',
                  ),
                ],
              ),
            ),
          ),
          Container(
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
                  onPressed: _isProcessing ? null : _activateNow,
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
                      : const Text(
                          'AKTIFKAN SEKARANG',
                          style: TextStyle(fontSize: 15, letterSpacing: 0.5),
                        ),
                ),
              ),
            ),
          ),
        ],
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

  String _formatRupiah(num value) {
    return NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(value);
  }
}
