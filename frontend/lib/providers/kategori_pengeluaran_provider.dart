import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/models/kategori_pengeluaran_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';

class KategoriPengeluaranProvider extends ChangeNotifier {
  List<KategoriPengeluaran> _kategoriList = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<KategoriPengeluaran> get kategoriList => _kategoriList;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  final String _baseUrl = "/expenses/categories";

  String? _getToken() => AuthStorage.token;

  String _normalizeErrorMessage(dynamic rawMessage) {
    final message = rawMessage?.toString().trim() ?? '';
    final lower = message.toLowerCase();

    if (lower.contains('duplicate') ||
        lower.contains('error 1062') ||
        lower.contains('sudah ada')) {
      return 'Nama kategori ini sudah ada. Pakai nama lain ya.';
    }

    if (lower.contains('connection') || lower.contains('koneksi')) {
      return 'Koneksi lagi bermasalah. Coba lagi sebentar ya.';
    }

    if (message.isEmpty) return 'Kategori belum bisa disimpan. Coba lagi ya.';
    return message;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> fetchKategoriPengeluaran() async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final token = _getToken();
      final response = await ApiClient.get(_baseUrl, token: token);
      final result = jsonDecode(response.body);

      // PERBAIKAN: Cek status sebagai boolean sesuai log I/flutter
      if (response.statusCode == 200 && result['status'] == true) {
        if (result['data'] != null) {
          _kategoriList = (result['data'] as List)
              .map((e) => KategoriPengeluaran.fromJson(e))
              .toList();
        } else {
          _kategoriList = [];
        }
      } else {
        _errorMessage = result['message'] ?? "Gagal mengambil data kategori";
        _kategoriList = [];
      }
    } catch (e) {
      _errorMessage = "Terjadi kesalahan koneksi: $e";
      _kategoriList = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> createKategoriPengeluaran(
    Map<String, dynamic> payload,
  ) async {
    _setLoading(true);
    try {
      final token = _getToken();
      final response = await ApiClient.post(
        _baseUrl,
        body: payload,
        token: token,
      );
      final result = jsonDecode(response.body);

      // PERBAIKAN: Cek status boolean true atau status code 201
      if (response.statusCode == 201 || result['status'] == true) {
        await fetchKategoriPengeluaran();
        return {
          'success': true,
          'message': result['message'] ?? 'Kategori berhasil dibuat',
        };
      }

      return {
        'success': false,
        'message': _normalizeErrorMessage(result['error'] ?? result['message']),
      };
    } catch (e) {
      return {'success': false, 'message': _normalizeErrorMessage(e)};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> updateKategoriPengeluaran(
    String id,
    Map<String, dynamic> payload,
  ) async {
    _setLoading(true);
    try {
      final token = _getToken();
      final response = await ApiClient.put(
        "$_baseUrl/$id",
        body: payload,
        token: token,
      );
      final result = jsonDecode(response.body);

      if (result['status'] == true) {
        await fetchKategoriPengeluaran();
        return {
          'success': true,
          'message': result['message'] ?? 'Kategori berhasil diperbarui',
        };
      }

      return {
        'success': false,
        'message': _normalizeErrorMessage(result['error'] ?? result['message']),
      };
    } catch (e) {
      return {'success': false, 'message': _normalizeErrorMessage(e)};
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> deleteKategoriPengeluaran(String id) async {
    _setLoading(true);
    try {
      final token = _getToken();
      final response = await ApiClient.delete("$_baseUrl/$id", token: token);
      final result = jsonDecode(response.body);

      if (result['status'] == true) {
        await fetchKategoriPengeluaran();
        return {
          'success': true,
          'message': result['message'] ?? 'Kategori berhasil dihapus',
        };
      }

      return {
        'success': false,
        'message': _normalizeErrorMessage(result['error'] ?? result['message']),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Kategori belum bisa dihapus. Coba lagi ya.',
      };
    } finally {
      _setLoading(false);
    }
  }
}
