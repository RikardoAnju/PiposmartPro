import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class UploadImageHelper {
  /// Compresses [file] to a JPEG suitable for upload.
  ///
  /// Tries native platform compression first (Android BitmapFactory / iOS
  /// UIImage), which can decode HEIC/HEIF, WebP, and anything else the OS can
  /// display, and always outputs JPEG — the format the backend expects. This
  /// matters for receipts saved/downloaded from banking apps, which are often
  /// HEIC: the pure-Dart `image` package can't decode HEIC, so those files
  /// used to pass through untouched and get rejected server-side with
  /// "format file tidak didukung". The Dart path is kept as a fallback, and
  /// the original file as a last resort.
  static Future<File> compressImage(
    File file, {
    int maxWidth = 1280,
    int quality = 80,
    String prefix = 'upload',
  }) async {
    final native = await _compressNative(
      file,
      maxWidth: maxWidth,
      quality: quality,
      prefix: prefix,
    );
    if (native != null) return native;

    final dart = await _compressDart(
      file,
      maxWidth: maxWidth,
      quality: quality,
      prefix: prefix,
    );
    if (dart != null) return dart;

    debugPrint('compressImage: falling back to original file (undecodable)');
    return file;
  }

  static Future<File?> _compressNative(
    File file, {
    required int maxWidth,
    required int quality,
    required String prefix,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: maxWidth,
        minHeight: maxWidth,
        quality: quality,
        format: CompressFormat.jpeg,
      );

      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      debugPrint('compressImage native path failed: $e');
      return null;
    }
  }

  static Future<File?> _compressDart(
    File file, {
    required int maxWidth,
    required int quality,
    required String prefix,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;

      img.Image processed = decoded;
      if (decoded.width > maxWidth) {
        processed = img.copyResize(decoded, width: maxWidth);
      }

      final compressedBytes = Uint8List.fromList(
        img.encodeJpg(processed, quality: quality),
      );

      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await outFile.writeAsBytes(compressedBytes, flush: true);
      return outFile;
    } catch (e) {
      debugPrint('compressImage dart path failed: $e');
      return null;
    }
  }
}
