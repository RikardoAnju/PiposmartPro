import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/role_model.dart';
import '../../../../providers/role_provider.dart';
import '../../../../shared/widgets/custom_toast.dart';
import '../../../../shared/widgets/custom_textfield.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RoleFormScreen extends StatefulWidget {
  final Role? existingRole;
  const RoleFormScreen({super.key, this.existingRole});

  @override
  State<RoleFormScreen> createState() => _RoleFormScreenState();
}

class _RoleFormScreenState extends State<RoleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  bool _isLoading = false;

  // Definisi modul UI dan mapping-nya ke key backend
  final Map<String, List<String>> _uiModuleMapping = {
    'transaksi': ['transaksi'],
    'pelanggan': ['pelanggan'],
    'pengeluaran': ['pengeluaran'],
    'layanan_&_konfigurasi': [
      'layanan',
      'item',
      'parfum',
      'diskon',
      'pembayaran',
    ],
    'pegawai': ['pegawai'],
    'laporan': ['laporan'],
  };

  List<String> get _uiModules => _uiModuleMapping.keys.toList();

  final List<String> _commonActions = ['create', 'read', 'update', 'delete'];
  Map<String, List<String>> _selectedPermissions = {};

  static const Map<String, String> _moduleLabels = {
    'transaksi': 'Transaksi',
    'pelanggan': 'Pelanggan',
    'pengeluaran': 'Pengeluaran',
    'layanan_&_konfigurasi': 'Layanan & Konfigurasi',
    'pegawai': 'Karyawan',
    'laporan': 'Laporan',
  };

  static const Map<String, String> _actionLabels = {
    'all': 'Semua',
    'create': 'Buat',
    'read': 'Lihat',
    'update': 'Ubah',
    'delete': 'Hapus',
    'update_status': 'Ubah Status',
    'update_delivery_fee': 'Ubah Biaya Antar/Jemput',
    'read_home_summary': 'Ringkasan Beranda',
    'read_daily_summary': 'Ringkasan Harian',
    'read_omset': 'Lihat Penjualan',
    'read_pengeluaran': 'Lihat Pengeluaran',
    'read_pendapatan': 'Lihat Pendapatan',
    'read_profit_loss': 'Lihat Laba Rugi',
    'read_transaction': 'Lihat Transaksi',
    'read_service_summary': 'Lihat Ringkasan Layanan',
    'read_customer': 'Lihat Pelanggan',
    'read_debt': 'Lihat Piutang',
  };

  @override
  void initState() {
    super.initState();
    if (widget.existingRole != null) {
      _namaController.text = widget.existingRole!.nama;

      // Map existing backend permissions to UI modules
      widget.existingRole!.permissions.forEach((backendKey, actions) {
        // Cari UI module mana yang mengandung backend key ini
        String? uiModule;
        _uiModuleMapping.forEach((key, list) {
          if (list.contains(backendKey)) uiModule = key;
        });

        if (uiModule != null) {
          if (!_selectedPermissions.containsKey(uiModule)) {
            _selectedPermissions[uiModule!] = [];
          }
          for (var action in actions) {
            if (!_selectedPermissions[uiModule]!.contains(action)) {
              _selectedPermissions[uiModule]!.add(action);
            }
          }
        }
      });
    }
  }

  void _togglePermission(String module, String action) {
    HapticFeedback.lightImpact();
    setState(() {
      if (!_selectedPermissions.containsKey(module)) {
        _selectedPermissions[module] = [];
      }

      if (action == 'all') {
        if (_selectedPermissions[module]!.contains('all')) {
          _selectedPermissions[module]!.remove('all');
        } else {
          _selectedPermissions[module] = ['all'];
        }
      } else {
        _selectedPermissions[module]!.remove('all');
        if (_selectedPermissions[module]!.contains(action)) {
          _selectedPermissions[module]!.remove(action);
        } else {
          _selectedPermissions[module]!.add(action);
        }
      }

      if (_selectedPermissions[module]!.isEmpty) {
        _selectedPermissions.remove(module);
      }
    });
  }

  String _moduleLabel(String moduleName) {
    return _moduleLabels[moduleName] ?? moduleName.replaceAll('_', ' ').trim();
  }

  String _actionLabel(String action) {
    return _actionLabels[action] ?? action.replaceAll('_', ' ').trim();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPermissions.isEmpty) {
      CustomToast.show(
        context,
        message: "Minimal pilih satu izin akses",
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Transform UI modules back to backend keys
    Map<String, List<String>> finalPermissions = {};
    _selectedPermissions.forEach((uiModule, actions) {
      final backendKeys = _uiModuleMapping[uiModule] ?? [uiModule];
      for (var key in backendKeys) {
        finalPermissions[key] = List<String>.from(actions);
      }
    });

    final res = await context.read<RoleProvider>().saveRole(
      id: widget.existingRole?.id,
      nama: _namaController.text.trim().toUpperCase(),
      permissions: finalPermissions,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (res['success']) {
        CustomToast.show(context, message: res['message']);
        Navigator.pop(context);
      } else {
        CustomToast.show(context, message: res['message'], isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: Colors.white,
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
          widget.existingRole != null ? "EDIT ROLE" : "TAMBAH ROLE",
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                // Padding bottom 160 agar konten terakhir tidak tertutup tombol floating
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 160),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextField(
                      controller: _namaController,
                      labelText: "NAMA ROLE",
                      hintText: "Contoh: ADMIN / KASIR",
                      isRequired: true,
                      textCapitalization: TextCapitalization.characters,
                      fillColor: const Color(0xFFF9F9F9),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      "PILIH HAK AKSES PER MODUL",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: AppFont.w900,
                        color: Color(0xFF2C3E50),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _uiModules.length,
                      itemBuilder: (context, index) =>
                          _buildModuleCard(_uiModules[index]),
                    ),
                  ],
                ),
              ),
            ),

            // TOMBOL SIMPAN MELAYANG (FIXED AT BOTTOM CENTER)
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildFloatingSubmitButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(String moduleName) {
    bool hasPermission = _selectedPermissions.containsKey(moduleName);
    bool hasAll = _selectedPermissions[moduleName]?.contains('all') ?? false;

    List<String> availableActions = [];
    if (moduleName == 'laporan') {
      availableActions = [
        'all',
        'read_home_summary',
        'read_daily_summary',
        'read_omset',
        'read_pengeluaran',
        'read_pendapatan',
        'read_profit_loss',
        'read_transaction',
        'read_service_summary',
        'read_customer',
        'read_debt',
      ];
    } else {
      availableActions = ['all', ..._commonActions];
      if (moduleName == 'transaksi') {
        availableActions.addAll(['update_status', 'update_delivery_fee']);
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: hasPermission
            ? AppPalette.primary.withValues(alpha: 0.02)
            : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPermission
              ? AppPalette.primary.withValues(alpha: 0.2)
              : const Color(0xFFEEEEEE),
        ),
      ),
      child: ExpansionTile(
        shape: const Border(), // Hilangkan border default expansion tile
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: AppPalette.primary,
        title: Text(
          _moduleLabel(moduleName).toUpperCase(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: AppFont.w900,
            color: hasPermission ? AppPalette.primary : const Color(0xFF2C3E50),
          ),
        ),
        subtitle: Text(
          hasAll
              ? "Semua Akses Aktif"
              : "${_selectedPermissions[moduleName]?.length ?? 0} Izin aktif",
          style: TextStyle(
            fontSize: 11,
            fontWeight: AppFont.w600,
            color: hasPermission ? Colors.green : Colors.grey,
          ),
        ),
        children: [
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableActions.map((action) {
              final bool isSelected =
                  _selectedPermissions[moduleName]?.contains(action) ?? false;
              return FilterChip(
                label: Text(
                  _actionLabel(action).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: AppFont.w900,
                  ),
                ),
                selected: isSelected,
                onSelected: (_) => _togglePermission(moduleName, action),
                selectedColor: action == 'all'
                    ? Colors.blue
                    : AppPalette.primary,
                checkmarkColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSubmitButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(
          bottom: 30,
        ), // Naikkan tombol agar tidak tertutup nav gesture
        child: SizedBox(
          width:
              MediaQuery.of(context).size.width * 0.7, // Lebar proporsional 70%
          height: 54,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 10,
              shadowColor: AppPalette.primary.withValues(alpha: 0.4),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: AppCircularLoader(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "SIMPAN ROLE",
                    style: TextStyle(
                      fontWeight: AppFont.w900,
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
