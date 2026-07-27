import 'dart:io';
import 'package:flutter/foundation.dart';

class MenuItem {
  final String id;
  final String name;
  final String category;
  final double price;
  final String description;
  final bool isAvailable;
  final String itemCode;
  final String imageUrl;
  final int sortOrder;

  MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.description,
    this.isAvailable = true,
    required this.itemCode,
    this.imageUrl = '',
    this.sortOrder = 0,
  });

  /// Guaranteed demo image for every item based on category fallback
  String get effectiveImageUrl {
    if (imageUrl.trim().isNotEmpty) {
      final trimmed = imageUrl.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://') || trimmed.startsWith('data:image/')) {
        return trimmed;
      }
      // If it's a local path, verify if the file actually exists
      if (!kIsWeb) {
        try {
          if (File(trimmed).existsSync()) {
            return trimmed;
          }
        } catch (_) {
          // Fall through to default if there is a path format error
        }
      }
    }
    switch (category) {
      case 'Special Chai':
        return 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500&auto=format&fit=crop';
      case 'Cold Teas':
        return 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop';
      case 'Green & Herbal':
        return 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=500&auto=format&fit=crop';
      case 'Snacks & Bites':
        return 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500&auto=format&fit=crop';
      case 'Desserts':
        return 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500&auto=format&fit=crop';
      default:
        return 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500&auto=format&fit=crop';
    }
  }

  MenuItem copyWith({
    String? id,
    String? name,
    String? category,
    double? price,
    String? description,
    bool? isAvailable,
    String? itemCode,
    String? imageUrl,
    int? sortOrder,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      description: description ?? this.description,
      isAvailable: isAvailable ?? this.isAvailable,
      itemCode: itemCode ?? this.itemCode,
      imageUrl: imageUrl ?? this.imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'description': description,
      'isAvailable': isAvailable,
      'itemCode': itemCode,
      'imageUrl': imageUrl,
      'sortOrder': sortOrder,
    };
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['imageUrl'];
    return MenuItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: (json['description'] ?? '').toString(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      itemCode: (json['itemCode'] ?? 'ARM-00').toString(),
      imageUrl: (rawUrl == null || rawUrl == 'null') ? '' : rawUrl.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
