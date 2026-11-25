import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Konversi logo untuk printer thermal (1-bit).
///
/// SATU sumber kebenaran: dipakai untuk (a) menghasilkan byte ESC/POS saat
/// cetak, dan (b) menghasilkan PNG pratinjau di layar upload. Karena keduanya
/// dari proses yang sama, apa yang dilihat user saat upload = yang tercetak.
class LogoThermal {
  const LogoThermal._();

  /// Jumlah dot area cetak menurut lebar kertas (mm).
  static int paperDots(int paperWidth) =>
      paperWidth >= 80 ? 576 : 384;

  /// Lebar logo (dot) — default ~68% lebar kertas agar ada margin dan tetap
  /// besar/jelas.
  static int defaultLogoWidth(int paperWidth) =>
      (paperDots(paperWidth) * 0.68).round();

  /// Ubah gambar (warna apa pun) menjadi monokrom 1-bit dengan Floyd–Steinberg
  /// dithering. Hasilnya: Image di mana setiap piksel hitam (0) atau putih
  /// (255) — persis yang bisa dicetak printer thermal.
  static img.Image? toMonochrome(Uint8List bytes, {required int targetWidth}) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    var im = img.copyResize(decoded, width: targetWidth);
    im = img.grayscale(im);
    // Kontras sedikit dinaikkan agar area terang tidak lenyap total.
    im = img.contrast(im, contrast: 115);

    final w = im.width;
    final h = im.height;

    // Buffer luminance (double) untuk menyebar error dithering.
    final buf = List<double>.filled(w * h, 0);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        buf[y * w + x] = img.getLuminance(im.getPixel(x, y)).toDouble();
      }
    }

    // Floyd–Steinberg.
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final i = y * w + x;
        final oldV = buf[i];
        final newV = oldV < 128 ? 0.0 : 255.0;
        final err = oldV - newV;
        buf[i] = newV;
        if (x + 1 < w) buf[i + 1] += err * 7 / 16;
        if (y + 1 < h) {
          if (x > 0) buf[i + w - 1] += err * 3 / 16;
          buf[i + w] += err * 5 / 16;
          if (x + 1 < w) buf[i + w + 1] += err * 1 / 16;
        }
      }
    }

    final out = img.Image(width: w, height: h);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final v = buf[y * w + x] < 128 ? 0 : 255;
        out.setPixelRgb(x, y, v, v, v);
      }
    }
    return out;
  }

  /// PNG untuk pratinjau di layar (hasil monokrom apa adanya).
  static Uint8List previewPng(img.Image mono) =>
      Uint8List.fromList(img.encodePng(mono));

  /// Byte ESC/POS raster (GS v 0) yang sudah di-CENTER: bitmap dibuat selebar
  /// penuh area cetak lalu logo ditaruh di tengah (offset horizontal). GS v 0
  /// mengabaikan ESC a, jadi centering harus lewat padding seperti ini.
  static List<int> escPosCentered(img.Image mono, {required int paperWidth}) {
    final fullW = paperDots(paperWidth);
    final logoW = mono.width;
    final h = mono.height;
    final offset = ((fullW - logoW) ~/ 2).clamp(0, fullW);
    final bytesPerRow = (fullW + 7) ~/ 8;

    final out = <int>[];
    out.addAll([0x1D, 0x76, 0x30, 0x00]); // GS v 0
    out.addAll([bytesPerRow % 256, bytesPerRow ~/ 256]);
    out.addAll([h % 256, h ~/ 256]);

    for (int y = 0; y < h; y++) {
      for (int xByte = 0; xByte < bytesPerRow; xByte++) {
        int byte = 0;
        for (int bit = 0; bit < 8; bit++) {
          final xFull = xByte * 8 + bit;
          final xImg = xFull - offset;
          if (xFull < fullW && xImg >= 0 && xImg < logoW) {
            if (img.getLuminance(mono.getPixel(xImg, y)) < 128) {
              byte |= (0x80 >> bit);
            }
          }
        }
        out.add(byte);
      }
    }
    return out;
  }
}
