import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/inventory/inventory_settings_screen.dart';
import 'package:ayocucinew/providers/inventory_provider.dart';
import 'package:ayocucinew/screens/inventory/widgets/inventory_loading_shimmer.dart';
import 'package:provider/provider.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();
    Future.microtask(inventory.fetchOverview);
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final items = inventory.items.map(_toStock).toList();
    final criticalItems = items
        .where((item) => item.$4 == 'HABIS' || item.$4 == 'MENIPIS')
        .toList();
    final isInitialLoading = !inventory.hasLoaded || inventory.isLoading;
    final isEmpty =
        inventory.hasLoaded &&
        !inventory.isLoading &&
        inventory.items.isEmpty &&
        inventory.categories.isEmpty;
    return AppScaffold(
      backgroundColor: Colors.white,
      floatingActionButton: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventorySettingsScreen()),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppPalette.ink,
          elevation: 7,
          tooltip: 'Pengaturan inventory',
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.settings_rounded, size: 27),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final h = c.maxWidth > 650 ? c.maxWidth * .15 : 18.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(h, 16, h, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(context),
                  const SizedBox(height: 18),
                  _summary(
                    inventory.totalItems,
                    inventory.lowStock,
                    inventory.outOfStock,
                  ),
                  const SizedBox(height: 16),
                  _search(),
                  const SizedBox(height: 12),
                  _filters(),
                  if (isInitialLoading)
                    const InventoryLoadingShimmer()
                  else if (isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 42),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/no-data/no data.webp',
                              width: 170,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Tidak ada Inventory',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: AppFont.w700,
                                color: AppPalette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    if (criticalItems.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _title('Perlu Diperhatikan', action: 'Lihat Semua'),
                      const SizedBox(height: 10),
                      ...criticalItems.map(_stock),
                      const SizedBox(height: 18),
                    ] else
                      const SizedBox(height: 20),
                    _title('Kategori Barang'),
                    const SizedBox(height: 10),
                    if (inventory.isLoading && inventory.categories.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (inventory.categories.isNotEmpty)
                      _categories(inventory.categories),
                    const SizedBox(height: 16),
                    _actions(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => SizedBox(
    height: 42,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: _asset('10_icon_kembali.webp', 24),
            ),
          ),
        ),
        const Text(
          'Inventory',
          style: TextStyle(
            fontSize: 20,
            fontWeight: AppFont.w800,
            color: Color(0xFF26364B),
          ),
        ),
      ],
    ),
  );
  Widget _summary(int total, int low, int out) => Container(
    height: 112,
    clipBehavior: Clip.antiAlias,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF4ED), Color(0xFFFFFCFA)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFFFE3D6)),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Stack(
      children: [
        Positioned(left: -28, bottom: -44, child: _heroBubble(94)),
        Positioned(right: -25, top: -38, child: _heroBubble(82)),
        Row(
          children: [
            Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDCBC),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/icons/inventory/01_illustrasi_kotak_inventory_3d.webp',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RINGKASAN INVENTORY',
                    style: TextStyle(
                      color: AppPalette.muted,
                      fontSize: 9,
                      letterSpacing: .6,
                      fontWeight: AppFont.w700,
                    ),
                  ),
                  Text(
                    '$total',
                    style: const TextStyle(
                      color: AppPalette.primary,
                      fontSize: 38,
                      height: .95,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Total Barang',
                    style: TextStyle(color: AppPalette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            _summaryDivider(),
            _summaryStat(
              '06_icon_stok_menipis.webp',
              '$low',
              'Menipis',
              AppPalette.warning,
            ),
            _summaryDivider(),
            _summaryStat(
              '07_icon_stok_habis.webp',
              '$out',
              'Habis',
              const Color(0xFFF52F55),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _heroBubble(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: const Color(0xFFFFE9DA),
      shape: BoxShape.circle,
    ),
  );

  Widget _summaryDivider() => Container(
    width: 1,
    height: 54,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    color: const Color(0xFFFFE2D4),
  );

  Widget _summaryStat(String icon, String value, String label, Color color) =>
      SizedBox(
        width: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _asset(icon, 20),
            ),
            const SizedBox(height: 3),
            SizedBox(
              width: 44,
              height: 20,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 17,
                    height: 1,
                    fontWeight: AppFont.w800,
                    color: AppPalette.ink,
                  ),
                ),
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppPalette.muted),
            ),
          ],
        ),
      );
  Widget _search() => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Row(
      children: [
        _asset('11_icon_pencarian.webp', 21),
        const SizedBox(width: 10),
        Text(
          'Cari barang atau kategori',
          style: TextStyle(color: AppPalette.muted, fontSize: 13),
        ),
      ],
    ),
  );
  Widget _filters() => Row(
    children: [
      _filter('Semua', true, AppPalette.primary),
      _filter(
        'Menipis',
        false,
        AppPalette.warning,
        '06_icon_stok_menipis.webp',
      ),
      _filter(
        'Habis',
        false,
        const Color(0xFFF52F55),
        '07_icon_stok_habis.webp',
      ),
    ],
  );
  Widget _filter(String l, bool a, Color c, [String? icon]) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 7),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(
        color: a ? c : c.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[_asset(icon, 15), const SizedBox(width: 6)],
            Text(
              l,
              style: TextStyle(
                fontSize: 12,
                fontWeight: a ? FontWeight.w700 : FontWeight.w500,
                color: a ? Colors.white : const Color(0xFF687487),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _title(String t, {String? action}) => Row(
    children: [
      Text(
        t,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: AppFont.w800,
          color: Color(0xFF132238),
        ),
      ),
      const Spacer(),
      if (action != null)
        Text(
          '$action  ›',
          style: const TextStyle(
            fontSize: 12,
            color: AppPalette.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
    ],
  );

  (String, String, String, String, String, Color) _toStock(
    Map<String, dynamic> item,
  ) {
    final stock = (item['stock'] as num?)?.toDouble() ?? 0;
    final minimum = (item['minimum_stock'] as num?)?.toDouble() ?? 0;
    final isOut = stock <= 0;
    final icon = _categoryIcon(item['category_name'] as String? ?? '');
    final iconKey = item['category_icon_key'] as String? ?? '';
    return (
      item['name'] as String? ?? '-',
      item['category_name'] as String? ?? 'Tanpa kategori',
      '${_formatQuantity(stock)} ${item['unit'] ?? ''}',
      isOut
          ? 'HABIS'
          : stock <= minimum
          ? 'MENIPIS'
          : 'AMAN',
      iconKey.isNotEmpty
          ? 'assets/icons/inventory/category_options/$iconKey'
          : icon.$1,
      icon.$2,
    );
  }

  (String, Color) _categoryIcon(String name) {
    final normalized = name.toLowerCase();
    if (normalized.contains('packag')) {
      return ('03_icon_packaging_pink.webp', const Color(0xFFFFE4F1));
    }
    if (normalized.contains('pewangi') || normalized.contains('pelembut')) {
      return ('04_icon_pewangi_pelembut_kuning.webp', const Color(0xFFFFF3CC));
    }
    if (normalized.contains('perlengkapan')) {
      return ('05_icon_perlengkapan_hijau.webp', const Color(0xFFE2F9E9));
    }
    return ('02_icon_bahan_pencucian_biru.webp', const Color(0xFFE0F6FF));
  }

  String _formatQuantity(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');

  Widget _stock((String, String, String, String, String, Color) x) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: x.$6,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: _asset(x.$5, 34),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                x.$1,
                style: const TextStyle(fontWeight: AppFont.w800, fontSize: 14),
              ),
              Text(
                x.$2,
                style: const TextStyle(color: AppPalette.muted, fontSize: 12),
              ),
              Container(
                margin: const EdgeInsets.only(top: 5),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: x.$4 == 'HABIS'
                      ? const Color(0xFFFFE5EA)
                      : const Color(0xFFFFEDD9),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  x.$4,
                  style: TextStyle(
                    color: x.$4 == 'HABIS'
                        ? const Color(0xFFF52F55)
                        : AppPalette.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          x.$3,
          style: const TextStyle(fontWeight: AppFont.w800, fontSize: 14),
        ),
        _asset('12_icon_panah_kanan.webp', 18),
      ],
    ),
  );
  Widget _categories(List<Map<String, dynamic>> categories) => GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 1,
    mainAxisSpacing: 10,
    childAspectRatio: 4.35,
    children: categories.map((category) {
      final icon = _categoryIcon(category['name'] as String? ?? '');
      final iconKey = category['icon_key'] as String? ?? '';
      return _cat(
        category['name'] as String? ?? '-',
        '',
        iconKey.isNotEmpty
            ? 'assets/icons/inventory/category_options/$iconKey'
            : icon.$1,
        icon.$2,
      );
    }).toList(),
  );
  Widget _cat(String t, String n, String icon, Color bg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppShadows.cardSoft,
    ),
    child: Row(
      children: [
        SizedBox(width: 46, height: 46, child: _asset(icon, 25)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t,
                maxLines: 1,
                style: const TextStyle(
                  fontWeight: AppFont.w700,
                  fontSize: 12,
                  height: 1.15,
                ),
              ),
              Text(
                n,
                style: const TextStyle(color: AppPalette.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        _asset('12_icon_panah_kanan.webp', 16),
      ],
    ),
  );
  Widget _actions() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: _asset('13_icon_sesuaikan_stok.webp', 20),
          label: const Text('Sesuaikan Stok'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppPalette.primary,
            side: const BorderSide(color: AppPalette.primary),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () {},
          icon: _asset('14_icon_update_stok_putih.webp', 20),
          label: const Text('Update Stok'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _asset(String name, double size) => Image.asset(
    name.startsWith('assets/') ? name : 'assets/icons/inventory/$name',
    width: size,
    height: size,
    fit: BoxFit.contain,
  );
}
