import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../models/order.dart';
import '../../providers/printer_provider.dart';
import '../../services/bluetooth_printer_service.dart';
import '../../theme/app_theme.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final OrderModel order;

  const ReceiptPreviewDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);
    final config = printerProvider.config;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dialog Header
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryAmber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Receipt Print Preview',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),

            // Thermal Paper Roll Preview Box
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PdfPreview(
                    build: (format) => BluetoothPrinterService.generateThermalReceiptPdf(
                      order: order,
                      config: config,
                    ),
                    maxPageWidth: 320,
                    allowPrinting: false,
                    allowSharing: true,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                    loadingWidget: const Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryAmber),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Printer Connection Status Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: config.isConnected
                    ? AppTheme.matchaGreen.withValues(alpha: 0.15)
                    : Colors.orange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    config.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                    size: 18,
                    color: config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      config.isConnected
                          ? 'Printer Paired: ${config.deviceName} (${config.paperWidthMm}mm)'
                          : 'Bluetooth Printer Not Paired (System PDF Spooler Ready)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('System Print / PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.dividerColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      BluetoothPrinterService.printReceipt(
                        context: context,
                        order: order,
                        config: config,
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bluetooth_audio_rounded, size: 18),
                    label: const Text('Bluetooth Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      if (!config.isConnected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'No Bluetooth printer paired. Please pair your Bluetooth thermal printer in Owner Portal > Printer Setup.'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      } else {
                        final success = await printerProvider.printReceiptDirectly(order);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Sent receipt ESC/POS payload to ${config.deviceName}!'
                                  : 'Failed sending data to ${config.deviceName}. Check Bluetooth connection.'),
                              backgroundColor: success ? AppTheme.matchaGreen : Colors.redAccent,
                            ),
                          );
                        }
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
