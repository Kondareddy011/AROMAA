import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';

import '../models/order.dart';
import '../models/printer_config.dart';

class BluetoothPrinterService {
  /// Request Bluetooth & Location runtime permissions on mobile devices (Android 6+ / Android 12+)
  static Future<bool> requestBluetoothPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    try {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
      final locGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? true;

      return (scanGranted && connectGranted) || locGranted;
    } catch (e) {
      debugPrint('Permission request error: $e');
      return true;
    }
  }

  /// Check if System Bluetooth is ON
  static Future<bool> isBluetoothEnabled() async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  /// Scan and retrieve REAL paired/discovered Bluetooth devices from the OS Bluetooth adapter
  static Future<List<Map<String, String>>> scanRealBluetoothDevices() async {
    try {
      // Request Android runtime permissions for Bluetooth scan & connect
      await requestBluetoothPermissions();

      final bool btOn = await PrintBluetoothThermal.bluetoothEnabled;
      if (!btOn) {
        return [];
      }

      final List<BluetoothInfo> items = await PrintBluetoothThermal.pairedBluetooths;
      return items.map((device) {
        return {
          'name': device.name.isNotEmpty ? device.name : 'Bluetooth POS Printer',
          'address': device.macAdress,
        };
      }).toList();
    } catch (e) {
      debugPrint('Error scanning real Bluetooth devices: $e');
      return [];
    }
  }

  /// Connect directly to a real Bluetooth device using MAC address
  static Future<bool> connectRealDevice(String macAddress) async {
    try {
      await requestBluetoothPermissions();
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      return result;
    } catch (e) {
      debugPrint('Error connecting to Bluetooth device: $e');
      return false;
    }
  }

  /// Disconnect current real Bluetooth device
  static Future<bool> disconnectRealDevice() async {
    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (_) {
      return false;
    }
  }

  /// Send ESC/POS byte commands directly to connected Bluetooth thermal printer
  static Future<bool> printRealEscPosBytes(List<int> bytes) async {
    try {
      final bool isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        return await PrintBluetoothThermal.writeBytes(bytes);
      }
      return false;
    } catch (e) {
      debugPrint('Error printing ESC/POS bytes: $e');
      return false;
    }
  }

  /// Generate thermal roll PDF document suitable for 58mm or 80mm roll width.
  static Future<Uint8List> generateThermalReceiptPdf({
    required OrderModel order,
    required PrinterConfig config,
  }) async {
    final pdf = pw.Document();

    final paperWidth = config.paperWidthMm == 80
        ? PdfPageFormat.roll80
        : PdfPageFormat.roll57;

    final dateFormat = DateFormat('dd-MM-yyyy HH:mm');
    final formattedDate = dateFormat.format(order.timestamp);

    pdf.addPage(
      pw.Page(
        pageFormat: paperWidth.copyWith(
          marginTop: 8,
          marginBottom: 12,
          marginLeft: 8,
          marginRight: 8,
        ),
        build: (pw.Context context) {
          final scale = config.fontScale;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Cafe Name
              pw.Text(
                config.cafeName,
                style: pw.TextStyle(
                  fontSize: 17 * scale,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              // Tagline
              pw.Text(
                config.tagline,
                style: pw.TextStyle(fontSize: 8 * scale),
              ),
              pw.SizedBox(height: 6),
              
              // Divider
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // Token Number
              pw.Text(
                'TOKEN NO: #${order.tokenNumber.toString().padLeft(3, '0')}',
                style: pw.TextStyle(fontSize: 11 * scale, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              
              // Divider
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // Date
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Text(
                  'Date: $formattedDate',
                  style: pw.TextStyle(fontSize: 9 * scale),
                ),
              ),
              pw.SizedBox(height: 2),
              
              // Divider
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 4),

              // Items Ordered (formatted as "Item Name xQty - Rs.Amount")
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: order.items.map((item) {
                    final name = item.variant != 'Regular'
                        ? '${item.item.name} (${item.variant})'
                        : item.item.name;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                      child: pw.Text(
                        '$name x${item.quantity} - Rs.${item.totalPrice.toStringAsFixed(0)}',
                        style: pw.TextStyle(fontSize: 9 * scale),
                      ),
                    );
                  }).toList(),
                ),
              ),

              pw.SizedBox(height: 4),
              // Divider
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 2),

              // Total Amount
              pw.Text(
                'TOTAL: Rs.${order.totalAmount.toStringAsFixed(2)} (${order.paymentMethod})',
                style: pw.TextStyle(fontSize: 10 * scale, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              
              // Divider
              pw.Divider(thickness: 0.8, color: PdfColors.black),
              pw.SizedBox(height: 6),

              // Footer Message
              pw.Text(
                config.footerMessage,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 8 * scale),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Direct print method using Printing plugin (handles thermal printers / system spooler)
  static Future<bool> printReceipt({
    required BuildContext context,
    required OrderModel order,
    required PrinterConfig config,
  }) async {
    final pdfBytes = await generateThermalReceiptPdf(order: order, config: config);
    return await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Bill_${order.billNumber}',
    );
  }

  /// Builds raw ESC/POS byte sequence for direct Bluetooth serial sending
  static List<int> buildEscPosBytes({
    required OrderModel order,
    required PrinterConfig config,
  }) {
    final List<int> bytes = [];

    // ESC @ - Initialize printer
    bytes.addAll([0x1B, 0x40]);

    // Center align for Header
    bytes.addAll([0x1B, 0x61, 0x01]);

    // Bold large title
    bytes.addAll([0x1D, 0x21, 0x11]); // double width, double height
    bytes.addAll([0x1B, 0x45, 0x01]); // bold on
    bytes.addAll('${config.cafeName}\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]); // bold off
    bytes.addAll([0x1D, 0x21, 0x00]); // reset size to normal

    // Tagline
    bytes.addAll('${config.tagline}\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Bold Token Number
    bytes.addAll([0x1B, 0x45, 0x01]); // bold on
    bytes.addAll('TOKEN NO: #${order.tokenNumber.toString().padLeft(3, '0')}\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]); // bold off
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Left align for Date
    bytes.addAll([0x1B, 0x61, 0x00]);
    final formattedDate = DateFormat('dd-MM-yyyy HH:mm').format(order.timestamp);
    bytes.addAll('Date: $formattedDate\n'.codeUnits);
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Items
    for (var item in order.items) {
      final name = item.variant != 'Regular'
          ? '${item.item.name} (${item.variant})'
          : item.item.name;
      final line = '$name x${item.quantity} - Rs.${item.totalPrice.toStringAsFixed(0)}\n';
      bytes.addAll(line.codeUnits);
    }
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Center align for Total
    bytes.addAll([0x1B, 0x61, 0x01]);
    bytes.addAll([0x1B, 0x45, 0x01]); // bold on
    bytes.addAll('TOTAL: Rs.${order.totalAmount.toStringAsFixed(2)} (${order.paymentMethod})\n'.codeUnits);
    bytes.addAll([0x1B, 0x45, 0x00]); // bold off
    bytes.addAll('--------------------------------\n'.codeUnits);

    // Footer
    bytes.addAll('${config.footerMessage}\n\n\n'.codeUnits);

    // GS V 66 0 - Paper cut command
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }
}
