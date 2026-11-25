import 'package:ayocucinew/data/models/antar_jemput_model.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class JemputAntarWidget extends StatefulWidget {
  final void Function(JemputAntarData data)? onChanged;
  final JemputAntarData? initialData;
  final bool lockDeliveryFee;
  final bool? startExpanded;
  final VoidCallback? onUnauthorizedFeeEdit;

  const JemputAntarWidget({
    super.key,
    this.onChanged,
    this.initialData,
    this.lockDeliveryFee = false,
    this.startExpanded,
    this.onUnauthorizedFeeEdit,
  });

  @override
  State<JemputAntarWidget> createState() => _JemputAntarWidgetState();
}

class _JemputAntarWidgetState extends State<JemputAntarWidget> {
  late JemputAntarData _data;
  late JemputAntarData _initialData;
  late bool _isExpanded;

  final _jemputAlamatCtrl = TextEditingController();
  final _jemputBiayaCtrl = TextEditingController();
  final _antarAlamatCtrl = TextEditingController();
  final _antarBiayaCtrl = TextEditingController();

  static const _primaryColor = AppPalette.primary;
  static const _animDuration = Duration(milliseconds: 250);
  static const _animCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    _data = widget.initialData ?? const JemputAntarData();
    _initialData = _data;
    _isExpanded =
        widget.startExpanded ?? (_data.jemputEnabled || _data.antarEnabled);
    _syncControllersFromData();
  }

  // FIX: deteksi perubahan initialData dari luar (misal setelah prefill pelunasan)
  @override
  void didUpdateWidget(JemputAntarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldData = oldWidget.initialData;
    final newData = widget.initialData;

    if (newData == null) return;

    // Hanya sync jika data benar-benar berubah (bukan hasil edit user sendiri)
    final dataChanged =
        oldData?.jemputEnabled != newData.jemputEnabled ||
        oldData?.jemputAlamat != newData.jemputAlamat ||
        oldData?.jemputBiaya != newData.jemputBiaya ||
        oldData?.antarEnabled != newData.antarEnabled ||
        oldData?.antarAlamat != newData.antarAlamat ||
        oldData?.antarBiaya != newData.antarBiaya;

    if (dataChanged) {
      setState(() {
        _data = newData;
        _initialData = newData;
        if (widget.startExpanded == null &&
            (_data.jemputEnabled || _data.antarEnabled)) {
          _isExpanded = true;
        }
        _syncControllersFromData();
      });
    }
  }

  void _syncControllersFromData() {
    _jemputAlamatCtrl.text = _data.jemputAlamat;
    _jemputBiayaCtrl.text = _data.jemputBiaya > 0
        ? CurrencyFormatter.formatNumberToInput(_data.jemputBiaya)
        : '';
    _antarAlamatCtrl.text = _data.antarAlamat;
    _antarBiayaCtrl.text = _data.antarBiaya > 0
        ? CurrencyFormatter.formatNumberToInput(_data.antarBiaya)
        : '';
  }

  void _notify() => widget.onChanged?.call(_data);

  bool _isProtectedFeeChange(JemputAntarData nextData) {
    if (!widget.lockDeliveryFee) return false;
    return (nextData.jemputBiaya - _initialData.jemputBiaya).abs() > 0.01 ||
        (nextData.antarBiaya - _initialData.antarBiaya).abs() > 0.01;
  }

  bool _applyData(JemputAntarData nextData, {bool syncControllers = false}) {
    if (_isProtectedFeeChange(nextData)) {
      widget.onUnauthorizedFeeEdit?.call();
      _syncControllersFromData();
      return false;
    }

    setState(() {
      _data = nextData;
      if (syncControllers) _syncControllersFromData();
    });
    _notify();
    return true;
  }

  void _toggleJemput(bool val) {
    final nextData = _data.copyWith(
      jemputEnabled: val,
      jemputAlamat: val ? _data.jemputAlamat : '',
      jemputBiaya: val ? _data.jemputBiaya : 0,
    );
    _applyData(nextData, syncControllers: true);
  }

  void _toggleAntar(bool val) {
    final nextData = _data.copyWith(
      antarEnabled: val,
      antarAlamat: val ? _data.antarAlamat : '',
      antarBiaya: val ? _data.antarBiaya : 0,
    );
    _applyData(nextData, syncControllers: true);
  }

  @override
  void dispose() {
    _jemputAlamatCtrl.dispose();
    _jemputBiayaCtrl.dispose();
    _antarAlamatCtrl.dispose();
    _antarBiayaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          ClipRect(
            child: AnimatedSize(
              duration: _animDuration,
              curve: _animCurve,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        if (widget.lockDeliveryFee) ...[
                          _buildLockedFeeNotice(),
                          const SizedBox(height: 12),
                        ],
                        _buildServiceRow(
                          icon: Icons.south_west_rounded,
                          iconColor: _primaryColor,
                          iconBg: AppPalette.primarySoft,
                          label: 'Jemput',
                          subtitle: 'Ambil dari alamat pelanggan',
                          enabled: _data.jemputEnabled,
                          onToggle: _toggleJemput,
                        ),
                        ClipRect(
                          child: AnimatedSize(
                            duration: _animDuration,
                            curve: _animCurve,
                            alignment: Alignment.topCenter,
                            child: _data.jemputEnabled
                                ? _buildAddressForm(
                                    alamatCtrl: _jemputAlamatCtrl,
                                    biayaCtrl: _jemputBiayaCtrl,
                                    onAlamatChanged: (v) {
                                      _data = _data.copyWith(jemputAlamat: v);
                                      _notify();
                                    },
                                    onBiayaChanged: (v) {
                                      final nextData = _data.copyWith(
                                        jemputBiaya:
                                            CurrencyFormatter.parseRupiahToDouble(
                                              v,
                                            ),
                                      );
                                      _applyData(
                                        nextData,
                                        syncControllers: _isProtectedFeeChange(
                                          nextData,
                                        ),
                                      );
                                    },
                                    lockFee: widget.lockDeliveryFee,
                                  )
                                : const SizedBox(
                                    width: double.infinity,
                                    height: 0,
                                  ),
                          ),
                        ),
                        if (_data.jemputEnabled) const SizedBox(height: 4),
                        const Divider(height: 24),
                        _buildServiceRow(
                          icon: Icons.north_east_rounded,
                          iconColor: _primaryColor,
                          iconBg: AppPalette.primarySoft,
                          label: 'Antar',
                          subtitle: 'Kirim ke alamat pelanggan',
                          enabled: _data.antarEnabled,
                          onToggle: _toggleAntar,
                        ),
                        ClipRect(
                          child: AnimatedSize(
                            duration: _animDuration,
                            curve: _animCurve,
                            alignment: Alignment.topCenter,
                            child: _data.antarEnabled
                                ? _buildAddressForm(
                                    alamatCtrl: _antarAlamatCtrl,
                                    biayaCtrl: _antarBiayaCtrl,
                                    onAlamatChanged: (v) {
                                      _data = _data.copyWith(antarAlamat: v);
                                      _notify();
                                    },
                                    onBiayaChanged: (v) {
                                      final nextData = _data.copyWith(
                                        antarBiaya:
                                            CurrencyFormatter.parseRupiahToDouble(
                                              v,
                                            ),
                                      );
                                      _applyData(
                                        nextData,
                                        syncControllers: _isProtectedFeeChange(
                                          nextData,
                                        ),
                                      );
                                    },
                                    lockFee: widget.lockDeliveryFee,
                                  )
                                : const SizedBox(
                                    width: double.infinity,
                                    height: 0,
                                  ),
                          ),
                        ),
                        if (_data.jemputEnabled || _data.antarEnabled) ...[
                          const Divider(height: 24),
                          _buildTotalBiaya(),
                        ],
                      ],
                    )
                  : const SizedBox(width: double.infinity, height: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final totalBiaya = _data.totalBiaya;
    final hasDeliveryFee = totalBiaya > 0;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_rounded,
            color: _primaryColor,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            'Jemput & Antar',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderBadge(
            hasDeliveryFee
                ? CurrencyFormatter.formatToRupiah(totalBiaya)
                : 'Opsional',
            accent: hasDeliveryFee,
          ),
          const Spacer(),
          AnimatedRotation(
            turns: _isExpanded ? 0.5 : 0,
            duration: _animDuration,
            curve: _animCurve,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadge(String label, {required bool accent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent ? AppPalette.primarySoft : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: accent ? _primaryColor : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildLockedFeeNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.primaryPale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.primaryBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: _primaryColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Biaya antar/jemput perlu otorisasi role untuk diubah.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onToggle,
          activeThumbColor: _primaryColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildAddressForm({
    required TextEditingController alamatCtrl,
    required TextEditingController biayaCtrl,
    required ValueChanged<String> onAlamatChanged,
    required ValueChanged<String> onBiayaChanged,
    bool lockFee = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          _buildTextField(
            controller: alamatCtrl,
            hint: 'Alamat',
            icon: Icons.location_on_outlined,
            onChanged: onAlamatChanged,
            keyboardType: TextInputType.streetAddress,
          ),
          const SizedBox(height: 10),
          _buildCurrencyField(
            controller: biayaCtrl,
            hint: 'Biaya (Rp)',
            icon: Icons.receipt_outlined,
            onChanged: onBiayaChanged,
            readOnly: lockFee,
            onTap: lockFee ? widget.onUnauthorizedFeeEdit : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        textCapitalization: TextCapitalization.words,
        maxLength: 150,
        maxLines: null,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildCurrencyField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required ValueChanged<String> onChanged,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? AppPalette.primarySoft : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: readOnly ? AppPalette.primaryBorder : Colors.grey.shade200,
        ),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        keyboardType: TextInputType.number,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        onChanged: (raw) {
          final formatted = CurrencyFormatter.formatInputToRupiah(raw);
          controller.value = TextEditingValue(
            text: formatted,
            selection: TextSelection.collapsed(offset: formatted.length),
          );
          onChanged(formatted);
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBiaya() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Total Biaya Antar/Jemput',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          CurrencyFormatter.formatToRupiah(_data.totalBiaya),
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
