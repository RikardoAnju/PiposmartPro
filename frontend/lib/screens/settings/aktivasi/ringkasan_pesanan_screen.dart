import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/providers/pegawai_provider.dart';
import 'package:ayocucinew/providers/koin_provider.dart';
import 'package:ayocucinew/screens/settings/aktivasi/widgets/transfer_instruction_screen.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../../providers/addon_provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/models/addon_model.dart';
import '../../../../shared/widgets/custom_toast.dart';
import 'pembelian_saya_screen.dart';
import 'widgets/addon_success_screen.dart';
import 'widgets/outlet_pro_success_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import '../koin/topup_koin_screen.dart';

class RingkasanPesananScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int total; // Ini total dalam Rupiah
  final List<String>? addonIds;
  final bool isAktivasiOnly;
  final Map<String, String>? targetIds;

  const RingkasanPesananScreen({
    super.key,
    required this.items,
    required this.total,
    this.addonIds,
    this.isAktivasiOnly = false,
    this.targetIds,
  });

  @override
  State<RingkasanPesananScreen> createState() => _RingkasanPesananScreenState();
}

class _RingkasanPesananScreenState extends State<RingkasanPesananScreen> {
  String? _selectedMetode;
  bool _isLoading = false;
  final Map<String, String> _internalTargetIds = {};

  // Voucher State
  final TextEditingController _voucherController = TextEditingController();
  String? _appliedVoucher;
  double _potonganPromo = 0;
  bool _isValidatingVoucher = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAktivasiOnly) {
      _selectedMetode = 'KOIN';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PegawaiProvider>().fetchEmployees();
      context.read<AddonProvider>().fetchActiveAddons();
      context.read<AppProvider>().fetchAppData();
    });
  }

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  bool _isEmployeeRequiredButEmpty() {
    for (var item in widget.items) {
      if (item['id'] == 'AD-001' && _internalTargetIds[item['id']] == null) {
        return true;
      }
    }
    return false;
  }

  bool get _isAddonOnly => !widget.isAktivasiOnly;

  void _applyVoucher() async {
    if (_voucherController.text.isEmpty) return;

    setState(() => _isValidatingVoucher = true);
    final addonProv = context.read<AddonProvider>();
    final res = await addonProv.validateVoucher(_voucherController.text.trim());

    if (mounted) {
      setState(() => _isValidatingVoucher = false);
      if (res['success']) {
        final data = res['data'];
        double totalAwal = widget.total.toDouble();
        double potongan = 0;

        if (data['vc_jenis'] == 'persen') {
          potongan = totalAwal * (data['vc_nilai_potongan'] / 100);
        } else {
          potongan = (data['vc_nilai_potongan'] as num).toDouble();
        }

        setState(() {
          _appliedVoucher = _voucherController.text.trim();
          _potonganPromo = potongan;

          // ✅ UX ENHANCEMENT: Jika total jadi 0, hilangkan pilihan metode
          if (totalAwal - _potonganPromo <= 0) {
            _selectedMetode = "TRANSFER"; // Dummy for backend
          }
        });

        CustomToast.show(
          context,
          message:
              "Voucher ${data['vc_jenis'] == 'persen' ? '${data['vc_nilai_potongan']}%' : 'Rp ${data['vc_nilai_potongan']}'} berhasil digunakan!",
        );
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    }
  }

  List<Map<String, dynamic>> get _availableMethods {
    if (!widget.isAktivasiOnly) {
      return [
        {
          'label': 'Potong Koin (Instant)',
          'value': 'KOIN',
          'icon': Icons.monetization_on_rounded,
        },
      ];
    }

    final list = [
      {
        'label': 'Transfer Bank (Manual)',
        'value': 'TRANSFER',
        'icon': Icons.account_balance_rounded,
      },
    ];
    return list;
  }

  String _formatRupiah(num value) => NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  ).format(value);

  AddonSuccessKind _resolveAddonSuccessKind(AddonProvider addonProv) {
    final selectedIds = widget.addonIds ?? const <String>[];
    if (selectedIds.isEmpty) return AddonSuccessKind.updated;

    final activeCount = selectedIds
        .where(
          (id) => addonProv.activeAddons.any((active) => active.addonId == id),
        )
        .length;

    if (activeCount == 0) return AddonSuccessKind.firstActivation;
    if (activeCount == selectedIds.length) return AddonSuccessKind.renewed;
    return AddonSuccessKind.updated;
  }

  String? _resolveItemLabel(Map<String, dynamic> item) {
    final raw = item['nama'] ?? item['name'];
    final label = raw?.toString().trim();
    if (label == null || label.isEmpty) return null;
    return label;
  }

  String? _resolveFeatureName() {
    if (widget.items.isEmpty) return null;
    final firstName = _resolveItemLabel(widget.items.first);
    if (firstName == null || firstName.isEmpty) return null;
    return firstName;
  }

  List<String> _resolveFeatureNames() {
    return widget.items
        .map(_resolveItemLabel)
        .whereType<String>()
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String? _resolveFeatureId() {
    if (widget.items.isEmpty) return null;
    final firstId = widget.items.first['id']?.toString().trim();
    if (firstId == null || firstId.isEmpty) return null;
    return firstId;
  }

  Future<void> _handlePayment() async {
    if (_selectedMetode == null) return;

    // Validasi Slot Pegawai
    for (var item in widget.items) {
      if (item['id'] == 'AD-001' && _internalTargetIds[item['id']] == null) {
        CustomToast.show(
          context,
          message: "Pilih pegawai untuk slot tambahan!",
          isError: true,
        );
        return;
      }
    }

    // Transfer: langsung ke satu layar Bayar via Transfer (pilih bank + upload
    // bukti digabung). Layar Pilih Bank terpisah sudah dihapus untuk mengurangi
    // friction.
    if (_selectedMetode == 'TRANSFER' && (widget.total - _potonganPromo) > 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TransferInstructionScreen(
            totalBayar: widget.total.toDouble() - _potonganPromo,
            addonIds: widget.addonIds,
            targetIds: _internalTargetIds.isNotEmpty
                ? _internalTargetIds
                : widget.targetIds,
            isAktivasiOnly: widget.isAktivasiOnly,
            voucherCode: _appliedVoucher,
          ),
        ),
      );
      return;
    }

    final addonProv = context.read<AddonProvider>();
    final appProv = context.read<AppProvider>();
    final koinProv = context.read<KoinProvider>();

    if (_selectedMetode == 'KOIN') {
      double totalKoinDibutuhkan = widget.total / koinProv.pricePerCoin;
      if ((appProv.outlet?.koin ?? 0) < totalKoinDibutuhkan) {
        CustomToast.show(
          context,
          message: "Saldo Koin tidak cukup!",
          isError: true,
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    Map<String, dynamic> res = {
      'success': false,
      'message': 'Terjadi kesalahan',
    };

    try {
      final addonSuccessKind =
          !widget.isAktivasiOnly && _selectedMetode == 'KOIN'
          ? _resolveAddonSuccessKind(addonProv)
          : null;

      if (widget.isAktivasiOnly) {
        res = await addonProv.activateOutlet(
          _selectedMetode!,
          voucherCode: _appliedVoucher,
        );
      } else {
        if (_selectedMetode == 'KOIN') {
          res = await addonProv.purchaseWithKoin(
            addonIds: widget.addonIds ?? [],
            targetIds: _internalTargetIds,
          );
        } else {
          res = await addonProv.checkoutAddons(
            addonIds: widget.addonIds ?? [],
            metode: _selectedMetode!,
            targetIds: _internalTargetIds,
            voucherCode: _appliedVoucher,
          );
        }
      }

      if (res['success']) {
        CustomToast.show(
          context,
          message: _selectedMetode == 'KOIN'
              ? "Fitur Berhasil Aktif!"
              : "Pesanan Berhasil Dibuat!",
        );
        await appProv.fetchAppData(force: true);
        await addonProv.fetchActiveAddons();
        await addonProv.fetchPendingOrders();

        if (_selectedMetode == 'KOIN') {
          if (widget.isAktivasiOnly) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const OutletProSuccessScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (ctx) => AddonSuccessScreen(
                  kind: addonSuccessKind ?? AddonSuccessKind.updated,
                  featureName: _resolveFeatureName(),
                  featureId: _resolveFeatureId(),
                  featureNames: _resolveFeatureNames(),
                  onPrimary: () =>
                      Navigator.of(ctx, rootNavigator: true).pop(),
                ),
              ),
            );
          }
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PembelianSayaScreen(),
            ),
          );
        }
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    } catch (e) {
      CustomToast.show(
        context,
        message: "Terjadi kesalahan: $e",
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkColor = Color(0xFF2C3E50);

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: darkColor,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ringkasan Pesanan',
          style: TextStyle(color: darkColor, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAttentionCard(),
                  const SizedBox(height: 20),
                  if (_isEmployeeRequiredButEmpty()) ...[
                    _buildEmployeeWarning(),
                    const SizedBox(height: 20),
                  ],
                  if (_isAddonOnly) ...[
                    _buildAddonValueCard(),
                    const SizedBox(height: 20),
                  ],
                  _buildFiturCard(),
                  const SizedBox(height: 24),

                  if (widget.isAktivasiOnly) ...[
                    _buildVoucherInput(),
                    const SizedBox(height: 24),
                  ],

                  // ✅ UX ENHANCEMENT: Jika GRATIS, tampilkan banner khusus & sembunyikan metode bayar
                  if ((widget.total - _potonganPromo) <= 0)
                    _buildFreePromoBanner()
                  else if (widget.isAktivasiOnly) ...[
                    const Text(
                      'Metode Pembayaran',
                      style: TextStyle(fontSize: 14, color: darkColor),
                    ),
                    const SizedBox(height: 12),
                    ..._availableMethods.map((m) => _buildMethodItem(m)),
                  ],

                  const SizedBox(height: 24),
                  if (_selectedMetode != null ||
                      (widget.total - _potonganPromo) <= 0)
                    _buildRincianTagihanDinamis(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          _buildBottomCTA(),
        ],
      ),
    );
  }

  Widget _buildFiturCard() {
    final pegProv = context.watch<PegawaiProvider>();
    final addonProv = context.watch<AddonProvider>();
    final koinProv = context.watch<KoinProvider>();
    final List addonEmployees = pegProv.employees
        .where((e) => e.type == 'addon')
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Add-on yang Dipilih',
              style: TextStyle(fontSize: 14, color: AppPalette.primary),
            ),
          ),
          ...widget.items.map((item) {
            bool isStaffSlot = item['id'] == 'AD-001';
            int itemKoin = (item['price'] / koinProv.pricePerCoin).toInt();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: AppPalette.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item['name'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2C3E50),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatRupiah(item['price']),
                            style: const TextStyle(fontSize: 13),
                          ),
                          if (!widget.isAktivasiOnly)
                            Text(
                              "$itemKoin Koin",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isStaffSlot)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(26, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Pilih Pegawai:",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: Colors.grey,
                              ),
                              hint: Text(
                                addonEmployees.isEmpty
                                    ? "Belum ada pegawai addon"
                                    : "Pilih Pegawai...",
                                style: const TextStyle(fontSize: 12),
                              ),
                              value: _internalTargetIds[item['id']],
                              items: addonEmployees.map<DropdownMenuItem<String>>((
                                p,
                              ) {
                                final active = addonProv.activeAddons.where(
                                  (a) =>
                                      a.targetId == p.id &&
                                      a.addonId == item['id'],
                                );
                                String status = active.isNotEmpty
                                    ? " (Aktif s/d ${DateFormat('dd/MM').format(active.first.berakhir)})"
                                    : " (Belum Aktif)";
                                return DropdownMenuItem<String>(
                                  value: p.id,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 16,
                                        color: AppPalette.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${p.nama.toUpperCase()}$status",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color.fromARGB(
                                            255,
                                            241,
                                            86,
                                            69,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: addonEmployees.isEmpty
                                  ? null
                                  : (val) => setState(
                                      () => _internalTargetIds[item['id']!] =
                                          val!,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAddonValueCard() {
    final addonProv = context.watch<AddonProvider>();
    final rows = widget.items.map((item) {
      final window = _resolveAddonWindow(
        addonProv: addonProv,
        addonId: item['id']?.toString() ?? '',
      );
      return _buildAddonValueRow(
        title: item['name']?.toString() ?? 'Add-on',
        startAt: window.$1,
        endAt: window.$2,
      );
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yang Anda dapatkan',
            style: TextStyle(fontSize: 14, color: AppPalette.primary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Aktif instan setelah koin dipotong. Masa aktif add-on mengikuti periode masing-masing item.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 14),
          ...rows,
        ],
      ),
    );
  }

  (DateTime, DateTime) _resolveAddonWindow({
    required AddonProvider addonProv,
    required String addonId,
  }) {
    final now = DateTime.now();
    final targetId = _internalTargetIds[addonId];
    ActiveAddon? active;

    for (final item in addonProv.activeAddons) {
      if (item.addonId != addonId) continue;
      if (targetId != null &&
          targetId.isNotEmpty &&
          item.targetId != targetId) {
        continue;
      }
      active = item;
      break;
    }

    final startAt = active != null && active.berakhir.isAfter(now)
        ? active.berakhir
        : now;
    final endAt = startAt.add(const Duration(days: 30));
    return (startAt, endAt);
  }

  Widget _buildAddonValueRow({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
  }) {
    final dateFmt = DateFormat('dd MMM yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildAddonDateInfo(
                  label: 'Mulai Aktif',
                  value: dateFmt.format(startAt),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAddonDateInfo(
                  label: 'Berakhir',
                  value: dateFmt.format(endAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddonDateInfo({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 12, color: Color(0xFF2C3E50)),
        ),
      ],
    );
  }

  Widget _buildVoucherInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: _appliedVoucher != null
              ? const Color(0xFF27AE60).withValues(alpha: 0.3)
              : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gunakan Kode Promo',
                style: TextStyle(fontSize: 13, color: Color(0xFF2C3E50)),
              ),
              if (_appliedVoucher != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    "TERPASANG",
                    style: TextStyle(color: Color(0xFF27AE60), fontSize: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _voucherController,
                  enabled: _appliedVoucher == null,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Ketik kode voucher...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: _appliedVoucher == null
                        ? const Color(0xFFF8F9FA)
                        : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isValidatingVoucher
                      ? null
                      : (_appliedVoucher == null
                            ? _applyVoucher
                            : () {
                                setState(() {
                                  _appliedVoucher = null;
                                  _potonganPromo = 0;
                                  _voucherController.clear();
                                  _selectedMetode = null; // Reset
                                });
                              }),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _appliedVoucher == null
                        ? AppPalette.primary
                        : const Color(0xFFE74C3C).withValues(alpha: 0.1),
                    foregroundColor: _appliedVoucher == null
                        ? Colors.white
                        : const Color(0xFFE74C3C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isValidatingVoucher
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _appliedVoucher == null ? 'TERAPKAN' : 'HAPUS',
                          style: const TextStyle(fontSize: 12),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreePromoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF27AE60).withValues(alpha: 0.1),
            const Color(0xFF2ECC71).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF27AE60),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.celebration_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "YAY! TRANSAKSI INI GRATIS",
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF27AE60),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "Voucher Anda menutupi seluruh biaya pesanan ini.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF2C3E50)),
          ),
        ],
      ),
    );
  }

  Widget _buildRincianTagihanDinamis() {
    final koinProv = context.watch<KoinProvider>();
    final appProv = context.watch<AppProvider>();
    const Color darkColor = Color(0xFF2C3E50);

    bool isKoin = _selectedMetode == 'KOIN';

    double hargaAsli = widget.isAktivasiOnly
        ? koinProv.activationFee
        : widget.total.toDouble();
    double totalRupiah = widget.total.toDouble() - _potonganPromo;
    double diskonAktivasi = hargaAsli - widget.total.toDouble();

    int koinTersedia = appProv.outlet?.koin ?? 0;
    int koinDibutuhkan = (totalRupiah / koinProv.pricePerCoin).toInt();
    bool saldoCukup = koinTersedia >= koinDibutuhkan;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isKoin && !saldoCukup
              ? Colors.red.shade200
              : const Color(0xFFEEEEEE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isKoin ? 'Rincian Koin' : 'Rincian Tagihan',
            style: const TextStyle(
              fontSize: 14,
              color: darkColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          if (isKoin) ...[
            _buildRowTagihan(
              'Koin Tersedia',
              koinTersedia.toString(),
              color: darkColor,
            ),
            _buildRowTagihan(
              'Koin Dibutuhkan',
              '- $koinDibutuhkan',
              color: Colors.red,
            ),
            const Divider(height: 32, color: Color(0xFFF1F3F5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sisa Saldo Koin',
                  style: TextStyle(fontSize: 13, color: darkColor),
                ),
                Text(
                  (koinTersedia - koinDibutuhkan).toString(),
                  style: TextStyle(
                    fontSize: 20,
                    color: saldoCukup ? const Color(0xFF27AE60) : Colors.red,
                  ),
                ),
              ],
            ),
            if (!saldoCukup)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "* Saldo koin tidak cukup untuk transaksi ini",
                  style: TextStyle(color: Colors.red.shade700, fontSize: 10),
                ),
              ),
          ] else ...[
            _buildRowTagihan('Harga Layanan', _formatRupiah(hargaAsli)),
            if (diskonAktivasi > 0)
              _buildRowTagihan(
                'Diskon Aktivasi',
                '- ${_formatRupiah(diskonAktivasi)}',
                color: const Color(0xFF27AE60),
              ),
            if (_potonganPromo > 0)
              _buildRowTagihan(
                'Potongan Promo',
                '- ${_formatRupiah(_potonganPromo)}',
                color: const Color(0xFF27AE60),
                isBold: true,
              ),
            _buildRowTagihan(
              'Biaya Transaksi',
              'Gratis',
              color: const Color(0xFF27AE60),
            ),
            const Divider(height: 32, color: Color(0xFFF1F3F5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Pembayaran',
                  style: TextStyle(fontSize: 13, color: darkColor),
                ),
                Text(
                  _formatRupiah(totalRupiah),
                  style: const TextStyle(
                    fontSize: 22,
                    color: AppPalette.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRowTagihan(
    String label,
    String value, {
    Color color = const Color(0xFF2C3E50),
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          Text(value, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildMethodItem(Map<String, dynamic> method) {
    bool isSelected = _selectedMetode == method['value'];
    return GestureDetector(
      onTap: () => setState(() => _selectedMetode = method['value']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppPalette.primary : const Color(0xFFEEEEEE),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              method['icon'],
              color: isSelected ? AppPalette.primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                method['label'],
                style: TextStyle(color: const Color(0xFF2C3E50)),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppPalette.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttentionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFEAA7)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppPalette.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isAktivasiOnly
                  ? 'Aktivasi outlet bersifat permanen.'
                  : 'Pembelian add-on dibayar instan memakai koin outlet.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF916400)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA() {
    final appProv = context.watch<AppProvider>();
    final koinProv = context.watch<KoinProvider>();
    final bool isAddonOnly = !widget.isAktivasiOnly;
    final bool isKoin = _selectedMetode == 'KOIN';
    final int koinTersedia = appProv.outlet?.koin ?? 0;
    final int koinDibutuhkan = koinProv.pricePerCoin <= 0
        ? 0
        : ((widget.total.toDouble() - _potonganPromo) / koinProv.pricePerCoin)
              .toInt();
    final bool saldoKoinCukup = koinTersedia >= koinDibutuhkan;
    final bool shouldTopup = isAddonOnly && isKoin && !saldoKoinCukup;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: (widget.total - _potonganPromo) <= 0
                  ? [const Color(0xFF27AE60), const Color(0xFF2ECC71)]
                  : [AppPalette.primary, AppPalette.primaryWarm],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (widget.total - _potonganPromo) <= 0
                    ? const Color(0xFF27AE60).withValues(alpha: 0.3)
                    : AppPalette.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed:
                ((_selectedMetode == null && widget.isAktivasiOnly) ||
                    _isLoading)
                ? null
                : (shouldTopup
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TopupKoinScreen(),
                            ),
                          );
                        }
                      : _handlePayment),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: AppCircularLoader(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    shouldTopup
                        ? 'TOP UP KOIN'
                        : (_isAddonOnly
                              ? 'AKTIFKAN ADD-ON'
                              : ((widget.total - _potonganPromo) <= 0
                                    ? 'AKTIFKAN SEKARANG'
                                    : 'BAYAR SEKARANG')),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEB2B2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.person_add_disabled_rounded, color: Color(0xFFE53E3E)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Pilih Pegawai!",
                  style: TextStyle(fontSize: 12, color: Color(0xFFC53030)),
                ),
                Text(
                  "Anda belum memilih pegawai untuk Slot Tambahan.",
                  style: TextStyle(fontSize: 10, color: Color(0xFF9B2C2C)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
