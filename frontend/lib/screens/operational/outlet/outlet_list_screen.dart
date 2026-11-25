import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
// lib/screens/operational/outlet/outlet_list_screen.dart

import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/api_client.dart';
import '../../../providers/app_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/custom_toast.dart';
import '../../../data/models/outlet_model.dart'; // Import model
import 'add_outlet_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class OutletListScreen extends StatefulWidget {
  const OutletListScreen({super.key});

  @override
  State<OutletListScreen> createState() => _OutletListScreenState();
}

class _OutletListScreenState extends State<OutletListScreen> {
  // Local state untuk melacak outlet mana yang sedang diproses pindah
  String? _processingOutletId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProv = context.read<AppProvider>();
      // Ambil profile aktif dan daftar list secara paralel
      Future.wait([appProv.fetchOutletProfile(), appProv.fetchUserOutlets()]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProv = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final isOwner = auth.actorType == 'user';

    // Ambil ID outlet aktif langsung dari model Outlet di AppProvider
    final activeId = appProv.outlet?.id;

    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isOwner ? "Manajemen Outlet" : "Pilih Outlet",
          style: TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: AppFont.w800,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: !isOwner
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.68,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddOutletScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: 10,
                      shadowColor: AppPalette.primary.withValues(alpha: 0.4),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_business_rounded, size: 20),
                        SizedBox(width: 10),
                        Text(
                          "TAMBAH OUTLET",
                          style: TextStyle(
                            fontWeight: AppFont.w900,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
      body: appProv.isLoading && appProv.outlets.isEmpty
          ? const OutletListSkeleton()
          : RefreshIndicator(
              onRefresh: () async {
                await Future.wait([
                  appProv.fetchOutletProfile(force: true),
                  appProv.fetchUserOutlets(),
                ]);
              },
              color: AppPalette.primary,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                itemCount: appProv.outlets.length,
                itemBuilder: (context, index) {
                  // Menggunakan object Outlet hasil mapping Provider
                  final Outlet item = appProv.outlets[index];
                  final String currentLoopId = item.id;

                  final isSelected = currentLoopId == activeId;
                  final isItemProcessing = _processingOutletId == currentLoopId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? AppPalette.primary
                            : Colors.grey.shade100,
                        width: 2,
                      ),
                      boxShadow: AppShadows.card,
                    ),
                    child: Row(
                      children: [
                        _buildOutletImage(item.gambar),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nama,
                                style: const TextStyle(
                                  fontWeight: AppFont.w900,
                                  fontSize: 15,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.alamat ?? "Alamat belum diatur",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (isSelected)
                          const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppPalette.primary,
                                size: 24,
                              ),
                              Text(
                                "Aktif",
                                style: TextStyle(
                                  color: AppPalette.primary,
                                  fontSize: 11,
                                  fontWeight: AppFont.w900,
                                ),
                              ),
                            ],
                          )
                        else
                          _buildSwitchButton(
                            context,
                            currentLoopId,
                            isItemProcessing,
                            appProv,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildOutletImage(String? path) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        shape: BoxShape.circle,
        image: path != null && path.isNotEmpty
            ? DecorationImage(
                // Menggunakan path dari model Outlet
                image: CachedNetworkImageProvider(
                  ApiClient.resolveImageVariantUrl(path, width: 360),
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
    );
  }

  Widget _buildSwitchButton(
    BuildContext context,
    String outletId,
    bool isProcessing,
    AppProvider prov,
  ) {
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: (_processingOutletId != null)
            ? null
            : () async {
                HapticFeedback.mediumImpact();
                setState(() => _processingOutletId = outletId);

                final safeContext = context;
                final res = await prov.switchOutlet(outletId);

                if (!mounted || !safeContext.mounted) return;
                setState(() => _processingOutletId = null);
                CustomToast.show(
                  safeContext,
                  message: res['message'],
                  isError: !res['success'],
                );
                if (res['success']) Navigator.pop(safeContext);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: AppCircularLoader(color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                "Pindah",
                style: TextStyle(fontSize: 12, fontWeight: AppFont.w900),
              ),
      ),
    );
  }
}
