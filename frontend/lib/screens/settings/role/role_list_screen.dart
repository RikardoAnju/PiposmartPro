import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/settings/role/widgets/role_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../providers/role_provider.dart';
import '../../../data/models/role_model.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class RoleListScreen extends StatefulWidget {
  const RoleListScreen({super.key});

  @override
  State<RoleListScreen> createState() => _RoleListScreenState();
}

class _RoleListScreenState extends State<RoleListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final provider = context.read<RoleProvider>();
        await provider.fetchRoles();

        if (mounted && provider.errorMessage != null) {
          CustomToast.show(
            context,
            message: provider.errorMessage!,
            isError: true,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoleProvider>();

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
        title: const Text(
          "Kembali",
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          double horizontalPadding = constraints.maxWidth > 600
              ? constraints.maxWidth * 0.15
              : 20;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => provider.fetchRoles(),
                color: AppPalette.primary,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  // Padding bottom 140 agar item terakhir tidak tertutup tombol floating
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10,
                    horizontalPadding,
                    140,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hak Akses / Role",
                        style: TextStyle(
                          fontWeight: AppFont.w900,
                          fontSize: 22,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Kelola peran dan izin akses untuk setiap karyawan Anda",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (provider.isLoading && provider.roles.isEmpty)
                        const ManagementListSkeleton(
                          showSearch: false,
                          itemCount: 4,
                        )
                      else if (provider.errorMessage != null)
                        _buildErrorState(provider.errorMessage!)
                      else if (provider.roles.isEmpty)
                        _buildEmptyState()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: provider.roles.length,
                          itemBuilder: (context, index) =>
                              _buildRoleCard(provider.roles[index]),
                        ),
                    ],
                  ),
                ),
              ),

              // TOMBOL AKSI MODERN (Floating Style)
              if (provider.errorMessage == null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildFloatingAddButton(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          const Icon(Icons.lock_person_rounded, size: 70, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            "Akses Terbatas",
            style: TextStyle(fontSize: 18, fontWeight: AppFont.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.primary.withValues(alpha: 0.1),
              elevation: 0,
              foregroundColor: AppPalette.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("KEMBALI KE PENGATURAN"),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 80),
        child: Column(
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 60,
              color: Color(0xFFE0E0E0),
            ),
            SizedBox(height: 16),
            Text(
              "Belum ada data role",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(Role role) {
    // Hitung module berdasarkan pengelompokan UI agar konsisten dengan RoleFormScreen
    final uiModules = {
      'transaksi',
      'pelanggan',
      'pengeluaran',
      'layanan_&_konfigurasi',
      'pegawai',
      'laporan',
    };

    final mapping = {
      'layanan': 'layanan_&_konfigurasi',
      'item': 'layanan_&_konfigurasi',
      'parfum': 'layanan_&_konfigurasi',
      'diskon': 'layanan_&_konfigurasi',
      'pembayaran': 'layanan_&_konfigurasi',
      'metode_pembayaran': 'layanan_&_konfigurasi', // fallback
    };

    Set<String> activeUiModules = {};
    role.permissions.forEach((key, actions) {
      if (actions.isNotEmpty) {
        String uiKey = mapping[key] ?? key;
        if (uiModules.contains(uiKey)) {
          activeUiModules.add(uiKey);
        }
      }
    });

    int moduleCount = activeUiModules.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFF2F2F2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppPalette.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: AppPalette.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.nama.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: AppFont.w700,
                      fontSize: 15,
                      color: Color(0xFF2C3E50),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Akses ke $moduleCount Modul Sistem",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: AppFont.w500,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconActionButton(
                  icon: Icons.edit_rounded,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            RoleFormScreen(existingRole: role),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildIconActionButton(
                  icon: Icons.delete_rounded,
                  color: AppPalette.primary,
                  onTap: () => _confirmDelete(role.id, role.nama),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RoleFormScreen()),
              );
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
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_moderator_outlined, size: 20),
                const SizedBox(width: 10),
                Text(
                  "BUAT ROLE BARU",
                  style: TextStyle(
                    fontWeight: AppFont.w900,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(String id, String name) {
    HapticFeedback.heavyImpact();
    final scaffoldContext = context;
    showDialog(
      context: context,
      builder: (dContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Hapus Role?",
          style: TextStyle(fontWeight: AppFont.w700),
        ),
        content: Text(
          "Apakah Anda yakin ingin menghapus role '$name'? Role yang masih digunakan oleh pegawai tidak dapat dihapus.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dContext),
            child: const Text(
              "BATAL",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w700),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = scaffoldContext.read<RoleProvider>();
              Navigator.pop(dContext);
              final res = await provider.deleteRole(id);
              if (!mounted) return;
              if (res['success']) {
                CustomToast.show(
                  scaffoldContext,
                  message: "Role berhasil dihapus",
                );
              } else {
                CustomToast.show(
                  scaffoldContext,
                  message: res['message'],
                  isError: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              "HAPUS",
              style: TextStyle(color: Colors.white, fontWeight: AppFont.w700),
            ),
          ),
        ],
      ),
    );
  }
}
