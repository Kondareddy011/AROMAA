import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/item.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import '../models/business_profile.dart';

class StorageService {
  static const String _keyItems = 'aroma_menu_items';
  static const String _keyOrders = 'aroma_orders_history';
  static const String _keyPrinterConfig = 'aroma_printer_config';
  static const String _keyOwnerPin = 'aroma_owner_pin';
  static const String _keyBusinessProfile = 'aroma_business_profile';
  static const String _keyTokenCustomization = 'aroma_token_customization';

  // Seed Initial Menu Items with High Quality Images
  static List<MenuItem> get initialMenuItems => [
        MenuItem(
          id: 'item_1',
          itemCode: 'TC-01',
          name: 'Kulhad Elaichi Chai',
          category: 'Special Chai',
          price: 30.0,
          description: 'Authentic clay pot brewed tea infused with fresh cardamom.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_2',
          itemCode: 'TC-02',
          name: 'Ginger Masala Chai',
          category: 'Special Chai',
          price: 35.0,
          description: 'Strong tea infused with crushed fresh ginger & Indian spices.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_3',
          itemCode: 'TC-03',
          name: 'Irani Special Dum Chai',
          category: 'Special Chai',
          price: 40.0,
          description: 'Rich, thick creamy authentic Hyderabadi Dum tea.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1597481499750-3e6b22637e12?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_4',
          itemCode: 'CT-01',
          name: 'Iced Peach Sparkling Tea',
          category: 'Cold Teas',
          price: 90.0,
          description: 'Refreshing brewed black tea blended with peach juice and mint.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_5',
          itemCode: 'CT-02',
          name: 'Lemon Mint Iced Tea',
          category: 'Cold Teas',
          price: 80.0,
          description: 'Zesty lemon juice, fresh mint leaves & chilled black tea.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_6',
          itemCode: 'HT-01',
          name: 'Kashmiri Saffron Kahwa',
          category: 'Green & Herbal',
          price: 110.0,
          description: 'Traditional green tea brewed with saffron strands, cinnamon & almonds.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1544787219-7f47ccb76574?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_7',
          itemCode: 'HT-02',
          name: 'Organic Matcha Green Tea',
          category: 'Green & Herbal',
          price: 120.0,
          description: 'Premium Japanese ceremonial grade matcha whisked with warm water/milk.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_8',
          itemCode: 'SN-01',
          name: 'Bun Maska (Maskan)',
          category: 'Snacks & Bites',
          price: 50.0,
          description: 'Fresh warm soft bun stuffed with generous sweet white butter.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_9',
          itemCode: 'SN-02',
          name: 'Hot Crispy Samosa (2 Pcs)',
          category: 'Snacks & Bites',
          price: 40.0,
          description: 'Crispy fried potato samosas served with sweet dates & mint chutney.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_10',
          itemCode: 'SN-03',
          name: 'Paneer Cheese Grill Sandwich',
          category: 'Snacks & Bites',
          price: 120.0,
          description: 'Loaded paneer tikka cubes with melted cheese & secret spices.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_11',
          itemCode: 'DS-01',
          name: 'Warm Chocolate Sizzling Brownie',
          category: 'Desserts',
          price: 140.0,
          description: 'Rich dark chocolate brownie served with vanilla ice cream.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500&auto=format&fit=crop',
        ),
        MenuItem(
          id: 'item_12',
          itemCode: 'DS-02',
          name: 'Rose Milk Cake Slice',
          category: 'Desserts',
          price: 110.0,
          description: 'Soft sponge soaked in fragrant rose cardamom milk syrup.',
          isAvailable: true,
          imageUrl: 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=500&auto=format&fit=crop',
        ),
      ];

  // Load Menu Items
  Future<List<MenuItem>> getMenuItems() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyItems);
    if (jsonStr == null || jsonStr.isEmpty) {
      await saveMenuItems(initialMenuItems);
      return initialMenuItems;
    }
    try {
      final List<dynamic> rawList = jsonDecode(jsonStr);
      final list = rawList.map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList();
      // Ensure existing menu items get seeded image URLs if missing
      bool modified = false;
      for (int i = 0; i < list.length; i++) {
        if (list[i].imageUrl.isEmpty) {
          final seedMatch = initialMenuItems.firstWhere(
            (s) => s.id == list[i].id || s.itemCode == list[i].itemCode,
            orElse: () => list[i],
          );
          final newUrl = seedMatch.imageUrl.isNotEmpty ? seedMatch.imageUrl : list[i].effectiveImageUrl;
          list[i] = list[i].copyWith(imageUrl: newUrl);
          modified = true;
        }
      }
      if (modified) {
        await saveMenuItems(list);
      }
      return list;
    } catch (_) {
      return initialMenuItems;
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
}
