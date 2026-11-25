import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppCachedNetworkImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final int? maxWidthDiskCache;
  final int? maxHeightDiskCache;

  const AppCachedNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.memCacheWidth,
    this.memCacheHeight,
    this.maxWidthDiskCache,
    this.maxHeightDiskCache,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return errorWidget ?? const SizedBox.shrink();
    }

    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final resolvedMemCacheWidth =
        memCacheWidth ?? _resolveCacheDimension(width, pixelRatio);
    final resolvedMemCacheHeight =
        memCacheHeight ?? _resolveCacheDimension(height, pixelRatio);
    final resolvedDiskCacheWidth = maxWidthDiskCache ?? resolvedMemCacheWidth;
    final resolvedDiskCacheHeight =
        maxHeightDiskCache ?? resolvedMemCacheHeight;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: resolvedMemCacheWidth,
      memCacheHeight: resolvedMemCacheHeight,
      maxWidthDiskCache: resolvedDiskCacheWidth,
      maxHeightDiskCache: resolvedDiskCacheHeight,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      useOldImageOnUrlChange: true,
      placeholder: (_, _) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (_, _, _) => errorWidget ?? const SizedBox.shrink(),
    );
  }

  int? _resolveCacheDimension(double? logicalSize, double pixelRatio) {
    if (logicalSize == null || !logicalSize.isFinite || logicalSize <= 0) {
      return null;
    }
    return (logicalSize * pixelRatio).round().clamp(1, 4096);
  }
}
