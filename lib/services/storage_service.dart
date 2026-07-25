import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import '../models/business_profile.dart';
import '../models/token_customization.dart';


class StorageService {
  static const String _keyItems = 'aroma_menu_items';
  static const String _keyOrders = 'aroma_orders_history';
  static const String _keyPrinterConfig = 'aroma_printer_config';
  static const String _keyOwnerPin = 'aroma_owner_pin';
  static const String _keyBusinessProfile = 'aroma_business_profile';
  static const String _keyTokenCustomization = 'aroma_token_customization';

  // Seed Initial Menu Items with High Quality Images
  static List<MenuItem> get initialMenuItems => [];

  // Load Menu Items
  Future<List<MenuItem>> getMenuItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyItems);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> rawList = jsonDecode(jsonStr);
      final list = rawList.map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  // Save Menu Items
  Future<void> saveMenuItems(List<MenuItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_keyItems, jsonEncode(rawList));
  }

  // Load Real Orders (No Demo Data)
  Future<List<OrderModel>> getOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyOrders);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> rawList = jsonDecode(jsonStr);
      return rawList.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // Save Orders
  Future<void> saveOrders(List<OrderModel> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = orders.map((e) => e.toJson()).toList();
    await prefs.setString(_keyOrders, jsonEncode(rawList));
  }

  // Clear Orders History
  Future<void> clearOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOrders);
  }

  // Printer Config
  Future<PrinterConfig> getPrinterConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyPrinterConfig);
    if (jsonStr == null || jsonStr.isEmpty) {
      return PrinterConfig();
    }
    try {
      return PrinterConfig.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return PrinterConfig();
    }
  }

  Future<void> savePrinterConfig(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPrinterConfig, jsonEncode(config.toJson()));
  }

  // Owner PIN
  Future<String> getOwnerPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyOwnerPin) ?? '1234';
  }

  Future<void> setOwnerPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOwnerPin, pin);
  }

  // Business Profile
  Future<BusinessProfile> getBusinessProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyBusinessProfile);
    if (jsonStr == null || jsonStr.isEmpty) {
      return BusinessProfile();
    }
    try {
      return BusinessProfile.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return BusinessProfile();
    }
  }

  Future<void> saveBusinessProfile(BusinessProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBusinessProfile, jsonEncode(profile.toJson()));
  }

  // Token Customization
  Future<TokenCustomization> getTokenCustomization() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyTokenCustomization);
    if (jsonStr == null || jsonStr.isEmpty) {
      return TokenCustomization();
    }
    try {
      return TokenCustomization.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return TokenCustomization();
    }
  }

  Future<void> saveTokenCustomization(TokenCustomization customization) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTokenCustomization, jsonEncode(customization.toJson()));
  }

  static const String _keyCategories = 'aroma_custom_categories';

  Future<List<String>> getCustomCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCategories) ?? [];
  }

  Future<void> saveCustomCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCategories, categories);
  }
}
