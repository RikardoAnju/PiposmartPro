import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/services/service_list_screen.dart

import 'package:ayocucinew/providers/transaction_provider.dart';
import 'package:ayocucinew/shared/widgets/currency_formatter.dart';
import 'package:ayocucinew/screens/operational/services/add_service_screen.dart';
import 'package:ayocucinew/screens/operational/services/add_product_screen.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/service_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/service_model.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class ServiceListScreen extends StatefulWidget {
  const ServiceListScreen({super.key});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedUnitFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  Future<void> _refreshData() async {
    if (mounted) {
      await context.read<ServiceProvider>().fetchServices();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _quickAddProduct(ServiceCategory category) async {
    final provider = context.read<ServiceProvider>();
    provider.loadCategoryForEdit(category);
    final initialCount = category.products.length;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProductScreen()),
    );

    if (!mounted) return;

    if (provider.tempProducts.length > initialCount) {
      final res = await provider.updateFullService(category.id);
      if (mounted) {
        CustomToast.show(
          context,
          message: res['message'],
          isError: !res['success'],
        );
        if (res['success']) _refreshData();
      }
    } else {
      provider.clearState();
    }
  }

  @override
  Widget build(BuildContext context) {
    final serviceProvider = context.watch<ServiceProvider>();
    final auth = context.watch<AuthProvider>();
    final canCreate = auth.canAccess('layanan', 'create');
    final canUpdate = auth.canAccess('layanan', 'update');
    final canDelete = auth.canAccess('layanan', 'delete');

    return AppScaffold(
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
      body: Column(
        children: [
          _buildSearchSection(),
          _buildFilterBar(serviceProvider.categories),
          const SizedBox(height: 10),
          Expanded(
            child: serviceProvider.isLoading
                ? const ManagementListSkeleton(grouped: true)
                : serviceProvider.categories.isEmpty
                ? const EmptyStateWidget(
                    message: "Belum ada layanan terdaftar.",
                  )
                : _buildServiceList(
                    serviceProvider,
                    canUpdate: canUpdate,
                    canDelete: canDelete,
                  ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () {
                serviceProvider.clearState();
                Navigator.pushNamed(
                  context,
                  '/add-service',
                ).then((_) => _refreshData());
              },
              backgroundColor: AppPalette.primary,
              elevation: 4,
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            )
          : null,
    );
  }

  Widget _buildSearchSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: AppSearchField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        hintText: 'Cari Layanan',
      ),
    );
  }

  Widget _buildFilterBar(List<ServiceCategory> categories) {
    final units = {'Semua'};
    for (var cat in categories) {
      for (var prod in cat.products) {
        if (prod.unit.isNotEmpty) units.add(prod.unit);
      }
    }
    final sortedUnits = units.toList()
      ..sort((a, b) => a == 'Semua' ? -1 : a.compareTo(b));

    return Container(
      height: 55,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: sortedUnits.length,
        itemBuilder: (context, index) {
          final unit = sortedUnits[index];
          final isSelected = _selectedUnitFilter == unit;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              label: Container(
                constraints: const BoxConstraints(minWidth: 40),
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
              elevation: 0,
            ),
          );
        },
      ),
    );
  }

  Widget _buildServiceList(
    ServiceProvider serviceProvider, {
    required bool canUpdate,
    required bool canDelete,
  }) {
    final filteredCategories = serviceProvider.categories.where((cat) {
      final matchesSearch =
          cat.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          cat.products.any(
            (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
          );

      if (_selectedUnitFilter == 'Semua') return matchesSearch;

      final hasMatchingUnit = cat.products.any(
        (p) => p.unit == _selectedUnitFilter,
      );
      return matchesSearch && hasMatchingUnit;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        return _buildCategoryCard(
          filteredCategories[index],
          serviceProvider,
          canUpdate: canUpdate,
          canDelete: canDelete,
        );
      },
    );
  }

  Widget _buildCategoryCard(
    ServiceCategory category,
    ServiceProvider serviceProvider, {
    required bool canUpdate,
    required bool canDelete,
  }) {
    final displayProducts = _selectedUnitFilter == 'Semua'
        ? category.products
              .where(
                (p) =>
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList()
        : category.products
              .where(
                (p) =>
                    p.unit == _selectedUnitFilter &&
                    p.name.toLowerCase().contains(_searchQuery.toLowerCase()),
              )
              .toList();

    if (displayProducts.isEmpty) return const SizedBox.shrink();

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
              children: displayProducts
                  .map(
                    (product) => _buildProductItem(
                      product,
                      category,
                      serviceProvider,
                      canDelete: canDelete,
                    ),
                  )
                  .toList(),
            ),
          ),
          if (canUpdate)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMinimalOutlinedButton(
                      label: "Edit",
                      icon: Icons.edit,
                      color: const Color(0xFF4CAF50),
                      onTap: () {
                        serviceProvider.loadCategoryForEdit(category);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddServiceScreen(existingCategory: category),
                          ),
                        ).then((_) => _refreshData());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMinimalOutlinedButton(
                      label: "Tambah",
                      icon: Icons.add_circle_outline,
                      color: AppPalette.primary,
                      onTap: () => _quickAddProduct(category),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductItem(
    ServiceProduct product,
    ServiceCategory category,
    ServiceProvider provider, {
    required bool canDelete,
  }) {
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
          if (canDelete)
            IconButton(
              onPressed: () =>
                  _confirmDeleteProduct(product, category, provider),
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.redAccent,
                size: 22,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMinimalOutlinedButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 45,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 14)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: const Color(0xFFF8F9FA),
          elevation: 0,
        ),
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

  void _confirmDeleteProduct(
    ServiceProduct product,
    ServiceCategory category,
    ServiceProvider provider,
  ) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hapus Produk?", style: TextStyle()),
        content: Text(
          "Yakin ingin menghapus '${product.name}' dari kategori ${category.name}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final mainContext = this.context;
              Navigator.pop(context);

              provider.loadCategoryForEdit(category);
              provider.removeProduct(product.id);
              final res = await provider.updateFullService(category.id);

              if (!mainContext.mounted) return;
              CustomToast.show(
                mainContext,
                message: res['message'],
                isError: !res['success'],
              );
              if (res['success']) _refreshData();
            },
            child: const Text("Ya, Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
