import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ayocucinew/shared/widgets/app_asset_image.dart';
import '../../data/models/notif_model.dart';
import '../../core/utils/api_client.dart';
import '../../shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';
import '../../core/service/notification_navigation_service.dart';

class NotificationDetailScreen extends StatelessWidget {
  final NotifModel notif;

  const NotificationDetailScreen({super.key, required this.notif});

  Map<String, dynamic> _getCategoryStyle(String category) {
    switch (category.toUpperCase()) {
      case 'PROMO':
        return {
          'asset': 'assets/icons/notification/Promo.webp',
          'color': AppPalette.primaryDeep,
          'bg': AppPalette.primarySoft,
        };
      case 'INFO':
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'color': AppPalette.primaryDeep,
          'bg': AppPalette.primarySoft,
        };
      case 'SYSTEM':
      case 'ANNOUNCEMENT':
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'color': AppPalette.primaryDeep,
          'bg': AppPalette.primarySoft,
        };
      case 'REFERRAL':
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'color': const Color(0xFF16A34A),
          'bg': const Color(0xFFEAFBF0),
        };
      default:
        return {
          'asset': 'assets/icons/notification/Notif.webp',
          'color': Colors.grey,
          'bg': const Color(0xFFF1F3F5),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getCategoryStyle(notif.kategori);
    final imageUrl = _resolveImageUrl(notif.imageUrl);
    final hasAction = NotificationNavigationService.hasUsefulAction(
      notif.payload,
    );

    return AppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Detail Notifikasi",
          style: TextStyle(fontWeight: AppFont.w800, fontSize: 16),
        ),
      ),
      body: SingleChildScrollView(
        // Padding bottom besar supaya konten tidak tertutup floating pill
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 44,
                  width: 44,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: style['bg'],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppAssetImage(
                    style['asset'] as String,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    errorWidget: Icon(
                      Icons.notifications_none_rounded,
                      color: style['color'],
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif.judul.toUpperCase(),
                        style: TextStyle(
                          color: style['color'],
                          fontWeight: AppFont.w900,
                          fontSize: 13,
                          letterSpacing: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        DateFormat(
                          'dd MMMM yyyy, HH:mm',
                          'id_ID',
                        ).format(notif.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Divider(thickness: 1, color: Color(0xFFF1F3F5)),
            ),
            if (imageUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1.95,
                  child: AppCachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 1280,
                    maxWidthDiskCache: 1280,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              notif.pesan,
              style: TextStyle(
                fontSize: 15,
                height: 1.72,
                color: Colors.grey[800],
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
      // --- FLOATING PILL BUTTON 75% WIDTH ---
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SafeArea(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.75, // Lebar 75%
          height: 56,
          child: FloatingActionButton.extended(
            onPressed: () async {
              if (hasAction) {
                await NotificationNavigationService.open(notif.payload);
                return;
              }
              if (context.mounted) Navigator.pop(context);
            },
            elevation: 8,
            backgroundColor: AppPalette.primaryDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30), // Pill Shape
            ),
            label: Text(
              hasAction
                  ? (notif.ctaLabel?.trim().isNotEmpty == true
                        ? notif.ctaLabel!.toUpperCase()
                        : 'BUKA SELENGKAPNYA')
                  : 'KEMBALI',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: AppFont.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _resolveImageUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return ApiClient.resolveImageVariantUrl(path, width: 1280, quality: 82);
  }
}
