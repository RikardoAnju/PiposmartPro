import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/api_client.dart';
import '../../../providers/report_provider.dart';

class ReportHeaderCard extends StatelessWidget {
  const ReportHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ReportProvider>().outletProfile;
    final String outletName = profile?['ot_nama'] ?? "Ayo Cuci Laundry";
    final String outletAddress = profile?['ot_alamat'] ?? "Alamat belum diatur";
    final String? imageUrl = profile?['ot_gambar'];

    return Column(
      children: [
        // Card Profil Outlet
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(radius: 16, shadow: AppShadows.card),
          child: Row(
            children: [
              // Gambar Outlet Dinamis
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppPalette.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(
                            ApiClient.resolveImageVariantUrl(
                              imageUrl,
                              width: 320,
                            ),
                          ),
                          fit: BoxFit.cover,
                        )
                      : const DecorationImage(
                          image: AssetImage(
                            'assets/icons/logo/logo_final_with_frame.webp',
                          ),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Nama & Greeting
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      outletName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: AppFont.w700,
                        color: Colors.grey.shade800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Halo teman cuci, ini laporan harian Anda!",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Tampilkan alamat di header sebagai pengganti badge lokasi
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 10,
                          color: AppPalette.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            outletAddress,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
