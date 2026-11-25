import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/app_asset_image.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OperationalGrid extends StatelessWidget {
  const OperationalGrid({super.key});

  @override
  Widget build(BuildContext context) {
    // Memantau tipe aktor saat ini dari AuthProvider
    final auth = context.watch<AuthProvider>();
    final canManageOutletFeatures = auth.isOwnerOrAdmin;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 25, shadow: AppShadows.card),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
        children: [
          _menuItem(
            context,
            'Layanan',
            'home/layanan_home.png',
            '/kelola-layanan',
            isProtected: true,
            hasAccess: _canReadServices(auth),
          ),
          _menuItem(
            context,
            'Pelanggan',
            'home/pelanggan_home.png',
            '/customer-list',
            isProtected: true,
            hasAccess: auth.canAccess('pelanggan', 'read'),
          ),
          _menuItem(
            context,
            'Karyawan',
            'home/karyawan_home.png',
            '/pegawai-data',
            isProtected: true,
            hasAccess: canManageOutletFeatures || auth.canAccess('pegawai', 'read'),
          ),
          _menuItem(
            context,
            'Absensi & Payroll',
            'home/absensi_payroll_home.png',
            '/pegawai-list',
            isProtected: true,
            // Pegawai harus dapat membuka hub untuk mengakses Absensi Saya.
            // Hak `pegawai.read` tetap diperlukan untuk layar pengelolaan
            // karyawan milik owner; status add-on diperiksa di dalam hub.
            hasAccess:
                auth.actorType == 'pegawai' ||
                auth.canAccess('pegawai', 'read'),
          ),
          _menuItem(
            context,
            'Pengeluaran',
            'home/pengeluaran_home.png',
            '/expense-list',
            isProtected: true,
            hasAccess: auth.canAccess('pengeluaran', 'read'),
          ),
          _menuItem(
            context,
            'Inventory',
            'home/inventory_home.png',
            '/item-list',
            isProtected: true,
            hasAccess: auth.canAccess('item', 'read'),
          ),

          _menuItem(
            context,
            'Laporan',
            'home/laporan_home.png',
            '/laporan',
            isProtected: true,
            hasAccess: auth.canReadAnyReport,
          ),
          _menuItem(
            context,
            'Outlet',
            'home/outlet_home.png',
            '/manage-outlet',
            isProtected: true,
            hasAccess: canManageOutletFeatures || auth.allOutletAccess,
          ),
        ],
      ),
    );
  }

  bool _canReadServices(AuthProvider auth) {
    return const [
      'layanan',
      'parfum',
      'item',
      'diskon',
    ].any((module) => auth.canAccess(module, 'read'));
  }

  Widget _menuItem(
    BuildContext context,
    String label,
    String iconName,
    String route, {
    bool isProtected = false,
    bool hasAccess = true,
    bool comingSoon = false,
    String? lockedMessage,
  }) {
    final isLocked = isProtected && !hasAccess;

    return GestureDetector(
      onTap: () {
        if (comingSoon) {
          CustomToast.show(
            context,
            message: 'Inventory Coming Soon',
            icon: Icons.notifications_none_rounded,
          );
          return;
        }
        // Proteksi hanya dijalankan saat di-tap
        if (isProtected && !hasAccess) {
          CustomToast.show(
            context,
            message:
                lockedMessage ?? 'Akses $label belum diberikan untuk akun ini.',
            isError: true,
          );
          if (lockedMessage?.startsWith('Aktifkan add-on') == true) {
            Navigator.pushNamed(context, '/aktivasi-akun');
          }
          return;
        }
        Navigator.pushNamed(context, route);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double iconBoxSize = constraints.maxWidth * 0.78;

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: iconBoxSize,
                width: iconBoxSize,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  // Tampilan disamakan semua (Pink muda khas AyoCuci)
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: isLocked ? 0.58 : 1,
                        child: AppAssetImage(
                          'assets/icons/$iconName',
                          fit: BoxFit.contain,
                          cacheWidth: 180,
                          errorWidget: const Icon(
                            Icons.apps,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                    ),
                    if (isLocked)
                      Positioned(
                        top: -5,
                        right: -5,
                        child: Container(
                          width: 21,
                          height: 21,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppPalette.primary.withValues(alpha: 0.25),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x16000000),
                                blurRadius: 5,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 12,
                            color: AppPalette.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: label == 'Absensi & Payroll'
                    ? const Text(
                        'Absensi & Payroll',
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.15,
                          fontWeight: AppFont.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      )
                    : Align(
                        alignment: Alignment.topCenter,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            label,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: AppFont.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
