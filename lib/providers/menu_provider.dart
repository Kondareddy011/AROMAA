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
        ..._customCategories,
      ];

  List<MenuItem> get filteredItems {
    final list = _items.where((item) {
      final matchesCategory = _selectedCategory == 'All' || item.category == _selectedCategory;
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.itemCode.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  MenuProvider() {
    loadMenuItems();
  }

  Future<void> loadMenuItems({bool forceOnline = false}) async {
    _isLoading = true;
    notifyListeners();

    const demoItemIds = {
      'item_1', 'item_2', 'item_3', 'item_4', 'item_5', 'item_6',
      'item_7', 'item_8', 'item_9', 'item_10', 'item_11', 'item_12'
    };

    if (!forceOnline) {
      // Offline mode: load strictly from local storage cache
      _customCategories = await _storageService.getCustomCategories();
      if (_customCategories.isEmpty) {
        _customCategories = [
          'Special Chai',
          'Cold Teas',
          'Green & Herbal',
          'Snacks & Bites',
          'Desserts',
        ];
        await _storageService.saveCustomCategories(_customCategories);
      }

      _items = await _storageService.getMenuItems();
      _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      
      // Auto-assign sequential sort orders if needed
      bool needsReindex = false;
      for (int i = 0; i < _items.length; i++) {
        if (_items[i].sortOrder != i) {
          _items[i] = _items[i].copyWith(sortOrder: i);
          needsReindex = true;
        }
      }
      if (needsReindex) {
        await _storageService.saveMenuItems(_items);
      }

      // As a absolute fallback if local is empty, try once from remote
      if (_items.isEmpty) {
        try {
          final remoteItems = await _firestoreService.getMenuItems();
          if (remoteItems.isNotEmpty) {
            _items = remoteItems;
            _items.removeWhere((item) => demoItemIds.contains(item.id));
            _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            for (int i = 0; i < _items.length; i++) {
              _items[i] = _items[i].copyWith(sortOrder: i);
            }
            await _storageService.saveMenuItems(_items);
          }
        } catch (e) {
          print('Local fallback Firestore error: $e');
        }
      }
    } else {
      // Online mode: force fetch from remote Firestore database and sync to offline storage
      try {
        final remoteCats = await _firestoreService.getCustomCategories();
        if (remoteCats.isNotEmpty) {
          _customCategories = remoteCats;
          await _storageService.saveCustomCategories(_customCategories);
        }
      } catch (e) {
        print('Firestore fetch categories error: $e');
      }

      try {
        final remoteItems = await _firestoreService.getMenuItems();
        if (remoteItems.isNotEmpty) {
          _items = remoteItems;
          _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
          final demoItems = _items.where((item) => demoItemIds.contains(item.id)).toList();
          if (demoItems.isNotEmpty) {
            _items.removeWhere((item) => demoItemIds.contains(item.id));
            for (int i = 0; i < _items.length; i++) {
              _items[i] = _items[i].copyWith(sortOrder: i);
            }
            await _storageService.saveMenuItems(_items);
            for (var demo in demoItems) {
              await _firestoreService.deleteMenuItem(demo.id);
            }
          } else {
            bool needsReindex = false;
            for (int i = 0; i < _items.length; i++) {
              if (_items[i].sortOrder != i) {
                _items[i] = _items[i].copyWith(sortOrder: i);
                needsReindex = true;
              }
            }
            await _storageService.saveMenuItems(_items);
            if (needsReindex) {
              for (var item in _items) {
                await _firestoreService.saveMenuItem(item);
              }
            }
          }
        }
      } catch (e) {
        print('Firestore fetch menu items error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  List<String> get customCategories => _customCategories;

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

  Future<void> deleteCategory(String categoryName) async {
    _customCategories.remove(categoryName);
    await _storageService.saveCustomCategories(_customCategories);
    await _firestoreService.saveCustomCategories(_customCategories);
    notifyListeners();
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
    final itemWithOrder = newItem.copyWith(sortOrder: _items.length);
    _items.add(itemWithOrder);
    await _storageService.saveMenuItems(_items);
    await _firestoreService.saveMenuItem(itemWithOrder);
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
    // Reindex remaining items
    for (int i = 0; i < _items.length; i++) {
      _items[i] = _items[i].copyWith(sortOrder: i);
    }
    await _storageService.saveMenuItems(_items);
    await _firestoreService.deleteMenuItem(itemId);
    // Save updated index to Firestore
    for (var item in _items) {
      await _firestoreService.saveMenuItem(item);
    }
    notifyListeners();
  }

  Future<void> moveItemUp(String itemId) async {
    final filtered = filteredItems;
    final fIndex = filtered.indexWhere((i) => i.id == itemId);
    if (fIndex > 0) {
      final current = filtered[fIndex];
      final previous = filtered[fIndex - 1];

      final mIndexCurrent = _items.indexWhere((i) => i.id == current.id);
      final mIndexPrev = _items.indexWhere((i) => i.id == previous.id);

      if (mIndexCurrent != -1 && mIndexPrev != -1) {
        final tempOrder = current.sortOrder;
        _items[mIndexCurrent] = current.copyWith(sortOrder: previous.sortOrder);
        _items[mIndexPrev] = previous.copyWith(sortOrder: tempOrder);

        _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        await _storageService.saveMenuItems(_items);
        await _firestoreService.saveMenuItem(_items[mIndexCurrent]);
        await _firestoreService.saveMenuItem(_items[mIndexPrev]);
        notifyListeners();
      }
    }
  }

  Future<void> moveItemDown(String itemId) async {
    final filtered = filteredItems;
    final fIndex = filtered.indexWhere((i) => i.id == itemId);
    if (fIndex != -1 && fIndex < filtered.length - 1) {
      final current = filtered[fIndex];
      final next = filtered[fIndex + 1];

      final mIndexCurrent = _items.indexWhere((i) => i.id == current.id);
      final mIndexNext = _items.indexWhere((i) => i.id == next.id);

      if (mIndexCurrent != -1 && mIndexNext != -1) {
        final tempOrder = current.sortOrder;
        _items[mIndexCurrent] = current.copyWith(sortOrder: next.sortOrder);
        _items[mIndexNext] = next.copyWith(sortOrder: tempOrder);

        _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        await _storageService.saveMenuItems(_items);
        await _firestoreService.saveMenuItem(_items[mIndexCurrent]);
        await _firestoreService.saveMenuItem(_items[mIndexNext]);
        notifyListeners();
      }
    }
  }

  Future<void> reorderItems(int oldIndex, int newIndex) async {
    final filtered = List<MenuItem>.from(filteredItems);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final List<int> originalSortOrders = filtered.map((e) => e.sortOrder).toList();

    final item = filtered.removeAt(oldIndex);
    filtered.insert(newIndex, item);

    for (int i = 0; i < filtered.length; i++) {
      final currentItem = filtered[i];
      final mIndex = _items.indexWhere((it) => it.id == currentItem.id);
      if (mIndex != -1) {
        _items[mIndex] = _items[mIndex].copyWith(sortOrder: originalSortOrders[i]);
      }
    }

    _items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    await _storageService.saveMenuItems(_items);

    for (int i = 0; i < filtered.length; i++) {
      final currentItem = filtered[i];
      final mIndex = _items.indexWhere((it) => it.id == currentItem.id);
      if (mIndex != -1) {
        await _firestoreService.saveMenuItem(_items[mIndex]);
      }
    }

    notifyListeners();
  }
}
