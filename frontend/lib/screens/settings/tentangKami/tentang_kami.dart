import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/screens/auth/legal/kebijakan_privasi.dart';
import 'package:ayocucinew/screens/auth/legal/syarat_dan_ketentuan.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../../providers/setting_provider.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class TentangKamiPage extends StatelessWidget {
  const TentangKamiPage({super.key});

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String? email) async {
    if (email == null || email.isEmpty) return;
    final Uri uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    String formattedPhone = phone;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = '62${formattedPhone.substring(1)}';
    }
    final Uri uri = Uri.parse('https://wa.me/$formattedPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppPalette.primary,
              AppPalette.primaryWarm,
            ],
            stops: [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Consumer<SettingProvider>(
                builder: (context, provider, child) {
                  final settings = provider.appSettings;
                  final isLoading = provider.isLoading;

                  final whatsapp = settings?['whatsapp_number'] as String?;
                  final instagram = settings?['instagram_username'] as String?;
                  final facebook = settings?['facebook_username'] as String?;
                  final email = settings?['email'] as String?;
                  final tiktok = settings?['tiktok_username'] as String?;
                  final website = settings?['website_url'] as String?;
                  final playstore = settings?['playstore_url'] as String?;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // HEADER
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.arrow_back_ios_new,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Kembali',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: AppFont.w600,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 30),

                      // LOGO
                      Image.asset(
                        'assets/icons/ic_logo_home.webp',
                        height: 50,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.local_laundry_service,
                            size: 80,
                            color: Colors.white,
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // TITLE
                      const Text(
                        'Tentang Kami',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: AppFont.w700,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // SUBTITLE
                      const Text(
                        'Solusi kasir laundry untuk mengelola transaksi dan operasional secara mudah dan efisien.',
                        textAlign: TextAlign.center,
                        softWrap: true,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // SECTION TITLE
                      const Text(
                        'HUBUNGI KAMI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: AppFont.w700,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // LOADING
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      else ...[
                        // WHATSAPP
                        if (whatsapp != null && whatsapp.isNotEmpty) ...[
                          _contactItem(
                            iconWidget: _buildCircleIcon(
                              Icons.wechat,
                              Colors.green,
                            ),
                            text: whatsapp,
                            onTap: () => _launchWhatsApp(whatsapp),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // INSTAGRAM
                        if (instagram != null && instagram.isNotEmpty) ...[
                          _contactItem(
                            iconWidget: _buildCircleIconInstagram(),
                            text: instagram.startsWith('@')
                                ? instagram
                                : '@$instagram',
                            onTap: () => _launchUrl(
                              'https://instagram.com/${instagram.replaceAll('@', '')}',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // FACEBOOK
                        if (facebook != null && facebook.isNotEmpty) ...[
                          _contactItem(
                            iconWidget: _buildCircleIcon(
                              Icons.facebook,
                              const Color(0xFF1877F2),
                            ),
                            text: facebook,
                            onTap: () =>
                                _launchUrl('https://facebook.com/$facebook'),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // EMAIL
                        if (email != null && email.isNotEmpty) ...[
                          _contactItem(
                            iconWidget: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                Icons.email,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            text: email,
                            onTap: () => _launchEmail(email),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // TIKTOK
                        if (tiktok != null && tiktok.isNotEmpty) ...[
                          _contactItem(
                            iconWidget: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                Icons.music_note,
                                color: Colors.black,
                                size: 24,
                              ),
                            ),
                            text: tiktok.startsWith('@') ? tiktok : '@$tiktok',
                            onTap: () => _launchUrl(
                              'https://tiktok.com/@${tiktok.replaceAll('@', '')}',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // WEBSITE
                        if (website != null && website.isNotEmpty) ...[
                          _contactItem(
                            iconWidget: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(
                                Icons.language,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            text: website
                                .replaceAll('https://', '')
                                .replaceAll('http://', ''),
                            onTap: () => _launchUrl(
                              website.startsWith('http')
                                  ? website
                                  : 'https://$website',
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // SYARAT & KETENTUAN
                        _contactItem(
                          iconWidget: Image.asset(
                            'assets/icons/ic_t&c.webp',
                            width: 30,
                            height: 30,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.description,
                                  color: Colors.white,
                                  size: 26,
                                ),
                          ),
                          text: 'Syarat & Ketentuan',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SyaratKetentuanPage(),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // KEBIJAKAN PRIVASI
                        _contactItem(
                          iconWidget: Image.asset(
                            'assets/icons/ic_kebijakan_privasi.webp',
                            width: 30,
                            height: 30,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.privacy_tip,
                                  color: Colors.white,
                                  size: 26,
                                ),
                          ),
                          text: 'Kebijakan Privasi',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const KebijakanPrivasiPage(),
                            ),
                          ),
                        ),

                        if (defaultTargetPlatform == TargetPlatform.android) ...[
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: () {
                              if (playstore != null && playstore.isNotEmpty) {
                                _launchUrl(playstore);
                              }
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 18,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppPalette.primary,
                                    AppPalette.primaryDeep,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.star_border,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Beri Rating',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: AppFont.w700,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Dukung kami di Playstore',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],

                      const SizedBox(height: 40),

                      Text(
                        ' AYOCUCI 2026',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: AppFont.w600,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIcon(IconData iconData, Color color) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(iconData, color: color, size: 18)),
    );
  }

  Widget _buildCircleIconInstagram() {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              colors: [Colors.purple, Colors.pink, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds);
          },
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _contactItem({
    required Widget iconWidget,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            SizedBox(width: 30, child: Center(child: iconWidget)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: AppFont.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 22),
          ],
        ),
      ),
    );
  }
}
