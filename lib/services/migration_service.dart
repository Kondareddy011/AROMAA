import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/item.dart';
import '../models/order.dart';
import '../models/business_profile.dart';
import '../models/token_customization.dart';
import 'turso_service.dart';

class MigrationService {
  static const String _projectId = 'aroma-945aa';
  static const String _firestoreBaseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static Map<String, dynamic> _parseFirestoreFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    fields.forEach((key, valObj) {
      final Map<String, dynamic> map = valObj as Map<String, dynamic>;
      if (map.containsKey('stringValue')) {
        result[key] = map['stringValue'];
      } else if (map.containsKey('doubleValue')) {
        result[key] = (map['doubleValue'] as num).toDouble();
      } else if (map.containsKey('integerValue')) {
        result[key] = int.tryParse(map['integerValue'] as String) ?? 0;
      } else if (map.containsKey('booleanValue')) {
        result[key] = map['booleanValue'] as bool;
      } else if (map.containsKey('mapValue')) {
        final innerFields = map['mapValue']['fields'] as Map<String, dynamic>?;
        if (innerFields != null) {
          result[key] = _parseFirestoreFields(innerFields);
        }
      } else if (map.containsKey('arrayValue')) {
        final List<dynamic>? values = map['arrayValue']['values'] as List<dynamic>?;
        result[key] = values?.map((e) {
          final val = e as Map<String, dynamic>;
          if (val.containsKey('mapValue')) {
            final innerFields = val['mapValue']['fields'] as Map<String, dynamic>?;
            return innerFields != null ? _parseFirestoreFields(innerFields) : null;
          } else if (val.containsKey('stringValue')) {
            return val['stringValue'];
          } else if (val.containsKey('integerValue')) {
            return int.tryParse(val['integerValue'] as String) ?? 0;
          } else if (val.containsKey('doubleValue')) {
            return (val['doubleValue'] as num).toDouble();
          } else if (val.containsKey('booleanValue')) {
            return val['booleanValue'] as bool;
          }
          return null;
        }).where((e) => e != null).toList() ?? [];
      }
    });
    return result;
  }

  static Future<List<Map<String, dynamic>>> _fetchCollection(String collectionName) async {
    final url = Uri.parse('$_firestoreBaseUrl/$collectionName');
    final response = await http.get(url);

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        return [];
      }
      throw Exception('Failed to fetch collection $collectionName from Firestore REST API: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (!data.containsKey('documents')) {
      return [];
    }

    final docs = data['documents'] as List<dynamic>;
    final List<Map<String, dynamic>> results = [];
    for (var doc in docs) {
      final docMap = doc as Map<String, dynamic>;
      final String namePath = docMap['name'] as String;
      final String docId = namePath.split('/').last;

      final fields = docMap['fields'] as Map<String, dynamic>? ?? {};
      final parsedFields = _parseFirestoreFields(fields);
      parsedFields['id'] = docId;
      results.add(parsedFields);
    }
    return results;
  }

  static Future<void> migrateFirestoreToTurso() async {
    print('=== Starting Firestore to Turso Migration (via REST API) ===');
    try {
      final turso = TursoService();
      await turso.initDatabase();

      // 1. Migrate Menu Items
      print('Fetching menu_items from Firestore REST API...');
      final menuDocs = await _fetchCollection('menu_items');
      int menuCount = 0;
      for (var data in menuDocs) {
        try {
          final item = MenuItem.fromJson(data);
          await turso.saveMenuItem(item);
          menuCount++;
        } catch (e) {
          print('Error migrating menu item ${data['id']}: $e');
        }
      }
      print('Successfully migrated $menuCount menu items');

      // 2. Migrate Orders
      print('Fetching orders from Firestore REST API...');
      final orderDocs = await _fetchCollection('orders');
      List<OrderModel> orders = [];
      for (var data in orderDocs) {
        try {
          final order = OrderModel.fromJson(data);
          orders.add(order);
        } catch (e) {
          print('Error parsing order ${data['id']}: $e');
        }
      }
      if (orders.isNotEmpty) {
        await turso.saveOrders(orders);
      }
      print('Successfully migrated ${orders.length} orders');

      // 3. Migrate Settings
      print('Fetching settings from Firestore REST API...');
      final settingDocs = await _fetchCollection('settings');
      int settingsCount = 0;
      for (var data in settingDocs) {
        try {
          final docId = data['id'] as String;
          if (docId == 'business_profile') {
            final profile = BusinessProfile.fromJson(data);
            await turso.saveBusinessProfile(profile);
            settingsCount++;
          } else if (docId == 'token_customization') {
            final config = TokenCustomization.fromJson(data);
            await turso.saveTokenCustomization(config);
            settingsCount++;
          } else if (docId == 'custom_categories') {
            final list = data['categories'] as List<dynamic>?;
            final categories = list?.map((e) => e.toString()).toList() ?? [];
            await turso.saveCustomCategories(categories);
            settingsCount++;
          }
        } catch (e) {
          print('Error migrating setting ${data['id']}: $e');
        }
      }
      print('Successfully migrated $settingsCount settings documents');
      print('=== Migration Completed Successfully ===');
    } catch (e) {
      print('Migration failed: $e');
    }
  }
}
