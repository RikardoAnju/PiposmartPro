import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApiClient upload URL helpers', () {
    test('resolves legacy upload paths against plain API URL', () {
      expect(
        ApiClient.resolveUploadUrl('/uploads/content/banner.jpg'),
        'https://api-dev.ayocuci.id/uploads/content/banner.jpg',
      );
      expect(
        ApiClient.resolveUploadUrl('pengeluaran/bukti.jpg'),
        'https://api-dev.ayocuci.id/uploads/pengeluaran/bukti.jpg',
      );
    });

    test('keeps absolute URLs unchanged', () {
      expect(
        ApiClient.resolveUploadUrl('https://cdn.example.com/file.jpg'),
        'https://cdn.example.com/file.jpg',
      );
    });

    test('adds OSS image variant processing for Alibaba OSS URLs', () {
      final url = ApiClient.resolveImageVariantUrl(
        'https://ayocuci-data.oss-ap-southeast-3.aliyuncs.com/uploads/content/banner.jpg',
        width: 720,
        quality: 82,
      );

      expect(url, contains('x-oss-process='));
      expect(url, contains('image/resize,w_720'));
      expect(url, contains('quality,q_82'));
      expect(url, contains('format,webp'));
    });

    test('does not add OSS processing to non-OSS URLs', () {
      expect(
        ApiClient.resolveImageVariantUrl(
          'https://api.ayocuci.id/uploads/content/banner.jpg',
          width: 720,
        ),
        'https://api.ayocuci.id/uploads/content/banner.jpg',
      );
    });
  });
}
