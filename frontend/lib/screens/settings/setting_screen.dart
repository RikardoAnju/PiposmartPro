import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ayocucinew/screens/settings/koin/koin_management_screen.dart';
import 'package:ayocucinew/screens/settings/referral/referral_page.dart';
import 'package:ayocucinew/screens/settings/tentangKami/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import 'package:ayocucinew/shared/widgets/responsive_center.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:ayocucinew/shared/widgets/app_version_text.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/utils/api_client.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/setting_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_profile_owner_screen.dart';
import 'outlet/list_konfigurasi.dart';
import 'role/role_list_screen.dart';
import '../operational/services/service_list_screen.dart';
import 'parfum/parfum_list_screen.dart';
import 'item/item_list_screen.dart';
import 'diskon/diskon_list_screen.dart';
import 'keuangan/kategori%20pengeluaran/kategori_list.dart';
import 'printer/nota_settings_page.dart';
import 'printer/kelolah_permission.dart';
import 'tentangKami/tentang_kami.dart';
import 'feature_request/feature_request_screen.dart';

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SettingProvider>().fetchSettingsData();
    });
  }

  String _getIconPath(String fileName) =>
      'assets/icons/setting_screen/$fileName';

  Future<void> _openCustomerSupport() async {
    final provider = context.read<SettingProvider>();
    if (provider.appSettings == null) {
      await provider.fetchSettingsData(silent: true);
    }
    if (!mounted) return;

    final rawNumber = provider.appSettings?['whatsapp_number']
        ?.toString()
        .trim();
    if (rawNumber == null || rawNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor Customer Support belum diatur oleh admin.'),
        ),
      );
      return;
    }

    var phone = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) phone = '62${phone.substring(1)}';
    if (!phone.startsWith('62')) phone = '62$phone';

    final url = Uri.https('wa.me', '/$phone', {
      'text': 'Halo Customer Support AyoCuci, saya membutuhkan bantuan.',
    });
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp tidak dapat dibuka.')),
      );
    }
  }

  TextStyle _menuTitleStyle(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!.copyWith(
        fontSize: 15,
        fontWeight: AppFont.w600,
        color: const Color(0xFF2C3E50),
      );

  TextStyle _menuSubtitleStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(
        fontSize: 12,
        fontWeight: AppFont.w500,
        color: Colors.grey.shade600,
      );

  TextStyle _metaLabelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
        fontSize: 11,
        fontWeight: AppFont.w600,
        color: Colors.grey.shade600,
        letterSpacing: 0,
      );

  TextStyle _sectionTitleStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
        fontSize: 13,
        fontWeight: AppFont.w700,
        color: Colors.blueGrey.shade500,
        letterSpacing: 0.2,
      );

  @override
  Widget build(BuildContext context) {
    final settingProv = context.watch<SettingProvider>();
    final authProv = context.watch<AuthProvider>();
    final outlet = settingProv.outletData;
    const Color primaryColor = AppPalette.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 25,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset(
                'assets/icons/ic_logo.webp',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
      body: settingProv.isLoading
          ? const SettingsHomeSkeleton()
          : RefreshIndicator(
              onRefresh: () => settingProv.fetchSettingsData(),
              color: primaryColor,
              child: ResponsiveCenter(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(outlet, authProv),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModernInfoCard(
                              icon: Icons.verified_user_rounded,
                              iconColor: Colors.blue,
                              label: "Status Akun",
                              value: settingProv.daysLeft,
                              valueColor: settingProv.isTrialAccount
                                  ? const Color.fromARGB(255, 250, 94, 4)
                                  : Colors.green.shade700,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/aktivasi-akun',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildModernInfoCard(
                              icon: Icons.groups_2_rounded,
                              iconColor: Colors.orange,
                              label: "Tim Pegawai",
                              value: "${settingProv.totalPegawaiRiil} Orang",
                              valueColor: Colors.black,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/pegawai-list'),
                            ),
                          ),
                        ],
                      ),
                      // Koin & Langganan/Aktivasi = OWNER-ONLY (billing).
                      if (authProv.isOwnerOrAdmin) ...[
                        const SizedBox(height: 16),
                        _buildKoinGradientCard(settingProv.formattedKoin),
                        const SizedBox(height: 16),
                        _buildUpgradeBannerSection(),
                      ],
                      const SizedBox(height: 25),

                      _buildSectionTitle("Konfigurasi"),

                      // Outlet & Role = OWNER-ONLY (pengaturan sensitif).
                      if (authProv.isOwnerOrAdmin) ...[
                        _buildMenuItem(
                          _getIconPath("s_outlet.webp"),
                          "Outlet",
                          "Konfigurasi Profil Outlet",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const KonfigurasiProfilOutletPage(),
                            ),
                          ),
                        ),
                        _buildMenuItem(
                          _getIconPath("s_role.webp"),
                          "Role",
                          "Kelola Role dan Permission Role",
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RoleListScreen(),
                            ),
                          ),
                        ),
                      ],

                      _buildExpandableMenuItem(
                        _getIconPath("s_layanan.webp"),
                        "Layanan",
                        "Konfigurasi Layanan & Produk",
                        children: [
                          _buildSubMenuTile(
                            Icons.dry_cleaning,
                            "Kelola Layanan",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ServiceListScreen(),
                              ),
                            ),
                          ),
                          _buildSubMenuTile(
                            Icons.opacity,
                            "Parfum",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ParfumListScreen(),
                              ),
                            ),
                          ),
                          _buildSubMenuTile(
                            Icons.check_box_outlined,
                            "Item Satuan",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ItemListScreen(),
                              ),
                            ),
                          ),
                          _buildSubMenuTile(
                            Icons.confirmation_num_outlined,
                            "Diskon",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DiskonListScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      _buildExpandableMenuItem(
                        _getIconPath("s_keuangan.webp"),
                        "Keuangan",
                        "Kelola Kategori Keuangan",
                        children: [
                          _buildSubMenuTile(
                            Icons.category_rounded,
                            "Kategori Pengeluaran",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const KategoriPengeluaranListScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      _buildExpandableMenuItem(
                        _getIconPath("s_printer.webp"),
                        "Printer",
                        "Kelola Printer dan Nota",
                        children: [
                          _buildSubMenuTile(
                            Icons.receipt_long_rounded,
                            "Kelola Format Nota",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const NotaSettingsPage(),
                              ),
                            ),
                          ),
                          _buildSubMenuTile(
                            Icons.security_rounded,
                            "Akses Cetak (Permission)",
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const PermissionPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildSectionTitle("Support"),
                      _buildMenuItem(
                        _getIconPath("ic_cs.png"),
                        "Customer Support",
                        "Pusat bantuan Teman Cuci",
                        onTap: _openCustomerSupport,
                      ),
                      _buildMenuItem(
                        _getIconPath("s_info.webp"),
                        "Request Fitur",
                        "Usulkan dan vote fitur berikutnya",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FeatureRequestScreen(),
                          ),
                        ),
                      ),
                      _buildMenuItem(
                        _getIconPath("ic_tutor.png"),
                        "Tutorial",
                        "Panduan menggunakan ayocuci",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TutorialScreen(),
                          ),
                        ),
                      ),
                      _buildMenuItem(
                        _getIconPath("s_info.webp"),
                        "Tentang Kami",
                        "Informasi Mengenai Aplikasi AyoCuci",
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TentangKamiPage(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "#LaundryCuanBisnisMaju",
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: AppFont.w500,
                            ),
                          ),
                          const AppVersionText(
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 15,
                              fontWeight: AppFont.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildLogoutButton(context),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // --- WIDGET COMPONENTS ---

  Widget _buildModernInfoCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(radius: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _metaLabelStyle(context)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 14,
                        fontWeight: AppFont.w700,
                        color: valueColor,
                      ),
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

  Widget _buildProfileHeader(Map<String, dynamic>? outlet, AuthProvider auth) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileOwnerScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(radius: 24, shadow: AppShadows.card),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F5),
                borderRadius: BorderRadius.circular(16),
                image: outlet?['ot_gambar'] != null
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          ApiClient.resolveImageVariantUrl(
                            outlet!['ot_gambar'],
                            width: 320,
                          ),
                        ),
                        fit: BoxFit.cover,
                      )
                    : const DecorationImage(
                        image: AssetImage(
                          'assets/icons/logo/logo_final_with_frame.webp',
                        ),
                        fit: BoxFit.contain,
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outlet?['ot_nama'] ?? "Ayo Cuci Laundry",
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                      fontSize: 16,
                      fontWeight: AppFont.w700,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    auth.userName ?? 'User',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: AppFont.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    auth.userRole ?? 'Owner',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      fontSize: 12,
                      fontWeight: AppFont.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeBannerSection() {
    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/aktivasi-akun'),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(
              radius: 24,
              shadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.extension_rounded,
                    color: Color(0xFF2C3E50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Tingkatkan Bisnis Anda",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                      Text(
                        "Aktifkan Fitur tambahan untuk lebih maksimal",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: AppFont.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        _buildMenuItem(
          _getIconPath("ic_referal.webp"),
          "Undang Teman",
          "Dapatkan bonus jutaan rupiah",
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReferralPage()),
          ),
        ),
      ],
    );
  }

  Widget _buildKoinGradientCard(String koin) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const KoinManagementScreen()),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppPalette.brandGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.colored(AppPalette.primary),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: AppAssetImage(
                  'assets/icons/ic_koin.webp',
                  width: 32,
                  height: 32,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Koin Anda Saat Ini",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: AppFont.w600,
                      ),
                    ),
                    Text(
                      koin,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Top Up Koin",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppPalette.primary,
                    fontWeight: AppFont.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(title, style: _sectionTitleStyle(context)),
    );
  }

  Widget _buildMenuItem(
    String iconPath,
    String title,
    String sub, {
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: AppBorderSides.card,
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: _buildLeadingIcon(iconPath),
          title: Text(title, style: _menuTitleStyle(context)),
          subtitle: Text(sub, style: _menuSubtitleStyle(context)),
          trailing: const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem(
    String iconPath,
    String title,
    String sub, {
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.cardSoft,
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: AppBorderSides.card,
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: _buildLeadingIcon(iconPath),
            title: Text(title, style: _menuTitleStyle(context)),
            subtitle: Text(sub, style: _menuSubtitleStyle(context)),
            iconColor: AppPalette.primary,
            collapsedIconColor: Colors.grey,
            childrenPadding: EdgeInsets.zero,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFFAFBFC),
                  border: Border(top: BorderSide(color: Color(0xFFEFF1F4))),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(String iconPath) {
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: AppAssetImage(
        iconPath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildSubMenuTile(IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppPalette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppPalette.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 13,
                    fontWeight: AppFont.w600,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: auth.isLoading
            ? null
            : () => _showLogoutConfirmation(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: const Text(
          "LOGOUT",
          style: TextStyle(
            color: Colors.white,
            letterSpacing: 1.1,
            fontWeight: AppFont.w700,
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    HapticFeedback.mediumImpact();
    final rootContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: AppPalette.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        "Keluar dari akun?",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: AppFont.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Anda perlu login kembali untuk memakai aplikasi ini.",
                  style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                    fontWeight: AppFont.w500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          foregroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          "Batal",
                          style: TextStyle(fontWeight: AppFont.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          rootContext.read<SettingProvider>().clearData();
                          rootContext.read<AppProvider>().logout();
                          await rootContext.read<AuthProvider>().logout();
                          if (!rootContext.mounted) return;
                          Navigator.pushNamedAndRemoveUntil(
                            rootContext,
                            '/login',
                            (route) => false,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text(
                          "Keluar",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: AppFont.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
