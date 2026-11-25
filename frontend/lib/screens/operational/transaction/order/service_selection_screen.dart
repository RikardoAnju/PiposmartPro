import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:provider/provider.dart';
import '../../../../providers/service_provider.dart';
import '../../../../providers/transaction_provider.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../widgets/modal_input_qty.dart';
import '../../../../data/models/service_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/responsive_center.dart';

class ServiceSelectionScreen extends StatefulWidget {
  const ServiceSelectionScreen({super.key});

  @override
  State<ServiceSelectionScreen> createState() => _ServiceSelectionScreenState();
}

class _ServiceSelectionScreenState extends State<ServiceSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedUnitFilter = "SEMUA";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ServiceProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = context.watch<ServiceProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Kembali',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ResponsiveCenter(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSearchField(
                    controller: _searchController,
                    hintText: "Cari Layanan",
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 10),

                  // --- FILTER BAR DENGAN UKURAN SERAGAM ---
                  _buildUnitFilterBar(serviceProvider.categories),

                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Layanan/Tidak Ada?",
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/service-list');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          "Kelola Layanan",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: AppFont.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: serviceProvider.isLoading
                  ? const ManagementListSkeleton(grouped: true)
                  : serviceProvider.categories.isEmpty
                  ? const EmptyStateWidget(
                      message: "Belum ada layanan yang tersedia",
                    )
                  : _buildServiceList(serviceProvider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitFilterBar(List<ServiceCategory> categories) {
    final units = {"SEMUA"};
    for (var cat in categories) {
      for (var prod in cat.products) {
        if (prod.unit.isNotEmpty) units.add(prod.unit.toUpperCase());
      }
    }
    final sortedUnits = units.toList()
      ..sort((a, b) => a == "SEMUA" ? -1 : a.compareTo(b));

    return SizedBox(
      height: 39,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: sortedUnits.length,
        itemBuilder: (context, index) {
          final unit = sortedUnits[index];
          final isSelected = _selectedUnitFilter == unit;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              // --- PENYERAGAMAN UKURAN ---
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              label: Container(
                constraints: const BoxConstraints(
                  minWidth: 40,
                ), // Ukuran tombol minimal seragam
                alignment: Alignment.center,
                child: Text(
                  TransactionProvider.displayUnit(unit).toUpperCase(),
                ),
              ),
              selected: isSelected,
              onSelected: (val) => setState(() => _selectedUnitFilter = unit),
              selectedColor: AppPalette.primary,
              backgroundColor: const Color(0xFFF1F3F5),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceList(ServiceProvider serviceProvider) {
    final filteredCategories = serviceProvider.categories.where((category) {
      final matchesSearch =
          category.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          category.products.any(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          );

      if (_selectedUnitFilter == "SEMUA") return matchesSearch;

      final hasMatchingUnit = category.products.any(
        (p) => p.unit.toUpperCase() == _selectedUnitFilter,
      );
      return matchesSearch && hasMatchingUnit;
    }).toList();

    if (filteredCategories.isEmpty && _searchQuery.isNotEmpty) {
      return EmptyStateWidget(message: "Tidak ada layanan yang sesuai");
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];

        final displayProducts = category.products.where((p) {
          final matchesSearch = p.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
          if (_selectedUnitFilter == "SEMUA") return matchesSearch;
          return matchesSearch && p.unit.toUpperCase() == _selectedUnitFilter;
        }).toList();

        if (displayProducts.isEmpty) return const SizedBox.shrink();

        return _buildCategoryGroup(category, displayProducts);
      },
    );
  }

  Widget _buildCategoryGroup(
    ServiceCategory category,
    List<ServiceProduct> products,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: AppDecorations.card(radius: 20),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F9FC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFEDF1F5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 16.5,
                    height: 1.2,
                    color: AppPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.processes.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _buildProcessSummary(category.processes),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: products.asMap().entries.map((entry) {
                return _buildServiceItem(category.name, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(String categoryName, ServiceProduct product) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              product.iconPath,
              width: 35,
              height: 35,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.local_laundry_service, color: Colors.blue),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
                const SizedBox(height: 4),
                Text(
                  "${CurrencyFormatter.formatToRupiah(product.price)} / ${TransactionProvider.displayUnit(product.unit)} - ${product.duration} ${product.durationUnit}",
                  style: const TextStyle(
                    color: Color(0xFF636E72),
                    fontSize: 13,
                  ),
                ),
                if (product.minimalOrder != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    "Min. order ${product.minimalOrder! % 1 == 0 ? product.minimalOrder!.toStringAsFixed(0) : product.minimalOrder!.toStringAsFixed(1)} ${TransactionProvider.displayUnit(product.unit)}",
                    style: const TextStyle(
                      color: AppPalette.primary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _showQtyModal(categoryName, product),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(70, 38),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              "PILIH",
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFont.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessSummary(List<String> processes) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppPalette.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Icon(
            Icons.route_rounded,
            color: AppPalette.primary,
            size: 13,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            processes.join('  •  '),
            softWrap: true,
            style: const TextStyle(
              color: AppPalette.primary,
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showQtyModal(String categoryName, ServiceProduct product) {
    final provider = context.read<TransactionProvider>();
    final hasExistingService = provider.cartItems.any(
      (item) =>
          item.categoryName == categoryName &&
          item.serviceName == product.name &&
          item.productId == product.id,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ModalInputQty(
        serviceName: product.name,
        price: product.price.toDouble(),
        unit: product.unit,
        minimalOrder: product.minimalOrder,
        hasExistingService: hasExistingService,
        onConfirm: (qty, selectedItems, mergeDuplicate) {
          try {
            final groupKey = provider.addServiceToCart(
              categoryName: categoryName,
              serviceName: product.name,
              price: product.price.toDouble(),
              qty: qty,
              duration: product.duration,
              durationUnit: product.durationUnit,
              unit: product.unit,
              iconPath: product.iconPath,
              minimalOrder: product.minimalOrder,
              productId: product.id,
              mergeDuplicate: mergeDuplicate,
            );
            provider.setOptionalItemsForService(
              groupKey,
              selectedItems
                  .map(
                    (item) => {
                      'id': item.id,
                      'name': item.nama,
                      'qty': item.qty,
                    },
                  )
                  .toList(),
            );
            Navigator.pop(context);
            Navigator.pop(context);
          } on ArgumentError catch (error) {
            CustomToast.show(
              context,
              message: error.message.toString(),
              isError: true,
            );
          }
        },
      ),
    );
  }
}
