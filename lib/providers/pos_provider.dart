import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import 'sales_provider.dart';

class POSProvider with ChangeNotifier {
  final List<OrderItem> _cartItems = [];
  String _orderType = 'Dine-In'; // Dine-In or Takeaway
  String _paymentMethod = 'UPI / QR'; // Cash, UPI / QR, Card
  double _discountAmount = 0.0;
  double _taxPercentage = 5.0; // GST 5%
  bool _taxEnabled = true;

  List<OrderItem> get cartItems => _cartItems;
  String get orderType => _orderType;
  String get paymentMethod => _paymentMethod;
  double get discountAmount => _discountAmount;
  double get taxPercentage => _taxPercentage;
  bool get taxEnabled => _taxEnabled;

  double get subtotal {
    return _cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double get taxAmount {
    if (!_taxEnabled) return 0.0;
    return (subtotal * (_taxPercentage / 100));
  }

  double get grandTotal {
    final total = subtotal + taxAmount - _discountAmount;
    return total < 0 ? 0.0 : total;
  }

  int get totalItemCount {
    return _cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  int getItemQuantity(String itemId) {
    final match = _cartItems.where((ci) => ci.item.id == itemId);
    return match.fold(0, (sum, ci) => sum + ci.quantity);
  }

  void updateTaxSettings({required bool enabled, required double percentage}) {
    _taxEnabled = enabled;
    _taxPercentage = percentage;
    notifyListeners();
  }

  void addToCart(MenuItem item, {String variant = 'Regular'}) {
    final existingIndex = _cartItems.indexWhere(
        (ci) => ci.item.id == item.id && ci.variant == variant);

    if (existingIndex != -1) {
      _cartItems[existingIndex].quantity += 1;
    } else {
      _cartItems.add(OrderItem(item: item, quantity: 1, variant: variant));
    }
    notifyListeners();
  }

  void updateQuantity(int index, int delta) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index].quantity += delta;
      if (_cartItems[index].quantity <= 0) {
        _cartItems.removeAt(index);
      }
      notifyListeners();
    }
  }

  void updateVariant(int index, String variant) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index].variant = variant;
      notifyListeners();
    }
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  void decrementCartItem(String itemId, {String variant = 'Regular'}) {
    final existingIndex = _cartItems.indexWhere(
        (ci) => ci.item.id == itemId && ci.variant == variant);
    if (existingIndex != -1) {
      _cartItems[existingIndex].quantity -= 1;
      if (_cartItems[existingIndex].quantity <= 0) {
        _cartItems.removeAt(existingIndex);
      }
      notifyListeners();
    }
  }

  void setOrderType(String type) {
    _orderType = type;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setDiscountAmount(double discount) {
    _discountAmount = discount;
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _discountAmount = 0.0;
    notifyListeners();
  }

  Future<OrderModel?> checkout({
    required String staffName,
    required SalesProvider salesProvider,
    required PrinterConfig printerConfig,
  }) async {
    if (_cartItems.isEmpty) return null;

    final id = const Uuid().v4();
    final today = DateTime.now();
    final billNum = 'ARM-${DateFormat('yyMMdd').format(today)}-000'; // Token 0 unassigned placeholder

    final order = OrderModel(
      id: id,
      billNumber: billNum,
      tokenNumber: 0,
      items: List.from(_cartItems),
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: _discountAmount,
      totalAmount: grandTotal,
      paymentMethod: _paymentMethod,
      orderType: _orderType,
      timestamp: today,
      staffName: staffName,
    );

    // Save order in Sales Provider
    await salesProvider.addOrder(order);

    // Clear cart
    clearCart();
    return order;
  }
}
