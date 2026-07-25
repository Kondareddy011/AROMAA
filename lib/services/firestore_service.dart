import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/business_profile.dart';
import '../models/token_customization.dart';


class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection names
  static const String _ordersCollection = 'orders';
  static const String _menuCollection = 'menu_items';
  static const String _settingsCollection = 'settings';

  // --- MENU METHODS --- //

  Future<List<MenuItem>> getMenuItems() async {
    try {
      final snapshot = await _db.collection(_menuCollection).get();
      return snapshot.docs
          .map((doc) => MenuItem.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Firestore error fetching menu items: $e');
      return [];
    }
  }

  Future<void> saveMenuItem(MenuItem item) async {
    try {
      await _db.collection(_menuCollection).doc(item.id).set(item.toJson());
    } catch (e) {
      print('Firestore error saving menu item: $e');
    }
  }

  Future<void> deleteMenuItem(String id) async {
    try {
      await _db.collection(_menuCollection).doc(id).delete();
    } catch (e) {
      print('Firestore error deleting menu item: $e');
    }
  }

  // --- ORDER METHODS --- //

  Future<List<OrderModel>> getOrders() async {
    try {
      final snapshot = await _db
          .collection(_ordersCollection)
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => OrderModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Firestore error fetching orders: $e');
      return [];
    }
  }

  Future<void> saveOrder(OrderModel order) async {
    try {
      await _db.collection(_ordersCollection).doc(order.id).set(order.toJson());
    } catch (e) {
      print('Firestore error saving order: $e');
    }
  }

  Future<void> saveOrders(List<OrderModel> orders) async {
    final batch = _db.batch();
    for (var o in orders) {
      final docRef = _db.collection(_ordersCollection).doc(o.id);
      batch.set(docRef, o.toJson());
    }
    await batch.commit();
  }

  Future<void> clearOrders() async {
    try {
      final snapshot = await _db.collection(_ordersCollection).get();
      final batch = _db.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('Firestore error clearing orders: $e');
    }
  }

  // --- SETTINGS METHODS --- //

  Future<BusinessProfile?> getBusinessProfile() async {
    try {
      final doc = await _db.collection(_settingsCollection).doc('business_profile').get();
      if (doc.exists && doc.data() != null) {
        return BusinessProfile.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Firestore error fetching business profile: $e');
    }
    return null;
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    try {
      await _db
          .collection(_settingsCollection)
          .doc('business_profile')
          .set(profile.toJson());
    } catch (e) {
      print('Firestore error saving business profile: $e');
    }
  }

  Future<TokenCustomization?> getTokenCustomization() async {
    try {
      final doc = await _db.collection(_settingsCollection).doc('token_customization').get();
      if (doc.exists && doc.data() != null) {
        return TokenCustomization.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Firestore error fetching token customization: $e');
    }
    return null;
  }

  Future<void> saveTokenCustomization(TokenCustomization config) async {
    try {
      await _db
          .collection(_settingsCollection)
          .doc('token_customization')
          .set(config.toJson());
    } catch (e) {
      print('Firestore error saving token customization: $e');
    }
  }
}
