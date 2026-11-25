import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ayocucinew/core/constants/api_endpoints.dart';
import 'package:ayocucinew/core/events/app_events.dart';
import 'package:ayocucinew/core/utils/api_client.dart';
import 'package:ayocucinew/core/utils/auth_storage.dart';
import 'package:ayocucinew/core/utils/upload_image_helper.dart';
import 'package:ayocucinew/data/models/setting_nota_model.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class NotaSettingsProvider extends ChangeNotifier {
  NotaSettings? _notaSettings;
  bool _isLoading = false;
  bool _isBusy = false;
  bool _isInlineSaving = false;
  String? _errorMessage;
  Future<void>? _ongoingFetch;
  StreamSubscription<AppEvent>? _eventSubscription;

  NotaSettingsProvider() {
    _listenToEvents();
  }

  NotaSettings? get notaSettings => _notaSettings;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get isInlineSaving => _isInlineSaving;
  String? get errorMessage => _errorMessage;

  String? _getToken() => AuthStorage.token;

  void _listenToEvents() {
    _eventSubscription = appEventBus.stream.listen((event) {
      if (event is OutletSwitched) {
        clearData(notify: false);
        unawaited(fetchNotaSettings(force: true, silent: true));
      } else if (event is OutletProfileUpdated) {
        unawaited(fetchNotaSettings(force: true, silent: true));
      }
    });
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }

  void _setInlineSaving(bool value) {
    if (_isInlineSaving == value) return;
    _isInlineSaving = value;
    notifyListeners();
  }

  void _replaceSettings(NotaSettings? settings, {bool notify = true}) {
    _notaSettings = settings;
    if (notify) notifyListeners();
  }

  bool _isSuccessResponse(Map<String, dynamic> data) {
    return data['status'] == true || data['success'] == true;
  }

  NotaSettings? _parseSettings(Map<String, dynamic> data) {
    final raw = data['data'];
    if (raw is Map<String, dynamic>) {
      return NotaSettings.fromJson(raw);
    }
    return null;
  }

  NotaSettings? _applyPayloadToSettings(
    NotaSettings? current,
    Map<String, dynamic> payload,
  ) {
    if (current == null) return null;

    return current.copyWith(
      cnNamaOutlet: payload.containsKey('cn_nama_outlet')
          ? payload['cn_nama_outlet'] as String?
          : null,
      cnAlamat: payload.containsKey('cn_alamat')
          ? payload['cn_alamat'] as String?
          : null,
      cnKontak: payload.containsKey('cn_kontak')
          ? payload['cn_kontak'] as String?
          : null,
      cnLogo: payload.containsKey('cn_logo')
          ? payload['cn_logo'] as String?
          : null,
      cnFooterNota: payload.containsKey('cn_footer_nota')
          ? payload['cn_footer_nota'] as String?
          : null,
      cnFooterWhatsapp: payload.containsKey('cn_footer_whatsapp')
          ? payload['cn_footer_whatsapp'] as String?
          : null,
      cnSettLogo: payload.containsKey('cn_sett_logo')
          ? payload['cn_sett_logo'] as bool?
          : null,
      cnSettQr: payload.containsKey('cn_sett_qr')
          ? payload['cn_sett_qr'] as bool?
          : null,
      cnSettKasir: payload.containsKey('cn_sett_kasir')
          ? payload['cn_sett_kasir'] as bool?
          : null,
      cnSettKeterangan: payload.containsKey('cn_sett_keterangan')
          ? payload['cn_sett_keterangan'] as bool?
          : null,
      cnSettNota: payload.containsKey('cn_sett_nota')
          ? payload['cn_sett_nota'] as bool?
          : null,
      cnSettWhatsapp: payload.containsKey('cn_sett_whatsapp')
          ? payload['cn_sett_whatsapp'] as bool?
          : null,
      cnSettRounding: payload.containsKey('cn_sett_rounding')
          ? payload['cn_sett_rounding'] as bool?
          : null,
      cnSettDurasi: payload.containsKey('cn_sett_durasi')
          ? payload['cn_sett_durasi'] as bool?
          : null,
      cnUkuran: payload.containsKey('cn_ukuran')
          ? payload['cn_ukuran'] as int?
          : null,
      cnLastupdate: DateTime.now(),
    );
  }

  Future<void> fetchNotaSettings({
    bool force = false,
    bool silent = false,
  }) async {
    if (!force && _notaSettings != null) return;
    if (_ongoingFetch != null) return _ongoingFetch!;

    final future = _fetchNotaSettingsInternal(silent: silent);
    _ongoingFetch = future;

    try {
      await future;
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<void> _fetchNotaSettingsInternal({required bool silent}) async {
    if (!silent && _notaSettings == null) {
      _setLoading(true);
    }
    _errorMessage = null;

    try {
      final token = _getToken();
      final response = await ApiClient.get(
        ApiEndpoints.notaSettings,
        token: token,
      );

      debugPrint('📡 [GET] nota-setting status: ${response.statusCode}');
      debugPrint('📡 [GET] nota-setting body: ${response.body}');

      if (response.statusCode == 404) {
        _replaceSettings(null);
        _errorMessage = null;
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && _isSuccessResponse(data)) {
        _replaceSettings(_parseSettings(data));
        return;
      }

      _errorMessage =
          data['message']?.toString() ?? 'Gagal memuat pengaturan nota';
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error fetchNotaSettings: $e');
      _errorMessage = e.toString();
      notifyListeners();
    } finally {
      if (!silent) {
        _setLoading(false);
      } else {
        _isLoading = false;
      }
    }
  }

  Future<Map<String, dynamic>> _sendUpdate(
    Map<String, dynamic> payload, {
    required bool inline,
  }) async {
    final previous = _notaSettings;

    if (inline) {
      _errorMessage = null;
      _replaceSettings(_applyPayloadToSettings(_notaSettings, payload));
      _setInlineSaving(true);
    } else {
      _errorMessage = null;
      _setBusy(true);
    }

    try {
      final token = _getToken();
      final response = await ApiClient.put(
        ApiEndpoints.notaSettings,
        body: payload,
        token: token,
      );

      debugPrint('📤 [PUT] nota-setting payload: $payload');
      debugPrint('📥 [PUT] nota-setting status: ${response.statusCode}');
      debugPrint('📥 [PUT] nota-setting body: ${response.body}');

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 && _isSuccessResponse(data)) {
        final settings = _parseSettings(data);
        if (settings != null) {
          _replaceSettings(settings);
        } else {
          await fetchNotaSettings(force: true, silent: true);
        }
        appEventBus.add(PrintSettingChanged());
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Pengaturan berhasil diperbarui',
        };
      }

      if (inline) {
        _replaceSettings(previous);
      }
      _errorMessage =
          data['message']?.toString() ?? 'Gagal memperbarui pengaturan';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    } catch (e) {
      if (inline) {
        _replaceSettings(previous);
      }
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    } finally {
      if (inline) {
        _setInlineSaving(false);
      } else {
        _setBusy(false);
      }
    }
  }

  Future<Map<String, dynamic>> updateNotaSettings(
    Map<String, dynamic> payload,
  ) async {
    return _sendUpdate(payload, inline: false);
  }

  Future<Map<String, dynamic>> saveNotaSettings(NotaSettingsInput input) async {
    return updateNotaSettings(input.toJson());
  }

  Future<Map<String, dynamic>> saveNotaSettingsSilently(
    Map<String, dynamic> payload,
  ) async {
    if (_notaSettings == null) {
      await fetchNotaSettings(force: true, silent: true);
    }

    if (_notaSettings == null) {
      return {
        'success': false,
        'message': 'Pengaturan nota belum siap. Coba muat ulang halaman.',
      };
    }

    return _sendUpdate(payload, inline: true);
  }

  Future<Map<String, dynamic>> toggleField(String fieldName, bool value) async {
    return saveNotaSettingsSilently({fieldName: value});
  }

  Future<Map<String, dynamic>> updatePrinterSize(int size) async {
    if (size != 58 && size != 80) {
      return {
        'success': false,
        'message': 'Ukuran printer harus 58mm atau 80mm',
      };
    }
    return saveNotaSettingsSilently({'cn_ukuran': size});
  }

  Future<Map<String, dynamic>> uploadNotaLogo(File imageFile) async {
    _errorMessage = null;
    _setBusy(true);

    try {
      final token = _getToken();
      final compressed = await UploadImageHelper.compressImage(
        imageFile,
        maxWidth: 800,
        quality: 82,
        prefix: 'nota_logo',
      );

      final request = http.MultipartRequest(
        'POST',
        ApiClient.buildUri(ApiEndpoints.notaLogo),
      );
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.files.add(
        await http.MultipartFile.fromPath('logo', compressed.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && _isSuccessResponse(data)) {
        final settings = _parseSettings(data);
        if (settings != null) {
          _replaceSettings(settings);
        } else {
          await fetchNotaSettings(force: true, silent: true);
        }
        appEventBus.add(PrintSettingChanged());
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Logo nota berhasil diunggah',
        };
      }

      _errorMessage = data['message']?.toString() ?? 'Gagal upload logo nota';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    } finally {
      _setBusy(false);
    }
  }

  Future<Map<String, dynamic>> deleteNotaLogo() async {
    _errorMessage = null;
    _setBusy(true);

    try {
      final token = _getToken();
      final response = await ApiClient.delete(
        ApiEndpoints.notaLogo,
        token: token,
      );
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && _isSuccessResponse(data)) {
        final settings = _parseSettings(data);
        if (settings != null) {
          _replaceSettings(settings);
        } else {
          await fetchNotaSettings(force: true, silent: true);
        }
        appEventBus.add(PrintSettingChanged());
        return {
          'success': true,
          'message':
              data['message']?.toString() ?? 'Logo nota berhasil dihapus',
        };
      }

      _errorMessage =
          data['message']?.toString() ?? 'Gagal menghapus logo nota';
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': e.toString()};
    } finally {
      _setBusy(false);
    }
  }

  Future<void> syncOutletInfoToNota({
    required String nama,
    required String alamat,
    required String kontak,
  }) async {
    final result = await updateNotaSettings({
      'cn_nama_outlet': nama,
      'cn_alamat': alamat,
      'cn_kontak': kontak,
    });

    debugPrint('✅ syncOutletInfoToNota result: $result');
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _notaSettings = null;
    _isLoading = false;
    _isBusy = false;
    _isInlineSaving = false;
    _errorMessage = null;
    notifyListeners();
  }

  void clearData({bool notify = true}) {
    _notaSettings = null;
    _errorMessage = null;
    _isLoading = false;
    _isBusy = false;
    _isInlineSaving = false;
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}
