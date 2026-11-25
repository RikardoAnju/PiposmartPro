import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/providers/app_provider.dart';
import 'package:ayocucinew/providers/auth_provider.dart';
import 'package:ayocucinew/screens/settings/outlet/metode_pembayaran/list_metode_pembayaran.dart';
import 'package:ayocucinew/screens/settings/outlet/edit_profile_outlet_screen.dart'; // Import Screen Baru
import 'package:ayocucinew/screens/settings/outlet/widgets/modal_pengaturan_outlet.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class KonfigurasiProfilOutletPage extends StatefulWidget {
  const KonfigurasiProfilOutletPage({super.key});

  @override
  State<KonfigurasiProfilOutletPage> createState() =>
      _KonfigurasiProfilOutletPageState();
}

class _KonfigurasiProfilOutletPageState
    extends State<KonfigurasiProfilOutletPage> {
  @override
  void initState() {
    super.initState();
    _loadOutletData();
  }

  Future<void> _loadOutletData() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AppProvider>().fetchOutletProfile();
      }
    });
  }

  // NAVIGASI KE SCREEN EDIT PROFIL (PENGGANTI MODAL)
  void _navigateToEditProfile() {
    final auth = context.read<AuthProvider>();
    if (!auth.isOwnerOrAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya owner/admin yang dapat mengubah profil outlet.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileOutletScreen()),
    ).then((_) => _loadOutletData()); // Refresh data saat kembali
  }

  Future<void> _showModalPengaturanOutlet() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const ModalPengaturanOutlet(initialSkipProses: false),
    );
    if (result != null && mounted) {
      debugPrint('Skip Proses diubah menjadi: $result');
    }
  }

  void navigateToPaymentMethod() {
    final provider = context.read<AppProvider>();
    final profile = provider
        .outlet; // Ambil data outlet langsung dari model Outlet di AppProvider

    if (profile != null) {
      final outletId = profile.id; // Ambil ID outlet dari model
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PaymentMethodPage(outletId: outletId.toString()),
        ),
      );
    } else {
      _showErrorSnackBar();
    }
  }

  void _showErrorSnackBar() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data profil belum siap. Silakan tarik layar.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEditOutlet = context.watch<AuthProvider>().isOwnerOrAdmin;

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
          'Konfigurasi Profil Outlet',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: AppFont.w800,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<AppProvider>().fetchOutletProfile(),
        color: AppPalette.primary,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildSettingCard(
              context,
              title: 'Edit Profile Outlet',
              subtitle: canEditOutlet
                  ? 'Edit nama, nomor HP, dan lokasi outlet'
                  : 'Hanya owner/admin yang dapat mengubah profil outlet',
              onTap: _navigateToEditProfile, // Panggil Screen Baru
              enabled: canEditOutlet,
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              context,
              title: 'Pengaturan Outlet',
              subtitle: 'Atur sistem proses dan operasional',
              onTap: _showModalPengaturanOutlet,
            ),
            const SizedBox(height: 12),
            _buildSettingCard(
              context,
              title: 'Pengaturan Metode Pembayaran',
              subtitle: 'Kelola QRIS, Tunai, dan Bank Transfer',
              onTap: navigateToPaymentMethod,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? AppPalette.primary.withValues(alpha: 0.1)
                : const Color(0xFFE5E7EB),
          ),
          boxShadow: enabled ? AppShadows.card : AppShadows.cardSoft,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: AppFont.w700,
                      color: enabled
                          ? const Color(0xFF2C3E50)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: enabled ? Colors.grey[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              enabled ? Icons.arrow_forward_ios : Icons.lock_outline_rounded,
              size: 14,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
