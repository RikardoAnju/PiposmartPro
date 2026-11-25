import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/app_search_field.dart';

class BankOption {
  final String name;
  final String category;
  final Color color;

  const BankOption({
    required this.name,
    required this.category,
    required this.color,
  });
}

class BankPickerPage extends StatefulWidget {
  final String? selected;

  const BankPickerPage({super.key, this.selected});

  static Future<String?> show(BuildContext context, {String? selected}) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => BankPickerPage(selected: selected)),
    );
  }

  @override
  State<BankPickerPage> createState() => _BankPickerPageState();
}

class _BankPickerPageState extends State<BankPickerPage> {
  static const Color kPrimary = AppPalette.primary;
  static const Color kBg = Color(0xFFF6F7F9);

  final _searchController = TextEditingController();
  String _query = '';

  static const List<BankOption> _allOptions = [
    // Bank
    BankOption(name: 'BCA', category: 'Bank', color: Color(0xFF005BAC)),
    BankOption(name: 'Mandiri', category: 'Bank', color: Color(0xFF003087)),
    BankOption(name: 'BNI', category: 'Bank', color: Color(0xFF004B87)),
    BankOption(name: 'BRI', category: 'Bank', color: Color(0xFF00529B)),
    BankOption(name: 'CIMB Niaga', category: 'Bank', color: Color(0xFFCC0000)),
    BankOption(name: 'BTN', category: 'Bank', color: Color(0xFF007A3D)),
    BankOption(name: 'Bank Jago', category: 'Bank', color: Color(0xFF00B14F)),
    BankOption(
      name: 'Bank Syariah Indonesia',
      category: 'Bank',
      color: Color(0xFF007A3D),
    ),
    BankOption(
      name: 'Permata Bank',
      category: 'Bank',
      color: Color(0xFF004B87),
    ),
    BankOption(name: 'Danamon', category: 'Bank', color: Color(0xFFCC0000)),
    // E-Wallet
    BankOption(name: 'Gopay', category: 'E-Wallet', color: Color(0xFF00AED6)),
    BankOption(name: 'OVO', category: 'E-Wallet', color: Color(0xFF4C3494)),
    BankOption(name: 'Dana', category: 'E-Wallet', color: Color(0xFF118EEA)),
    BankOption(
      name: 'ShopeePay',
      category: 'E-Wallet',
      color: Color(0xFFEE4D2D),
    ),
    BankOption(name: 'LinkAja', category: 'E-Wallet', color: Color(0xFFE82529)),
    BankOption(name: 'SeaBank', category: 'E-Wallet', color: Color(0xFF2B5CE6)),
    BankOption(name: 'Jenius', category: 'E-Wallet', color: Color(0xFF00A8E8)),
  ];

  List<BankOption> get _filtered {
    if (_query.isEmpty) return _allOptions;
    return _allOptions
        .where((b) => b.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  Map<String, List<BankOption>> get _grouped {
    final map = <String, List<BankOption>>{};
    for (final b in _filtered) {
      map.putIfAbsent(b.category, () => []).add(b);
    }
    return map;
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped;

    return AppScaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Pilih Bank/E-Wallet',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AppSearchField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              onClear: () {
                _searchController.clear();
                setState(() => _query = '');
              },
              showClear: _query.isNotEmpty,
              hintText: 'Cari bank atau e-wallet...',
            ),
          ),

          // List
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ditemukan',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: grouped.entries.expand((entry) {
                      return [
                        // Category header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w700,
                              color: Colors.grey,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Items
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: entry.value.asMap().entries.map((e) {
                              final idx = e.key;
                              final bank = e.value;
                              final isFirst = idx == 0;
                              final isLast = idx == entry.value.length - 1;
                              final isSelected = widget.selected == bank.name;

                              return Column(
                                children: [
                                  if (!isFirst)
                                    Divider(
                                      height: 1,
                                      color: Colors.grey.shade100,
                                      indent: 68,
                                    ),
                                  InkWell(
                                    onTap: () =>
                                        Navigator.of(context).pop(bank.name),
                                    borderRadius: BorderRadius.vertical(
                                      top: isFirst
                                          ? const Radius.circular(14)
                                          : Radius.zero,
                                      bottom: isLast
                                          ? const Radius.circular(14)
                                          : Radius.zero,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          // Avatar
                                          Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                              color: bank.color.withValues(
                                                alpha: 0.12,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              _initials(bank.name),
                                              style: TextStyle(
                                                color: bank.color,
                                                fontWeight: AppFont.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              bank.name,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected
                                                    ? AppFont.w700
                                                    : AppFont.w500,
                                                color: isSelected
                                                    ? kPrimary
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (isSelected)
                                            Container(
                                              width: 22,
                                              height: 22,
                                              decoration: const BoxDecoration(
                                                color: kPrimary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ];
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
