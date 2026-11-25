import 'package:flutter/material.dart';

class AppAssetImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final AlignmentGeometry alignment;
  final Widget? errorWidget;
  final int? cacheWidth;
  final int? cacheHeight;

  const AppAssetImage(
    this.path, {
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
    this.colorBlendMode,
    this.filterQuality = FilterQuality.medium,
    this.isAntiAlias = false,
    this.alignment = Alignment.center,
    this.errorWidget,
    this.cacheWidth,
    this.cacheHeight,
  });

  int? _effectiveCacheWidth(BuildContext context) {
    if (cacheWidth != null) return cacheWidth;
    if (width == null) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return (width! * dpr).round();
  }

  int? _effectiveCacheHeight(BuildContext context) {
    if (cacheHeight != null) return cacheHeight;
    if (height == null) return null;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    return (height! * dpr).round();
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      alignment: alignment,
      gaplessPlayback: true,
      cacheWidth: _effectiveCacheWidth(context),
      cacheHeight: _effectiveCacheHeight(context),
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            const Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey,
            );
      },
    );
  }
}
