import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../theme/app_theme.dart';

class BluetoothPermissionDialog extends StatelessWidget {
  const BluetoothPermissionDialog({super.key});

  /// Static helper to check permissions and show popup if not granted yet
  static Future<bool> ensurePermissionWithPopup(BuildContext context) async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    // Check if permissions are already granted
    final scanStatus = await Permission.bluetoothScan.status;
    final connectStatus = await Permission.bluetoothConnect.status;
    final locStatus = await Permission.locationWhenInUse.status;

    final isFullyGranted = (scanStatus.isGranted && connectStatus.isGranted) || locStatus.isGranted;

    if (isFullyGranted) {
      return true;
    }

    if (!context.mounted) return false;

    // Show interactive custom Allow / Deny dialog
    final bool? userChoice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const BluetoothPermissionDialog(),
    );

    return userChoice ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(
                  Icons.bluetooth_searching_rounded,
                  size: 44,
                  color: AppTheme.primaryAmber,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Bluetooth Permission Required',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Explanation
            Text(
              'AROMAA Cafe POS needs access to Bluetooth & Location to scan, pair, and print bills to your thermal receipt printer.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Bullet features
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                children: [
                  _buildFeatureRow(Icons.bluetooth_connected, 'Scan real nearby Bluetooth POS printers'),
                  const SizedBox(height: 8),
                  _buildFeatureRow(Icons.print_rounded, 'Send direct ESC/POS receipt data over Bluetooth'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Deny / Allow)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.dividerColor),
                    ),
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                    child: const Text('Deny'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryAmber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      // Trigger native OS permission request
                      final statuses = await [
                        Permission.bluetoothScan,
                        Permission.bluetoothConnect,
                        Permission.locationWhenInUse,
                      ].request();

                      final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
                      final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
                      final locGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? true;

                      final isGranted = (scanGranted && connectGranted) || locGranted;

                      if (context.mounted) {
                        Navigator.pop(context, isGranted);
                      }
                    },
                    child: const Text('Allow Permission'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryAmber),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
