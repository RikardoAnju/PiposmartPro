import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../data/models/pengeluaran_model.dart';
import '../core/utils/api_client.dart';
import '../core/utils/auth_storage.dart';
import '../core/events/app_events.dart';
import '../core/utils/upload_image_helper.dart';

class PengeluaranProvider extends ChangeNotifier {
  List<Pengeluaran> _expenses = [];
  bool _isLoading = false;
  String? _activeStart;
  String? _activeEnd;

  // 🎧 Subscription untuk mendengarkan event global
  StreamSubscription? _eventSubscription;

  List<Pengeluaran> get expenses => _expenses;
  bool get isLoading => _isLoading;

  final String _baseUrl = "${ApiClient.baseUrl}/expenses";

  PengeluaranProvider() {
    _listenToEvents();
  }

  /// 🎧 Mendengarkan sinyal perpindahan outlet atau perubahan data
  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OutletSwitched) {
        debugPrint(
          "PengeluaranProvider: Outlet berpindah, mereset data lama...",
        );
        _resetData();
      } else if (event is ExpenseChanged) {
        if (_activeStart != null && _activeEnd != null) {
          refreshActiveRange(silent: true);
        }
      }
    });
  }

  /// Menghapus data lama pas pindah outlet biar gak "halusinasi" data lama
  void _resetData() {
    _expenses = [];
    _isLoading = false;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  /// Fetch list pengeluaran berdasarkan rentang tanggal
  Future<void> fetchExpenses({String? start, String? end}) async {
    _activeStart = start;
    _activeEnd = end;
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      if (token == null) return;

      String urlPath = "/expenses";
      if (start != null && end != null) urlPath += "?start=$start&end=$end";

      final response = await ApiClient.get(urlPath, token: token);
      final res = jsonDecode(response.body);

      if (response.statusCode == 200 && res['status'] == true) {
        final rawData = res['data'];
        if (rawData != null && rawData is List) {
          _expenses = rawData.map((e) => Pengeluaran.fromJson(e)).toList();
        } else {
          _expenses = [];
        }
      } else {
        _expenses = [];
      }
    } catch (e) {
      debugPrint("Error Fetch Expenses: $e");
      _expenses = []; // Fallback ke empty list jika error
    } finally {
      _setLoading(false);
    }
  }

  /// Membuat pengeluaran baru dengan upload file bukti
  Future<Map<String, dynamic>> createExpense({
    required String kategoriId,
    required double total,
    required String keterangan,
    required String tanggal,
    required List<File> images,
  }) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['kategori_id'] = kategoriId;
      request.fields['total'] = total.toString();
      request.fields['keterangan'] = keterangan;
      request.fields['tanggal'] = tanggal;

      for (var img in images) {
        final compressed = await UploadImageHelper.compressImage(
          img,
          maxWidth: 1280,
          quality: 80,
          prefix: 'expense',
        );
        request.files.add(
          await http.MultipartFile.fromPath('bukti', compressed.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final res = jsonDecode(response.body);

      if (response.statusCode == 201 || (res['status'] == true)) {
        final rawData = res['data'];
        if (rawData is Map<String, dynamic>) {
          _upsertExpense(Pengeluaran.fromJson(rawData));
        } else {
          await refreshActiveRange(silent: true);
        }

        appEventBus.add(ExpenseChanged());

        return {'success': true, 'message': res['message']};
      }

      return {
        'success': false,
        'message': res['message'] ?? res['error'] ?? 'Gagal simpan pengeluaran',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan sistem: $e'};
    } finally {
      _setLoading(false);
    }
  }

  /// Memperbarui data pengeluaran (Update)
  Future<Map<String, dynamic>> updateExpense({
    required String id,
    required String kategoriId,
    required double total,
    required String keterangan,
    required String tanggal,
    required List<File> images,
  }) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      var request = http.MultipartRequest('PUT', Uri.parse("$_baseUrl/$id"));

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['kategori_id'] = kategoriId;
      request.fields['total'] = total.toString();
      request.fields['keterangan'] = keterangan;
      request.fields['tanggal'] = tanggal;

      for (var img in images) {
        final compressed = await UploadImageHelper.compressImage(
          img,
          maxWidth: 1280,
          quality: 80,
          prefix: 'expense',
        );
        request.files.add(
          await http.MultipartFile.fromPath('bukti', compressed.path),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final res = jsonDecode(response.body);

      if (response.statusCode == 200 && res['status'] == true) {
        final rawData = res['data'];
        if (rawData is Map<String, dynamic>) {
          _upsertExpense(Pengeluaran.fromJson(rawData));
        } else {
          await refreshActiveRange(silent: true);
        }

        appEventBus.add(ExpenseChanged());

        return {'success': true, 'message': res['message']};
      }

      return {
        'success': false,
        'message': res['message'] ?? 'Gagal memperbarui pengeluaran',
      };
    } catch (e) {
      return {'success': false, 'message': 'Kesalahan sistem: $e'};
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshActiveRange({bool silent = false}) async {
    if (_activeStart == null || _activeEnd == null) return;
    if (!silent) {
      await fetchExpenses(start: _activeStart, end: _activeEnd);
      return;
    }

    try {
      final token = AuthStorage.token;
      if (token == null) return;
      final response = await ApiClient.get(
        "/expenses?start=$_activeStart&end=$_activeEnd",
        token: token,
      );
      final res = jsonDecode(response.body);
      if (response.statusCode == 200 && res['status'] == true) {
        final rawData = res['data'];
        _expenses = rawData is List
            ? rawData.map((e) => Pengeluaran.fromJson(e)).toList()
            : [];
        _sortExpenses();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error Refresh Active Expenses: $e");
    }
  }

  void _upsertExpense(Pengeluaran expense) {
    final inActiveRange = _isInActiveRange(expense.tanggal);
    final index = _expenses.indexWhere((item) => item.id == expense.id);

    if (!inActiveRange) {
      if (index != -1) {
        _expenses.removeAt(index);
        notifyListeners();
      }
      return;
    }

    if (index == -1) {
      _expenses.insert(0, expense);
    } else {
      _expenses[index] = expense;
    }
    _sortExpenses();
    notifyListeners();
  }

  bool _isInActiveRange(DateTime date) {
    if (_activeStart == null || _activeEnd == null) return true;

    final start = DateTime.tryParse(_activeStart!);
    final end = DateTime.tryParse(_activeEnd!);
    if (start == null || end == null) return true;

    final day = DateTime(date.year, date.month, date.day);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);

    return !day.isBefore(startDay) && !day.isAfter(endDay);
  }

  void _sortExpenses() {
    _expenses.sort((a, b) => b.tanggal.compareTo(a.tanggal));
  }

  /// Menghapus data pengeluaran
  Future<Map<String, dynamic>> deleteExpense(String id) async {
    _setLoading(true);
    try {
      final token = AuthStorage.token;
      final response = await ApiClient.delete("/expenses/$id", token: token);
      final res = jsonDecode(response.body);

      if (res['status'] == true) {
        _expenses.removeWhere((element) => element.id == id);

        // Trigger refresh Dashboard Summary
        appEventBus.add(ExpenseChanged());

        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': res['error'] ?? 'Gagal menghapus'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    } finally {
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel(); // 🧹 Mencegah memory leak
    super.dispose();
  }
}
