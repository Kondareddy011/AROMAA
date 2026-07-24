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
    return {
      'item': item.toJson(),
      'quantity': quantity,
      'variant': variant,
      'notes': notes,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      item: MenuItem.fromJson(json['item'] as Map<String, dynamic>),
      quantity: json['quantity'] as int? ?? 1,
      variant: json['variant'] as String? ?? 'Regular',
      notes: json['notes'] as String? ?? '',
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
    return OrderModel(
      id: json['id'] as String,
      billNumber: json['billNumber'] as String? ?? json['id'] as String,
      tokenNumber: json['tokenNumber'] as int? ?? 1,
      items: (json['items'] as List<dynamic>)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      subtotal: (json['subtotal'] as num).toDouble(),
      taxAmount: (json['taxAmount'] as num).toDouble(),
      discountAmount: (json['discountAmount'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      orderType: json['orderType'] as String? ?? 'Dine-In',
      timestamp: DateTime.parse(json['timestamp'] as String),
      staffName: json['staffName'] as String? ?? 'Staff Counter',
      status: json['status'] as String? ?? 'Completed',
    );
  }
}
