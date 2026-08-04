import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:file_saver/file_saver.dart';

import '../../models/item.dart';
import '../../models/order.dart';
import '../../models/business_profile.dart';
import '../../models/token_customization.dart';

import '../../providers/auth_provider.dart';
import '../../providers/menu_provider.dart';
import '../../providers/printer_provider.dart';
import '../../providers/sales_provider.dart';
import '../../theme/app_theme.dart';
import '../login_screen.dart';
import '../widgets/bluetooth_permission_dialog.dart';
import '../widgets/receipt_preview_dialog.dart';
import '../widgets/menu_item_image.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;

  // Persistent controllers for printer settings
  final TextEditingController _cafeNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _gstinController = TextEditingController();
  final TextEditingController _footerController = TextEditingController();
  final TextEditingController _taxPercentageController = TextEditingController();
  final TextEditingController _currentPinController = TextEditingController();
  final TextEditingController _newPinController = TextEditingController();
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Setup 5-second auto-refresh timer for orders
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        Provider.of<SalesProvider>(context, listen: false).loadOrders();
      }
    });

    // Force load/sync the menu items from remote Firestore online when Owner Portal opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MenuProvider>(context, listen: false).loadMenuItems(forceOnline: true);
    });
  }

  void _onTabChanged() {
    if (_tabController.index == 3 && !_tabController.indexIsChanging) {
      _autoScanAndConnectPrinters();
    }
  }

  void _autoScanAndConnectPrinters() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final printerProvider = Provider.of<PrinterProvider>(context, listen: false);
      if (!printerProvider.isScanning) {
        await printerProvider.scanBluetoothDevices();
        final config = printerProvider.config;
        if (!config.isConnected && config.macAddress.isNotEmpty && config.macAddress != '00:11:22:33:44:55') {
          final hasSaved = printerProvider.discoveredDevices.any((d) => d['address'] == config.macAddress);
          if (hasSaved) {
            final savedDevice = printerProvider.discoveredDevices.firstWhere((d) => d['address'] == config.macAddress);
            await printerProvider.connectDevice(savedDevice['name'] ?? config.deviceName, config.macAddress);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _cafeNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _gstinController.dispose();
    _footerController.dispose();
    _taxPercentageController.dispose();
    _currentPinController.dispose();
    _newPinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryAmber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryAmber),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AROMAA OWNER PORTAL',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                Text(
                  'Store Performance & Operations',
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Logout to Portal Login',
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryAmber,
          labelColor: AppTheme.primaryAmber,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Sales Analytics'),
            Tab(icon: Icon(Icons.restaurant_menu_rounded), text: 'Menu Manager'),
            Tab(icon: Icon(Icons.receipt_rounded), text: 'Order Audit'),
            Tab(icon: Icon(Icons.print_rounded), text: 'Printer Setup'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSalesAnalyticsTab(context),
          _buildMenuManagerTab(context),
          _buildOrderAuditTab(context),
          _buildPrinterSetupTab(context),
        ],
      ),
    );
  }

  // --- TAB 1: SALES ANALYTICS --- //
  Widget _buildSalesAnalyticsTab(BuildContext context) {
    final sales = Provider.of<SalesProvider>(context);

    return RefreshIndicator(
      onRefresh: () async {
        await sales.loadOrders();
        await sales.loadSettings();
      },
      color: AppTheme.primaryAmber,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revenue & Overall Sales Breakdown',
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Overview Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 750;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: isWide ? 1.6 : 1.4,
                children: [
                  _buildMetricCard(
                    title: 'Today Sales',
                    amount: 'Rs. ${sales.todaySalesTotal.toStringAsFixed(0)}',
                    subtitle: '${sales.todayOrderCount} Orders Today',
                    icon: Icons.today_rounded,
                    color: AppTheme.primaryAmber,
                    onDownload: () {
                      final now = DateTime.now();
                      final todayOrders = sales.orders.where((o) =>
                          o.timestamp.year == now.year &&
                          o.timestamp.month == now.month &&
                          o.timestamp.day == now.day).toList();
                      _exportCardReportCsv(context, todayOrders, 'Today Sales');
                    },
                  ),
                  _buildMetricCard(
                    title: 'Weekly Sales',
                    amount: 'Rs. ${sales.weeklySalesTotal.toStringAsFixed(0)}',
                    subtitle: 'Last 7 Days',
                    icon: Icons.date_range_rounded,
                    color: Colors.blueAccent,
                    onDownload: () {
                      final now = DateTime.now();
                      final startOfWeek = now.subtract(const Duration(days: 7));
                      final weeklyOrders = sales.orders.where((o) => o.timestamp.isAfter(startOfWeek)).toList();
                      _exportCardReportCsv(context, weeklyOrders, 'Weekly Sales');
                    },
                  ),
                  _buildMetricCard(
                    title: 'Monthly Sales',
                    amount: 'Rs. ${sales.monthlySalesTotal.toStringAsFixed(0)}',
                    subtitle: 'Current Month Total',
                    icon: Icons.calendar_month_rounded,
                    color: AppTheme.matchaGreen,
                    onDownload: () {
                      final now = DateTime.now();
                      final startOfMonth = now.subtract(const Duration(days: 30));
                      final monthlyOrders = sales.orders.where((o) => o.timestamp.isAfter(startOfMonth)).toList();
                      _exportCardReportCsv(context, monthlyOrders, 'Monthly Sales');
                    },
                  ),
                  _buildMetricCard(
                    title: 'Total Amount Received',
                    amount: 'Rs. ${sales.totalAmountReceived.toStringAsFixed(0)}',
                    subtitle: 'Lifetime Revenue',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.purpleAccent,
                    onDownload: () {
                      _exportCardReportCsv(context, sales.orders, 'Total Revenue');
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Revenue Chart Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Revenue Trend (Rs.)',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.show_chart_rounded, color: AppTheme.primaryAmber),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 220,
                    child: _buildSalesLineChart(sales),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom Info Row: Payment Breakdown & Top Selling
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Flex(
                direction: isWide ? Axis.horizontal : Axis.vertical,
                children: [
                  // Payment Method Breakdown
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Mode Distribution',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ...sales.paymentMethodTotals.entries.map((e) {
                              final total = sales.totalAmountReceived > 0 ? sales.totalAmountReceived : 1.0;
                              final pct = (e.value / total * 100);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e.key, style: GoogleFonts.outfit(fontSize: 13)),
                                        Text('Rs. ${e.value.toStringAsFixed(0)} (${pct.toStringAsFixed(0)}%)',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: pct / 100,
                                      color: e.key == 'UPI / QR'
                                          ? AppTheme.primaryAmber
                                          : e.key == 'Cash'
                                              ? AppTheme.matchaGreen
                                              : Colors.blueAccent,
                                      backgroundColor: AppTheme.cardSurface,
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isWide ? 16 : 0, height: isWide ? 0 : 16),

                  // Items Sold (All)
                  Expanded(
                    flex: isWide ? 1 : 0,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Items Sold (All)',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Builder(
                              builder: (context) {
                                final menuProvider = Provider.of<MenuProvider>(context);
                                final allItems = menuProvider.items;

                                // Calculate sold quantity for all items
                                final soldCounts = <String, int>{};
                                for (var o in sales.orders) {
                                  if (o.status == 'Completed') {
                                    for (var item in o.items) {
                                      soldCounts[item.item.name] = (soldCounts[item.item.name] ?? 0) + item.quantity;
                                    }
                                  }
                                }

                                // Build a list of all items, with their sold count
                                final itemsWithSales = allItems.map((item) {
                                  final count = soldCounts[item.name] ?? 0;
                                  return MapEntry(item.name, count);
                                }).toList();

                                // Also include any items that were sold but might not be in the active menu anymore
                                for (var entry in soldCounts.entries) {
                                  if (!itemsWithSales.any((element) => element.key == entry.key)) {
                                    itemsWithSales.add(entry);
                                  }
                                }

                                // Sort by count descending
                                itemsWithSales.sort((a, b) => b.value.compareTo(a.value));

                                if (itemsWithSales.isEmpty) {
                                  return Text('No sales data yet', style: GoogleFonts.outfit(color: AppTheme.textSecondary));
                                }

                                return SizedBox(
                                  height: 220,
                                  child: Scrollbar(
                                    thumbVisibility: true,
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      padding: const EdgeInsets.only(right: 8),
                                      itemCount: itemsWithSales.length,
                                      itemBuilder: (context, index) {
                                        final e = itemsWithSales[index];
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.local_cafe_rounded,
                                                    size: 16, color: AppTheme.primaryAmber),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text(
                                                  e.key,
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.cardSurface,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '${e.value} sold',
                                                  style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.primaryAmber),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onDownload,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ),
                if (onDownload != null) ...[
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 14),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onDownload,
                    tooltip: 'Download CSV',
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(icon, color: color, size: 16),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                amount,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(fontSize: 10, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesLineChart(SalesProvider sales) {
    final dailyData = sales.last7DaysDailySales;

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final idx = val.toInt();
                if (idx >= 0 && idx < dailyData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      dailyData[idx]['dayLabel'] as String,
                      style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(dailyData.length, (i) {
              return FlSpot(i.toDouble(), (dailyData[i]['total'] as double));
            }),
            isCurved: true,
            color: AppTheme.primaryAmber,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppTheme.primaryAmber.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 2: MENU MANAGER --- //
  Widget _buildMenuManagerTab(BuildContext context) {
    final menuProvider = Provider.of<MenuProvider>(context);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryAmber,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Add Menu Item'),
        onPressed: () => _showAddEditItemDialog(context),
      ),
      body: Column(
        children: [
          // Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.cardBg,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => menuProvider.setSearchQuery(val),
                    decoration: const InputDecoration(
                      hintText: 'Search menu items to edit or remove...',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Menu Items List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => menuProvider.loadMenuItems(),
              color: AppTheme.primaryAmber,
              child: ReorderableListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                buildDefaultDragHandles: false,
                itemCount: menuProvider.filteredItems.length,
                onReorder: (oldIndex, newIndex) {
                  menuProvider.reorderItems(oldIndex, newIndex);
                },
                itemBuilder: (context, index) {
                  final item = menuProvider.filteredItems[index];
                  return Card(
                    key: ValueKey(item.id),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Row(
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(
                                Icons.drag_indicator_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: MenuItemImage(
                              imageUrl: item.effectiveImageUrl,
                              width: 42,
                              height: 42,
                              iconSize: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  softWrap: true,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Rs.${item.price.toStringAsFixed(0)} • ${item.category}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: AppTheme.primaryAmber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.scale(
                                scale: 0.75,
                                child: Switch(
                                  value: item.isAvailable,
                                  activeColor: AppTheme.primaryAmber,
                                  onChanged: (_) => menuProvider.toggleAvailability(item.id),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showAddEditItemDialog(context, existingItem: item),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Confirm Item Deletion'),
                                      content: Text('Are you sure you want to remove "${item.name}" from the menu?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                          onPressed: () {
                                            menuProvider.deleteItem(item.id);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddEditItemDialog(BuildContext context, {MenuItem? existingItem}) {
    final menuProvider = Provider.of<MenuProvider>(context, listen: false);

    final isEditing = existingItem != null;
    final nameCtrl = TextEditingController(text: existingItem?.name ?? '');
    final codeCtrl = TextEditingController(text: existingItem?.itemCode ?? 'TC-0${menuProvider.items.length + 1}');
    final priceCtrl = TextEditingController(text: existingItem?.price.toStringAsFixed(0) ?? '30');
    final descCtrl = TextEditingController(text: existingItem?.description ?? '');
    final imageCtrl = TextEditingController(text: existingItem?.imageUrl ?? '');
    final availableCategories = menuProvider.categories.where((c) => c != 'All').toList();
    String category = existingItem?.category ?? (availableCategories.isNotEmpty ? availableCategories.first : 'Special Chai');
    if (!availableCategories.contains(category) && availableCategories.isNotEmpty) {
      category = availableCategories.first;
    }

    // Curated high quality demo preset images for 1-click selection
    final Map<String, String> demoPresets = {
      'Kulhad Tea': 'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=500&auto=format&fit=crop',
      'Ginger Tea': 'https://images.unsplash.com/photo-1561336313-0bd5e0b27ec8?w=500&auto=format&fit=crop',
      'Cold Tea': 'https://images.unsplash.com/photo-1556679343-c7306c1976bc?w=500&auto=format&fit=crop',
      'Lemon Mint': 'https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=500&auto=format&fit=crop',
      'Matcha': 'https://images.unsplash.com/photo-1536256263959-770b48d82b0a?w=500&auto=format&fit=crop',
      'Bun Maska': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=500&auto=format&fit=crop',
      'Samosa': 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=500&auto=format&fit=crop',
      'Sandwich': 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=500&auto=format&fit=crop',
      'Brownie': 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=500&auto=format&fit=crop',
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            final previewUrl = imageCtrl.text.trim().isNotEmpty
                ? imageCtrl.text.trim()
                : MenuItem(id: '', name: '', category: category, price: 0, description: '', itemCode: '').effectiveImageUrl;

            return AlertDialog(
              title: Text(isEditing ? 'Edit Menu Item' : 'Add New Menu Item'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 440,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Item Image Live Preview Container
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppTheme.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.dividerColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MenuItemImage(
                              imageUrl: previewUrl,
                              iconSize: 40,
                            ),

                            // Overlay Label
                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Live Image Preview',
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Image Upload & Category Selection
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: availableCategories.contains(category) ? category : (availableCategories.isNotEmpty ? availableCategories.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: availableCategories
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.outfit(fontSize: 13))))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => category = val);
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.settings_outlined, color: AppTheme.primaryAmber, size: 26),
                            onPressed: () {
                              _showManageCategoriesDialog(context, menuProvider, category, (newCat) {
                                setState(() {
                                  category = newCat;
                                });
                              });
                            },
                            tooltip: 'Manage Categories',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.photo_library_rounded, size: 16),
                              label: const Text('Gallery', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryAmber,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final XFile? photo = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 400,
                                  maxHeight: 400,
                                  imageQuality: 70,
                                );
                                if (photo != null) {
                                  final bytes = await photo.readAsBytes();
                                  final base64Str = base64Encode(bytes);
                                  setState(() {
                                    imageCtrl.text = 'data:image/jpeg;base64,$base64Str';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.camera_alt_rounded, size: 16),
                              label: const Text('Camera', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryAmber,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              onPressed: () async {
                                final picker = ImagePicker();
                                final XFile? photo = await picker.pickImage(
                                  source: ImageSource.camera,
                                  maxWidth: 400,
                                  maxHeight: 400,
                                  imageQuality: 70,
                                );
                                if (photo != null) {
                                  final bytes = await photo.readAsBytes();
                                  final base64Str = base64Encode(bytes);
                                  setState(() {
                                    imageCtrl.text = 'data:image/jpeg;base64,$base64Str';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Image URL / Path TextField
                      TextField(
                        controller: imageCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Image URL or File Path',
                          hintText: 'Paste web URL or pick image above',
                          suffixIcon: imageCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  onPressed: () {
                                    imageCtrl.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Item Name (e.g. Ginger Lemon Tea)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price (Rs.)'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(labelText: 'Description'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                    if (nameCtrl.text.trim().isEmpty || price <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please provide valid name and price')),
                      );
                      return;
                    }

                    if (isEditing) {
                      final updated = existingItem.copyWith(
                        name: nameCtrl.text.trim(),
                        itemCode: codeCtrl.text.trim(),
                        price: price,
                        category: category,
                        description: descCtrl.text.trim(),
                        imageUrl: imageCtrl.text.trim(),
                      );
                      menuProvider.updateItem(updated);
                    } else {
                      final newItem = MenuItem(
                        id: 'menu_${DateTime.now().millisecondsSinceEpoch}',
                        itemCode: codeCtrl.text.trim(),
                        name: nameCtrl.text.trim(),
                        category: category,
                        price: price,
                        description: descCtrl.text.trim(),
                        imageUrl: imageCtrl.text.trim(),
                      );
                      menuProvider.addItem(newItem);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(isEditing ? 'Save Changes' : 'Add Item'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showManageCategoriesDialog(BuildContext context, MenuProvider menuProvider, String currentCategory, Function(String) onCategorySelected) {
    final catCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Manage Categories', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: catCtrl,
                            decoration: const InputDecoration(
                              labelText: 'New Category Name',
                              hintText: 'e.g. Mocktails',
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryAmber),
                          onPressed: () async {
                            final name = catCtrl.text.trim();
                            if (name.isNotEmpty) {
                              await menuProvider.addCategory(name);
                              catCtrl.clear();
                              onCategorySelected(name);
                              setDialogState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Custom Categories:',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: menuProvider.customCategories.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text('No custom categories yet.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: menuProvider.customCategories.length,
                              itemBuilder: (context, index) {
                                final cat = menuProvider.customCategories[index];
                                return ListTile(
                                  title: Text(cat, style: GoogleFonts.outfit(fontSize: 13)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                    onPressed: () async {
                                      await menuProvider.deleteCategory(cat);
                                      if (currentCategory == cat) {
                                        onCategorySelected('Special Chai');
                                      }
                                      setDialogState(() {});
                                    },
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportSalesReportCsv(BuildContext context, List<OrderModel> orders, String reportType) async {
    try {
      final buffer = StringBuffer();
      // CSV Headers: Token Number,Payment Type,Amount,Items Sold,Items Ordered
      buffer.writeln('Token Number,Payment Type,Amount,Items Sold,Items Ordered');

      // Sort chronologically
      final sorted = List<OrderModel>.from(orders);
      sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      double grandTotal = 0.0;
      int grandTotalQty = 0;
      String? lastDate;

      // Track individual item quantities
      final itemBreakdown = <String, int>{};

      for (var o in sorted) {
        final currentDateStr = DateFormat('dd-MM-yyyy').format(o.timestamp);
        if (lastDate != null && lastDate != currentDateStr) {
          buffer.writeln('=== NEXT DAY: $currentDateStr ===,,,,');
        }
        lastDate = currentDateStr;

        final itemsStr = o.items.map((i) => '${i.item.name} (${i.variant} x${i.quantity})').join('; ');
        final escapedItems = '"${itemsStr.replaceAll('"', '""')}"';
        final totalQty = o.items.fold<int>(0, (sum, i) => sum + i.quantity);

        for (var i in o.items) {
          final displayName = i.variant != 'Regular' ? '${i.item.name} (${i.variant})' : i.item.name;
          itemBreakdown[displayName] = (itemBreakdown[displayName] ?? 0) + i.quantity;
        }
        
        buffer.writeln('${o.tokenNumber},${o.paymentMethod},${o.totalAmount.toStringAsFixed(2)},$totalQty,$escapedItems');
        grandTotal += o.totalAmount;
        grandTotalQty += totalQty;
      }

      buffer.writeln('Total,,${grandTotal.toStringAsFixed(2)},$grandTotalQty,');
      
      // Separate list of items sold
      buffer.writeln();
      buffer.writeln('Item Wise Breakdown,,,,');
      itemBreakdown.forEach((itemName, qty) {
        buffer.writeln('$itemName :- $qty,,,,');
      });

      final csvContent = buffer.toString();
      final bytes = Uint8List.fromList(utf8.encode(csvContent));

      final fileName = 'aromaa_${reportType.toLowerCase().replaceAll(' ', '_')}_report_${DateFormat('yyyyMMdd').format(DateTime.now())}';

      final String? path = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reportType report saved successfully to: $path'),
            backgroundColor: AppTheme.matchaGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export report: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _exportCardReportCsv(BuildContext context, List<OrderModel> orders, String reportType) async {
    try {
      final buffer = StringBuffer();
      // CSV Headers: Token Number,Total Orders,Items Sold,Items Ordered,Payment Type,Total Amount
      buffer.writeln('Token Number,Total Orders,Items Sold,Items Ordered,Payment Type,Total Amount');

      // Sort chronologically
      final sorted = List<OrderModel>.from(orders);
      sorted.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      double grandTotal = 0.0;
      int grandTotalQty = 0;
      String? lastDate;
      int serialNo = 1;

      // Track individual item quantities
      final itemBreakdown = <String, int>{};

      for (var o in sorted) {
        final currentDateStr = DateFormat('dd-MM-yyyy').format(o.timestamp);
        if (lastDate != null && lastDate != currentDateStr) {
          buffer.writeln('=== NEXT DAY: $currentDateStr ===,,,,,');
        }
        lastDate = currentDateStr;

        final itemsStr = o.items.map((i) => '${i.item.name} (${i.variant} x${i.quantity})').join('; ');
        final escapedItems = '"${itemsStr.replaceAll('"', '""')}"';
        final totalQty = o.items.fold<int>(0, (sum, i) => sum + i.quantity);

        for (var i in o.items) {
          final displayName = i.variant != 'Regular' ? '${i.item.name} (${i.variant})' : i.item.name;
          itemBreakdown[displayName] = (itemBreakdown[displayName] ?? 0) + i.quantity;
        }
        
        buffer.writeln('${o.tokenNumber},$serialNo,$totalQty,$escapedItems,${o.paymentMethod},${o.totalAmount.toStringAsFixed(2)}');
        serialNo++;
        grandTotal += o.totalAmount;
        grandTotalQty += totalQty;
      }

      buffer.writeln('Total,,$grandTotalQty,,,${grandTotal.toStringAsFixed(2)}');

      // Separate list of items sold
      buffer.writeln();
      buffer.writeln('Item Wise Breakdown,,,,,');
      itemBreakdown.forEach((itemName, qty) {
        buffer.writeln('$itemName :- $qty,,,,,');
      });

      final csvContent = buffer.toString();
      final bytes = Uint8List.fromList(utf8.encode(csvContent));

      final fileName = 'aromaa_${reportType.toLowerCase().replaceAll(' ', '_')}_details_${DateFormat('yyyyMMdd').format(DateTime.now())}';

      final String? path = await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );

      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$reportType details saved successfully to: $path'),
            backgroundColor: AppTheme.matchaGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export details: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Widget _buildOrderAuditTab(BuildContext context) {
    final sales = Provider.of<SalesProvider>(context);

    if (sales.orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => sales.loadOrders(),
        color: AppTheme.primaryAmber,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, size: 54, color: AppTheme.primaryAmber),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Bills Issued Yet',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When counter staff members issue bills from the Staff POS, all transaction records & printed receipts will appear here in real-time.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => sales.loadOrders(),
      color: AppTheme.primaryAmber,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.cardBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Transactions (${sales.orders.length})',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      tooltip: 'Download Sales CSV',
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primaryAmber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.download_rounded, size: 16, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              'Download CSV',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onSelected: (value) {
                        final now = DateTime.now();
                        List<OrderModel> filteredOrders = [];
                        String reportType = '';

                        if (value == 'daily') {
                          reportType = 'Daily';
                          filteredOrders = sales.orders.where((o) {
                            return o.timestamp.year == now.year &&
                                o.timestamp.month == now.month &&
                                o.timestamp.day == now.day;
                          }).toList();
                        } else if (value == 'weekly') {
                          reportType = 'Weekly';
                          final startOfWeek = now.subtract(const Duration(days: 7));
                          filteredOrders = sales.orders.where((o) {
                            return o.timestamp.isAfter(startOfWeek);
                          }).toList();
                        } else if (value == 'monthly') {
                          reportType = 'Monthly';
                          final startOfMonth = now.subtract(const Duration(days: 30));
                          filteredOrders = sales.orders.where((o) {
                            return o.timestamp.isAfter(startOfMonth);
                          }).toList();
                        } else if (value == 'total') {
                          reportType = 'Total Revenue';
                          filteredOrders = sales.orders;
                        }

                        _exportSalesReportCsv(context, filteredOrders, reportType);
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'daily',
                          child: Text('Today\'s Sales (Daily)', style: GoogleFonts.outfit(fontSize: 13)),
                        ),
                        PopupMenuItem<String>(
                          value: 'weekly',
                          child: Text('Last 7 Days (Weekly)', style: GoogleFonts.outfit(fontSize: 13)),
                        ),
                        PopupMenuItem<String>(
                          value: 'monthly',
                          child: Text('Last 30 Days (Monthly)', style: GoogleFonts.outfit(fontSize: 13)),
                        ),
                        PopupMenuItem<String>(
                          value: 'total',
                          child: Text('All-Time Sales (Total)', style: GoogleFonts.outfit(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                      label: const Text('Reset Sales History', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Clear All Sales History'),
                            content: const Text('Are you sure you want to reset all transaction audit logs? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                onPressed: () {
                                  sales.clearAllOrders();
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Clear History'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: sales.orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = sales.orders[index];
                final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(order.timestamp);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryAmber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryAmber, size: 18),
                    ),
                    title: Text(
                      'Bill No: ${order.billNumber} • Rs.${order.totalAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Text(
                      '$formattedDate • ${order.paymentMethod} (${order.orderType})',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Item Breakdown:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            ...order.items.map((i) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${i.item.name} x${i.quantity}', style: GoogleFonts.outfit(fontSize: 11)),
                                    Text('Rs.${i.totalPrice.toStringAsFixed(0)}', style: GoogleFonts.outfit(fontSize: 11)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.print_rounded, size: 14),
                                  label: const Text('Reprint', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primaryAmber,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => ReceiptPreviewDialog(order: order),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                                  label: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                    side: const BorderSide(color: Colors.redAccent),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Transaction'),
                                        content: Text('Are you sure you want to delete Bill No: ${order.billNumber}? This action cannot be undone.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                            onPressed: () {
                                              sales.deleteOrder(order.id);
                                              Navigator.pop(ctx);
                                            },
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 4: PRINTER SETUP --- //
  Widget _buildPrinterSetupTab(BuildContext context) {
    final printerProvider = Provider.of<PrinterProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final config = printerProvider.config;

    if (!_controllersInitialized && config.cafeName.isNotEmpty) {
      _cafeNameController.text = config.cafeName;
      _addressController.text = config.address;
      _phoneController.text = config.phone;
      _gstinController.text = config.gstin;
      _footerController.text = config.footerMessage;
      _taxPercentageController.text = config.taxPercentage.toString();
      _controllersInitialized = true;
    } else if (!_controllersInitialized) {
      _cafeNameController.text = config.cafeName;
      _addressController.text = config.address;
      _phoneController.text = config.phone;
      _gstinController.text = config.gstin;
      _footerController.text = config.footerMessage;
      _taxPercentageController.text = config.taxPercentage.toString();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bluetooth Thermal Printer Configuration',
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Connection Status Tile
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        config.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                        size: 36,
                        color: config.isConnected ? AppTheme.matchaGreen : Colors.orange,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              config.isConnected ? 'Connected: ${config.deviceName}' : 'No Bluetooth Printer Connected',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              config.isConnected
                                  ? 'MAC: ${config.macAddress} (${config.paperWidthMm}mm Roll Width)'
                                  : 'Scan below to discover nearby Bluetooth POS printers',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final granted = await BluetoothPermissionDialog.ensurePermissionWithPopup(context);
                          if (granted) {
                            printerProvider.scanBluetoothDevices();
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bluetooth permission is required to scan thermal printers.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryAmber,
                          foregroundColor: Colors.black,
                        ),
                        child: printerProvider.isScanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text('Scan Printers'),
                      ),
                    ],
                  ),

                  if (printerProvider.scanErrorMessage != null) ...[
                    const Divider(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              printerProvider.scanErrorMessage!,
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (printerProvider.discoveredDevices.isNotEmpty) ...[
                    const Divider(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Real Paired Bluetooth Devices (${printerProvider.discoveredDevices.length}):',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...printerProvider.discoveredDevices.map((dev) {
                      final isCurrent = config.isConnected && config.macAddress == dev['address'];
                      return ListTile(
                        leading: const Icon(Icons.print_rounded, color: AppTheme.primaryAmber),
                        title: Text(dev['name']!),
                        subtitle: Text(dev['address']!),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent ? AppTheme.matchaGreen : AppTheme.primaryAmber,
                            foregroundColor: isCurrent ? Colors.white : Colors.black,
                          ),
                          onPressed: () async {
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
                          child: Text(isCurrent ? 'Connected' : 'Connect'),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Receipt Layout Parameters
          Text(
            'Thermal Bill Header & Footer Settings',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _cafeNameController,
                    decoration: const InputDecoration(labelText: 'Cafe Header Name'),
                    onChanged: (val) => printerProvider.updateConfig(config.copyWith(cafeName: val)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(labelText: 'Store Address Line'),
                    onChanged: (val) => printerProvider.updateConfig(config.copyWith(address: val)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(labelText: 'Phone Number'),
                          onChanged: (val) => printerProvider.updateConfig(config.copyWith(phone: val)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _gstinController,
                          decoration: const InputDecoration(labelText: 'GSTIN Number'),
                          onChanged: (val) => printerProvider.updateConfig(config.copyWith(gstin: val)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _footerController,
                    decoration: const InputDecoration(labelText: 'Footer Thank-You Message'),
                    onChanged: (val) => printerProvider.updateConfig(config.copyWith(footerMessage: val)),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('Auto Print on Checkout', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Automatically print physical bill immediately upon counter checkout', style: GoogleFonts.outfit(fontSize: 11)),
                    value: config.autoPrintEnabled,
                    activeColor: AppTheme.primaryAmber,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      printerProvider.updateConfig(config.copyWith(autoPrintEnabled: val));
                    },
                  ),
                  const SizedBox(height: 16),

                  // Paper Roll Size Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Paper Roll Width:', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 58, label: Text('58mm (2 Inch)')),
                          ButtonSegment(value: 80, label: Text('80mm (3 Inch)')),
                        ],
                        selected: {config.paperWidthMm},
                        onSelectionChanged: (val) {
                          printerProvider.updateConfig(config.copyWith(paperWidthMm: val.first));
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Token Customization Settings Card
          Text(
            'Token & Print Customization',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text('Print Price on Token / KOT', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Disable to print KOT tickets with item details only (hides amounts)', style: GoogleFonts.outfit(fontSize: 11)),
                    value: config.printPriceOnToken,
                    activeColor: AppTheme.primaryAmber,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      printerProvider.updateConfig(config.copyWith(printPriceOnToken: val));
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('Print Staff & Customer Details', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Include counter staff name and payment method mode on token', style: GoogleFonts.outfit(fontSize: 11)),
                    value: config.printCustomerDetails,
                    activeColor: AppTheme.primaryAmber,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      printerProvider.updateConfig(config.copyWith(printCustomerDetails: val));
                    },
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Font Size Scale Factor', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('Adjust text scaling: ${(config.fontScale * 100).toStringAsFixed(0)}%', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      SizedBox(
                        width: 140,
                        child: Slider(
                          value: config.fontScale,
                          min: 0.6,
                          max: 1.5,
                          divisions: 9,
                          activeColor: AppTheme.primaryAmber,
                          inactiveColor: AppTheme.dividerColor,
                          label: config.fontScale.toStringAsFixed(1),
                          onChanged: (val) {
                            printerProvider.updateConfig(config.copyWith(fontScale: val));
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Manual Token Counter Reset', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('Restart daily token sequence back to 1', style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Restart Counter', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Restart Daily Token Counter?'),
                              content: const Text('Are you sure you want to reset the daily counter? The next customer bill issued today will start from token #001.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () {
                                    printerProvider.updateConfig(config.copyWith(
                                      tokenResetTime: DateTime.now().toIso8601String(),
                                    ));
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Daily token counter successfully reset to 1!'),
                                        backgroundColor: AppTheme.matchaGreen,
                                      ),
                                    );
                                  },
                                  child: const Text('Reset Counter'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Portal Security Settings Card
          Text(
            'Portal Security Settings',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Owner Portal PIN',
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Change the 4-digit PIN required to log in to the Owner Portal',
                    style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _currentPinController,
                          decoration: const InputDecoration(
                            labelText: 'Current PIN',
                            hintText: 'Enter old PIN',
                            border: OutlineInputBorder(),
                            isDense: true,
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _newPinController,
                          decoration: const InputDecoration(
                            labelText: 'New PIN',
                            hintText: 'Enter new 4-digit PIN',
                            border: OutlineInputBorder(),
                            isDense: true,
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          obscureText: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryAmber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: () async {
                        final currentPin = _currentPinController.text.trim();
                        final newPin = _newPinController.text.trim();
                        if (currentPin.length != 4 || newPin.length != 4) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN must be exactly 4 digits.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        final success = await authProvider.updateOwnerPin(currentPin, newPin);
                        if (success) {
                          _currentPinController.clear();
                          _newPinController.clear();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Owner PIN updated successfully!'),
                                backgroundColor: AppTheme.matchaGreen,
                              ),
                            );
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Incorrect current PIN. Update failed.'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      child: Text('Update PIN', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
