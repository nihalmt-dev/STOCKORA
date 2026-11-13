
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'products_screen.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String token;

  const DashboardScreen({
    super.key,
    required this.token,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const bg = Color(0xFF0B1120);
  static const sidebarBg = Color(0xFF101B2C);
  static const surface = Color(0xFF172235);
  static const mint = Color(0xFF5EEAC4);
  static const muted = Color(0xFF94A3B8);
  static const borderColor = Color(0xFF29384D);

  int selectedIndex = 0;
  bool openLowStockOnly = false;
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic> stats = {};

  final menuItems = <Map<String, dynamic>>[
    {'icon': Icons.grid_view_rounded, 'title': 'Dashboard'},
    {'icon': Icons.inventory_2_outlined, 'title': 'Products'},
    {'icon': Icons.warehouse_outlined, 'title': 'Inventory'},
    {'icon': Icons.people_outline_rounded, 'title': 'Customers'},
    {'icon': Icons.shopping_bag_outlined, 'title': 'Orders'},
    {'icon': Icons.bar_chart_rounded, 'title': 'Reports'},
  ];

  @override
  void initState() {
    super.initState();
    fetchDashboardStats();
  }

  Future<void> fetchDashboardStats() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/dashboard/stats'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('API Error ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        stats = Map<String, dynamic>.from(data);
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        errorMessage = 'Unable to load dashboard data';
        isLoading = false;
      });
    }
  }

  void changePage(int index, {bool closeDrawer = false, bool lowStockOnly = false}) {
    if (index == 1) {
      setState(() => openLowStockOnly = lowStockOnly);
    }
    if (index == selectedIndex) {
      if (closeDrawer && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    final previousIndex = selectedIndex;
    setState(() => selectedIndex = index);
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (index == 0 && previousIndex != 0) fetchDashboardStats();
  }

  Future<void> handleBack() async {
    if (selectedIndex != 0) {
      changePage(0);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Exit STOCKORA?',
            style: TextStyle(color: Colors.white)),
        content: const Text('Do you want to close the app?',
            style: TextStyle(color: muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay', style: TextStyle(color: mint)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: mint,
                foregroundColor: bg),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (exit == true && mounted && !kIsWeb) {
      SystemNavigator.pop();
    }
  }

  void showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sidebarBg,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Text('Explore STOCKORA',
                  style: TextStyle(color: Colors.white,
                      fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              for (final index in [2, 3, 5])
                ListTile(
                  leading: Icon(menuItems[index]['icon'] as IconData,
                      color: mint),
                  title: Text(menuItems[index]['title'] as String,
                      style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: muted),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    changePage(index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: surface,
        title: const Text('Logout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout from STOCKORA?',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel', style: TextStyle(color: mint)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: mint,
              foregroundColor: bg,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logout failed. Please try again.')),
      );
    }
  }

  void showProfileMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: sidebarBg,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF254D49),
                  child: Icon(Icons.person_outline, color: mint, size: 27),
                ),
                SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('STOCKORA Workspace', style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Signed in', style: TextStyle(color: mint, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 18),
              const Divider(color: borderColor),
              ListTile(
                leading: const Icon(Icons.space_dashboard_outlined, color: mint),
                title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  changePage(0);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  logout();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: muted),
                title: const Text('Close', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget mobileNavigation() {
    final tab = selectedIndex == 0 ? 0 : selectedIndex == 1 ? 1 : selectedIndex == 4 ? 2 : 3;
    const tabs = [
      (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
      (Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Products'),
      (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, 'Orders'),
      (Icons.grid_view_outlined, Icons.grid_view_rounded, 'More'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: sidebarBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final active = tab == index;
              final item = tabs[index];
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => index == 3 ? showMoreMenu() : changePage([0, 1, 4][index]),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: active ? mint.withValues(alpha: 0.11) : Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(active ? item.$2 : item.$1, color: active ? mint : muted, size: 23),
                        const SizedBox(height: 5),
                        Text(item.$3, style: TextStyle(color: active ? mint : muted,
                          fontSize: 10.5, fontWeight: active ? FontWeight.w800 : FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget menuTile(int index) {
    final selected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected
            ? mint.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            menuItems[index]['icon'] as IconData,
            size: 21,
            color: selected ? mint : muted,
          ),
          title: Text(
            menuItems[index]['title'] as String,
            style: TextStyle(
              color: selected ? mint : Colors.white70,
              fontWeight:
                  selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
          onTap: () => changePage(index, closeDrawer: MediaQuery.sizeOf(context).width < 800),
        ),
      ),
    );
  }

  Widget sidebar() {
    return Container(
      width: 235,
      color: sidebarBg,
      padding: const EdgeInsets.fromLTRB(15, 22, 15, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  color: mint,
                  size: 30,
                ),
                SizedBox(width: 10),
                Text(
                  'STOCKORA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text(
              'INVENTORY INTELLIGENCE',
              style: TextStyle(
                color: muted,
                fontSize: 9,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 38),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 14),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          ...List.generate(menuItems.length, menuTile),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.w600,
            )),
            onTap: logout,
          ),
          const Divider(color: borderColor),
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 10,
              horizontal: 8,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF254D49),
                  child: Icon(
                    Icons.person_outline,
                    color: mint,
                    size: 20,
                  ),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Workspace',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'STOCKORA',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Widget kpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [surface, Color.lerp(surface, accent, 0.055)!],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 16, offset: Offset(0, 7))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: accent, size: 20),
            ),
            const Spacer(),
            Icon(Icons.north_east_rounded, color: accent.withValues(alpha: 0.45), size: 17),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: Colors.white,
              fontSize: 27, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          ),
          const SizedBox(height: 4),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 10)),
        ],
      ),
      ),
    );
  }

  Widget quickAction({required String title, required IconData icon,
      required int page, required Color accent}) {
    return InkWell(
      onTap: () => changePage(page),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 19)),
          const SizedBox(width: 10),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w700))),
          const Icon(Icons.chevron_right_rounded, color: muted, size: 17),
        ]),
      ),
    );
  }

  Widget lowStockSection() {
    final items = (stats['lowStockProducts'] as List?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Low Stock Alerts',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${items.length} items',
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Products that need your attention',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          const Divider(color: borderColor),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: mint),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All products have sufficient stock',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) {
              final stock = item['stock'] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.inventory_2_outlined,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item['name']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SKU: ${item['sku']}',
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$stock left',
                        style: const TextStyle(
                          color: Colors.orangeAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Color orderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return mint;
      case 'pending':
        return Colors.orangeAccent;
      case 'cancelled':
      case 'canceled':
        return Colors.redAccent;
      default:
        return const Color(0xFF73A9FF);
    }
  }

  Widget recentOrdersSection() {
    final orders = (stats['recentOrders'] as List?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: mint,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Recent Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Latest customer orders',
            style: TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: borderColor),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'No recent orders available',
                style: TextStyle(color: muted),
              ),
            )
          else
            ...orders.take(5).map((order) {
              final id = order['_id']?.toString() ?? '';
              final shortId =
                  id.length > 6 ? id.substring(id.length - 6) : id;

              final customer = order['customer'];
              String customerName = 'Customer';

              if (customer is Map) {
                customerName =
                    customer['name']?.toString() ?? 'Customer';
              } else if (order['customerName'] != null) {
                customerName = order['customerName'].toString();
              }

              final amount = num.tryParse(
                    (order['totalAmount'] ??
                            order['total'] ??
                            0)
                        .toString(),
                  ) ??
                  0;

              final status =
                  order['status']?.toString() ?? 'Pending';
              final statusColor = orderStatusColor(status);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: mint.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: mint,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Order #$shortId',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${amount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          status.toUpperCase(),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget dashboardContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: mint));
    }
    if (errorMessage != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_rounded, color: muted, size: 38),
        const SizedBox(height: 12),
        Text(errorMessage!, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 15),
        OutlinedButton(onPressed: fetchDashboardStats, child: const Text('Try again')),
      ]));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final compact = width < 550;
      final columns = width >= 1050 ? 4 : 2;
      return RefreshIndicator(
        color: mint,
        onRefresh: fetchDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(compact ? 16 : 26, 18, compact ? 16 : 26, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (compact) ...[
              const Text('Dashboard Overview', style: TextStyle(
                color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Your business, at a glance',
                style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 22),
            ] else ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(compact ? 21 : 27),
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A4C51), Color(0xFF12323E), Color(0xFF172235)]),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF32636A)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: mint.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 7, color: mint),
                      SizedBox(width: 7),
                      Text('WORKSPACE OVERVIEW', style: TextStyle(color: mint,
                        fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ])),
                  const Spacer(),
                  IconButton(onPressed: fetchDashboardStats,
                    tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded, color: Colors.white70)),
                ]),
                const SizedBox(height: 15),
                Text('Business at a glance', style: TextStyle(color: Colors.white,
                  fontSize: compact ? 24 : 30, fontWeight: FontWeight.w800,
                  letterSpacing: -0.8)),
                const SizedBox(height: 7),
                const Text('Everything you need to manage your inventory, all in one place.',
                  style: TextStyle(color: Color(0xFFB6D0D2), fontSize: 12.5, height: 1.5)),
                const SizedBox(height: 18),
                InkWell(onTap: () => changePage(1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                    decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(12)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Manage products', style: TextStyle(color: bg, fontSize: 12,
                        fontWeight: FontWeight.w800)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: bg, size: 17),
                    ]))),
              ]),
            ),
            const SizedBox(height: 27),
            ],
            Row(children: [
              const Expanded(child: Text('Key metrics', style: TextStyle(color: Colors.white,
                fontSize: 19, fontWeight: FontWeight.w800))),
              Text('LIVE OVERVIEW', style: TextStyle(color: muted,
                fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
            ]),
            const SizedBox(height: 13),
            GridView.count(
              crossAxisCount: columns, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12, crossAxisSpacing: 12,
              mainAxisExtent: compact ? 163 : 175,
              children: [
                kpiCard(title: 'Total Products', value: '${stats['totalProducts'] ?? 0}',
                  icon: Icons.inventory_2_outlined, accent: mint,
                  subtitle: 'In your catalog', onTap: () => changePage(1)),
                kpiCard(title: 'Total Orders', value: '${stats['totalOrders'] ?? 0}',
                  icon: Icons.shopping_bag_outlined, accent: const Color(0xFF80B5FF),
                  subtitle: 'Orders recorded', onTap: () => changePage(4)),
                kpiCard(title: 'Total Sales', value: '₹${stats['totalSales'] ?? 0}',
                  icon: Icons.payments_outlined, accent: const Color(0xFFFFCB75),
                  subtitle: 'Revenue to date', onTap: () => changePage(5)),
                kpiCard(title: 'Low Stock Alerts', value: '${stats['lowStockCount'] ?? 0}',
                  icon: Icons.warning_amber_rounded, accent: const Color(0xFFFF9F77),
                  subtitle: 'Need attention', onTap: () => changePage(1, lowStockOnly: true)),
              ],
            ),
            if (width < 800) ...[
              const SizedBox(height: 24),
              const Text('Quick access', style: TextStyle(
                color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 13),
              Row(children: [
                Expanded(child: quickAction(title: 'Products',
                  icon: Icons.inventory_2_outlined, page: 1, accent: mint)),
                const SizedBox(width: 12),
                Expanded(child: quickAction(title: 'Inventory',
                  icon: Icons.warehouse_outlined, page: 2,
                  accent: const Color(0xFF80B5FF))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: quickAction(title: 'Customers',
                  icon: Icons.people_outline_rounded, page: 3,
                  accent: const Color(0xFFFFCB75))),
                const SizedBox(width: 12),
                Expanded(child: quickAction(title: 'Orders',
                  icon: Icons.shopping_bag_outlined, page: 4,
                  accent: const Color(0xFFBB9BFF))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: quickAction(title: 'Reports',
                  icon: Icons.bar_chart_rounded, page: 5,
                  accent: const Color(0xFFFF9F77))),
                const Expanded(child: SizedBox.shrink()),
              ]),
            ],
            const SizedBox(height: 27),
            if (width >= 800)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: lowStockSection()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: recentOrdersSection()),
              ])
            else
              Column(children: [
                lowStockSection(),
                const SizedBox(height: 16),
                recentOrdersSection(),
              ]),
          ]),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 64,
          titleSpacing: wide ? 24 : 8,
          leading: wide ? null : selectedIndex == 0
              ? const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Icon(Icons.inventory_2_rounded, color: mint, size: 27),
                )
              : IconButton(
                  tooltip: 'Back to Dashboard',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => changePage(0),
                ),
          title: Text(
            wide ? menuItems[selectedIndex]['title'] as String
                : selectedIndex == 0 ? 'STOCKORA'
                : menuItems[selectedIndex]['title'] as String,
            style: const TextStyle(fontSize: 19,
                fontWeight: FontWeight.w800, letterSpacing: 0.3),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh dashboard',
              onPressed: fetchDashboardStats,
              icon: const Icon(Icons.refresh_rounded, color: muted),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Logout',
              onPressed: logout,
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Workspace profile',
              onPressed: showProfileMenu,
              icon: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF254D49),
                child: Icon(Icons.person_outline, color: mint, size: 20),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        bottomNavigationBar: wide ? null : mobileNavigation(),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) sidebar(),
            Expanded(
              child: selectedIndex == 0
                  ? dashboardContent()
                  : selectedIndex == 1
                      ? ProductsScreen(
                           key: ValueKey(openLowStockOnly),
                           token: widget.token,
                           initialLowStockOnly: openLowStockOnly,
                         )
                      : selectedIndex == 2
                          ? InventoryScreen(token: widget.token)
                          : selectedIndex == 3
                              ? CustomersScreen(token: widget.token)
                              : selectedIndex == 4
                                  ? OrdersScreen(token: widget.token)
                                  : selectedIndex == 5
                                      ? ReportsScreen(token: widget.token)
                                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
