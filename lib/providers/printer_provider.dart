import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models/order.dart';
import '../models/printer_config.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/storage_service.dart';

class PrinterProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();

  PrinterConfig _config = PrinterConfig();
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _scanErrorMessage;
  List<Map<String, String>> _discoveredDevices = [];
  List<Printer> _systemPrinters = [];

  PrinterConfig get config => _config;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  String? get scanErrorMessage => _scanErrorMessage;
  List<Map<String, String>> get discoveredDevices => _discoveredDevices;
  List<Printer> get systemPrinters => _systemPrinters;

  PrinterProvider() {
    loadConfig();
    loadSystemPrinters();
  }

  Future<void> loadSystemPrinters() async {
    try {
      _systemPrinters = await Printing.listPrinters();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadConfig() async {
    _config = await _storageService.getPrinterConfig();
    notifyListeners();

    if (_config.macAddress.isNotEmpty && _config.macAddress != '00:11:22:33:44:55') {
      autoConnectPreviousDevice();
    }
  }

  Future<void> autoConnectPreviousDevice() async {
    _isConnecting = true;
    notifyListeners();
    try {
      final isBtOn = await BluetoothPrinterService.isBluetoothEnabled();
      if (!isBtOn) {
        _isConnecting = false;
        _config = _config.copyWith(isConnected: false);
        notifyListeners();
        return;
      }
      final success = await BluetoothPrinterService.connectRealDevice(_config.macAddress);
      _config = _config.copyWith(isConnected: success);
      await _storageService.savePrinterConfig(_config);
    } catch (_) {
      _config = _config.copyWith(isConnected: false);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> updateConfig(PrinterConfig newConfig) async {
    _config = newConfig;
    await _storageService.savePrinterConfig(_config);
    notifyListeners();
  }

  Future<void> scanBluetoothDevices() async {
    _isScanning = true;
    _scanErrorMessage = null;
    _discoveredDevices = [];
    notifyListeners();

    try {
      final isBtOn = await BluetoothPrinterService.isBluetoothEnabled();
      if (!isBtOn) {
        _scanErrorMessage = 'Bluetooth is turned OFF on this device. Please turn ON Bluetooth.';
        _isScanning = false;
        notifyListeners();
        return;
      }

      final devices = await BluetoothPrinterService.scanRealBluetoothDevices();
      _discoveredDevices = devices;

      if (_discoveredDevices.isEmpty) {
        _scanErrorMessage = 'No paired Bluetooth thermal printers found. Make sure your printer is turned ON and paired in system Bluetooth settings.';
      }
    } catch (e) {
      _scanErrorMessage = 'Failed to scan Bluetooth adapter: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connectDevice(String name, String mac) async {
    _isConnecting = true;
    notifyListeners();

    final success = await BluetoothPrinterService.connectRealDevice(mac);

    _config = _config.copyWith(
      deviceName: name,
      macAddress: mac,
      isConnected: success,
    );
    await _storageService.savePrinterConfig(_config);

    _isConnecting = false;
    notifyListeners();
    return success;
  }

  Future<void> disconnectDevice() async {
    await BluetoothPrinterService.disconnectRealDevice();
    _config = _config.copyWith(isConnected: false);
    await _storageService.savePrinterConfig(_config);
    notifyListeners();
  }

  Future<bool> printReceiptDirectly(OrderModel order) async {
    final active = await BluetoothPrinterService.isConnectionActive();
    if (!active && _config.macAddress.isNotEmpty && _config.macAddress != '00:11:22:33:44:55') {
      await autoConnectPreviousDevice();
    }
    
    final bytes = BluetoothPrinterService.buildEscPosBytes(
      order: order,
      config: _config,
    );
    return await BluetoothPrinterService.printRealEscPosBytes(bytes);
  }
}
