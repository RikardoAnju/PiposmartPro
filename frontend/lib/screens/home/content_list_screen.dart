import 'package:ayocucinew/shared/widgets/app_scaffold.dart';
import 'package:ayocucinew/core/theme/app_font.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/data/models/content_banner_model.dart';
import 'package:ayocucinew/providers/content_provider.dart';
import 'package:ayocucinew/shared/widgets/app_cached_network_image.dart';
import 'package:ayocucinew/shared/widgets/app_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'content_detail_screen.dart';
import 'package:ayocucinew/core/theme/app_palette.dart';

enum ContentListFilter { all, promo, informasi }

class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  ContentListFilter _filter = ContentListFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ContentProvider>();
      if (provider.items.isEmpty) {
        provider.fetchContent();
      }
    });
  }

  List<ContentBannerModel> _filteredItems(ContentProvider provider) {
    switch (_filter) {
      case ContentListFilter.promo:
        return provider.promos;
      case ContentListFilter.informasi:
        return provider.infos;
      case ContentListFilter.all:
        return provider.items;
    }
  }

  String _resolveImageUrl(String path) {
    return ApiClient.resolveImageVariantUrl(path, width: 640);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Promo & Informasi',
          style: TextStyle(fontWeight: AppFont.w800, fontSize: 16),
        ),
      ),
      body: Consumer<ContentProvider>(
        builder: (context, provider, _) {
          final items = _filteredItems(provider);

          if (provider.isLoading && provider.items.isEmpty) {
            return const _ContentListSkeleton();
          }

          return RefreshIndicator(
            color: AppPalette.primary,
            onRefresh: () => provider.fetchContent(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedFilterHeader(
                    minHeight: 52,
                    maxHeight: 52,
                    child: Container(
                      color: const Color(0xFFF8F9FA),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      alignment: Alignment.centerLeft,
                      child: _FilterBar(
                        selected: _filter,
                        onChanged: (value) => setState(() => _filter = value),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                if (items.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'Belum ada konten untuk kategori ini',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: AppFont.w600,
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = items[index];
                        return _ContentListCard(
                          item: item,
                          imageUrl: _resolveImageUrl(item.imageUrl),
                        );
                      }, childCount: items.length),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PinnedFilterHeader extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _PinnedFilterHeader({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedFilterHeader oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}

class _FilterBar extends StatelessWidget {
  final ContentListFilter selected;
  final ValueChanged<ContentListFilter> onChanged;

  const _FilterBar({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: 'Semua',
            active: selected == ContentListFilter.all,
            onTap: () => onChanged(ContentListFilter.all),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Promo',
            active: selected == ContentListFilter.promo,
            onTap: () => onChanged(ContentListFilter.promo),
          ),
          const SizedBox(width: 10),
          _FilterChip(
            label: 'Informasi',
            active: selected == ContentListFilter.informasi,
            onTap: () => onChanged(ContentListFilter.informasi),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppPalette.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppPalette.primary : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : const Color(0xFF6B7280),
            fontWeight: AppFont.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ContentListCard extends StatelessWidget {
  final ContentBannerModel item;
  final String imageUrl;

  const _ContentListCard({required this.item, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ContentDetailScreen(content: item)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: AppDecorations.card(radius: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: AppCachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: const ColoredBox(color: Color(0xFFF3F4F6)),
                  errorWidget: Container(
                    color: const Color(0xFFF3F4F6),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.category == 'PROMO' ? 'Promo' : 'Informasi',
                      style: const TextStyle(
                        color: AppPalette.primary,
                        fontSize: 11,
                        fontWeight: AppFont.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: AppFont.w900,
                      color: Color(0xFF111827),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.summary.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.summary,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(item.publishedAt),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: AppFont.w700,
                      color: Color(0xFF9CA3AF),
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
}

class _ContentListSkeleton extends StatelessWidget {
  const _ContentListSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Row(
            children: const [
              AppSkeletonBox(width: 78, height: 36, radius: 999),
              SizedBox(width: 10),
              AppSkeletonBox(width: 70, height: 36, radius: 999),
              SizedBox(width: 10),
              AppSkeletonBox(width: 92, height: 36, radius: 999),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(
            4,
            (_) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(height: 180, radius: 18),
                  Padding(
                    padding: EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppSkeletonBox(width: 70, height: 22, radius: 999),
                        SizedBox(height: 10),
                        AppSkeletonBox(height: 16, radius: 8),
                        SizedBox(height: 8),
                        AppSkeletonBox(height: 12, radius: 8),
                        SizedBox(height: 6),
                        AppSkeletonBox(width: 100, height: 11, radius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
