import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/sales_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/bluetooth_printer_service.dart';

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({super.key});

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final TextEditingController _cashTenderedController = TextEditingController();

  double _cashTendered = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final printerConfig = Provider.of<PrinterProvider>(context, listen: false).config;
      Provider.of<POSProvider>(context, listen: false).updateTaxSettings(
        enabled: printerConfig.taxEnabled,
        percentage: printerConfig.taxPercentage,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final posProvider = Provider.of<POSProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final printerProvider = Provider.of<PrinterProvider>(context, listen: false);

    final grandTotal = posProvider.grandTotal;
    final changeDue = _cashTendered > grandTotal ? _cashTendered - grandTotal : 0.0;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Checkout & Billing',
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 12),

              // Total Payable Display Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryAmber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL PAYABLE',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryAmber,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${posProvider.totalItemCount} Items (${posProvider.orderType})',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Text(
                      'Rs. ${grandTotal.toStringAsFixed(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryAmber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Selected Items Breakdown Details
              Text(
                'Selected Items Details',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              if (posProvider.cartItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No items in cart.',
                      style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: posProvider.cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.dividerColor),
                    itemBuilder: (context, index) {
                      final cartItem = posProvider.cartItems[index];
                      final item = cartItem.item;
                      final quantity = cartItem.quantity;
                      final itemSubtotal = item.price * quantity;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Thumbnail
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Image.network(
                                  item.effectiveImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppTheme.cardSurface,
                                    child: const Icon(Icons.coffee_rounded, size: 18, color: AppTheme.primaryAmber),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Rs.${item.price.toStringAsFixed(0)} each',
                                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),

                            // Quantity Adjustments
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded, size: 18, color: Colors.redAccent),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    posProvider.updateQuantity(index, -1);
                                  },
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '$quantity',
                                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppTheme.primaryAmber),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    posProvider.updateQuantity(index, 1);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Subtotal
                            Text(
                              'Rs.${itemSubtotal.toStringAsFixed(0)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),

              // Payment Method Selector
              Text(
                'Payment Method',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'UPI / QR 📱',
                      isSelected: posProvider.paymentMethod == 'UPI / QR',
                      onTap: () => posProvider.setPaymentMethod('UPI / QR'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Cash 💵',
                      isSelected: posProvider.paymentMethod == 'Cash',
                      onTap: () => posProvider.setPaymentMethod('Cash'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: 'Card 💳',
                      isSelected: posProvider.paymentMethod == 'Card',
                      onTap: () => posProvider.setPaymentMethod('Card'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment Mode Specific Details
              if (posProvider.paymentMethod == 'UPI / QR') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.qr_code_2_rounded, size: 80, color: AppTheme.textPrimary),
                      const SizedBox(height: 8),
                      Text(
                        'Scan & Pay via Google Pay / PhonePe / Paytm',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'UPI ID: aroma.teacafe@upi',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.primaryAmber),
                      ),
                    ],
                  ),
                ),
              ] else if (posProvider.paymentMethod == 'Cash') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _cashTenderedController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Cash Amount Received (Rs.)',
                          prefixText: 'Rs. ',
                        ),
                        onChanged: (val) {
                          setState(() {
                            _cashTendered = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Change Return:', style: GoogleFonts.outfit(fontSize: 14)),
                          Text(
                            'Rs. ${changeDue.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: changeDue >= 0 ? AppTheme.matchaGreen : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.dividerColor),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Issue & Print Bill'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        // 1. Create order with token 0
                        final order = await posProvider.checkout(
                          staffName: authProvider.activeStaffName,
                          salesProvider: salesProvider,
                          printerConfig: printerProvider.config,
                        );

                        if (!context.mounted) return;
                        if (order != null) {
                          // 2. Close checkout dialog
                          Navigator.pop(context);

                          // 3. Compute what the tentative token number and bill number will be
                          final tentativeToken = salesProvider.getNextDailyTokenNumber(printerProvider.config.tokenResetTime);
                          final today = DateTime.now();
                          final tentativeBillNum = 'ARM-${DateFormat('yyMMdd').format(today)}-${tentativeToken.toString().padLeft(3, '0')}';

                          // 4. Construct printOrder with the tentative details for printing
                          final printOrder = order.copyWith(
                            tokenNumber: tentativeToken,
                            billNumber: tentativeBillNum,
                          );

                          // 5. Try printing printOrder
                          bool printSuccess = false;
                          if (printerProvider.config.isConnected) {
                            printSuccess = await printerProvider.printReceiptDirectly(printOrder);
                          } else {
                            printSuccess = await BluetoothPrinterService.printReceipt(
                              context: context,
                              order: printOrder,
                              config: printerProvider.config,
                            );
                          }

                          // 6. If print succeeded, write the assigned token & bill number to database/state!
                          if (printSuccess) {
                            await salesProvider.updateOrderToken(order.id, tentativeToken, tentativeBillNum);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Order Checked Out & Token #$tentativeToken Printed!'),
                                  backgroundColor: AppTheme.matchaGreen,
                                ),
                              );
                            }
                          } else {
                            // If print failed or was cancelled, keep token number at 0!
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Print cancelled/failed. Token number not assigned.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryAmber : AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.primaryAmber : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.black : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
