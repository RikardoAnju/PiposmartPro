import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/utils/api_client.dart';
import '../data/models/content_banner_model.dart';

class ContentProvider extends ChangeNotifier {
  List<ContentBannerModel> _items = [];
  bool _isLoading = false;
  Future<void>? _fetchFuture;

  List<ContentBannerModel> get items => List.unmodifiable(_items);
  List<ContentBannerModel> get promos =>
      _items.where((e) => e.category == 'PROMO').toList();
  List<ContentBannerModel> get infos =>
      _items.where((e) => e.category == 'INFORMASI').toList();
  bool get isLoading => _isLoading;

  Future<void> fetchContent() async {
    if (_fetchFuture != null) return _fetchFuture!;

    _fetchFuture = _fetchContent();
    try {
      return await _fetchFuture!;
    } finally {
      _fetchFuture = null;
    }
  }

  Future<void> _fetchContent() async {
    _isLoading = _items.isEmpty;
    if (_isLoading) notifyListeners();

    try {
      await for (final res in ApiClient.getStreamWithCache('/content')) {
        if (res.statusCode == 200) {
          // Explicitly decode bytes as UTF-8 to prevent invalid character issues
          final decodedBody = utf8.decode(res.bodyBytes, allowMalformed: true);
          final body = jsonDecode(decodedBody);
          final List data = body['data'] ?? [];
          _items = data.map((e) => ContentBannerModel.fromJson(e)).toList();
          _isLoading = false;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('❌ Fetch Content Error: $e');
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}
