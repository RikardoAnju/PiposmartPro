// lib/screens/home/widgets/home_header.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../providers/notification_provider.dart';
import '../../../shared/widgets/app_asset_image.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          SizedBox(
            height: 35, // kecilkan biar sejajar
            child: AppAssetImage(
              'assets/icons/ic_logo_home.webp',
              height: 35,
              fit: BoxFit.contain,
            ),
          ),

          // Bell Notifikasi
          _buildNotificationBell(context),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProv, _) {
        return Stack(
          alignment: Alignment.topRight,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pushNamed(context, '/notifications'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            if (notifProv.unreadCount > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppPalette.primaryDeep,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    notifProv.unreadCount > 9
                        ? '9+'
                        : notifProv.unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: AppFont.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
