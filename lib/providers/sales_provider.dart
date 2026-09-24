import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/business_profile.dart';
import '../models/token_customization.dart';

import '../services/storage_service.dart';
import '../services/turso_service.dart';

class SalesProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final TursoService _tursoService = TursoService();

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  BusinessProfile _businessProfile = BusinessProfile();
  TokenCustomization _tokenCustomization = TokenCustomization();

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  BusinessProfile get businessProfile => _businessProfile;
  TokenCustomization get tokenCustomization => _tokenCustomization;

  SalesProvider() {
    loadOrders();
    loadSettings();
  }

  Future<void> loadOrders({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      // Load from remote database
      final remoteOrders = await _tursoService.getOrders();
      
      // Merge remote orders with local orders so completed local orders are never reverted back to Billed
      final Map<String, OrderModel> merged = {};
      for (var r in remoteOrders) {
        merged[r.id] = r;
      }
      
      for (var l in _orders) {
        if (merged.containsKey(l.id)) {
          // If local order is marked Completed but remote is still Billed, keep local Completed!
          if (l.status == 'Completed' && merged[l.id]!.status == 'Billed') {
            merged[l.id] = merged[l.id]!.copyWith(status: 'Completed');
          }
        } else {
          merged[l.id] = l;
        }
      }
      
      _orders = merged.values.toList();
      _orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      await _storageService.saveOrders(_orders); // Cache locally
    } catch (e) {
      debugPrint('Turso error fetching orders, falling back to cache: $e');
      if (_orders.isEmpty) {
        _orders = await _storageService.getOrders();
        _orders.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSettings() async {
    // Try business profile from Turso
    final remoteProfile = await _tursoService.getBusinessProfile();
    if (remoteProfile != null) {
      _businessProfile = remoteProfile;
      await _storageService.saveBusinessProfile(remoteProfile);
    } else {
      _businessProfile = await _storageService.getBusinessProfile();
    }

    // Try token customization from Turso
    final remoteToken = await _tursoService.getTokenCustomization();
    if (remoteToken != null) {
      _tokenCustomization = remoteToken;
      await _storageService.saveTokenCustomization(remoteToken);
    } else {
      _tokenCustomization = await _storageService.getTokenCustomization();
    }
    notifyListeners();
  }

  Future<void> updateBusinessProfile(BusinessProfile profile) async {
    _businessProfile = profile;
    await _storageService.saveBusinessProfile(profile);
    await _tursoService.saveBusinessProfile(profile);
    notifyListeners();
  }

  Future<void> updateTokenCustomization(TokenCustomization customization) async {
    _tokenCustomization = customization;
    await _storageService.saveTokenCustomization(customization);
    await _tursoService.saveTokenCustomization(customization);
    notifyListeners();
  }

  Future<void> addOrder(OrderModel newOrder) async {
    _orders.insert(0, newOrder);
    notifyListeners();
    _storageService.saveOrders(_orders);
    try {
      await _tursoService.saveOrder(newOrder);
    } catch (e) {
      debugPrint('Turso error saving order: $e');
    }
  }

  Future<void> updateOrderToken(String orderId, int tokenNumber, String billNumber) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final updatedOrder = _orders[index].copyWith(
        tokenNumber: tokenNumber,
        billNumber: billNumber,
      );
      _orders[index] = updatedOrder;
      notifyListeners();
      _storageService.saveOrders(_orders);
      try {
        await _tursoService.saveOrder(updatedOrder);
      } catch (e) {
        debugPrint('Turso error updating token: $e');
      }
    }
  }

  Future<void> deleteOrder(String orderId) async {
    _orders.removeWhere((o) => o.id == orderId);
    notifyListeners();
    _storageService.saveOrders(_orders);
    try {
      await _tursoService.deleteOrder(orderId);
    } catch (e) {
      debugPrint('Turso error deleting order: $e');
    }
  }

  Future<void> clearAllOrders() async {
    _orders.clear();
    notifyListeners();
    _storageService.clearOrders();
    try {
      await _tursoService.clearOrders();
    } catch (e) {
      debugPrint('Turso error clearing orders: $e');
    }
  }

  // --- ANALYTICS CALCULATIONS --- //

  // Today Sales Total
  double get todaySalesTotal {
    final now = DateTime.now();
    return _orders.where((o) {
      return o.timestamp.year == now.year &&
          o.timestamp.month == now.month &&
          o.timestamp.day == now.day &&
          (o.status == 'Completed' || o.status == 'Billed');
    }).fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  int get todayOrderCount {
    final now = DateTime.now();
    return _orders.where((o) {
      return o.timestamp.year == now.year &&
          o.timestamp.month == now.month &&
          o.timestamp.day == now.day &&
          (o.status == 'Completed' || o.status == 'Billed');
    }).length;
  }

  // Weekly Sales Total (Last 7 Days)
  double get weeklySalesTotal {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _orders.where((o) {
      return o.timestamp.isAfter(sevenDaysAgo) &&
          (o.status == 'Completed' || o.status == 'Billed');
    }).fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  // Monthly Sales Total (Current Month)
  double get monthlySalesTotal {
    final now = DateTime.now();
    return _orders.where((o) {
      return o.timestamp.year == now.year &&
          o.timestamp.month == now.month &&
          (o.status == 'Completed' || o.status == 'Billed');
    }).fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  // Lifetime Total Amount Received
  double get totalAmountReceived {
    return _orders
        .where((o) => o.status == 'Completed' || o.status == 'Billed')
        .fold(0.0, (sum, o) => sum + o.totalAmount);
  }

  // Payment Breakdown
  Map<String, double> get paymentMethodTotals {
    final Map<String, double> totals = {
      'UPI / QR': 0.0,
      'Cash': 0.0,
      'Card': 0.0,
    };
    for (var o in _orders) {
      if (o.status == 'Completed' || o.status == 'Billed') {
        totals[o.paymentMethod] = (totals[o.paymentMethod] ?? 0.0) + o.totalAmount;
      }
    }
    return totals;
  }

  // Top Selling Items (Name -> Count)
  List<MapEntry<String, int>> get topSellingItems {
    final Map<String, int> counts = {};
    for (var o in _orders) {
      if (o.status == 'Completed' || o.status == 'Billed') {
        for (var item in o.items) {
          counts[item.item.name] = (counts[item.item.name] ?? 0) + item.quantity;
        }
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  // Chart data: Last 7 Days daily totals
  List<Map<String, dynamic>> get last7DaysDailySales {
    final List<Map<String, dynamic>> list = [];
    final now = DateTime.now();

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final total = _orders.where((o) {
        return o.timestamp.year == date.year &&
            o.timestamp.month == date.month &&
            o.timestamp.day == date.day &&
            (o.status == 'Completed' || o.status == 'Billed');
      }).fold(0.0, (sum, o) => sum + o.totalAmount);

      list.add({
        'dayLabel': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
        'date': date,
        'total': total,
      });
    }
    return list;
  }

  int getNextDailyTokenNumber(String lastResetIso) {
    final today = DateTime.now();
    final lastReset = DateTime.tryParse(lastResetIso) ?? DateTime(2020, 1, 1);
    
    // Filter orders of today that actually have a printed token (tokenNumber > 0)
    // and were placed after the last manual reset time!
    final todayPrintedOrders = _orders.where((o) =>
        o.tokenNumber > 0 &&
        o.timestamp.year == today.year &&
        o.timestamp.month == today.month &&
        o.timestamp.day == today.day &&
        o.timestamp.isAfter(lastReset));

    if (todayPrintedOrders.isEmpty) {
      return 1;
    }
    return todayPrintedOrders.map((o) => o.tokenNumber).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      final updatedOrder = _orders[index].copyWith(status: newStatus);
      _orders[index] = updatedOrder;
      notifyListeners();
      _storageService.saveOrders(_orders);
      try {
        await _tursoService.updateOrderStatus(orderId, newStatus);
      } catch (e) {
        debugPrint('Turso error updating order status: $e');
      }
    }
  }

  Future<void> markAllBilledAsDelivered() async {
    for (int i = 0; i < _orders.length; i++) {
      if (_orders[i].status == 'Billed') {
        _orders[i] = _orders[i].copyWith(status: 'Completed');
      }
    }
    notifyListeners();
    _storageService.saveOrders(_orders);
    try {
      await _tursoService.markAllBilledAsCompleted();
    } catch (e) {
      debugPrint('Turso error marking all billed completed: $e');
    }
  }

  int getNextDailyBillNumber(String lastResetIso) {
    final today = DateTime.now();
    final lastReset = DateTime.tryParse(lastResetIso) ?? DateTime(2020, 1, 1);
    
    final todayBills = _orders.where((o) =>
        !o.billNumber.endsWith('-000') &&
        o.timestamp.year == today.year &&
        o.timestamp.month == today.month &&
        o.timestamp.day == today.day &&
        o.timestamp.isAfter(lastReset));

    if (todayBills.isEmpty) {
      return 1;
    }
    
    final seqs = todayBills.map((o) {
      final parts = o.billNumber.split('-');
      if (parts.length >= 3) {
        return int.tryParse(parts[2]) ?? 0;
      }
      return 0;
    });
    
    return seqs.reduce((a, b) => a > b ? a : b) + 1;
  }
}
