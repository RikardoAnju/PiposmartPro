import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Melacak seberapa sering tiap layanan (productId) ditambahkan ke order,
/// disimpan lokal per perangkat. Dipakai untuk mengurutkan chip "Tambah Cepat"
/// dari yang paling sering dipakai — tanpa perlu perubahan backend.
class ServiceUsageTracker {
  static const String _key = 'service_usage_counts_v1';

  /// Ambil map {productId: jumlahPemakaian}.
  static Future<Map<String, int>> getCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Tambah satu hitungan pemakaian untuk sebuah layanan.
  static Future<void> record(String productId) async {
    if (productId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final counts = await getCounts();
    counts[productId] = (counts[productId] ?? 0) + 1;
    await prefs.setString(_key, jsonEncode(counts));
  }
}
