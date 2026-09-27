import 'item.dart';

class OrderItem {
  final MenuItem item;
  int quantity;
  String variant; // e.g. "Regular", "Kulhad", "Large"
  String notes;

  OrderItem({
    required this.item,
    this.quantity = 1,
    this.variant = 'Regular',
    this.notes = '',
  });

  double get unitPrice => item.price;
  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toJson() {
    final itemJson = item.toJson();
    final img = itemJson['imageUrl']?.toString() ?? '';
    // Strip large base64 or data URLs from order receipts to keep order records lightweight (<1KB)
    if (img.startsWith('data:image/') || img.length > 200) {
      itemJson['imageUrl'] = '';
    }
    return {
      'item': itemJson,
      'quantity': quantity,
      'variant': variant,
      'notes': notes,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    MenuItem parsedItem;
    try {
      if (json['item'] is Map<String, dynamic>) {
        parsedItem = MenuItem.fromJson(json['item'] as Map<String, dynamic>);
      } else if (json['item'] is Map) {
        parsedItem = MenuItem.fromJson(Map<String, dynamic>.from(json['item'] as Map));
      } else {
        parsedItem = MenuItem(
          id: (json['itemId'] ?? json['id'] ?? 'item_unknown').toString(),
          name: (json['name'] ?? json['itemName'] ?? 'Unknown Item').toString(),
          category: (json['category'] ?? 'General').toString(),
          price: (json['price'] as num?)?.toDouble() ?? 0.0,
          description: '',
          itemCode: 'ARM-00',
        );
      }
    } catch (_) {
      parsedItem = MenuItem(
        id: 'item_unknown',
        name: 'Item',
        category: 'General',
        price: 0.0,
        description: '',
        itemCode: 'ARM-00',
      );
    }

    return OrderItem(
      item: parsedItem,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      variant: (json['variant'] ?? 'Regular').toString(),
      notes: (json['notes'] ?? '').toString(),
    );
  }
}

class OrderModel {
  final String id;
  final String billNumber;
  final int tokenNumber;
  final List<OrderItem> items;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod; // Cash, UPI, Card
  final String orderType; // Dine-In, Takeaway
  final DateTime timestamp;
  final String staffName;
  final String status; // Completed, Refunded

  OrderModel({
    required this.id,
    required this.billNumber,
    required this.tokenNumber,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.orderType,
    required this.timestamp,
    required this.staffName,
    this.status = 'Completed',
  });

  OrderModel copyWith({
    String? id,
    String? billNumber,
    int? tokenNumber,
    List<OrderItem>? items,
    double? subtotal,
    double? taxAmount,
    double? discountAmount,
    double? totalAmount,
    String? paymentMethod,
    String? orderType,
    DateTime? timestamp,
    String? staffName,
    String? status,
  }) {
    return OrderModel(
      id: id ?? this.id,
      billNumber: billNumber ?? this.billNumber,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      orderType: orderType ?? this.orderType,
      timestamp: timestamp ?? this.timestamp,
      staffName: staffName ?? this.staffName,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'billNumber': billNumber,
      'tokenNumber': tokenNumber,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'orderType': orderType,
      'timestamp': timestamp.toIso8601String(),
      'staffName': staffName,
      'status': status,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawId = (json['id'] ?? '').toString();
    final rawBill = (json['billNumber'] ?? rawId).toString();
    
    // Safely parse items list
    final List<OrderItem> parsedItems = [];
    if (json['items'] is List) {
      for (var item in (json['items'] as List)) {
        try {
          if (item is Map<String, dynamic>) {
            parsedItems.add(OrderItem.fromJson(item));
          } else if (item is Map) {
            parsedItems.add(OrderItem.fromJson(Map<String, dynamic>.from(item)));
          }
        } catch (_) {}
      }
    }

    DateTime parsedDate;
    try {
      final tsStr = json['timestamp']?.toString();
      parsedDate = tsStr != null ? (DateTime.tryParse(tsStr)?.toLocal() ?? DateTime.now()) : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return OrderModel(
      id: rawId.isNotEmpty ? rawId : 'order_${DateTime.now().millisecondsSinceEpoch}',
      billNumber: rawBill.isNotEmpty ? rawBill : 'ARM-001',
      tokenNumber: (json['tokenNumber'] as num?)?.toInt() ?? 1,
      items: parsedItems,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (json['paymentMethod'] ?? 'UPI / QR').toString(),
      orderType: (json['orderType'] ?? 'Dine-In').toString(),
      timestamp: parsedDate,
      staffName: (json['staffName'] ?? 'Staff Counter').toString(),
      status: (json['status'] ?? 'Completed').toString(),
    );
  }
}
