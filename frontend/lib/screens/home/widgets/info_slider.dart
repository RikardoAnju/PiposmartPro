import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/api_client.dart';
import '../../../data/models/content_banner_model.dart';
import '../../../providers/content_provider.dart';
import '../../../shared/widgets/app_cached_network_image.dart';
import '../content_list_screen.dart';
import '../content_detail_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

class InfoSlider extends StatefulWidget {
  final bool isDarkBackground;
  const InfoSlider({super.key, this.isDarkBackground = false});

  @override
  State<InfoSlider> createState() => _InfoSliderState();
}

class _InfoSliderState extends State<InfoSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ContentProvider>(
      builder: (context, provider, _) {
        final infos = provider.infos;
        if (infos.isEmpty) return const SizedBox.shrink();
        return _InfoContentSlider(
          items: infos,
          pageController: _pageController,
          currentPage: _currentPage.clamp(0, infos.length - 1),
          onPageChanged: (index) => setState(() => _currentPage = index),
          isDarkBackground: widget.isDarkBackground,
        );
      },
    );
  }
}

class _InfoContentSlider extends StatelessWidget {
  final List<ContentBannerModel> items;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  final bool isDarkBackground;

  const _InfoContentSlider({
    required this.items,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
    this.isDarkBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    const imageAspectRatio = 16 / 9;
    const titleStripHeight = 40.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 108, minHeight: 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDarkBackground
                      ? Colors.white.withValues(alpha: 0.2)
                      : const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Informasi',
                  style: TextStyle(
                    color: isDarkBackground ? Colors.white : AppPalette.primary,
                    fontSize: 12,
                    fontWeight: AppFont.w800,
                    height: 1,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ContentListScreen()),
                ),
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: isDarkBackground
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppPalette.primary,
                    fontSize: 12,
                    fontWeight: AppFont.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            const horizontalMargin = 40.0;
            const verticalSafetyBuffer = 4.0;
            final cardWidth = constraints.maxWidth - horizontalMargin;
            final imageHeight = cardWidth / imageAspectRatio;
            final sliderHeight =
                imageHeight + titleStripHeight + verticalSafetyBuffer;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: sliderHeight,
              child: PageView.builder(
                controller: pageController,
                onPageChanged: onPageChanged,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ContentDetailScreen(content: item),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: AppDecorations.card(
                        radius: 20,
                        shadow: AppShadows.card,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                            child: SizedBox(
                              height: imageHeight,
                              width: double.infinity,
                              child: AppCachedNetworkImage(
                                imageUrl: _resolveImageUrl(item.imageUrl),
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: Container(
                                  color: Colors.grey.shade50,
                                ),
                                errorWidget: Container(
                                  color: AppPalette.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: AppPalette.primary,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: titleStripHeight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textHeightBehavior:
                                      const TextHeightBehavior(
                                        applyHeightToFirstAscent: false,
                                        applyHeightToLastDescent: false,
                                      ),
                                  style: const TextStyle(
                                    color: Color(0xFF1F2A37),
                                    fontSize: 14,
                                    fontWeight: AppFont.w800,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            items.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: currentPage == index
                    ? AppPalette.primary
                    : AppPalette.primaryBorderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _resolveImageUrl(String path) {
    return ApiClient.resolveImageVariantUrl(path, width: 720);
  }
}
