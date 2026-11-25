import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// ignore_for_file: use_build_context_synchronously
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/operational/employee/employee_detail_screen.dart';
import 'package:ayocucinew/screens/operational/employee/widgets/employee_form_screen.dart';
import 'package:ayocucinew/screens/settings/aktivasi/aktivasi_akun_screen.dart';
import 'package:ayocucinew/shared/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../../providers/pegawai_provider.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../data/models/pegawai_model.dart';
import '../../../shared/widgets/custom_toast.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class EmployeeListScreen extends StatefulWidget {
  final bool openSalarySettings;

  const EmployeeListScreen({super.key, this.openSalarySettings = false});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        context.read<PegawaiProvider>().fetchEmployees(),
        context.read<AppProvider>().fetchOutletProfile(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PegawaiProvider>();
    final appProvider = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    const Color primaryColor = AppPalette.primary;
    const Color darkColor = Color(0xFF2C3E50);

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: darkColor,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Manajemen Karyawan",
          style: TextStyle(
            color: darkColor,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _buildPillAddButton(provider.isLimitReached),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  provider.fetchEmployees(),
                  appProvider.fetchOutletProfile(force: true),
                ]);
              },
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderSummary(
                      provider,
                      appProvider,
                      canSwitch:
                          auth.actorType == 'user' || auth.allOutletAccess,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "DAFTAR PEGAWAI",
                      style: TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 12,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (provider.isLoading && provider.employees.isEmpty)
                      const ManagementListSkeleton(
                        showSearch: false,
                        itemCount: 4,
                      )
                    else if (provider.employees.isEmpty)
                      Column(
                        children: [
                          const SizedBox(height: 60),
                          EmptyStateWidget(
                            title: "Belum ada pegawai",
                            message: "Silahkan tambahkan pegawai baru.",
                          ),
                        ],
                      )
                    else
                      ...provider.employees.map(
                        (emp) => _buildEmployeeCard(emp),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummary(
    PegawaiProvider provider,
    AppProvider appProvider, {
    required bool canSwitch,
  }) {
    final outlet = appProvider.outlet;
    // Aktif = benar-benar bisa dipakai: pg_status aktif (tidak dimatikan
    // manual) DAN kuota/add-on-nya aktif (base atau add-on aktif).
    // Sisanya (dimatikan manual, add-on belum aktif, atau kadaluarsa) = inactive.
    final int activeCount = provider.activeEmployeeCount;
    final int inactiveCount = provider.inactiveEmployeeCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: BoxDecoration(
        // Gradiasi Koin AyoCuci (Sesuai Screenshot lo Puh)
        gradient: const LinearGradient(
          colors: [AppPalette.primary, AppPalette.primaryWarm],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppPalette.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: !canSwitch
                  ? null
                  : () async {
                      await Navigator.pushNamed(context, '/manage-outlet');
                      if (!mounted) return;
                      await Future.wait([
                        context.read<AppProvider>().fetchOutletProfile(
                          force: true,
                        ),
                        context.read<PegawaiProvider>().fetchEmployees(),
                      ]);
                    },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.white,
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'OUTLET AKTIF',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10,
                              fontWeight: AppFont.w800,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            outlet?.nama ?? 'Memuat outlet...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: AppFont.w900,
                            ),
                          ),
                          if (outlet?.alamat?.trim().isNotEmpty == true)
                            Text(
                              outlet!.alamat!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (canSwitch)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ganti',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: AppFont.w800,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.swap_horiz_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.25),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem("Total Tim", provider.employees.length.toString()),
              _buildVerticalDivider(),
              _buildStatItem("Aktif", activeCount.toString()),
              _buildVerticalDivider(),
              _buildStatItem("Inactive", inactiveCount.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: AppFont.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: AppFont.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 25,
      width: 1,
      color: Colors.white.withValues(alpha: 0.3),
    );
  }

  Widget _buildEmployeeCard(Pegawai emp) {
    const Color primaryColor = AppPalette.primary;
    const Color darkColor = Color(0xFF2C3E50);

    Color themeColor;
    String badgeText;
    String footerText;
    IconData footerIcon;

    switch (emp.statusType) {
      case EmployeeStatusType.base:
        themeColor = primaryColor;
        badgeText = "PEGAWAI DASAR";
        footerText = "Pegawai tetap (Kuota Gratis)";
        footerIcon = Icons.stars_rounded;
        break;
      case EmployeeStatusType.addonActive:
        themeColor = const Color(0xFF00BFA5); // Teal / Green
        badgeText = "ADDON AKTIF";
        footerText =
            "Aktif s/d ${PegawaiProvider.formatTanggalIndo(emp.activeUntil!)}";
        footerIcon = Icons.verified_user_rounded;
        break;
      case EmployeeStatusType.addonInactive:
        themeColor = Colors.orange.shade700;
        badgeText = "BELUM AKTIF";
        footerText = "Menunggu aktivasi / Belum dibeli";
        footerIcon = Icons.hourglass_top_rounded;
        break;
      case EmployeeStatusType.addonExpired:
        themeColor = Colors.red.shade600;
        badgeText = "KADALUARSA";
        footerText =
            "Masa aktif habis pd ${PegawaiProvider.formatTanggalIndo(emp.activeUntil!)}";
        footerIcon = Icons.warning_amber_rounded;
        break;
    }

    // Karyawan dimatikan manual (pg_status = 0) padahal kuota/add-on-nya aktif.
    // Kasus add-on belum aktif sudah tertangani lewat badge "BELUM AKTIF",
    // jadi hindari redundansi — tandai hanya base / add-on aktif yang di-OFF.
    final bool isManuallyInactive =
        emp.status == 0 &&
        (emp.statusType == EmployeeStatusType.base ||
            emp.statusType == EmployeeStatusType.addonActive);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: themeColor, width: 6)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatarWidget(emp, themeColor),
                    const SizedBox(width: 14),
                    // --- SISI KIRI: NAMA & ROLE ---
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.nama.toUpperCase(),
                            style: TextStyle(
                              fontWeight: AppFont.w900,
                              fontSize: 15,
                              color: emp.isExpired ? Colors.grey : darkColor,
                              decoration: emp.isExpired
                                  ? TextDecoration.lineThrough
                                  : null,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildRoleChip(emp.role?.nama ?? "Staff"),
                              _buildBadgeWidget(badgeText, themeColor),
                              if (isManuallyInactive)
                                _buildBadgeWidget(
                                  "NON-AKTIF",
                                  Colors.red.shade600,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // --- SISI KANAN: ACTION BUTTONS ---
                    _buildActionButtons(emp),
                  ],
                ),
              ),
              _buildFooterWidget(footerText, footerIcon, themeColor, emp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(Pegawai emp, Color themeColor) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: themeColor.withValues(alpha: 0.1),
          child: Icon(Icons.person_rounded, color: themeColor, size: 28),
        ),
        if (emp.type == 'addon' && !emp.isExpired)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stars_rounded, size: 16, color: themeColor),
            ),
          ),
      ],
    );
  }

  Widget _buildBadgeWidget(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: AppFont.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppPalette.primary.withValues(
          alpha: 0.08,
        ), // ✅ Background orange sangat tipis
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: AppFont.w900,
          color: Color.fromARGB(
            255,
            230,
            89,
            29,
          ), // ✅ Orange yang lebih deep/tua
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Pegawai emp) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmployeeFormScreen(existing: emp),
            ),
          );
        } else if (value == 'delete') {
          _confirmDelete(emp.id, emp.nama);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: const [
              Icon(Icons.edit_rounded, color: Colors.green, size: 20),
              SizedBox(width: 12),
              Text(
                'Edit Pegawai',
                style: TextStyle(fontSize: 13, fontWeight: AppFont.w600),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: const [
              Icon(
                Icons.delete_outline_rounded,
                color: AppPalette.primary,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Hapus',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFont.w600,
                  color: AppPalette.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooterWidget(
    String text,
    IconData icon,
    Color color,
    Pegawai emp,
  ) {
    const Color darkColor = Color(0xFF2C3E50);
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => widget.openSalarySettings
                ? EmployeeFormScreen(existing: emp, initialStep: 1)
                : EmployeeDetailScreen(emp: emp),
          ),
        ).then((_) {
          if (context.mounted) {
            context.read<PegawaiProvider>().fetchEmployees();
          }
        });
      },
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: AppFont.w700,
                  color: color.withValues(alpha: 0.8),
                ),
              ),
            ),
            Row(
              children: [
                Text(
                  "Detail",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: AppFont.w900,
                    color: darkColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 10,
                  color: darkColor.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- TOMBOL TAMBAH PILL ROUNDED (FLOATING STYLE) ---
  Widget _buildPillAddButton(bool isLimit) {
    final buttonColor = isLimit ? Colors.amber[800]! : AppPalette.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 30),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.68,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              if (isLimit) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AktivasiAkunScreen(),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EmployeeFormScreen(),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 10,
              shadowColor: buttonColor.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isLimit
                      ? Icons.shopping_cart_checkout_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isLimit ? "BELI SLOT PEGAWAI PRO" : "TAMBAH PEGAWAI",
                      maxLines: 1,
                      style: const TextStyle(
                        fontWeight: AppFont.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          "Hapus Pegawai?",
          style: TextStyle(fontWeight: AppFont.w900),
        ),
        content: Text("Akses '$name' akan dicabut permanen. Lanjutkan?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "BATAL",
              style: TextStyle(color: Colors.grey, fontWeight: AppFont.w700),
            ),
          ),
          TextButton(
            onPressed: () async {
              final res = await context.read<PegawaiProvider>().deleteEmployee(
                id,
              );
              Navigator.pop(ctx);
              CustomToast.show(
                context,
                message: res['message'],
                isError: !res['success'],
              );
            },
            child: const Text(
              "HAPUS",
              style: TextStyle(
                color: AppPalette.primary,
                fontWeight: AppFont.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
