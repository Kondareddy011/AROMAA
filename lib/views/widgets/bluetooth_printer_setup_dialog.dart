import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/printer_provider.dart';
import '../../theme/app_theme.dart';
import 'bluetooth_permission_dialog.dart';

class BluetoothPrinterSetupDialog extends StatelessWidget {
  const BluetoothPrinterSetupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const BluetoothPrinterSetupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);
    final config = printerProvider.config;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print_rounded, color: AppTheme.primaryAmber, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Bluetooth Printer Setup',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 12),

            // Connection Status Tile
            Card(
              elevation: 0,
              color: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: config.isConnected ? AppTheme.matchaGreen.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      config.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                      size: 32,
                      color: config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.isConnected ? 'Connected: ${config.deviceName}' : 'No Printer Connected',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            config.isConnected
                                ? 'MAC: ${config.macAddress} (${config.paperWidthMm}mm Width)'
                                : 'Scan below to discover nearby Bluetooth POS printers',
                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (config.isConnected)
                      TextButton(
                        onPressed: () async {
                          await printerProvider.disconnectDevice();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        child: const Text('Disconnect'),
                      )
                    else
                      ElevatedButton(
                        onPressed: () async {
                          final granted = await BluetoothPermissionDialog.ensurePermissionWithPopup(context);
                          if (granted) {
                            printerProvider.scanBluetoothDevices();
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bluetooth permission is required to scan printers.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAmber,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        child: printerProvider.isScanning
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Scan'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Paper Roll Width setting
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paper Roll Width:',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 58, label: Text('58mm (2 Inch)')),
                    ButtonSegment(value: 80, label: Text('80mm (3 Inch)')),
                  ],
                  selected: {config.paperWidthMm},
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: GoogleFonts.outfit(fontSize: 11),
                  ),
                  onSelectionChanged: (val) {
                    printerProvider.updateConfig(config.copyWith(paperWidthMm: val.first));
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Discovered Devices list
            Text(
              'Available Paired Devices:',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: printerProvider.discoveredDevices.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          printerProvider.scanErrorMessage ?? 
                          (printerProvider.isScanning 
                              ? 'Searching for nearby paired devices...' 
                              : 'No devices scanned yet. Click Scan above.'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12, 
                            color: printerProvider.scanErrorMessage != null ? Colors.orange : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: printerProvider.discoveredDevices.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final dev = printerProvider.discoveredDevices[index];
                        final isCurrent = config.isConnected && config.macAddress == dev['address'];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.print_rounded, color: AppTheme.primaryAmber, size: 20),
                          title: Text(
                            dev['name'] ?? 'Unknown Device',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            dev['address'] ?? '',
                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                          trailing: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isCurrent ? AppTheme.matchaGreen : AppTheme.primaryAmber,
                              foregroundColor: isCurrent ? Colors.white : Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: isCurrent ? null : () async {
                              final success = await printerProvider.connectDevice(dev['name']!, dev['address']!);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? 'Successfully connected to ${dev['name']}!'
                                        : 'Could not connect to ${dev['name']}. Ensure printer is powered ON.'),
                                    backgroundColor: success ? AppTheme.matchaGreen : Colors.redAccent,
                                  ),
                                );
                              }
                            },
                            child: Text(
                              isCurrent ? 'Connected' : 'Connect',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
