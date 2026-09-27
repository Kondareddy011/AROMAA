import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/item.dart';
import '../models/order.dart';
import '../models/business_profile.dart';
import '../models/token_customization.dart';
import 'turso_config.dart';

class TursoService {
  static final TursoService _instance = TursoService._internal();
  factory TursoService() => _instance;
  TursoService._internal();

  Map<String, dynamic> _toHranaValue(dynamic val) {
    if (val == null) {
      return {'type': 'null'};
    } else if (val is int) {
      return {'type': 'integer', 'value': val.toString()};
    } else if (val is double) {
      return {'type': 'float', 'value': val};
    } else if (val is bool) {
      return {'type': 'integer', 'value': val ? '1' : '0'};
    } else {
      return {'type': 'text', 'value': val.toString()};
    }
  }

  List<Map<String, dynamic>> _parseRows(Map<String, dynamic> result) {
    try {
      final cols = (result['cols'] as List<dynamic>?) ?? [];
      final rows = (result['rows'] as List<dynamic>?) ?? [];

      return rows.map((row) {
        final rowMap = <String, dynamic>{};
        if (row is! List) return rowMap;
        final values = row;
        for (int i = 0; i < cols.length && i < values.length; i++) {
          final colName = (cols[i]['name'] ?? 'col_$i').toString();
          final valObj = values[i];
          if (valObj is! Map) {
            rowMap[colName] = valObj;
            continue;
          }
          final type = (valObj['type'] ?? 'null').toString();

          dynamic val;
          if (type == 'null') {
            val = null;
          } else if (type == 'integer') {
            val = int.tryParse(valObj['value']?.toString() ?? '') ?? 0;
          } else if (type == 'float') {
            final raw = valObj['value'];
            val = raw is num ? raw.toDouble() : (double.tryParse(raw?.toString() ?? '') ?? 0.0);
          } else if (type == 'text') {
            val = valObj['value']?.toString();
          } else if (type == 'blob') {
            val = valObj['base64']?.toString();
          }

          rowMap[colName] = val;
        }
        return rowMap;
      }).toList();
    } catch (e) {
      debugPrint('Error parsing Turso rows: $e');
      return [];
    }
  }

  Future<dynamic> _executePipeline(List<Map<String, dynamic>> requests) async {
    try {
      var baseUrl = await TursoConfig.getDatabaseUrl();
      final token = await TursoConfig.getAuthToken();

      if (baseUrl.startsWith('libsql://')) {
        baseUrl = 'https://${baseUrl.substring(9)}';
      }

      final url = Uri.parse('$baseUrl/v2/pipeline');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'requests': requests,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Turso request failed with status: ${response.statusCode}, body: ${response.body}');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid Turso response format');
      }
      final results = (data['results'] as List<dynamic>?) ?? [];
      
      // Check if any request failed
      for (var res in results) {
        if (res is Map && res['type'] == 'error') {
          throw Exception('Turso statement execution error: ${res['error'] ?? res}');
        }
      }

      return data;
    } catch (e) {
      debugPrint('Turso pipeline error: $e');
      rethrow;
    }
  }

  Future<void> initDatabase() async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': '''
              CREATE TABLE IF NOT EXISTS menu_items (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                category TEXT NOT NULL,
                price REAL NOT NULL,
                description TEXT NOT NULL,
                isAvailable INTEGER NOT NULL DEFAULT 1,
                itemCode TEXT NOT NULL,
                imageUrl TEXT NOT NULL,
                sortOrder INTEGER NOT NULL DEFAULT 0
              );
            '''
          }
        },
        {
          'type': 'execute',
          'stmt': {
            'sql': '''
              CREATE TABLE IF NOT EXISTS orders (
                id TEXT PRIMARY KEY,
                billNumber TEXT NOT NULL,
                tokenNumber INTEGER NOT NULL,
                items TEXT NOT NULL,
                subtotal REAL NOT NULL,
                taxAmount REAL NOT NULL,
                discountAmount REAL NOT NULL,
                totalAmount REAL NOT NULL,
                paymentMethod TEXT NOT NULL,
                orderType TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                staffName TEXT NOT NULL,
                status TEXT NOT NULL
              );
            '''
          }
        },
        {
          'type': 'execute',
          'stmt': {
            'sql': '''
              CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
              );
            '''
          }
        },
        {
          'type': 'close'
        }
      ]);
      debugPrint('Turso Database schema initialized successfully');
    } catch (e) {
      debugPrint('Turso initDatabase error: $e');
    }
  }

  // --- MENU METHODS --- //

  Future<List<MenuItem>> getMenuItems() async {
    try {
      final pipeline = await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': 'SELECT * FROM menu_items ORDER BY sortOrder ASC;'
          }
        },
        {
          'type': 'close'
        }
      ]);

      if (pipeline['results'] == null || (pipeline['results'] as List).isEmpty) {
        return [];
      }
      final firstResult = pipeline['results'][0];
      if (firstResult['response'] == null || firstResult['response']['result'] == null) {
        return [];
      }
      final result = firstResult['response']['result'] as Map<String, dynamic>;
      final parsed = _parseRows(result);
      return parsed.map((row) {
        // Map SQLite integer boolean back to dynamic bool
        row['isAvailable'] = (row['isAvailable'] == 1 || row['isAvailable'] == true);
        return MenuItem.fromJson(row);
      }).toList();
    } catch (e) {
      debugPrint('Turso error fetching menu items: $e');
      return [];
    }
  }

  Future<void> saveMenuItem(MenuItem item) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': '''
              INSERT OR REPLACE INTO menu_items (
                id, name, category, price, description, isAvailable, itemCode, imageUrl, sortOrder
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            ''',
            'args': [
              _toHranaValue(item.id),
              _toHranaValue(item.name),
              _toHranaValue(item.category),
              _toHranaValue(item.price),
              _toHranaValue(item.description),
              _toHranaValue(item.isAvailable),
              _toHranaValue(item.itemCode),
              _toHranaValue(item.imageUrl),
              _toHranaValue(item.sortOrder)
            ]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error saving menu item: $e');
    }
  }

  Future<void> deleteMenuItem(String id) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': 'DELETE FROM menu_items WHERE id = ?;',
            'args': [_toHranaValue(id)]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error deleting menu item: $e');
    }
  }

  // --- ORDER METHODS --- //

  Future<List<OrderModel>> getOrders({int limit = 1000}) async {
    try {
      final pipeline = await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': 'SELECT * FROM orders ORDER BY timestamp DESC LIMIT $limit;'
          }
        },
        {
          'type': 'close'
        }
      ]);

      if (pipeline['results'] == null || (pipeline['results'] as List).isEmpty) {
        return [];
      }
      final firstResult = pipeline['results'][0];
      if (firstResult['response'] == null || firstResult['response']['result'] == null) {
        return [];
      }

      final result = firstResult['response']['result'] as Map<String, dynamic>;
      final parsed = _parseRows(result);
      final List<OrderModel> orders = [];
      
      for (var row in parsed) {
        try {
          // Safely decode nested items list
          final rawItems = row['items'];
          if (rawItems is String && rawItems.isNotEmpty) {
            try {
              row['items'] = jsonDecode(rawItems);
            } catch (_) {
              row['items'] = [];
            }
          } else if (rawItems is! List) {
            row['items'] = [];
          }
          orders.add(OrderModel.fromJson(row));
        } catch (itemError) {
          debugPrint('Skipping malformed order row: $itemError');
        }
      }
      return orders;
    } catch (e) {
      debugPrint('Turso error fetching orders: $e');
      return [];
    }
  }

  Future<void> saveOrder(OrderModel order) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': '''
              INSERT OR REPLACE INTO orders (
                id, billNumber, tokenNumber, items, subtotal, taxAmount, discountAmount, totalAmount, paymentMethod, orderType, timestamp, staffName, status
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            ''',
            'args': [
              _toHranaValue(order.id),
              _toHranaValue(order.billNumber),
              _toHranaValue(order.tokenNumber),
              _toHranaValue(jsonEncode(order.items.map((i) => i.toJson()).toList())),
              _toHranaValue(order.subtotal),
              _toHranaValue(order.taxAmount),
              _toHranaValue(order.discountAmount),
              _toHranaValue(order.totalAmount),
              _toHranaValue(order.paymentMethod),
              _toHranaValue(order.orderType),
              _toHranaValue(order.timestamp.toIso8601String()),
              _toHranaValue(order.staffName),
              _toHranaValue(order.status)
            ]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error saving order: $e');
    }
  }

  Future<void> saveOrders(List<OrderModel> orders) async {
    if (orders.isEmpty) return;
    try {
      final List<Map<String, dynamic>> requests = [];
      for (var order in orders) {
        requests.add({
          'type': 'execute',
          'stmt': {
            'sql': '''
              INSERT OR REPLACE INTO orders (
                id, billNumber, tokenNumber, items, subtotal, taxAmount, discountAmount, totalAmount, paymentMethod, orderType, timestamp, staffName, status
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            ''',
            'args': [
              _toHranaValue(order.id),
              _toHranaValue(order.billNumber),
              _toHranaValue(order.tokenNumber),
              _toHranaValue(jsonEncode(order.items.map((i) => i.toJson()).toList())),
              _toHranaValue(order.subtotal),
              _toHranaValue(order.taxAmount),
              _toHranaValue(order.discountAmount),
              _toHranaValue(order.totalAmount),
              _toHranaValue(order.paymentMethod),
              _toHranaValue(order.orderType),
              _toHranaValue(order.timestamp.toIso8601String()),
              _toHranaValue(order.staffName),
              _toHranaValue(order.status)
            ]
          }
        });
      }
      requests.add({'type': 'close'});
      await _executePipeline(requests);
    } catch (e) {
      debugPrint('Turso error saving batch orders: $e');
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': 'UPDATE orders SET status = ? WHERE id = ?;',
            'args': [
              _toHranaValue(newStatus),
              _toHranaValue(orderId),
            ]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error updating order status: $e');
    }
  }

  Future<void> markAllBilledAsCompleted() async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "UPDATE orders SET status = 'Completed' WHERE status = 'Billed';",
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error marking all billed orders completed: $e');
    }
  }

  Future<void> deleteOrder(String id) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': 'DELETE FROM orders WHERE id = ?;',
            'args': [_toHranaValue(id)]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error deleting order: $e');
    }
  }

  Future<void> clearOrders() async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': 'DELETE FROM orders;'
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error clearing orders: $e');
    }
  }

  // --- SETTINGS METHODS --- //

  Future<Map<String, dynamic>> getAllSettings() async {
    try {
      final pipeline = await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "SELECT key, value FROM settings WHERE key IN ('business_profile', 'token_customization', 'custom_categories');"
          }
        },
        {
          'type': 'close'
        }
      ]);

      if (pipeline['results'] == null || (pipeline['results'] as List).isEmpty) {
        return {};
      }
      final firstResult = pipeline['results'][0];
      if (firstResult['response'] == null || firstResult['response']['result'] == null) {
        return {};
      }
      final result = firstResult['response']['result'] as Map<String, dynamic>;
      final parsed = _parseRows(result);
      final Map<String, dynamic> settingsMap = {};
      for (var row in parsed) {
        final key = row['key']?.toString();
        final val = row['value']?.toString();
        if (key != null && val != null) {
          try {
            settingsMap[key] = jsonDecode(val);
          } catch (_) {
            settingsMap[key] = val;
          }
        }
      }
      return settingsMap;
    } catch (e) {
      debugPrint('Turso error fetching batch settings: $e');
      return {};
    }
  }

  Future<BusinessProfile?> getBusinessProfile() async {
    try {
      final pipeline = await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "SELECT value FROM settings WHERE key = 'business_profile';"
          }
        },
        {
          'type': 'close'
        }
      ]);

      final result = pipeline['results'][0]['response']['result'] as Map<String, dynamic>;
      final parsed = _parseRows(result);
      if (parsed.isNotEmpty) {
        final val = jsonDecode(parsed[0]['value'] as String) as Map<String, dynamic>;
        return BusinessProfile.fromJson(val);
      }
    } catch (e) {
      debugPrint('Turso error fetching business profile: $e');
    }
    return null;
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "INSERT OR REPLACE INTO settings (key, value) VALUES ('business_profile', ?);",
            'args': [
              _toHranaValue(jsonEncode(profile.toJson()))
            ]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error saving business profile: $e');
    }
  }

  Future<TokenCustomization?> getTokenCustomization() async {
    try {
      final pipeline = await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "SELECT value FROM settings WHERE key = 'token_customization';"
          }
        },
        {
          'type': 'close'
        }
      ]);

      final result = pipeline['results'][0]['response']['result'] as Map<String, dynamic>;
      final parsed = _parseRows(result);
      if (parsed.isNotEmpty) {
        final val = jsonDecode(parsed[0]['value'] as String) as Map<String, dynamic>;
        return TokenCustomization.fromJson(val);
      }
    } catch (e) {
      debugPrint('Turso error fetching token customization: $e');
    }
    return null;
  }

  Future<void> saveTokenCustomization(TokenCustomization config) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "INSERT OR REPLACE INTO settings (key, value) VALUES ('token_customization', ?);",
            'args': [
              _toHranaValue(jsonEncode(config.toJson()))
            ]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error saving token customization: $e');
    }
  }

  Future<List<String>> getCustomCategories() async {
    try {
      final pipeline = await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "SELECT value FROM settings WHERE key = 'custom_categories';"
          }
        },
        {
          'type': 'close'
        }
      ]);

      final result = pipeline['results'][0]['response']['result'] as Map<String, dynamic>;
      final parsed = _parseRows(result);
      if (parsed.isNotEmpty) {
        final val = jsonDecode(parsed[0]['value'] as String) as Map<String, dynamic>;
        final list = val['categories'] as List<dynamic>?;
        return list?.map((e) => e.toString()).toList() ?? [];
      }
    } catch (e) {
      debugPrint('Turso error fetching custom categories: $e');
    }
    return [];
  }

  Future<void> saveCustomCategories(List<String> categories) async {
    try {
      await _executePipeline([
        {
          'type': 'execute',
          'stmt': {
            'sql': "INSERT OR REPLACE INTO settings (key, value) VALUES ('custom_categories', ?);",
            'args': [
              _toHranaValue(jsonEncode({'categories': categories}))
            ]
          }
        },
        {
          'type': 'close'
        }
      ]);
    } catch (e) {
      debugPrint('Turso error saving custom categories: $e');
    }
  }
}
