import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/printer_provider.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import 'checkout_dialog.dart';
import '../widgets/menu_item_image.dart';

class StaffPOSScreen extends StatefulWidget {
  const StaffPOSScreen({super.key});

  @override
  State<StaffPOSScreen> createState() => _StaffPOSScreenState();
}

class _StaffPOSScreenState extends State<StaffPOSScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        Provider.of<MenuProvider>(context, listen: false).loadMenuItems(forceOnline: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Special Chai':
        return Icons.coffee_rounded;
      case 'Cold Teas':
        return Icons.local_drink_rounded;
      case 'Green & Herbal':
        return Icons.eco_rounded;
      case 'Snacks & Bites':
        return Icons.fastfood_rounded;
      case 'Desserts':
        return Icons.cake_rounded;
      default:
        return Icons.restaurant_menu_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final menuProvider = Provider.of<MenuProvider>(context);
    final posProvider = Provider.of<POSProvider>(context);
    final printerProvider = Provider.of<PrinterProvider>(context);

    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryAmber.withValues(alpha: 0.3), width: 1.5),
                image: const DecorationImage(
                  image: AssetImage('assets/logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AROMAA CAFE',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                Text(
                  'Staff Counter: ${authProvider.activeStaffName}',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Bluetooth Status Pill
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(printerProvider.config.isConnected
                      ? 'Connected to Bluetooth Printer: ${printerProvider.config.deviceName}'
                      : 'Bluetooth Printer disconnected. Switch to Owner Portal to configure.'),
                  backgroundColor: printerProvider.config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: printerProvider.config.isConnected
                    ? AppTheme.matchaGreen.withValues(alpha: 0.2)
                    : Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: printerProvider.config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    printerProvider.config.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                    size: 14,
                    color: printerProvider.config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    printerProvider.config.isConnected ? 'Printer Ready' : 'BT Offline',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: printerProvider.config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ),

          IconButton(
            tooltip: 'Switch Portal / Logout',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              authProvider.logout();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // 1. PERMANENT LEFT SIDE: Category Menu Sidebar
          SizedBox(
            width: isWide ? 175 : 115,
            child: _buildLeftMenuSidebar(context, menuProvider, isCompact: true),
          ),
          Container(width: 1, color: AppTheme.dividerColor),

          // 2. CENTER: Items Grid & Search
          Expanded(
            flex: isWide ? 3 : 1,
            child: Column(
              children: [
                Expanded(child: _buildItemsGridSection(context, menuProvider, posProvider)),
                if (!isWide) _buildMobileCartFooter(context, posProvider),
              ],
            ),
          ),

          // 3. RIGHT SIDE: Cart Sidebar (on Desktop / Tablet Wide Screens)
          if (isWide) ...[
            Container(width: 1, color: AppTheme.dividerColor),
            Expanded(
              flex: 2,
              child: _buildCartSidebar(context, posProvider),
            ),
          ],
        ],
      ),
    );
  }

  // --- LEFT SIDE: CATEGORY MENU SIDEBAR --- //
  Widget _buildLeftMenuSidebar(BuildContext context, MenuProvider menuProvider, {bool isCompact = false}) {
    return Container(
      color: AppTheme.cardBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isCompact ? 10 : 16, 14, isCompact ? 10 : 16, 10),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded, size: 18, color: AppTheme.primaryAmber),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isCompact ? 'CATEGORIES' : 'MENU CATEGORIES',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: isCompact ? 10 : 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.dividerColor),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: isCompact ? 6 : 10),
              itemCount: menuProvider.categories.length,
              itemBuilder: (context, index) {
                final category = menuProvider.categories[index];
                final isSelected = menuProvider.selectedCategory == category;
                final icon = _getCategoryIcon(category);

                // Count items in category
                final count = category == 'All'
                    ? menuProvider.items.length
                    : menuProvider.items.where((i) => i.category == category).length;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => menuProvider.selectCategory(category),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: EdgeInsets.symmetric(
                          horizontal: isCompact ? 8 : 12,
                          vertical: isCompact ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryAmber : AppTheme.cardSurface,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryAmber.withValues(alpha: 0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: isCompact ? 16 : 18,
                              color: isSelected ? Colors.black : AppTheme.primaryAmber,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                category,
                                maxLines: 2,
                                softWrap: true,
                                style: GoogleFonts.outfit(
                                  fontSize: isCompact ? 10 : 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? Colors.black : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : AppTheme.dividerColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.black : AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  // --- CENTER SECTION: ITEMS GRID & SEARCH --- //
  Widget _buildItemsGridSection(
    BuildContext context,
    MenuProvider menuProvider,
    POSProvider posProvider,
  ) {
    final items = menuProvider.filteredItems;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return Column(
      children: [
        // Search Bar Header
        Container(
          padding: const EdgeInsets.all(12),
          color: AppTheme.cardBg,
          child: TextField(
            controller: _searchController,
            onChanged: (val) => menuProvider.setSearchQuery(val),
            decoration: InputDecoration(
              hintText: 'Search chai, iced teas, snacks or code (TC-01)...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        menuProvider.setSearchQuery('');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Items Grid
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => menuProvider.loadMenuItems(forceOnline: true),
            color: AppTheme.primaryAmber,
            child: items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: size.height * 0.2),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.coffee_maker_outlined, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 12),
                            Text(
                              'No menu items found',
                              style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isWide ? 3 : 2,
                      childAspectRatio: isWide ? 0.75 : 0.70,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _buildMenuItemCard(context, item, posProvider);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(BuildContext context, MenuItem item, POSProvider posProvider) {
    final cartCount = posProvider.getItemQuantity(item.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.isAvailable ? () => posProvider.addToCart(item) : null,
        child: Opacity(
          opacity: item.isAvailable ? 1.0 : 0.5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Image with Code & Quantity Badge Overlays
              SizedBox(
                height: 105,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MenuItemImage(
                      imageUrl: item.effectiveImageUrl,
                      iconSize: 36,
                    ),

                    // Top Gradient Overlay for readability of badges
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.center,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Row: Item Code & Quantity Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!item.isAvailable)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SOLD OUT',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else if (cartCount > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    posProvider.decrementCartItem(item.id);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.remove_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryAmber,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '$cartCount',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Details: Name, Description, Price & Add Button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 2,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.description,
                            maxLines: 3,
                            softWrap: true,
                            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rs.${item.price.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryAmber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- RIGHT SIDE: CART SIDEBAR --- //
  Widget _buildCartSidebar(BuildContext context, POSProvider posProvider) {
    final cartItems = posProvider.cartItems;

    return Container(
      color: AppTheme.cardBg,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: AppTheme.primaryAmber),
                    const SizedBox(width: 8),
                    Text(
                      'Current Order',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                if (cartItems.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                    label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                    onPressed: () => posProvider.clearCart(),
                  ),
              ],
            ),
          ),

          // Cart List
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_shopping_cart_rounded, size: 54, color: AppTheme.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          'Cart is empty',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap items from the left menu to add to bill',
                          style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cartItems.length,
                    separatorBuilder: (_, __) => const Divider(height: 12, color: AppTheme.dividerColor),
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.item.name,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                Text(
                                  'Rs.${item.unitPrice.toStringAsFixed(0)} each',
                                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),

                          // Quantity controls
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20, color: Colors.redAccent),
                                onPressed: () => posProvider.updateQuantity(index, -1),
                              ),
                              Text(
                                '${item.quantity}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20, color: AppTheme.primaryAmber),
                                onPressed: () => posProvider.updateQuantity(index, 1),
                              ),
                            ],
                          ),

                          SizedBox(
                            width: 60,
                            child: Text(
                              'Rs.${item.totalPrice.toStringAsFixed(0)}',
                              textAlign: pwTextAlignRight(),
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Subtotal & Checkout Action Footer
          if (cartItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.cardSurface,
                border: Border(top: BorderSide(color: AppTheme.dividerColor)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subtotal:', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary)),
                      Text('Rs.${posProvider.subtotal.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 13)),
                    ],
                  ),
                  if (posProvider.taxEnabled && posProvider.taxPercentage > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('GST / Tax (${posProvider.taxPercentage.toStringAsFixed(0)}%):', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary)),
                        Text('Rs.${posProvider.taxAmount.toStringAsFixed(2)}', style: GoogleFonts.outfit(fontSize: 13)),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL BILL:', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        'Rs.${posProvider.grandTotal.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryAmber),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print_rounded, color: Colors.black),
                      label: const Text('PROCEED TO BILL & PRINT', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => const CheckoutDialog(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Mobile Cart Footer
  Widget _buildMobileCartFooter(BuildContext context, POSProvider posProvider) {
    if (posProvider.cartItems.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.cardSurface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${posProvider.totalItemCount} Items in Cart', style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary)),
              Text(
                'Total: Rs.${posProvider.grandTotal.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryAmber),
              ),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.black),
            label: const Text('Checkout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryAmber,
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const CheckoutDialog(),
              );
            },
          ),
        ],
      ),
    );
  }

  pwTextAlignRight() => TextAlign.right;
}
