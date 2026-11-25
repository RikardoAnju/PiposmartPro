import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:io';
import 'dart:async';

import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/service/lifecycle_event_service.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/app_provider.dart';
import '../../../providers/iap_provider.dart';
import '../../../providers/koin_provider.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'bank_selection_screen.dart';
import 'detail_topup_screen.dart';
import 'koin_topup_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TopupKoinScreen extends StatefulWidget {
  const TopupKoinScreen({super.key});

  @override
  State<TopupKoinScreen> createState() => _TopupKoinScreenState();
}

class _TopupKoinScreenState extends State<TopupKoinScreen>
    with WidgetsBindingObserver {
  static const int _minTopupRupiah = 20000;
  int? _selectedKoin;
  int _packageDiscountPct = 0;

  // Android only: custom nominal + voucher are gated behind an explicit
  // "Nominal Custom" option. A voucher may only be applied to a custom amount
  // (never stacked on a preset package's discount), so the voucher UI only
  // exists while this is true. iOS uses IAP and never touches this.
  bool _isCustomSelected = false;

  // Mode input custom: false = ketik jumlah koin, true = ketik nominal rupiah.
  // Koin tetap kanonik; rupiah hanya helper input (diperlakukan sebagai nilai
  // gross → koin = rupiah / hargaPerKoin, di-snap ke bilangan bulat).
  bool _isRupiahInput = false;

  double _voucherDiscountNominal = 0;
  String? _appliedVoucherCode;
  bool _isCheckingVoucher = false;

  final TextEditingController _customAmountCtrl = TextEditingController();
  final TextEditingController _manualVoucherCtrl = TextEditingController();

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _customTileKey = GlobalKey();

  String _selectedMethod = "";
  bool _awaitingIosTopupSuccess = false;
  bool _hasShownIosTopupSuccess = false;
  StreamSubscription? _eventSub;

  final int _maxKoin = 200000;

  void _refreshRealtimeState() {
    unawaited(context.read<KoinProvider>().refreshKoinData());
    unawaited(context.read<AppProvider>().fetchOutletProfile(force: true));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eventSub = appEventBus.stream.listen((event) {
      if (event is CoinBalanceChanged ||
          event is TopupSucceeded ||
          event is TopupStatusChanged) {
        _refreshRealtimeState();
      }

      if (!mounted) return;
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
      if (event is TopupSucceeded &&
          _awaitingIosTopupSuccess &&
          !_hasShownIosTopupSuccess &&
          mounted &&
          isCurrentRoute) {
        _awaitingIosTopupSuccess = false;
        _hasShownIosTopupSuccess = true;
        _refreshRealtimeState();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => KoinTopupSuccessScreen(
              kind: KoinTopupSuccessKind.completed,
              onPrimary: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LifecycleEventService.track(
        'coin_topup_viewed',
        metadata: {'source': 'coin_topup_screen'},
        localCooldown: const Duration(hours: 1),
      );
      final koinProv = context.read<KoinProvider>();
      koinProv.fetchEconomyConfig();
      koinProv.fetchKoinPackages();
      if (Platform.isIOS) {
        context.read<IapProvider>().initializeIosTopupProducts();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _eventSub?.cancel();
    _customAmountCtrl.dispose();
    _manualVoucherCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _awaitingIosTopupSuccess &&
        mounted) {
      context.read<KoinProvider>().refreshKoinData();
    }
  }

  double _calculateGrossPrice(int koin, double basePrice) => koin * basePrice;

  int _calculateVoucherPercent(double gross) {
    if (gross <= 0 || _voucherDiscountNominal <= 0) return 0;
    final pct = (_voucherDiscountNominal / gross) * 100;
    return pct.round().clamp(1, 100);
  }

  double _calculateFinalPrice(int koin, double basePrice) {
    double gross = _calculateGrossPrice(koin, basePrice);
    double afterPackageDisc = gross - (gross * (_packageDiscountPct / 100));
    double finalPrice = afterPackageDisc - _voucherDiscountNominal;
    if (finalPrice < 0) finalPrice = 0;
    // Samakan dengan backend: saat voucher dipakai, nominal bersih tidak boleh
    // turun di bawah minimal top up — backend akan menaikkannya ke minimal,
    // jadi tampilan total di sini harus ikut lantai yang sama agar tidak beda
    // dengan tagihan sebenarnya.
    if (_appliedVoucherCode != null && finalPrice < _minTopupRupiah) {
      finalPrice = _minTopupRupiah.toDouble();
    }
    return finalPrice;
  }

  void _resetVoucher() {
    setState(() {
      _appliedVoucherCode = null;
      _voucherDiscountNominal = 0;
    });
  }

  Future<void> _validateManualVoucher(int currentKoin) async {
    if (_manualVoucherCtrl.text.isEmpty) return;
    setState(() => _isCheckingVoucher = true);
    final result = await context.read<KoinProvider>().checkVoucher(
      _manualVoucherCtrl.text.toUpperCase(),
      currentKoin,
    );
    setState(() => _isCheckingVoucher = false);

    if (result['status'] == true) {
      setState(() {
        _appliedVoucherCode = _manualVoucherCtrl.text.toUpperCase();
        _voucherDiscountNominal =
            double.tryParse(result['data']['nominal_potongan'].toString()) ?? 0;
      });
      if (mounted) {
        CustomToast.show(context, message: "Voucher Berhasil Dipasang!");
      }
    } else {
      _resetVoucher();
      if (mounted) {
        CustomToast.show(
          context,
          message: result['message'] ?? "Voucher tidak valid",
        );
      }
    }
  }

  String _formatIDR(double amount) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(amount);

  String _formatCompactCoin(int amount) =>
      "${NumberFormat.decimalPattern('id_ID').format(amount)} Koin";

  @override
  Widget build(BuildContext context) {
    final koinProv = context.watch<KoinProvider>();
    final iapProv = context.watch<IapProvider>();
    final appProv = context.watch<AppProvider>();
    final double basePrice = koinProv.pricePerCoin;
    final int koinPerTrx = koinProv.coinPerTransaction;
    final List<Map<String, dynamic>> packages = koinProv.koinPackages;
    final coinStoreProducts = iapProv.coinStoreProducts;
    final bool isIosTopup = Platform.isIOS;

    final int minKoin = basePrice <= 0
        ? 0
        : (_minTopupRupiah / basePrice).ceil();

    // Angka mentah dari field custom. Di mode rupiah, ini nominal rupiah (gross)
    // yang dikonversi ke koin; di mode koin, ini langsung jumlah koin.
    final int rawCustomInput =
        int.tryParse(_customAmountCtrl.text.replaceAll('.', '')) ?? 0;
    final int customKoin = _isRupiahInput
        ? (basePrice <= 0 ? 0 : (rawCustomInput / basePrice).round())
        : rawCustomInput;

    int currentKoin = _selectedKoin ?? customKoin;

    double grossPrice = _calculateGrossPrice(currentKoin, basePrice);
    double finalPrice = _calculateFinalPrice(currentKoin, basePrice);

    bool hasCustomInput =
        _isCustomSelected && _customAmountCtrl.text.isNotEmpty;
    bool isUnderMin = hasCustomInput && currentKoin < minKoin;
    bool isOverMax = hasCustomInput && currentKoin > _maxKoin;
    bool isValidAmount = currentKoin >= minKoin && currentKoin <= _maxKoin;

    return AppScaffold(
      backgroundColor: Colors.white,
      // false: bottomSheet (estimasi + CTA) tetap menempel di bawah layar dan
      // TIDAK ikut naik saat keyboard muncul. Field tetap terlihat karena kita
      // auto-scroll tile custom ke atas viewport saat dipilih.
      resizeToAvoidBottomInset: false,
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
          "TOP UP KOIN",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body:
          (koinProv.isLoading ||
              koinProv.isFetchingPackages ||
              (isIosTopup && iapProv.isLoading && coinStoreProducts.isEmpty))
          ? const KoinTopupSkeleton()
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildSectionTitle(
                    isIosTopup ? "PILIH PAKET KOIN" : "PILIH PAKET UNTUNG",
                  ),
                  const SizedBox(height: 16),
                  if (isIosTopup &&
                      iapProv.errorMessage != null &&
                      coinStoreProducts.isEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          iapProv.errorMessage!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => context
                              .read<IapProvider>()
                              .initializeIosTopupProducts(),
                          child: const Text('Coba muat ulang produk'),
                        ),
                      ],
                    )
                  else if (isIosTopup && coinStoreProducts.isEmpty)
                    const Text(
                      "Produk iOS belum tersedia",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  else if (!isIosTopup && packages.isEmpty)
                    const Text(
                      "Tidak ada paket tersedia",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = (constraints.maxWidth - 12) / 2;
                        final cardHeight = cardWidth < 170 ? 146.0 : 142.0;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                mainAxisExtent: cardHeight,
                              ),
                          itemCount: isIosTopup
                              ? coinStoreProducts.length
                              : packages.length,
                          itemBuilder: (context, index) => isIosTopup
                              ? _buildIosPackageItem(
                                  coinStoreProducts[index],
                                  iapProv,
                                )
                              : _buildPackageItem(packages[index], basePrice),
                        );
                      },
                    ),
                  const SizedBox(height: 14),
                  if (!isIosTopup) ...[
                    _buildCustomOptionTile(),
                    if (_isCustomSelected) ...[
                      const SizedBox(height: 22),
                      _buildSectionTitle("NOMINAL CUSTOM"),
                      const SizedBox(height: 12),
                      _buildInputModeToggle(basePrice),
                      const SizedBox(height: 12),
                      _buildCustomTextField(
                        controller: _customAmountCtrl,
                        hint: _isRupiahInput
                            ? "Masukkan nominal rupiah..."
                            : "Masukkan jumlah koin...",
                        icon: _isRupiahInput
                            ? Icons.payments_rounded
                            : Icons.toll_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(7),
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            if (newValue.text.isEmpty) return newValue;
                            int value = int.parse(
                              newValue.text.replaceAll('.', ''),
                            );
                            final formatter = NumberFormat.decimalPattern(
                              'id_ID',
                            );
                            String newText = formatter.format(value);
                            return newValue.copyWith(
                              text: newText,
                              selection: TextSelection.collapsed(
                                offset: newText.length,
                              ),
                            );
                          }),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selectedKoin = null;
                            _packageDiscountPct = 0;
                          });
                          _resetVoucher();
                        },
                      ),
                      if (hasCustomInput)
                        _buildConversionHint(currentKoin, grossPrice),
                      if (isUnderMin || isOverMax)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Text(
                            isUnderMin
                                ? "Minimal top up adalah ${_formatIDR(_minTopupRupiah.toDouble())} (${NumberFormat.decimalPattern('id_ID').format(minKoin)} koin)"
                                : "Maksimal top up adalah ${NumberFormat.decimalPattern('id_ID').format(_maxKoin)} koin",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      _buildSectionTitle("KODE VOUCHER"),
                      const SizedBox(height: 12),
                      _buildVoucherInput(currentKoin),
                      const SizedBox(height: 20),
                    ],
                  ] else ...[
                    const SizedBox(height: 8),
                  ],
                  if (currentKoin > 0) ...[
                    const SizedBox(height: 14),
                    _buildSummaryCard(grossPrice, currentKoin, koinPerTrx),
                  ],
                ],
              ),
            ),
      bottomSheet: isIosTopup
          ? _buildIosBottomAction(iapProv, appProv, currentKoin)
          : _buildBottomAction(finalPrice, currentKoin, isValidAmount),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      color: Color(0xFF8A97A8),
      letterSpacing: 0.9,
    ),
  );

  Widget _buildVoucherInput(int currentKoin) {
    return Row(
      children: [
        Expanded(
          child: _buildCustomTextField(
            controller: _manualVoucherCtrl,
            hint: "Masukkan kode",
            icon: Icons.confirmation_num_rounded,
            color: const Color(0xFFF8F8F8),
            capslock: true,
            textStyle: const TextStyle(
              fontSize: 13,
              letterSpacing: 0.3,
              color: Color(0xFF5F6B7A),
            ),
            onChanged: (v) => _resetVoucher(),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: currentKoin > 0 && !_isCheckingVoucher
                ? () => _validateManualVoucher(currentKoin)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isCheckingVoucher
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppCircularLoader(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Cek",
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(double gross, int koin, int koinPerTrx) {
    double packageDiscountNominal = gross * (_packageDiscountPct / 100);
    double totalSave = packageDiscountNominal + _voucherDiscountNominal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            "Harga normal",
            _formatIDR(gross),
            isCrossed: totalSave > 0,
          ),
          if (_packageDiscountPct > 0)
            _buildSummaryRow(
              "Diskon paket ($_packageDiscountPct%)",
              "-${_formatIDR(packageDiscountNominal)}",
              isGreen: true,
            ),
          if (_voucherDiscountNominal > 0)
            _buildSummaryRow(
              "Voucher ($_appliedVoucherCode${_calculateVoucherPercent(gross) > 0 ? ' · ${_calculateVoucherPercent(gross)}%' : ''})",
              "-${_formatIDR(_voucherDiscountNominal)}",
              isGreen: true,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFEAECEF)),
          ),
          if (totalSave > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Kamu hemat",
                  style: TextStyle(fontSize: 10, color: Color(0xFF27AE60)),
                ),
                Text(
                  _formatIDR(totalSave),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF27AE60),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Estimasi transaksi",
                style: TextStyle(fontSize: 10, color: Color(0xFF8A97A8)),
              ),
              Text(
                "≈ ${_getTransactionEstimation(koin, koinPerTrx)}",
                style: const TextStyle(fontSize: 11, color: Color(0xFFFF6A1A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Estimasi berapa transaksi yang bisa dilayani dari koin yang dibeli.
  String _getTransactionEstimation(int koin, int koinPerTrx) {
    if (koin <= 0 || koinPerTrx <= 0) return "0 Transaksi";
    final int trx = koin ~/ koinPerTrx;
    return "${NumberFormat.decimalPattern('id_ID').format(trx)} Transaksi";
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isCrossed = false,
    bool isGreen = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Color(0xFF8A97A8)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              decoration: isCrossed ? TextDecoration.lineThrough : null,
              color: isGreen
                  ? const Color(0xFF27AE60)
                  : const Color(0xFF243041),
            ),
          ),
        ],
      ),
    );
  }

  // Pindah mode input Koin<->Rupiah, mengkonversi nilai yang sudah diketik agar
  // tetap setara. Voucher/diskon direset (konsisten dgn perubahan nominal lain).
  void _switchInputMode(bool toRupiah, double basePrice) {
    if (_isRupiahInput == toRupiah) return;
    final raw = int.tryParse(_customAmountCtrl.text.replaceAll('.', '')) ?? 0;
    final formatter = NumberFormat.decimalPattern('id_ID');
    setState(() {
      _isRupiahInput = toRupiah;
      _selectedKoin = null;
      _packageDiscountPct = 0;
      if (raw > 0 && basePrice > 0) {
        final converted = toRupiah
            ? (raw * basePrice)
                  .round() // koin -> rupiah gross
            : (raw / basePrice).round(); // rupiah -> koin
        _customAmountCtrl.text = formatter.format(converted);
      }
    });
    _resetVoucher();
  }

  Widget _buildInputModeToggle(double basePrice) {
    Widget seg(String label, bool rupiah) {
      final selected = _isRupiahInput == rupiah;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _switchInputMode(rupiah, basePrice),
          child: Container(
            height: 40,
            alignment: Alignment.center,
            color: Colors.transparent,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 13,
                fontWeight: AppFont.w700,
                color: selected
                    ? AppPalette.primaryDeep
                    : const Color(0xFF9AA6B2),
              ),
              child: Text(label),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Indikator putih yang meluncur (slide), bukan blink.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: _isRupiahInput ? segmentWidth : 0,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Row(children: [seg('Koin', false), seg('Rupiah', true)]),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConversionHint(int koin, double gross) {
    final text = _isRupiahInput
        ? "≈ ${NumberFormat.decimalPattern('id_ID').format(koin)} Koin"
        : "≈ ${_formatIDR(gross)}";
    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.sync_alt_rounded,
            size: 13,
            color: Color(0xFF90A0B0),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6E7B8B),
              fontWeight: AppFont.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    Color? color,
    bool capslock = false,
    TextStyle? textStyle,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: capslock
          ? TextCapitalization.characters
          : TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA6B2), fontSize: 13),
        prefixIcon: Icon(icon, size: 19, color: Color(0xFF90A0B0)),
        filled: true,
        fillColor: color ?? const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
      style:
          textStyle ?? const TextStyle(fontSize: 13, color: Color(0xFF243041)),
    );
  }

  // Bawa tile custom ke atas viewport agar field & konten custom yang baru
  // muncul langsung terlihat (setelah section-nya ter-expand).
  void _scrollCustomTileToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _customTileKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _buildCustomOptionTile() {
    final bool selected = _isCustomSelected;
    return GestureDetector(
      key: _customTileKey,
      onTap: () {
        setState(() {
          _isCustomSelected = true;
          _selectedKoin = null;
          _packageDiscountPct = 0;
        });
        _scrollCustomTileToTop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppPalette.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppPalette.primaryDeep : const Color(0xFFF1F3F5),
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.primaryDeep.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: selected
                    ? AppPalette.primaryDeep
                    : const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 20,
                color: selected ? Colors.white : const Color(0xFF8A97A8),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Nominal Custom",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFont.w700,
                      color: Color(0xFF243041),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Tentukan jumlah koin sendiri & pakai voucher",
                    style: TextStyle(fontSize: 11, color: Color(0xFF8A97A8)),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: selected
                  ? AppPalette.primaryDeep
                  : const Color(0xFFCED6E0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageItem(Map<String, dynamic> pkg, double basePrice) {
    int koinValue = pkg['jumlah_koin'] ?? 0;
    int discountPct = pkg['discount_pct'] ?? 0;
    bool isSelected = _selectedKoin == koinValue;
    double gross = _calculateGrossPrice(koinValue, basePrice);
    double net = gross * (1 - (discountPct / 100));
    double savedAmount = gross - net;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedKoin = koinValue;
          _packageDiscountPct = discountPct;
          _customAmountCtrl.clear();
          // Picking a preset exits custom mode and drops any voucher, so a
          // package discount and a voucher can never stack.
          _isCustomSelected = false;
        });
        _resetVoucher();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppPalette.primaryDeep
                : const Color(0xFFF1F3F5),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.primaryDeep.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 170;
            final padding = compact ? 10.0 : 12.0;
            final titleSize = compact ? 18.0 : 20.0;
            final priceSize = compact ? 12.0 : 13.0;
            final contentGap = discountPct > 0 ? (compact ? 6.0 : 8.0) : 16.0;

            return Stack(
              children: [
                if (discountPct > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildDiscountTag("$discountPct%"),
                  ),
                Padding(
                  padding: EdgeInsets.all(padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          NumberFormat.decimalPattern(
                            'id_ID',
                          ).format(koinValue),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: titleSize,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const Text(
                        "KOIN",
                        style: TextStyle(fontSize: 9, color: Colors.grey),
                      ),
                      SizedBox(height: contentGap),
                      if (discountPct > 0)
                        Text(
                          _formatIDR(gross),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        _formatIDR(net),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: priceSize,
                          color: Colors.black,
                        ),
                      ),
                      if (discountPct > 0)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 5 : 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF27AE60,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "Hemat ${_formatIDR(savedAmount)}",
                              maxLines: 1,
                              style: TextStyle(
                                color: const Color(0xFF27AE60),
                                fontSize: compact ? 7.5 : 8,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildIosPackageItem(ProductDetails product, IapProvider iapProv) {
    final backend = iapProv.getBackendProduct(product.id);
    final int coinAmount = backend?.coinAmount ?? 0;
    final bool isSelected = _selectedMethod == product.id;
    final bool isPopular = coinAmount == 500 || coinAmount == 1000;
    final double? normalPrice = context.read<KoinProvider>().pricePerCoin > 0
        ? coinAmount * context.read<KoinProvider>().pricePerCoin
        : null;
    final double? savings =
        normalPrice != null && normalPrice > product.rawPrice
        ? normalPrice - product.rawPrice
        : null;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = product.id;
          _selectedKoin = coinAmount;
          _packageDiscountPct = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppPalette.primaryDeep
                : const Color(0xFFF1F3F5),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.primaryDeep.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            if (isPopular)
              Positioned(top: 0, right: 0, child: _buildDiscountTag("POPULER")),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    NumberFormat.decimalPattern('id_ID').format(coinAmount),
                    style: const TextStyle(fontSize: 20, letterSpacing: -1),
                  ),
                  const Text(
                    "KOIN",
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  if (savings != null && savings > 0)
                    Text(
                      _formatIDR(normalPrice!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  Text(
                    product.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    savings != null && savings > 0
                        ? "Hemat ${_formatIDR(savings)}"
                        : "Pembayaran aman via App Store",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: savings != null && savings > 0
                          ? const Color(0xFF27AE60)
                          : Colors.orange.shade700,
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

  Widget _buildDiscountTag(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: const BoxDecoration(
      color: AppPalette.primaryDeep,
      borderRadius: BorderRadius.only(
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(14),
      ),
    ),
    child: Text(
      "-$text",
      style: const TextStyle(color: Colors.white, fontSize: 9),
    ),
  );

  Widget _buildBottomAction(double total, int koin, bool isValid) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "TOTAL BAYAR",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      _formatIDR(total),
                      style: const TextStyle(
                        fontSize: 21,
                        color: Color(0xFF243041),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: (total > 0 && isValid)
                      ? () => _handleAndroidTopup(koin, total)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primaryDeep,
                    disabledBackgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Lanjut",
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAndroidTopup(int koin, double total) {
    final koinProv = context.read<KoinProvider>();
    final activeTopup = koinProv.activeTopups
        .cast<Map<String, dynamic>?>()
        .firstWhere((item) {
          final status = item?['tk_status']?.toString().toLowerCase();
          return status == 'pending' || status == 'challenge';
        }, orElse: () => null);

    if (activeTopup != null) {
      CustomToast.show(
        context,
        message: 'Masih ada tagihan top up yang sedang berjalan.',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailTopupScreen(topup: activeTopup),
        ),
      );
      return;
    }

    _showPaymentMethod(koin, total);
  }

  Widget _buildIosBottomAction(
    IapProvider iapProv,
    AppProvider appProv,
    int koin,
  ) {
    final selectedProductId = _selectedMethod;
    final selectedStoreProduct = selectedProductId.isEmpty
        ? null
        : iapProv.getStoreProduct(selectedProductId);
    final canBuy =
        selectedStoreProduct != null &&
        appProv.outlet != null &&
        !iapProv.isPurchasing;
    final selectedPrice = selectedStoreProduct?.price ?? "Belum dipilih";

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iapProv.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                iapProv.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 11),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PAKET TERPILIH",
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      koin > 0 ? _formatCompactCoin(koin) : "Belum dipilih",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF243041),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedPrice,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A97A8),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 186,
                height: 52,
                child: ElevatedButton(
                  onPressed: canBuy
                      ? () async {
                          final result = await iapProv.purchaseCoinProduct(
                            productId: selectedStoreProduct.id,
                            outletId: appProv.outlet!.id,
                          );
                          if (!mounted) return;
                          if (result['success'] == true) {
                            _awaitingIosTopupSuccess = true;
                            _hasShownIosTopupSuccess = false;
                            await context
                                .read<KoinProvider>()
                                .refreshKoinData();
                            if (!mounted) return;
                            await context
                                .read<AppProvider>()
                                .fetchOutletProfile(force: true);
                            if (!mounted) return;
                          }
                          CustomToast.show(
                            context,
                            message:
                                result['message']?.toString() ??
                                'Memproses pembelian...',
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppPalette.primaryDeep,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 0,
                  ),
                  child: iapProv.isPurchasing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Beli via App Store",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
          if (!Platform.isIOS) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton.icon(
                onPressed: iapProv.isPurchasing
                    ? null
                    : () async {
                        await iapProv.recoverPurchases();
                        if (!mounted) return;
                        CustomToast.show(
                          context,
                          message:
                              'Memeriksa pembelian yang belum tuntas dari App Store...',
                        );
                      },
                icon: const Icon(
                  Icons.restore_rounded,
                  size: 16,
                  color: Color(0xFF8A97A8),
                ),
                label: const Text(
                  'Pulihkan Pembelian',
                  style: TextStyle(fontSize: 12, color: Color(0xFF8A97A8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // MODAL METHOD (PENTING: resizeToAvoidBottomInset scaffold induk sudah true)
  void _showPaymentMethod(int koin, double total) {
    _selectedMethod = "midtrans";
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final bottomSafeArea = MediaQuery.of(context).padding.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              20 + (bottomSafeArea < 12 ? 12 : bottomSafeArea),
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Biar fix mengikuti konten
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Metode Pembayaran",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFont.w800,
                    color: AppPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Otomatis dipilih sebagai default.",
                  style: TextStyle(fontSize: 12, color: AppPalette.muted),
                ),
                const SizedBox(height: 16),
                _buildMethodSelector(
                  title: "QRIS / VA / e-wallet",
                  sub: "Diverifikasi otomatis",
                  icon: Icons.bolt_rounded,
                  color: AppPalette.primary,
                  methodKey: "midtrans",
                  currentSelection: _selectedMethod,
                  badge: "Default",
                  onTap: () =>
                      setModalState(() => _selectedMethod = "midtrans"),
                ),
                const SizedBox(height: 12),
                _buildMethodSelector(
                  title: "Transfer + upload bukti",
                  sub: "Diverifikasi manual",
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF2F80ED),
                  methodKey: "transfer",
                  currentSelection: _selectedMethod,
                  onTap: () =>
                      setModalState(() => _selectedMethod = "transfer"),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _selectedMethod.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context);
                            if (_selectedMethod == "midtrans") {
                              _processMidtrans(koin, total);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BankSelectionScreen(
                                    jumlahKoin: koin,
                                    totalBayar: total,
                                    kodeVoucher: _appliedVoucherCode,
                                  ),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primaryDeep,
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _selectedMethod == "midtrans"
                          ? "Bayar Sekarang"
                          : "Lanjut ke Transfer",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMethodSelector({
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required String methodKey,
    required String currentSelection,
    required VoidCallback? onTap,
    String? badge,
    bool isDisabled = false,
  }) {
    bool isSelected = currentSelection == methodKey;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: isDisabled
              ? const Color(0xFFF8F9FA)
              : isSelected
              ? color.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDisabled
                ? const Color(0xFFE5E7EB)
                : isSelected
                ? color
                : const Color(0xFFF1F3F5),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDisabled
                    ? Colors.grey.withValues(alpha: 0.08)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: isDisabled ? Colors.grey : color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: AppFont.w800,
                            color: isDisabled
                                ? const Color(0xFF98A2B3)
                                : const Color(0xFF243041),
                          ),
                        ),
                      ),
                      if (badge != null && badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: AppFont.w700,
                              color: color,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDisabled
                          ? const Color(0xFF98A2B3)
                          : const Color(0xFF7C8896),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isDisabled
                  ? Icons.block_rounded
                  : isSelected
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: isDisabled
                  ? const Color(0xFF98A2B3)
                  : isSelected
                  ? color
                  : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  void _processMidtrans(int koin, double total) async {
    final koinProv = context.read<KoinProvider>();
    final result = await koinProv.requestTopup(
      jumlahKoin: koin,
      nominalBayar: total,
      metodeBayar: "midtrans",
      kodeVoucher: _appliedVoucherCode,
    );
    if (result['success'] == true) {
      final dynamic topupData = result['data']['topup_data'];
      final String? topupId = topupData is Map<String, dynamic>
          ? topupData['tk_id']?.toString()
          : result['data']['tk_id']?.toString();

      if (!mounted) return;

      final Map<String, dynamic> createdTopup = koinProv.allTopups
          .cast<Map<String, dynamic>>()
          .firstWhere(
            (t) => t['tk_id']?.toString() == topupId,
            orElse: () => topupData is Map<String, dynamic>
                ? Map<String, dynamic>.from(topupData)
                : <String, dynamic>{
                    'tk_id': topupId,
                    'tk_jumlah': koin,
                    'tk_total': total,
                    'tk_metode_bayar': 'midtrans',
                    'tk_status': 'pending',
                    'tk_snap_url': result['data']['snap_url'],
                  },
          );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              DetailTopupScreen(topup: createdTopup, autoLaunchSnapUrl: true),
        ),
      );
    } else {
      if (mounted) CustomToast.show(context, message: result['message']);
    }
  }
}
