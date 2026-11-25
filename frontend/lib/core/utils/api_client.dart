// lib/core/utils/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../events/app_events.dart';

class ApiClient {
  static final http.Client _client = http.Client();
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const int _maxLogChars = 1200;
  static Future<SharedPreferences>? _prefsFuture;
  static String? _lastInvalidatedTokenHash;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-dev.ayocuci.id/api/v1',
  );
  static const String _plainUrl = String.fromEnvironment(
    'API_PLAIN_URL',
    defaultValue: 'https://api-dev.ayocuci.id',
  );

  static String get baseUrl => _baseUrl;
  static String get plainUrl => _plainUrl;

  static String resolveUploadUrl(String? path) {
    final value = path?.trim();
    if (value == null || value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '$_plainUrl$value';
    if (value.startsWith('uploads/')) return '$_plainUrl/$value';
    return '$_plainUrl/uploads/$value';
  }

  static String resolveImageVariantUrl(
    String? path, {
    required int width,
    bool webp = true,
    int quality = 80,
  }) {
    final url = resolveUploadUrl(path);
    if (url.isEmpty || !url.contains('.aliyuncs.com/')) return url;

    final safeWidth = width.clamp(1, 4096);
    final safeQuality = quality.clamp(1, 100);
    final processParts = [
      'image/resize,w_$safeWidth',
      'quality,q_$safeQuality',
      if (webp) 'format,webp',
    ];

    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}x-oss-process=${processParts.join('/')}';
  }

  static Map<String, String> _getHeaders(String? token) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'AyoCuci/1.0 (Android)',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Uri _getUri(String endpoint) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    return Uri.parse('$_baseUrl$path');
  }

  static Uri buildUri(String endpoint) => _getUri(endpoint);

  static Future<SharedPreferences> _prefs() {
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  static String _cacheKey(Uri uri, String? token) {
    final tokenScope = token == null || token.isEmpty
        ? 'guest'
        : _stableHash(token);
    return 'api_cache:v1:$tokenScope:${uri.toString()}';
  }


  static Future<void> clearCache() async {
    final prefs = await _prefs();
    final keys = prefs.getKeys().where((k) => k.startsWith('api_cache:'));
    for (final key in keys.toList()) {
      await prefs.remove(key);
    }
  }

  static String _stableHash(String value) {
    // Use the 32-bit FNV-1a variant so this also works when Dart compiles
    // to JavaScript for Flutter Web.
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16);
  }

  static Future<void> _writeCache(
    Uri uri,
    String? token,
    http.Response response,
  ) async {
    if (response.statusCode != 200) return;
    final prefs = await _prefs();
    final key = _cacheKey(uri, token);

    // Explicitly decode with UTF-8 to prevent caching malformed latin1 strings
    // when API doesn't specify charset=utf-8
    final decodedBody = utf8.decode(response.bodyBytes, allowMalformed: true);
    await prefs.setString(key, decodedBody);
    await prefs.setInt('$key:ts', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<http.Response?> _readCachedResponse(
    Uri uri,
    String? token,
  ) async {
    final prefs = await _prefs();
    final cachedBody = prefs.getString(_cacheKey(uri, token));
    if (cachedBody == null || cachedBody.isEmpty) return null;

    if (kDebugMode) {
      debugPrint('📦 [CACHE] Menggunakan data terakhir: $uri');
    }
    return http.Response.bytes(
      utf8.encode(cachedBody),
      200,
      headers: const {
        'x-ayocuci-cache': 'stale',
        'content-type': 'application/json; charset=utf-8',
      },
      request: http.Request('GET', uri),
    );
  }

  // --- LOGGER HELPERS ---
  static void _logRequest(String method, Uri uri, dynamic body) {
    if (!kDebugMode) return;
    debugPrint('--------------------------');
    debugPrint('🚀 [$method] URL: $uri');
    if (body != null) {
      debugPrint(
        '📦 Payload: ${_truncateForLog(body is String ? body : jsonEncode(body))}',
      );
    }
  }

  static void _logResponse(http.Response response) {
    if (!kDebugMode) return;
    debugPrint('✅ [RESPONSE] Status: ${response.statusCode}');
    debugPrint('📑 Body: ${_truncateForLog(response.body)}');
    debugPrint('--------------------------');
  }

  static void _handleForcedLogout(http.Response response, String? token) {
    if (response.statusCode != 401 || token == null || token.isEmpty) return;
    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (body['force_logout'] != true) return;
      final tokenHash = _stableHash(token);
      if (_lastInvalidatedTokenHash == tokenHash) return;
      _lastInvalidatedTokenHash = tokenHash;
      appEventBus.add(
        SessionForceLogoutRequested(
          reason: body['message']?.toString().trim().isNotEmpty == true
              ? body['message'].toString()
              : 'Sesi Anda telah diakhiri. Silakan login kembali.',
        ),
      );
    } catch (_) {
    }
  }

  static String _truncateForLog(String value) {
    if (value.length <= _maxLogChars) return value;
    return '${value.substring(0, _maxLogChars)}... <${value.length - _maxLogChars} chars more>';
  }

  // --- HTTP METHODS ---
  static Future<http.Response> get(String endpoint, {String? token}) async {
    final uri = _getUri(endpoint);
    _logRequest('GET', uri, null);
    final response = await _client
        .get(uri, headers: _getHeaders(token))
        .timeout(_requestTimeout);
    _logResponse(response);
    _handleForcedLogout(response, token);
    return response;
  }

  static Future<http.Response> getWithCache(
    String endpoint, {
    String? token,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final uri = _getUri(endpoint);
    _logRequest('GET', uri, null);

    try {
      final response = await _client
          .get(uri, headers: _getHeaders(token))
          .timeout(timeout);
      _logResponse(response);
      _handleForcedLogout(response, token);
      await _writeCache(uri, token, response);
      return response;
    } catch (error) {
      final cached = await _readCachedResponse(uri, token);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Stream<http.Response> getStreamWithCache(
    String endpoint, {
    String? token,
    Duration timeout = const Duration(seconds: 12),
  }) async* {
    final uri = _getUri(endpoint);

    // 1. Return cache immediately if available
    final cached = await _readCachedResponse(uri, token);
    if (cached != null) {
      yield cached;
    }

    // 2. Fetch from network and yield again
    _logRequest('GET (Stream)', uri, null);
    try {
      final response = await _client
          .get(uri, headers: _getHeaders(token))
          .timeout(timeout);
      _logResponse(response);
      _handleForcedLogout(response, token);
      if (response.statusCode == 200) {
        await _writeCache(uri, token, response);
      }
      yield response;
    } catch (error) {
      if (cached == null) {
        rethrow; // Only throw if we had no cache to fallback to
      }
    }
  }

  static Future<http.Response> post(
    String endpoint, {
    dynamic body,
    String? token,
  }) async {
    final uri = _getUri(endpoint);
    _logRequest('POST', uri, body);
    final response = await _client
        .post(
          uri,
          headers: _getHeaders(token),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(_requestTimeout);
    _logResponse(response);
    _handleForcedLogout(response, token);
    return response;
  }

  static Future<http.Response> put(
    String endpoint, {
    dynamic body,
    String? token,
  }) async {
    final uri = _getUri(endpoint);
    _logRequest('PUT', uri, body);
    final response = await _client
        .put(
          uri,
          headers: _getHeaders(token),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(_requestTimeout);
    _logResponse(response);
    _handleForcedLogout(response, token);
    return response;
  }

  static Future<http.Response> patch(
    String endpoint, {
    dynamic body,
    String? token,
  }) async {
    final uri = _getUri(endpoint);
    _logRequest('PATCH', uri, body);
    final response = await _client
        .patch(
          uri,
          headers: _getHeaders(token),
          body: body is String ? body : jsonEncode(body),
        )
        .timeout(_requestTimeout);
    _logResponse(response);
    _handleForcedLogout(response, token);
    return response;
  }

  static Future<http.Response> delete(
    String endpoint, {
    dynamic body,
    String? token,
  }) async {
    final uri = _getUri(endpoint);
    _logRequest('DELETE', uri, body);
    final response = await _client
        .delete(
          uri,
          headers: _getHeaders(token),
          body: body == null
              ? null
              : (body is String ? body : jsonEncode(body)),
        )
        .timeout(_requestTimeout);
    _logResponse(response);
    _handleForcedLogout(response, token);
    return response;
  }
}
