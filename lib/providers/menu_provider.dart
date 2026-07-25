import 'package:flutter/material.dart';
import '../models/item.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class MenuProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final FirestoreService _firestoreService = FirestoreService();

  List<MenuItem> _items = [];
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = false;

  List<MenuItem> get items => _items;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;

  List<String> _customCategories = [];

  List<String> get categories => [
        'All',
        'Special Chai',
        'Cold Teas',
        'Green & Herbal',
        'Snacks & Bites',
        'Desserts',
        ..._customCategories,
      ];

  List<MenuItem> get filteredItems {
    return _items.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.itemCode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  MenuProvider() {
    loadMenuItems();
  }

  Future<void> loadMenuItems() async {
    _isLoading = true;
    notifyListeners();

    // Load categories
    final remoteCats = await _firestoreService.getCustomCategories();
    if (remoteCats.isNotEmpty) {
      _customCategories = remoteCats;
      await _storageService.saveCustomCategories(_customCategories);
    } else {
      _customCategories = await _storageService.getCustomCategories();
    }
    
    // Try to load from Firestore first
    final remoteItems = await _firestoreService.getMenuItems();
    if (remoteItems.isNotEmpty) {
      _items = remoteItems;
      await _storageService.saveMenuItems(_items); // Cache locally
    } else {
      // Fallback to local storage
      _items = await _storageService.getMenuItems();
      if (_items.isNotEmpty) {
        for (var item in _items) {
          await _firestoreService.saveMenuItem(item);
        }
      }
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCategory(String categoryName) async {
    final nameTrimmed = categoryName.trim();
    if (nameTrimmed.isEmpty) return;

    final list = categories;
    if (!list.contains(nameTrimmed)) {
      _customCategories.add(nameTrimmed);
      await _storageService.saveCustomCategories(_customCategories);
      await _firestoreService.saveCustomCategories(_customCategories);
      notifyListeners();
    }
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> addItem(MenuItem newItem) async {
    _items.add(newItem);
    await _storageService.saveMenuItems(_items);
    await _firestoreService.saveMenuItem(newItem);
    notifyListeners();
  }

  Future<void> updateItem(MenuItem updatedItem) async {
    final index = _items.indexWhere((i) => i.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      await _storageService.saveMenuItems(_items);
      await _firestoreService.saveMenuItem(updatedItem);
      notifyListeners();
    }
  }

  Future<void> toggleAvailability(String itemId) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(isAvailable: !_items[index].isAvailable);
      await _storageService.saveMenuItems(_items);
      await _firestoreService.saveMenuItem(_items[index]);
      notifyListeners();
    }
  }

  Future<void> deleteItem(String itemId) async {
    _items.removeWhere((i) => i.id == itemId);
    await _storageService.saveMenuItems(_items);
    await _firestoreService.deleteMenuItem(itemId);
    notifyListeners();
  }
}
