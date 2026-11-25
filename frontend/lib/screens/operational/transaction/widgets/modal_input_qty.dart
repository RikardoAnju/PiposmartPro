import 'package:ayocucinew/core/theme/app_font.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/item_model.dart';
import '../../../../providers/item_provider.dart';
import '../../../../providers/transaction_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class SelectedItemEntry {
  final String id;
  final String nama;
  int qty;

  SelectedItemEntry({required this.id, required this.nama, this.qty = 1});
}

class ModalInputQty extends StatefulWidget {
  final String serviceName;
  final double price;
  final String unit;
  final double? minimalOrder;
  final bool hasExistingService;
  final Function(double, List<SelectedItemEntry>, bool) onConfirm;

  const ModalInputQty({
    super.key,
    required this.serviceName,
    required this.price,
    required this.unit,
    this.minimalOrder,
    this.hasExistingService = false,
    required this.onConfirm,
  });

  @override
  State<ModalInputQty> createState() => _ModalInputQtyState();
}

class _ModalInputQtyState extends State<ModalInputQty> {
  static const double _maxQty = 999999.9999;
  static const int _maxIntegerDigits = 6;
  static const int _maxDecimalDigits = 4;

  late final TextEditingController _qtyController;
  final TextEditingController _itemSearchController = TextEditingController();
  final Map<String, TextEditingController> _itemControllers = {};

  // Kalkulator dimensi (khusus satuan berbasis luas, mis. karpet per m²)
  final TextEditingController _panjangController = TextEditingController();
  final TextEditingController _lebarController = TextEditingController();
  bool _dimensionExpanded = false;

  List<ItemLaundry> _allItems = [];
  List<ItemLaundry> _filteredItems = [];
  final Map<String, SelectedItemEntry> _selectedEntries = {};
  bool _itemsExpanded = false;
  bool _mergeDuplicate = true;

  static const _primary = AppPalette.primary;
  static const _primaryLight = AppPalette.primarySoft;
  static const _textDark = Color(0xFF1A1A2E);
  static const _textMuted = Color(0xFF9E9E9E);
  static const _surface = Color(0xFFF7F7F7);
  static const _border = Color(0xFFEEEEEE);

  bool get _isWholeNumberUnit {
    final unit = widget.unit.trim().toLowerCase();
    return unit == 'pcs' ||
        unit == 'pcs.' ||
        unit == 'koin' ||
        unit == 'coin' ||
        unit == 'piece' ||
        unit == 'item';
  }

  // Satuan berbasis luas: input dimensi (P × L dalam cm) dikonversi ke m².
  bool get _isAreaUnit {
    final unit = widget.unit.trim().toLowerCase();
    return unit == 'm' || unit == 'm2' || unit == 'm²';
  }

  // Label satuan untuk ditampilkan ke user. Satuan luas selalu tampil "m²"
  // walau tersimpan sebagai "m" di data.
  String get _unitLabel => TransactionProvider.displayUnit(widget.unit);

  @override
  void initState() {
    super.initState();
    final initialQty = widget.minimalOrder != null && widget.minimalOrder! > 1
        ? widget.minimalOrder!
        : 1.0;
    final normalizedInitialQty = _isWholeNumberUnit
        ? initialQty.roundToDouble()
        : initialQty;
    final initialText = _formatQtyValue(normalizedInitialQty);
    _qtyController = TextEditingController(text: initialText);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadItems());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _panjangController.dispose();
    _lebarController.dispose();
    _itemSearchController.dispose();
    for (var controller in _itemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadItems() async {
    final itemProvider = context.read<ItemProvider>();
    await itemProvider.loadItemsIfEmpty();
    if (!mounted) return;

    final trxProvider = context.read<TransactionProvider>();
    setState(() {
      _allItems = itemProvider.activeItems;
      _filteredItems = _allItems;

      final existingItems = trxProvider.getOptionalItemsForService(
        widget.serviceName,
      );
      for (final existing in existingItems) {
        _selectedEntries[existing.id] = SelectedItemEntry(
          id: existing.id,
          nama: existing.name,
          qty: existing.qty,
        );
        _itemControllers[existing.id] = TextEditingController(
          text: '${existing.qty}',
        );
      }
    });
  }

  void _filterItems(String query) {
    setState(() {
      _filteredItems = query.isEmpty
          ? _allItems
          : _allItems
                .where(
                  (i) => i.nama.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
    });
  }

  void _updateServiceQty(double delta) {
    final current =
        double.tryParse(_normalizeQtyInput(_qtyController.text)) ?? 0;
    final steppedDelta = _isWholeNumberUnit ? delta.sign : delta;
    final maxQty = _isWholeNumberUnit ? _maxQty.floorToDouble() : _maxQty;
    final rawNewVal = (current + steppedDelta).clamp(0, maxQty).toDouble();
    final newVal = _isWholeNumberUnit ? rawNewVal.roundToDouble() : rawNewVal;
    final textVal = _formatQtyValue(newVal);

    setState(() {
      _qtyController.text = textVal;
      _qtyController.selection = TextSelection.collapsed(
        offset: textVal.length,
      );
    });
  }

  // Hitung luas dari dimensi cm → m² dan isikan ke kolom jumlah.
  void _recalcFromDimensions() {
    final panjangCm =
        double.tryParse(_normalizeQtyInput(_panjangController.text)) ?? 0;
    final lebarCm =
        double.tryParse(_normalizeQtyInput(_lebarController.text)) ?? 0;

    if (panjangCm <= 0 || lebarCm <= 0) return;

    // cm → m, lalu P × L = luas (m²). Dibulatkan ke 4 desimal sesuai batas qty.
    final luas = (panjangCm / 100) * (lebarCm / 100);
    final clamped = luas.clamp(0, _maxQty).toDouble();
    final textVal = _formatQtyValue(
      double.parse(clamped.toStringAsFixed(_maxDecimalDigits)),
    );

    setState(() {
      _qtyController.text = textVal;
      _qtyController.selection = TextSelection.collapsed(
        offset: textVal.length,
      );
    });
  }

  void _toggleItem(ItemLaundry item) {
    setState(() {
      if (_selectedEntries.containsKey(item.id)) {
        _selectedEntries.remove(item.id);
        _itemControllers.remove(item.id)?.dispose();
      } else {
        _selectedEntries[item.id] = SelectedItemEntry(
          id: item.id,
          nama: item.nama,
          qty: 1,
        );
        _itemControllers[item.id] = TextEditingController(text: '1');
      }
    });
  }

  void _updateItemQty(String itemId, int delta) {
    final entry = _selectedEntries[itemId];
    if (entry == null) return;

    final newQty = entry.qty + delta;
    if (newQty <= 0) {
      setState(() {
        _selectedEntries.remove(itemId);
        _itemControllers.remove(itemId)?.dispose();
      });
    } else {
      setState(() {
        entry.qty = newQty;
        final ctrl = _itemControllers[itemId];
        if (ctrl != null) {
          ctrl.text = '$newQty';
          ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
        }
      });
    }
  }

  String _formatQtyValue(double value) {
    if (_isWholeNumberUnit) return value.round().toString();
    if (value % 1 == 0) return value.toStringAsFixed(0);
    return value
        .toStringAsFixed(_maxDecimalDigits)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _normalizeQtyInput(String text) {
    return text.replaceAll(',', '.');
  }

  bool _isValidQtyText(String text) {
    final normalizedText = _normalizeQtyInput(text);
    if (text.isEmpty) return true;
    if (_isWholeNumberUnit) {
      return RegExp('^\\d{0,$_maxIntegerDigits}\$').hasMatch(normalizedText);
    }
    return RegExp(
      '^\\d{0,$_maxIntegerDigits}(\\.\\d{0,$_maxDecimalDigits})?\$',
    ).hasMatch(normalizedText);
  }

  void _handleConfirm() {
    final rawQty =
        double.tryParse(_normalizeQtyInput(_qtyController.text)) ?? 0;
    final qty = _isWholeNumberUnit ? rawQty.roundToDouble() : rawQty;
    if (qty <= 0) return;
    if (qty > _maxQty) {
      CustomToast.show(
        context,
        message:
            'Maksimal jumlah adalah ${_formatQtyValue(_isWholeNumberUnit ? _maxQty.floorToDouble() : _maxQty)} $_unitLabel',
        isError: true,
      );
      return;
    }
    final minimum = widget.minimalOrder;
    if (minimum != null && qty < minimum) {
      CustomToast.show(
        context,
        message:
            'Minimal order ${widget.serviceName} adalah ${minimum.toStringAsFixed(minimum % 1 == 0 ? 0 : 1)} $_unitLabel',
        isError: true,
      );
      return;
    }

    widget.onConfirm(qty, _selectedEntries.values.toList(), _mergeDuplicate);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildQtyStepper(),
              if (widget.minimalOrder != null) _buildMinimumOrderHint(),
              _buildDecimalTip(),
              if (_isAreaUnit) _buildDimensionCalculator(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return SizeTransition(
                    sizeFactor: animation,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: widget.hasExistingService
                    ? _buildDuplicateModeToggle()
                    : const SizedBox.shrink(),
              ),
              // Item Cucian tidak relevan untuk satuan luas (mis. karpet per m²).
              if (!_isAreaUnit) ...[
                const Divider(height: 1, color: _border),
                _buildItemHeader(),
                if (_itemsExpanded) ...[
                  _buildSearchField(),
                  Expanded(child: _buildItemList()),
                ] else
                  _buildCollapsedItemHint(),
              ],
              const Divider(height: 1, color: _border),
              _buildConfirmButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      // Tambahkan padding atas agar tidak terlalu mepet dengan ujung modal
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Column(
        children: [
          // 1. Drag Handle (Garis kecil di atas) dipisah agar tidak mengganggu layout
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16), // Jarak yang pas antara garis dan judul
          // 2. Baris Judul & Tombol Close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Judul di Tengah
                Column(
                  children: [
                    const Text(
                      'Masukkan Jumlah',
                      style: TextStyle(
                        fontWeight: AppFont.w800,
                        fontSize: 17,
                        color: _textDark,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.serviceName} · $_unitLabel',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: AppFont.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                // Tombol Close persis di Kanan Tengah
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: _textDark,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _surface,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimumOrderHint() {
    final minimum = widget.minimalOrder!;
    final formatted = minimum % 1 == 0
        ? minimum.toStringAsFixed(0)
        : minimum.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppPalette.primaryBorder),
      ),
      child: Text(
        'Minimal order: $formatted $_unitLabel',
        style: const TextStyle(
          color: _primary,
          fontWeight: AppFont.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildQtyStepper() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            _buildStepButton(Icons.remove_rounded, () => _updateServiceQty(-1)),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IntrinsicWidth(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: AppFont.w800,
                        color: _primary,
                      ),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final normalizedText = _normalizeQtyInput(
                            newValue.text,
                          );
                          if (!_isValidQtyText(normalizedText)) {
                            return oldValue;
                          }
                          return newValue.copyWith(
                            text: normalizedText,
                            selection: TextSelection.collapsed(
                              offset: normalizedText.length,
                            ),
                          );
                        }),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: false,
                        fillColor: Colors.transparent,
                        isDense: true,
                        isCollapsed: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _unitLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: AppFont.w600,
                      color: _primary,
                    ),
                  ),
                ],
              ),
            ),
            _buildStepButton(Icons.add_rounded, () => _updateServiceQty(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildDecimalTip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 12, color: _textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _isWholeNumberUnit
                  ? 'Bilangan bulat • Maks ${_maxQty.floor()}'
                  : 'Desimal: . atau , • Maks ${_formatQtyValue(_maxQty)}',
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: _textMuted,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDimensionCalculator() {
    final panjangCm =
        double.tryParse(_normalizeQtyInput(_panjangController.text)) ?? 0;
    final lebarCm =
        double.tryParse(_normalizeQtyInput(_lebarController.text)) ?? 0;
    final hasResult = panjangCm > 0 && lebarCm > 0;
    final luas = (panjangCm / 100) * (lebarCm / 100);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () =>
                  setState(() => _dimensionExpanded = !_dimensionExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.straighten_rounded,
                      size: 18,
                      color: _primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Hitung dari ukuran (P × L)',
                        style: TextStyle(
                          fontWeight: AppFont.w700,
                          fontSize: 13,
                          color: _textDark,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _dimensionExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: _textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: !_dimensionExpanded
                  ? const SizedBox.shrink()
                  : Padding(
                      key: const ValueKey('dimension-fields'),
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: _buildDimensionField(
                                  _panjangController,
                                  'Panjang',
                                ),
                              ),
                              const Padding(
                                // Sejajarkan "×" dengan tengah kotak input (di bawah label).
                                padding: EdgeInsets.fromLTRB(10, 0, 10, 12),
                                child: Text(
                                  '×',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: AppFont.w800,
                                    color: _textMuted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _buildDimensionField(
                                  _lebarController,
                                  'Lebar',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: hasResult ? _primaryLight : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border),
                            ),
                            child: Text(
                              hasResult
                                  ? 'Luas = ${_formatQtyValue(double.parse(luas.toStringAsFixed(_maxDecimalDigits)))} $_unitLabel'
                                  : 'Isi panjang & lebar (cm) untuk menghitung otomatis',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: AppFont.w700,
                                color: hasResult ? _primary : _textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionField(TextEditingController controller, String label) {
    // Label diletakkan sebagai teks di atas field (bukan floating label bawaan)
    // supaya tidak ter-clip oleh tepi kartu kalkulator.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: AppFont.w600,
              color: _textMuted,
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          onChanged: (_) => _recalcFromDimensions(),
          inputFormatters: [
            TextInputFormatter.withFunction((oldValue, newValue) {
              final normalized = _normalizeQtyInput(newValue.text);
              if (normalized.isEmpty) {
                return newValue.copyWith(text: normalized);
              }
              // Maks 4 digit cm + 2 desimal (mis. 9999.99 cm = ~100 m).
              if (!RegExp(r'^\d{0,4}(\.\d{0,2})?$').hasMatch(normalized)) {
                return oldValue;
              }
              return newValue.copyWith(
                text: normalized,
                selection: TextSelection.collapsed(offset: normalized.length),
              );
            }),
          ],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: AppFont.w800,
            color: _textDark,
          ),
          decoration: InputDecoration(
            isDense: true,
            hintText: '0',
            hintStyle: const TextStyle(
              fontSize: 18,
              fontWeight: AppFont.w800,
              color: _border,
            ),
            suffixText: 'cm',
            suffixStyle: const TextStyle(
              fontSize: 13,
              fontWeight: AppFont.w700,
              color: _textMuted,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _primary, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDuplicateModeToggle() {
    return Padding(
      key: const ValueKey('duplicate-mode-toggle'),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double segmentWidth = constraints.maxWidth / 2;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: _mergeDuplicate ? 0 : segmentWidth,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!_mergeDuplicate) {
                            setState(() => _mergeDuplicate = true);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFont.w800,
                              color: _mergeDuplicate ? _primary : _textMuted,
                            ),
                            child: const Text('Gabungkan'),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_mergeDuplicate) {
                            setState(() => _mergeDuplicate = false);
                          }
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: AppFont.w800,
                              color: !_mergeDuplicate ? _primary : _textMuted,
                            ),
                            child: const Text('Pisah'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemHeader() {
    return InkWell(
      onTap: () => setState(() => _itemsExpanded = !_itemsExpanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.checkroom_rounded,
                size: 18,
                color: _primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Item Cucian',
              style: TextStyle(
                fontWeight: AppFont.w800,
                fontSize: 14,
                color: _textDark,
              ),
            ),
            const SizedBox(width: 8),
            if (_selectedEntries.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_selectedEntries.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ),
            const Spacer(),
            const Text(
              'Opsional',
              style: TextStyle(
                color: _textMuted,
                fontSize: 11,
                fontWeight: AppFont.w500,
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _itemsExpanded ? 0 : 0.5,
              duration: const Duration(milliseconds: 180),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 20,
                color: _textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedItemHint() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFBFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F1F3)),
        ),
        child: Text(
          _selectedEntries.isEmpty
              ? 'Hitung item cucian secara detail'
              : '${_selectedEntries.length} item cucian dipilih',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontWeight: AppFont.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: AppSearchField(
        controller: _itemSearchController,
        onChanged: _filterItems,
        hintText: 'Cari item...',
        height: 44,
      ),
    );
  }

  Widget _buildItemList() {
    final isLoading = context.watch<ItemProvider>().isLoading;
    if (isLoading) {
      return const Center(child: AppCircularLoader(color: _primary));
    }
    if (_filteredItems.isEmpty) {
      return const Center(
        child: Text('Tidak ditemukan', style: TextStyle(color: _textMuted)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final entry = _selectedEntries[item.id];
        return _buildItemRow(item, entry != null, entry);
      },
    );
  }

  Widget _buildItemRow(
    ItemLaundry item,
    bool isSelected,
    SelectedItemEntry? entry,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppPalette.primarySoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? _primary.withValues(alpha: 0.28)
              : const Color(0xFFEFF1F3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isSelected ? 0.04 : 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _toggleItem(item),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isSelected ? _primary : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? _primary : Colors.grey.shade400,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isSelected
                      ? _primary.withValues(alpha: 0.08)
                      : const Color(0xFFF6F7F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.checkroom_rounded,
                  color: isSelected ? _primary : const Color(0xFF7BC7BE),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nama Item',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _textMuted,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _toTitle(item.nama),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? AppFont.w800 : AppFont.w700,
                        color: isSelected ? _primary : _textDark,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected && entry != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primary.withValues(alpha: 0.16)),
                  ),
                  child: Row(
                    children: [
                      _buildMiniButton(
                        Icons.remove_rounded,
                        () => _updateItemQty(item.id, -1),
                      ),
                      SizedBox(
                        width: 36,
                        child: TextField(
                          controller: _itemControllers[item.id],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          textAlignVertical: TextAlignVertical.center,
                          style: const TextStyle(
                            fontWeight: AppFont.w800,
                            fontSize: 14,
                            color: _textDark,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            // TIDAK ADA setState di sini agar kursor tidak loncat/ganda
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed > 0) {
                              entry.qty = parsed;
                            }
                          },
                        ),
                      ),
                      _buildMiniButton(
                        Icons.add_rounded,
                        () => _updateItemQty(item.id, 1),
                      ),
                    ],
                  ),
                ),
              if (!isSelected)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300),
                    color: Colors.white,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primary),
        ),
      ),
    );
  }

  Widget _buildMiniButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: _primary),
      ),
    );
  }

  String _toTitle(String value) {
    final words = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  Widget _buildConfirmButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Text(
            'TAMBAHKAN KE KERANJANG',
            style: TextStyle(fontWeight: AppFont.w700),
          ),
        ),
      ),
    );
  }
}
