import 'package:flutter/material.dart';
import '../services/storage_service.dart';

enum UserRole { none, staff, owner }

class AuthProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();

  UserRole _currentRole = UserRole.none;
  String _activeStaffName = 'Staff Counter 1';
  String _ownerPin = '1234';
  bool _isLoading = false;

  UserRole get currentRole => _currentRole;
  String get activeStaffName => _activeStaffName;
  bool get isLoading => _isLoading;
  String get ownerPin => _ownerPin;

  AuthProvider() {
    _loadOwnerPin();
  }

  Future<void> _loadOwnerPin() async {
    _ownerPin = await _storageService.getOwnerPin();
    notifyListeners();
  }

  void loginAsStaff(String staffName) {
    _activeStaffName = staffName.isNotEmpty ? staffName : 'Staff Counter 1';
    _currentRole = UserRole.staff;
    notifyListeners();
  }

  Future<bool> verifyAndLoginAsOwner(String pin) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    if (pin == _ownerPin) {
      _currentRole = UserRole.owner;
      _isLoading = false;
      notifyListeners();
      return true;
    } else {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateOwnerPin(String oldPin, String newPin) async {
    if (oldPin != _ownerPin) return false;
    _ownerPin = newPin;
    await _storageService.setOwnerPin(newPin);
    notifyListeners();
    return true;
  }

  void logout() {
    _currentRole = UserRole.none;
    notifyListeners();
  }
}
