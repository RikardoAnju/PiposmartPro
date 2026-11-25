import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/core/utils/addon_gate_helper.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/providers/addon_provider.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class KelolaKaryawanScreen extends StatelessWidget {
  const KelolaKaryawanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final addons = context.watch<AddonProvider>();
    final isEmployee = auth.actorType == 'pegawai';
    final hasAttendanceAddon = addons.isFeatureActive('ATTENDANCE');
    final hasPayrollAddon = addons.isFeatureActive('PAYROLL');
    final hasPerfAddon = addons.isFeatureActive('KARYAWAN_PERFORMANCE');

    final canAccessAttendance = hasAddonAccess(
      context: context,
      hasAddon: hasAttendanceAddon,
    );
    final canAccessPayroll = hasAddonAccess(
      context: context,
      hasAddon: hasPayrollAddon,
    );
    final canAccessPerf = hasAddonAccess(
      context: context,
      hasAddon: hasPerfAddon,
    );

    final menus = <_MenuData>[
      if (isEmployee) ...[
        _MenuData(
          icon: Icons.fact_check_rounded,
          title: 'Absensi Saya',
          subtitle: 'Lakukan absen masuk, pulang, dan lihat riwayat kehadiran',
          color: AppPalette.success,
          route: '/employee-attendance',
          isLocked: !canAccessAttendance,
          lockedAddonName: 'Absensi Karyawan',
        ),
        _MenuData(
          icon: Icons.assignment_turned_in_rounded,
          title: 'Performa Saya',
          subtitle: 'Lihat progress pekerjaan dan transaksi yang dikerjakan',
          color: AppPalette.info,
          route: '/pegawai-log-kerja',
          isLocked: !canAccessPerf,
          lockedAddonName: 'Karyawan Performance',
        ),
      ] else ...[
        if (auth.hasAccess('pegawai', 'read'))
          _MenuData(
            icon: Icons.fact_check_rounded,
            title: 'Kelola Absen',
            subtitle: 'Catat dan pantau kehadiran karyawan',
            color: AppPalette.success,
            route: '/pegawai-absen',
            isLocked: !canAccessAttendance,
            lockedAddonName: 'Absensi Karyawan',
          ),
        if (auth.hasAccess('pegawai', 'read'))
          _MenuData(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Performa Karyawan',
            subtitle: 'Pantau aktivitas dan pekerjaan karyawan',
            color: AppPalette.info,
            route: '/pegawai-log-kerja',
            isLocked: !canAccessPerf,
            lockedAddonName: 'Karyawan Performance',
          ),
        if (auth.isOwnerOrAdmin)
          _MenuData(
            icon: Icons.payments_rounded,
            title: 'Penggajian',
            subtitle: 'Ringkasan upah dan pembayaran karyawan',
            color: AppPalette.warning,
            route: '/pegawai-gaji',
            isLocked: !canAccessPayroll,
            lockedAddonName: 'Payroll Karyawan',
          ),
      ],
    ];

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Absensi & Payroll',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          const _HeroHeader(),
          const SizedBox(height: 22),
          for (int i = 0; i < menus.length; i++) ...[
            _MenuCard(data: menus[i]),
            if (i != menus.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? route;
  final bool isLocked;
  final String? lockedAddonName;

  const _MenuData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
    this.isLocked = false,
    this.lockedAddonName,
  });
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.colored(AppPalette.primaryDeep),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppPalette.brandGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -18,
              bottom: -22,
              child: Opacity(
                opacity: 0.12,
                child: Icon(
                  Icons.groups_rounded,
                  size: 150,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pusat Karyawan Outlet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: AppFont.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Kelola data karyawan dan penggajian dalam satu tempat.',
                          style: TextStyle(
                            color: Color(0xFFFFE7DE),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final _MenuData data;

  const _MenuCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (data.isLocked) {
            CustomToast.show(
              context,
              message:
                  'Aktifkan add-on ${data.lockedAddonName ?? "terkait"} terlebih dahulu.',
              isError: true,
            );
            Navigator.pushNamed(context, '/aktivasi-akun');
            return;
          }
          if (data.route == null) {
            CustomToast.show(
              context,
              message: 'Menu ini sedang disiapkan.',
              isError: false,
            );
            return;
          }
          Navigator.pushNamed(context, data.route!);
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFEDEFF3), width: 1.2),
            boxShadow: AppShadows.cardSoft,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(data.icon, color: data.color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: AppPalette.ink,
                            fontSize: 15,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                        if (data.isLocked) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppPalette.primarySoft,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Add-on',
                              style: TextStyle(
                                color: AppPalette.primary,
                                fontSize: 10,
                                fontWeight: AppFont.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: data.isLocked
                      ? AppPalette.primarySoft
                      : const Color(0xFFF4F6F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.isLocked
                      ? Icons.lock_rounded
                      : Icons.chevron_right_rounded,
                  color: data.isLocked ? AppPalette.primary : AppPalette.muted,
                  size: data.isLocked ? 14 : 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
