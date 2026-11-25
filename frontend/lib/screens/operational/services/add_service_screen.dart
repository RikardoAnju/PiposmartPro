import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/services/add_service_screen.dart

import 'package:ayocucinew/data/models/service_model.dart';
import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/screens/operational/services/add_product_screen.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/service_provider.dart';
import '../../../shared/widgets/custom_textfield.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class AddServiceScreen extends StatefulWidget {
  final ServiceCategory? existingCategory;
  const AddServiceScreen({super.key, this.existingCategory});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  final _nameController = TextEditingController();
  List<String> _selectedProcesses = [];

  // Canonical order for the laundry steps, so the saved/displayed process
  // always reads "Cuci → Kering → Lipat → Setrika → Packing → Titip" regardless
  // of the order
  // the user tapped the checkboxes. Unknown/legacy steps sort to the end.
  static const List<String> _processOrder = [
    'Cuci',
    'Kering',
    'Lipat',
    'Setrika',
    'Packing',
    'Titip',
  ];

  int _processRank(String process) {
    final index = _processOrder.indexOf(process);
    return index == -1 ? _processOrder.length : index;
  }

  void _sortProcesses() {
    _selectedProcesses.sort(
      (a, b) => _processRank(a).compareTo(_processRank(b)),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ServiceProvider>();
      provider.clearState();
      if (widget.existingCategory != null) {
        final cat = widget.existingCategory!;
        _nameController.text = cat.name;
        setState(() {
          _selectedProcesses = List.from(cat.processes);
          _sortProcesses();
        });
        provider.updateCategoryInfo(cat.name, cat.processes);
        for (var product in cat.products) {
          provider.addProduct(product);
        }
      }
    });
  }

  void _toggleProcess(String process) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_selectedProcesses.contains(process)) {
        _selectedProcesses.remove(process);
      } else {
        _selectedProcesses.add(process);
      }
      _sortProcesses();
    });
  }

  // --- LOGIKA VALIDASI SEBELUM SIMPAN ---
  bool _validateInput(ServiceProvider provider) {
    if (_nameController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        message: "Nama kategori wajib diisi",
        isError: true,
      );
      return false;
    }
    if (_selectedProcesses.isEmpty) {
      CustomToast.show(
        context,
        message: "Pilih minimal satu proses",
        isError: true,
      );
      return false;
    }
    if (provider.tempProducts.isEmpty) {
      CustomToast.show(
        context,
        message: "Tambahkan minimal satu jenis produk",
        isError: true,
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = context.watch<ServiceProvider>();

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingCategory != null ? 'Edit Layanan' : 'Tambah Layanan',
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 160),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Nama Kategori",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _nameController,
                    hintText: "Kiloan, Satuan, Karpet, dll",
                    fillColor: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Proses",
                    style: TextStyle(fontSize: 14, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildProcessCheckbox("Cuci"),
                      _buildProcessCheckbox("Kering"),
                      _buildProcessCheckbox("Lipat"),
                      _buildProcessCheckbox("Setrika"),
                      _buildProcessCheckbox("Packing"),
                      _buildProcessCheckbox("Titip"),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Jenis Produk",
                        style: TextStyle(fontSize: 15, color: Colors.black),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddProductModal(context),
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        label: const Text("Tambah Produk"),
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.primary,
                          textStyle: const TextStyle(fontSize: 13),
                          backgroundColor: AppPalette.primary.withValues(
                            alpha: 0.1,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (serviceProvider.tempProducts.isEmpty)
                    _buildEmptyState()
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: serviceProvider.tempProducts.length,
                      itemBuilder: (context, index) {
                        final item = serviceProvider.tempProducts[index];
                        return _buildProductItem(item, serviceProvider);
                      },
                    ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildFloatingSubmitButton(serviceProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(ServiceProduct item, ServiceProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              item.iconPath,
              width: 38,
              height: 38,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.local_laundry_service, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  "${CurrencyFormatter.formatToRupiah(item.price)} / ${TransactionProvider.displayUnit(item.unit)}",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
          _buildSmallActionBtn(
            Icons.edit_rounded,
            Colors.green,
            () => _showAddProductModal(context, existingProduct: item),
          ),
          const SizedBox(width: 8),
          _buildSmallActionBtn(
            Icons.delete_rounded,
            AppPalette.primary,
            () => provider.removeProduct(item.id),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  Widget _buildProcessCheckbox(String label) {
    bool isSelected = _selectedProcesses.contains(label);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _toggleProcess(label),
      selectedColor: AppPalette.primary.withValues(alpha: 0.2),
      checkmarkColor: AppPalette.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppPalette.primary : Colors.black,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppPalette.primary : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildFloatingSubmitButton(ServiceProvider serviceProvider) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: 54,
          child: ElevatedButton(
            onPressed: serviceProvider.isLoading
                ? null
                : () async {
                    // Eksekusi validasi lokal
                    if (!_validateInput(serviceProvider)) return;

                    HapticFeedback.mediumImpact();
                    serviceProvider.updateCategoryInfo(
                      _nameController.text,
                      _selectedProcesses,
                    );

                    final res = widget.existingCategory != null
                        ? await serviceProvider.updateFullService(
                            widget.existingCategory!.id,
                          )
                        : await serviceProvider.saveFullService();

                    if (res['success'] && mounted) {
                      CustomToast.show(context, message: res['message']);
                      Navigator.pop(context);
                    } else if (mounted) {
                      CustomToast.show(
                        context,
                        message: res['message'],
                        isError: true,
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 10,
              shadowColor: AppPalette.primary.withValues(alpha: 0.4),
            ),
            child: serviceProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppCircularLoader(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.existingCategory != null
                        ? "UPDATE LAYANAN"
                        : "SIMPAN LAYANAN",
                    style: const TextStyle(fontSize: 14, letterSpacing: 1),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.only(top: 80, bottom: 40),
      child: Column(
        children: [
          Icon(
            Icons.add_shopping_cart_rounded,
            size: 48,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          const Text("Belum ada produk", style: TextStyle(color: Colors.grey)),
        ],
      ),
    ),
  );

  void _showAddProductModal(
    BuildContext context, {
    ServiceProduct? existingProduct,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddProductScreen(existingProduct: existingProduct),
      ),
    );
  }
}
