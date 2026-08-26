import '../models/item.dart';
import '../models/order.dart';
import '../models/business_profile.dart';
import '../models/token_customization.dart';
import 'turso_service.dart';

class FirestoreService {
  final TursoService _turso = TursoService();

  FirestoreService();

  // --- MENU METHODS --- //

  Future<List<MenuItem>> getMenuItems() => _turso.getMenuItems();

  Future<void> saveMenuItem(MenuItem item) => _turso.saveMenuItem(item);

  Future<void> deleteMenuItem(String id) => _turso.deleteMenuItem(id);

  // --- ORDER METHODS --- //

  Future<List<OrderModel>> getOrders() => _turso.getOrders();

  Future<void> saveOrder(OrderModel order) => _turso.saveOrder(order);

  Future<void> saveOrders(List<OrderModel> orders) => _turso.saveOrders(orders);

  Future<void> deleteOrder(String id) => _turso.deleteOrder(id);

  Future<void> clearOrders() => _turso.clearOrders();

  // --- SETTINGS METHODS --- //

  Future<BusinessProfile?> getBusinessProfile() => _turso.getBusinessProfile();

  Future<void> saveBusinessProfile(BusinessProfile profile) => _turso.saveBusinessProfile(profile);

  Future<TokenCustomization?> getTokenCustomization() => _turso.getTokenCustomization();

  Future<void> saveTokenCustomization(TokenCustomization config) => _turso.saveTokenCustomization(config);

  Future<List<String>> getCustomCategories() => _turso.getCustomCategories();

  Future<void> saveCustomCategories(List<String> categories) => _turso.saveCustomCategories(categories);
}
