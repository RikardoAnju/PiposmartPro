import 'package:flutter/material.dart';
import 'package:ayocucinew/core/utils/layanan_icon_resolver.dart';

class ServiceCategory {
  String id;
  String name;
  List<String> processes;
  List<ServiceProduct> products;

  ServiceCategory({
    required this.id,
    required this.name,
    required this.processes,
    required this.products,
  });

  ServiceCategory.empty() : id = '', name = '', processes = [], products = [];

  ServiceCategory copyWith({
    String? id,
    String? name,
    List<String>? processes,
    List<ServiceProduct>? products,
  }) {
    return ServiceCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      processes: processes ?? List.from(this.processes),
      products: products ?? List.from(this.products),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'processes': processes.join(','),
      'products': products.map((p) => p.toJson()).toList(),
    };
  }

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    var processData = json['proses'] ?? json['processes'];
    List<String> processList = [];

    if (processData is String && processData.isNotEmpty) {
      processList = processData.split(',').map((e) => e.trim()).toList();
    } else if (processData is List) {
      processList = List<String>.from(processData);
    }

    return ServiceCategory(
      id: json['id']?.toString() ?? '',
      name: json['nama'] ?? json['name'] ?? '',
      processes: processList,
      products:
          (json['products'] as List?)
              ?.map((p) => ServiceProduct.fromJson(p))
              .toList() ??
          [],
    );
  }
}

class ServiceProduct {
  String id;
  String name;
  double price;
  String unit;
  double? minimalOrder;
  int duration;
  String durationUnit;
  String iconPath;
  int priority;

  ServiceProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.unit,
    this.minimalOrder,
    required this.duration,
    required this.durationUnit,
    this.iconPath = defaultLayananAssetPath,
    this.priority = 0,
  });

  ServiceProduct.empty()
    : id = '',
      name = '',
      price = 0.0,
      unit = '',
      minimalOrder = null,
      duration = 0,
      durationUnit = '',
      iconPath = defaultLayananAssetPath,
      priority = 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'unit': unit,
      'minimalOrder': minimalOrder,
      'duration': duration,
      'durationUnit': durationUnit,
      'iconPath': iconPath,
      'prioritas': priority,
    };
  }

  factory ServiceProduct.fromJson(Map<String, dynamic> json) {
    final minimalOrderValue = json['minimal_order'] ?? json['minimalOrder'];

    return ServiceProduct(
      id: json['id']?.toString() ?? '',
      name: json['nama'] ?? json['name'] ?? '',
      price: (json['harga'] ?? json['price'] ?? 0).toDouble(),
      unit: json['satuan'] ?? json['unit'] ?? '',
      minimalOrder: minimalOrderValue?.toDouble(),
      duration: json['durasi'] ?? json['duration'] ?? 0,
      durationUnit: json['durasi_satuan'] ?? json['durationUnit'] ?? '',
      priority: json['prioritas'] ?? json['priority'] ?? 0,
      iconPath: resolveLayananIconPath(
        (json['icon'] ?? json['iconPath'] ?? '').toString(),
        serviceName: json['nama']?.toString() ?? json['name']?.toString() ?? '',
      ),
    );
  }

  String get displayPrice => 'Rp ${price.toStringAsFixed(0)}';
  String get displayDuration => '$duration $durationUnit';
}

class SearchResult {
  final ServiceCategory category;
  final ServiceProduct product;
  final MatchType matchType;

  SearchResult({
    required this.category,
    required this.product,
    required this.matchType,
  });

  SearchResult copyWith({
    ServiceCategory? category,
    ServiceProduct? product,
    MatchType? matchType,
  }) {
    return SearchResult(
      category: category ?? this.category,
      product: product ?? this.product,
      matchType: matchType ?? this.matchType,
    );
  }

  String get matchDescription {
    switch (matchType) {
      case MatchType.category:
        return 'Cocok dengan kategori';
      case MatchType.product:
        return 'Cocok dengan produk';
      case MatchType.both:
        return 'Cocok dengan kategori dan produk';
    }
  }
}

enum MatchType {
  category,
  product,
  both;

  String get displayName {
    switch (this) {
      case MatchType.category:
        return 'Kategori';
      case MatchType.product:
        return 'Produk';
      case MatchType.both:
        return 'Keduanya';
    }
  }

  IconData get icon {
    switch (this) {
      case MatchType.category:
        return Icons.category;
      case MatchType.product:
        return Icons.inventory_2;
      case MatchType.both:
        return Icons.check_circle;
    }
  }
}
