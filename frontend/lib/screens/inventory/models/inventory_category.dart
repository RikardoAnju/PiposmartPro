import 'package:flutter/material.dart';

class InventoryCategory {
  const InventoryCategory({
    required this.id,
    required this.name,
    required this.iconAsset,
    required this.iconKey,
    required this.backgroundColor,
  });

  final String id;
  final String name;
  final String iconAsset;
  final String iconKey;
  final Color backgroundColor;
}
