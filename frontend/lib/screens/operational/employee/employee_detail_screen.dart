// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/data/models/pegawai_model.dart';
import 'package:ayocucinew/screens/operational/employee/widgets/employee_form_screen.dart';
import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/shared/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/pegawai_provider.dart';
import '../../../providers/role_provider.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final Pegawai emp;

  const EmployeeDetailScreen({super.key, required this.emp});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  bool _showInfo = true;

  bool? _pendingActive;

  bool _actionBusy = false;

  Pegawai _resolveEmp() =>
      context.read<PegawaiProvider>().employeeByIdOr(widget.emp.id, widget.emp);

  Future<void> _toggleStatus(bool value) async {
    final provider = context.read<PegawaiProvider>();

    setState(() => _pendingActive = value);

    final res = await provider.updateEmployeeStatus(
      employee: _resolveEmp(),
      isActive: value,
    );

    if (!mounted) return;

    // Lepas override: build akan mengambil status asli dari provider
    // (sukses = status baru, gagal = status lama otomatis ter-revert).
    setState(() => _pendingActive = null);

    CustomToast.show(
      context,
      message: res['success'] == true
          ? (res['message'] ?? 'Status pegawai berhasil diperbarui')
          : (res['message'] ?? 'Gagal memperbarui status pegawai'),
      isError: res['success'] != true,
    );
  }

  @override
  Widget build(BuildContext context) {
    // watch → layar rebuild otomatis saat data pegawai berubah di provider
    // (mis. setelah edit atau toggle status).
    final employees = context.watch<PegawaiProvider>().employees;
    final emp = employees.firstWhere(
      (e) => e.id == widget.emp.id,
      orElse: () => widget.emp,
    );
    final bool isActive = _pendingActive ?? (emp.status == 1);
    final String loginLabel = emp.type == 'addon'
        ? (emp.activeUntil != null && emp.activeUntil!.isAfter(DateTime.now())
              ? 'Login aktif s/d ${PegawaiProvider.formatDateOrDash(emp.activeUntil)}'
              : 'Login add-on sudah habis')
        : 'Login selamanya selama status aktif';

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppPalette.ink,
            size: 19,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Pegawai',
          style: TextStyle(
            color: AppPalette.ink,
            fontWeight: AppFont.w800,
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmployeeFormScreen(existing: emp),
                ),
              );
              if (!mounted) return;
              // Ambil ulang data terbaru supaya detail tidak menampilkan data basi.
              await context.read<PegawaiProvider>().fetchEmployees();
            },
            child: const Text(
              'EDIT',
              style: TextStyle(
                color: AppPalette.primary,
                fontWeight: AppFont.w900,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          _buildProfileCard(context, emp, isActive),
          const SizedBox(height: 12),
          _buildStatusCard(context, emp, isActive, loginLabel),
          const SizedBox(height: 12),
          _buildInfoSection(emp),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.shield_outlined,
            title: 'Hak Akses Modul',
            subtitle: 'Lihat izin modul untuk role ${emp.role?.nama ?? 'ini'}.',
            color: AppPalette.primary,
            onTap: () => _showPermissionSheet(context),
          ),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.logout_rounded,
            title: 'Paksa Logout',
            subtitle: 'Keluar dari semua sesi aktif aplikasi.',
            color: AppPalette.warning,
            onTap: () => _forceLogout(context),
          ),
          const SizedBox(height: 12),
          _actionTile(
            icon: Icons.delete_outline_rounded,
            title: 'Hapus Karyawan',
            subtitle: 'Hapus data pegawai secara permanen.',
            color: AppPalette.danger,
            onTap: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Pegawai emp, bool isActive) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppPalette.primarySoft,
            child: Icon(
              Icons.person_rounded,
              color: AppPalette.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emp.nama.toUpperCase(),
                  style: const TextStyle(
                    color: AppPalette.ink,
                    fontSize: 15,
                    fontWeight: AppFont.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  emp.email,
                  style: const TextStyle(color: AppPalette.muted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _badge(emp.role?.nama ?? 'STAFF', AppPalette.primary),
                    _badge(
                      emp.type == 'base' ? 'BASE' : 'ADDON',
                      AppPalette.info,
                    ),
                    _badge(
                      isActive ? 'AKTIF' : 'NON-AKTIF',
                      isActive ? AppPalette.success : AppPalette.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    Pegawai emp,
    bool isActive,
    String loginLabel,
  ) {
    final bool addonExpired =
        emp.type == 'addon' &&
        (emp.activeUntil == null || !emp.activeUntil!.isAfter(DateTime.now()));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Pegawai',
                      style: TextStyle(color: AppPalette.muted, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? 'Pegawai Aktif' : 'Pegawai Nonaktif',
                      style: const TextStyle(
                        color: AppPalette.ink,
                        fontSize: 15,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeThumbColor: AppPalette.primary,
                // Nonaktifkan saat toggle sedang diproses agar tak dobel kirim.
                onChanged: _pendingActive != null ? null : _toggleStatus,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Satu baris informatif: masa berlaku login (bukan pengulangan status).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  emp.type == 'addon'
                      ? Icons.schedule_rounded
                      : Icons.all_inclusive_rounded,
                  size: 16,
                  color: addonExpired ? AppPalette.warning : AppPalette.muted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loginLabel,
                    style: TextStyle(
                      color: addonExpired ? AppPalette.warning : AppPalette.ink,
                      fontSize: 12,
                      fontWeight: AppFont.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Pegawai emp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => setState(() => _showInfo = !_showInfo),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Informasi Pegawai',
                    style: TextStyle(
                      color: AppPalette.ink,
                      fontSize: 13,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  Icon(
                    _showInfo
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppPalette.ink,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_showInfo) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F5)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _infoRow(
                    Icons.email_outlined,
                    'Email',
                    emp.email.isEmpty ? '-' : emp.email,
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.phone_outlined,
                    'Telepon',
                    emp.nohp.isEmpty ? '-' : emp.nohp,
                  ),
                  const SizedBox(height: 14),
                  _infoRow(
                    Icons.cake_outlined,
                    'Tanggal lahir',
                    PegawaiProvider.formatDateOrDash(emp.tanggalLahir),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: AppFont.w800),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    IconData? trailingIcon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppPalette.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppPalette.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  fontWeight: AppFont.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 13,
                  fontWeight: AppFont.w700,
                ),
              ),
            ],
          ),
        ),
        if (trailingIcon != null)
          Icon(trailingIcon, color: AppPalette.muted, size: 18),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppPalette.ink,
                      fontSize: 12,
                      fontWeight: AppFont.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppPalette.muted,
                      fontSize: 10,
                      height: 1.3,
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

  void _showPermissionSheet(BuildContext context) {
    final permissions = widget.emp.role?.permissions ?? {};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.82,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDF3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Hak Akses Modul',
                        style: TextStyle(
                          color: AppPalette.ink,
                          fontSize: 16,
                          fontWeight: AppFont.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F5)),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    24 + MediaQuery.viewPaddingOf(ctx).bottom,
                  ),
                  children: [
                    if (permissions.isEmpty)
                      _permissionEmptyCard()
                    else
                      ...permissions.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _permissionCard(entry.key, entry.value),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _permissionCard(String moduleKey, dynamic actionsValue) {
    final actions = actionsValue is List ? actionsValue : const [];
    final moduleLabel = RoleProvider.moduleLabel(moduleKey).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEFF3)),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: AppPalette.primary,
              ),
              const SizedBox(width: 8),
              Text(
                moduleLabel,
                style: const TextStyle(
                  color: AppPalette.ink,
                  fontSize: 13,
                  fontWeight: AppFont.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: actions.map<Widget>((action) {
              final text = RoleProvider.actionLabel(
                action.toString(),
              ).toUpperCase();
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  text == 'SEMUA' ? 'SEMUA' : text,
                  style: const TextStyle(
                    color: AppPalette.primary,
                    fontSize: 10,
                    fontWeight: AppFont.w800,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _permissionEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Role ini belum punya permission yang tercatat.',
        style: TextStyle(color: AppPalette.muted, fontSize: 12, height: 1.4),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Karyawan?'),
        content: Text('Data "${widget.emp.nama}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'HAPUS',
              style: TextStyle(color: AppPalette.danger),
            ),
          ),
        ],
      ),
    );

    if (shouldDelete != true || !context.mounted || _actionBusy) return;

    setState(() => _actionBusy = true);
    final res = await context.read<PegawaiProvider>().deleteEmployee(
      widget.emp.id,
    );
    if (!context.mounted) return;
    setState(() => _actionBusy = false);

    final bool ok = res['success'] == true;
    // Tampilkan toast SEBELUM pop (overlay root bertahan setelah route ditutup).
    CustomToast.show(
      context,
      message:
          res['message'] ??
          (ok ? 'Pegawai dihapus' : 'Gagal menghapus pegawai'),
      isError: !ok,
    );
    // Tutup layar HANYA bila hapus berhasil.
    if (ok) {
      Navigator.pop(context);
    }
  }

  Future<void> _forceLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Paksa Logout?'),
        content: Text(
          'Pegawai "${widget.emp.nama}" akan dikeluarkan dari semua sesi aktif.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('BATAL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'LOGOUT',
              style: TextStyle(color: AppPalette.warning),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !context.mounted || _actionBusy) return;

    setState(() => _actionBusy = true);
    final res = await context.read<PegawaiProvider>().forceLogoutEmployee(
      widget.emp.id,
    );

    if (!context.mounted) return;
    setState(() => _actionBusy = false);

    final bool ok = res['success'] == true;
    CustomToast.show(
      context,
      message:
          res['message'] ??
          (ok ? 'Sesi pegawai diakhiri' : 'Gagal memaksa logout'),
      isError: !ok,
    );
  }
}
