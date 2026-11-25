import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/data/models/service_model.dart';
import 'package:ayocucinew/core/utils/layanan_icon_resolver.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/service_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AddProductScreen extends StatefulWidget {
  final ServiceProduct? existingProduct;
  const AddProductScreen({super.key, this.existingProduct});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();
  final _minimumOrderController = TextEditingController();

  String _selectedUnit = "Pilih salah satu";
  String _selectedDurationUnit = "Hari";
  String _selectedIcon = defaultLayananAssetFileName;
  bool _hasMinimumOrder = false;

  final Map<String, int> _priorityOptions = {
    "Normal": 0,
    "Sedang": 10,
    "Tinggi / Ekspres": 20,
  };
  String _selectedPriorityLabel = "Normal";

  // ==================== ICON LIST ====================
  static const List<String> iconList = layananIconAssetNames;

  @override
  void initState() {
    super.initState();
    if (widget.existingProduct != null) {
      _initializeFromExisting();
    } else {
      _selectedIcon = iconList.first;
    }
  }

  void _initializeFromExisting() {
    final p = widget.existingProduct!;
    _nameController.text = p.name;
    _priceController.text = CurrencyFormatter.formatNumberToInput(p.price);
    _durationController.text = p.duration.toString();
    _hasMinimumOrder = p.minimalOrder != null;
    if (p.minimalOrder != null) {
      final value = p.minimalOrder!;
      _minimumOrderController.text = value % 1 == 0
          ? value.toStringAsFixed(0)
          : value.toString();
    }
    _selectedUnit = _displayUnitLabel(p.unit);
    _selectedDurationUnit = p.durationUnit;
    _selectedIcon =
        resolveLayananIconFileName(p.iconPath) ?? defaultLayananAssetFileName;

    // Set selected priority label based on integer value
    _selectedPriorityLabel = _priorityOptions.entries
        .firstWhere(
          (e) => e.value == p.priority,
          orElse: () => const MapEntry("Normal", 0),
        )
        .key;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _minimumOrderController.dispose();
    super.dispose();
  }

  String _displayUnitLabel(String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return "Kilogram (kg)";
      case 'pcs':
        return "Pieces (pcs)";
      case 'm':
      case 'm2':
      case 'm²':
        return "Meter Persegi (m²)";
      case 'koin':
        return "Koin (koin)";
      default:
        return unit;
    }
  }

  void _showPicker({
    required String title,
    required List<String> options,
    required String currentValue,
    required Function(String) onSelected,
  }) {
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.black),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: options
                    .map(
                      (option) => Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () {
                            onSelected(option);
                            Navigator.pop(context);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            child: Text(
                              option,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: currentValue == option
                                    ? AppPalette.primary
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  void _showIconPicker() {
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Pilih Icon Produk",
              style: TextStyle(fontSize: 18, color: Colors.black),
            ),
            const SizedBox(height: 25),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: iconList.length,
              itemBuilder: (context, index) {
                final icon = iconList[index];
                final isSelected = _selectedIcon == icon;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIcon = icon);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF1F7FF)
                          : const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppPalette.primary
                            : Colors.grey.shade200,
                        width: isSelected ? 2.5 : 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppPalette.primary.withValues(alpha: 0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: _buildProductImage(icon),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.existingProduct != null ? "Edit Produk" : "Tambah Produk",
          style: const TextStyle(fontSize: 18, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Nama Layanan"),
              _buildNameSection(),
              const SizedBox(height: 14),
              _buildLabel("Satuan"),
              _buildTriggerBtn(
                value: _selectedUnit,
                onTap: () => _showPicker(
                  title: "Pilih Satuan",
                  options: [
                    "Kilogram (kg)",
                    "Pieces (pcs)",
                    "Meter Persegi (m²)",
                    "Koin (koin)",
                  ],
                  currentValue: _selectedUnit,
                  onSelected: (val) => setState(() => _selectedUnit = val),
                ),
              ),
              const SizedBox(height: 14),
              _buildLabel(_priceLabel),
              _buildCurrencyInput(_priceController, "Rp 0"),
              const SizedBox(height: 14),
              _buildDurationSection(),
              const SizedBox(height: 14),
              _buildLabel("Prioritas Pengerjaan"),
              _buildTriggerBtn(
                value: _selectedPriorityLabel,
                onTap: () => _showPicker(
                  title: "Pilih Prioritas",
                  options: _priorityOptions.keys.toList(),
                  currentValue: _selectedPriorityLabel,
                  onSelected: (val) =>
                      setState(() => _selectedPriorityLabel = val),
                ),
              ),
              const SizedBox(height: 14),
              _buildLabel("Minimal Order"),
              _buildMinimumOrderSection(),
              const SizedBox(height: 24),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF2C3E50),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildNameSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildCustomInput(
            _nameController,
            "Contoh: Reguler, Express, Kilat",
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: _showIconPicker,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: _buildProductImage(_selectedIcon),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTriggerBtn({
    required String value,
    required VoidCallback onTap,
  }) {
    final isPlaceholder = value.contains("Pilih");

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isPlaceholder ? Colors.black38 : Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isPlaceholder ? Colors.grey.shade400 : AppPalette.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomInput(
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 14, color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildCurrencyInput(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 15, color: AppPalette.primary),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (v) {
        String formatted = CurrencyFormatter.formatInputToRupiah(v);
        controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        prefixText: "Rp ",
        prefixStyle: const TextStyle(fontSize: 15, color: AppPalette.primary),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppPalette.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildDurationSection() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Waktu"),
              _buildCustomInput(
                _durationController,
                "0",
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel("Durasi"),
              _buildTriggerBtn(
                value: _selectedDurationUnit,
                onTap: () => _showPicker(
                  title: "Pilih Durasi",
                  options: ["Hari", "Jam", "Minggu"],
                  currentValue: _selectedDurationUnit,
                  onSelected: (val) =>
                      setState(() => _selectedDurationUnit = val),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMinimumOrderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _hasMinimumOrder = false;
                      _minimumOrderController.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Radio<bool>(
                            value: false,
                            groupValue: _hasMinimumOrder,
                            onChanged: (value) {
                              setState(() {
                                _hasMinimumOrder = value ?? false;
                                _minimumOrderController.clear();
                              });
                            },
                            activeColor: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Tanpa minimal order",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    setState(() => _hasMinimumOrder = true);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: Radio<bool>(
                            value: true,
                            groupValue: _hasMinimumOrder,
                            onChanged: (value) {
                              setState(() => _hasMinimumOrder = value ?? false);
                            },
                            activeColor: AppPalette.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            "Set minimal order",
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_hasMinimumOrder) ...[
          const SizedBox(height: 12),
          _buildCustomInput(
            _minimumOrderController,
            "Contoh: 3",
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveProduct,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 4,
          shadowColor: AppPalette.primary.withValues(alpha: 0.4),
        ),
        child: Text(
          widget.existingProduct != null ? "UPDATE PRODUK" : "TAMBAH PRODUK",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(String fileName) {
    return Image.asset(
      resolveLayananIconPath(fileName),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              Icons.checkroom_rounded,
              color: Colors.grey.shade400,
              size: 28,
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProduct() async {
    if (_nameController.text.trim().isEmpty) {
      _showError("Nama layanan tidak boleh kosong!");
      return;
    }
    if (_nameController.text.trim().length < 3) {
      _showError("Nama layanan minimal 3 karakter!");
      return;
    }

    if (_selectedUnit == "Pilih salah satu") {
      _showError("Pilih satuan produk!");
      return;
    }

    final priceValue = CurrencyFormatter.parseRupiahToInt(
      _priceController.text,
    ).toDouble();
    if (priceValue <= 0) {
      _showError("Harga produk harus lebih dari 0!");
      return;
    }

    if (_durationController.text.isEmpty || _durationController.text == "0") {
      _showError("Isi durasi pengerjaan!");
      return;
    }

    double? minimalOrder;
    if (_hasMinimumOrder) {
      final minText = _minimumOrderController.text.trim();
      if (minText.isEmpty) {
        _showError("Isi minimal order!");
        return;
      }
      minimalOrder = double.tryParse(minText.replaceAll(',', '.'));
      if (minimalOrder == null || minimalOrder <= 0) {
        _showError("Minimal order harus lebih dari 0!");
        return;
      }
    }

    String displayUnit = _selectedUnit.contains('(')
        ? _selectedUnit.split('(')[1].replaceAll(')', '')
        : _selectedUnit;

    // Satuan luas ditampilkan "m²" tapi disimpan ternormalisasi "m" (konvensi backend).
    if (displayUnit == 'm²' || displayUnit == 'm2') {
      displayUnit = 'm';
    }

    final newProduct = ServiceProduct(
      id:
          widget.existingProduct?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      price: priceValue,
      unit: displayUnit,
      minimalOrder: minimalOrder,
      duration: int.tryParse(_durationController.text) ?? 1,
      durationUnit: _selectedDurationUnit,
      iconPath: resolveLayananIconPath(_selectedIcon),
      priority: _priorityOptions[_selectedPriorityLabel] ?? 0,
    );

    final result = widget.existingProduct != null
        ? context.read<ServiceProvider>().updateProduct(newProduct)
        : context.read<ServiceProvider>().addProduct(newProduct);

    if (result['success'] ?? false) {
      if (mounted) {
        CustomToast.show(context, message: "Berhasil disimpan");
        Navigator.pop(context);
      }
    } else {
      _showError(result['message'] ?? "Gagal menyimpan produk");
    }
  }

  void _showError(String message) {
    CustomToast.show(context, message: message, isError: true);
  }

  String get _priceLabel => _selectedUnit.contains("Pilih")
      ? "Harga Satuan"
      : "Harga / ${_selectedUnit.contains('(') ? _selectedUnit.split('(')[1].replaceAll(')', '') : _selectedUnit}";
}
