import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'products_screen.dart';
import 'inventory_screen.dart';
import 'customers_screen.dart';
import 'orders_screen.dart';
import 'reports_screen.dart';
import 'users_screen.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String token;
  const DashboardScreen({super.key, required this.token});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  static const bg = Color(0xFFF6F7FC);
  static const white = Colors.white;
  static const primary = Color(0xFF4F46E5);
  static const ink = Color(0xFF171B35);
  static const muted = Color(0xFF777F96);
  static const line = Color(0xFFE8EAF3);
  static const green = Color(0xFF059669);
  static const orange = Color(0xFFD97706);

  late final AnimationController _bannerMotion;

  int selectedIndex = 0;
  bool lowStockOnly = false;
  bool loading = true;
  String? error;
  String role = 'staff';
  String userName = 'Team member';
  Map<String, dynamic> stats = {};
  List<dynamic> restockRequests = [];
  bool restockLoading = false;
  Timer? _restockTimer;
  bool _fetchingRestocks = false;

  bool get canSeeFinance => role == 'admin' || role == 'manager';
  bool get isAdmin => role == 'admin';

  static const titles = [
    'Overview', 'Products', 'Inventory', 'Customers', 'Orders', 'Reports',
    'User Management',
  ];
  static const icons = [
    Icons.grid_view_rounded,
    Icons.inventory_2_outlined,
    Icons.warehouse_outlined,
    Icons.people_outline_rounded,
    Icons.shopping_bag_outlined,
    Icons.bar_chart_rounded,
    Icons.manage_accounts_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _bannerMotion = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _initialize();
    _restockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (canSeeFinance) fetchRestockRequests();
    });
  }

  @override
  void dispose() {
    _restockTimer?.cancel();
    _bannerMotion.dispose();
    super.dispose();
  }

  Widget _workspaceBanner(bool compact) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          ),
        ),
        child: Stack(children: [
          Positioned(
            top: -70, right: -35,
            child: Container(
              width: 215, height: 215,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 2),
              ),
            ),
          ),
          Positioned(
            bottom: -90, right: 105,
            child: Container(
              width: 170, height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.055),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 28,
              vertical: compact ? 22 : 27,
            ),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFE9D5FF), size: 15),
                    const SizedBox(width: 7),
                    Text('STOCKORA WORKSPACE', style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.83),
                      fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.6,
                    )),
                  ]),
                  const SizedBox(height: 11),
                  Text('Manage smarter. Grow faster.',
                    style: TextStyle(color: Colors.white,
                      fontSize: compact ? 20 : 27,
                      height: 1.2, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text('Welcome back, $userName. Your inventory and orders, all in one place.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82),
                      fontSize: compact ? 11 : 13, height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.17)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_circle_rounded,
                        size: 13, color: Color(0xFF86EFAC)),
                      const SizedBox(width: 7),
                      Text('${role.toUpperCase()} · Workspace active',
                        style: const TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ],
              )),
              if (!compact) ...[
                const SizedBox(width: 18),
                SizedBox(width: 175, height: 138,
                  child: AnimatedBuilder(
                    animation: _bannerMotion,
                    builder: (context, child) {
                      final floatY = _bannerMotion.value * 11;
                      return Stack(children: [
                        Positioned(top: 12 + floatY, right: 24,
                          child: _bannerIcon(Icons.inventory_2_rounded, 64, 0.18)),
                        Positioned(top: 72 - floatY * 0.6, left: 4,
                          child: _bannerIcon(Icons.shopping_bag_rounded, 47, 0.16)),
                        Positioned(top: 78 + floatY * 0.4, right: 0,
                          child: _bannerIcon(Icons.trending_up_rounded, 43, 0.16)),
                      ]);
                    },
                  ),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bannerIcon(IconData icon, double size, double opacity) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.48),
    );
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      role = prefs.getString('user_role') ?? 'staff';
      userName = prefs.getString('user_name') ?? 'Team member';
    });
    await fetchDashboardStats();
    if (canSeeFinance) await fetchRestockRequests();
  }

  Future<void> fetchDashboardStats() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/dashboard/stats'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (!mounted) return;
        setState(() {
          loading = false;
          error = 'Session expired or access denied. Please sign in again.';
        });
        return;
      }
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final result = jsonDecode(response.body);
      if (result is! Map<String, dynamic>) throw const FormatException();
      if (!mounted) return;
      setState(() {
        stats = result;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Unable to load dashboard. Check your backend connection.';
      });
    }
  }

  int get pendingRestockCount => restockRequests.where((r) =>
      r is Map && r['status']?.toString().toLowerCase() == 'pending').length;

  Future<void> fetchRestockRequests() async {
    if (!canSeeFinance || _fetchingRestocks) return;
    _fetchingRestocks = true;
    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/inventory/restock-requests'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() {
          restockRequests = data is List ? data : [];
        });
      }
    } catch (_) {
      // Keep the last known notifications if the network is unavailable.
    } finally {
      _fetchingRestocks = false;
    }
  }

  Future<void> _resolveRestock(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: white,
        title: const Text('Resolve restock request?',
            style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
        content: const Text(
          'Mark this request as resolved only after checking the stock. '
          'This action does not add stock automatically.',
          style: TextStyle(color: ink),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Mark resolved')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await http.patch(
        Uri.parse('http://localhost:5000/api/inventory/restock-requests/$id/resolve'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Restock request marked as resolved'),
          backgroundColor: green,
        ));
        await fetchRestockRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unable to resolve request (${response.statusCode})'),
        ));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connection error while resolving request'),
      ));
    }
  }

  Future<void> _showRestockNotifications() async {
    if (!canSeeFinance) return;
    await fetchRestockRequests();
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refreshSheet) {
          // Refresh the sheet after a request is resolved.
          final pending = restockRequests.where((r) =>
              r is Map && r['status']?.toString() == 'pending').toList();
          return SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.notifications_active_outlined,
                          color: primary, size: 24),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Restock requests',
                          style: TextStyle(color: ink, fontSize: 20,
                              fontWeight: FontWeight.w800))),
                      IconButton(
                        tooltip: 'Refresh requests',
                        onPressed: () async {
                          await fetchRestockRequests();
                          if (sheetContext.mounted) refreshSheet(() {});
                        },
                        icon: const Icon(Icons.refresh_rounded, color: primary),
                      ),
                    ]),
                    const SizedBox(height: 5),
                    Text('${pending.length} pending requests',
                        style: const TextStyle(color: muted, fontSize: 13)),
                    const SizedBox(height: 18),
                    if (pending.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                color: green, size: 38),
                            SizedBox(height: 10),
                            Text('No pending restock requests',
                                style: TextStyle(color: ink,
                                    fontWeight: FontWeight.w700)),
                          ],
                        )),
                      ),
                    for (final raw in pending)
                      if (raw is Map)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FD),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.inventory_2_outlined,
                                    color: orange, size: 20),
                                const SizedBox(width: 9),
                                Expanded(child: Text(
                                  raw['product'] is Map
                                      ? '${raw['product']['name'] ?? 'Product'}'
                                      : 'Product unavailable',
                                  style: const TextStyle(color: ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15),
                                )),
                                const Text('PENDING', style: TextStyle(
                                    color: orange, fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 8),
                              Text(
                                raw['product'] is Map
                                    ? 'Stock: ${raw['product']['stock'] ?? '-'}  ·  Threshold: ${raw['product']['lowStockThreshold'] ?? '-'}'
                                    : 'Product details unavailable',
                                style: const TextStyle(color: muted,
                                    fontSize: 12),
                              ),
                              const SizedBox(height: 4),
                              Text('Requested by: ${raw['requestedBy'] is Map ? raw['requestedBy']['name'] ?? 'Staff' : 'Staff'}',
                                  style: const TextStyle(color: ink,
                                      fontSize: 12)),
                              if ('${raw['note'] ?? ''}'.trim().isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text('Note: ${raw['note']}',
                                    style: const TextStyle(color: muted,
                                        fontSize: 12)),
                              ],
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    changePage(2);
                                  },
                                  icon: const Icon(Icons.warehouse_outlined,
                                      size: 17),
                                  label: const Text('Manage stock'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: primary,
                                  ),
                                )),
                                const SizedBox(width: 8),
                                Expanded(child: FilledButton(
                                  onPressed: () async {
                                    await _resolveRestock('${raw['_id']}');
                                    if (sheetContext.mounted) {
                                      refreshSheet(() {});
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: white,
                                  ),
                                  child: const Text('Resolve'),
                                )),
                              ]),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _notificationBell() => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        tooltip: 'Restock notifications',
        onPressed: _showRestockNotifications,
        icon: const Icon(Icons.notifications_none_rounded, color: ink),
      ),
      if (pendingRestockCount > 0)
        Positioned(
          right: 2,
          top: 0,
          child: IgnorePointer(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: white, width: 1.5),
            ),
            child: Text(pendingRestockCount > 99 ? '99+' : '$pendingRestockCount',
                style: const TextStyle(color: white, fontSize: 9,
                    fontWeight: FontWeight.w800)),
          )),
        ),
    ],
  );

  void changePage(int index, {bool filterLowStock = false}) {
    if (index == 5 && !canSeeFinance) return;
    if (index == 6 && !isAdmin) return;
    if (index < 0 || index >= titles.length) return;
    setState(() {
      selectedIndex = index;
      if (index == 1) lowStockOnly = filterLowStock;
    });
    if (index == 0) fetchDashboardStats();
  }

  Future<void> logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of STOCKORA?'),
        content: const Text('You can sign in again at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    await prefs.remove('user_name');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> handleBack() async {
    if (selectedIndex != 0) {
      changePage(0);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit STOCKORA?'),
        content: const Text('Do you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (exit == true && mounted && !kIsWeb) SystemNavigator.pop();
  }

  Widget _navItem(int index, {bool inSheet = false}) {
    final active = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: active ? const Color(0xFFEEEDFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          dense: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icons[index], color: active ? primary : muted, size: 21),
          title: Text(titles[index], style: TextStyle(
            color: active ? primary : ink,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          )),
          onTap: () {
            if (inSheet) Navigator.pop(context);
            changePage(index);
          },
        ),
      ),
    );
  }

  Widget _sidebar() => Container(
    width: 244,
    decoration: const BoxDecoration(
      color: white,
      border: Border(right: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.fromLTRB(15, 24, 15, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_rounded, color: white, size: 23),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('STOCKORA', style: TextStyle(
            fontWeight: FontWeight.w900, fontSize: 19, color: ink, letterSpacing: 1,
          ))),
        ]),
        const SizedBox(height: 7),
        const Padding(
          padding: EdgeInsets.only(left: 3),
          child: Text('INVENTORY WORKSPACE', style: TextStyle(
            fontSize: 9, color: muted, letterSpacing: 1.4,
          )),
        ),
        const SizedBox(height: 36),
        const Padding(
          padding: EdgeInsets.only(left: 12, bottom: 13),
          child: Text('WORKSPACE', style: TextStyle(
            color: muted, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700,
          )),
        ),
        for (var i = 0; i < titles.length; i++)
          if ((i != 5 || canSeeFinance) && (i != 6 || isAdmin)) _navItem(i),
        const Spacer(),
        if (isAdmin)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text('ADMIN ACCESS ENABLED', style: TextStyle(
              color: primary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700, fontSize: 10,
            )),
          ),
        const Divider(color: line),
        Material(color: Colors.transparent, child: ListTile(
          leading: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
          title: const Text('Sign out', style: TextStyle(color: Color(0xFFDC2626))),
          onTap: logout,
        )),
        const Divider(color: line),
        Material(color: Colors.transparent, child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFEEEDFF),
            child: Icon(Icons.person_outline, color: primary),
          ),
          title: Text(userName, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
          subtitle: Text(role.toUpperCase(), style: const TextStyle(color: muted, fontSize: 10)),
        )),
      ],
    ),
  );

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Explore STOCKORA', style: TextStyle(
                  color: ink, fontSize: 21, fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 5),
                const Text('Navigate your workspace', style: TextStyle(
                  color: muted, fontSize: 13, fontWeight: FontWeight.w500,
                )),
                const SizedBox(height: 18),
                for (final i in [2, 3, 5, 6])
                  if ((i != 5 || canSeeFinance) && (i != 6 || isAdmin))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Material(
                        color: selectedIndex == i
                            ? const Color(0xFFEEEDFF) : const Color(0xFFF8F9FD),
                        borderRadius: BorderRadius.circular(15),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 5,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE9E8FF),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(icons[i], color: primary, size: 21),
                          ),
                          title: Text(titles[i], style: const TextStyle(
                            color: ink, fontSize: 15, fontWeight: FontWeight.w700,
                          )),
                          trailing: const Icon(Icons.chevron_right_rounded,
                            color: muted, size: 21),
                          onTap: () {
                            Navigator.pop(sheetContext);
                            changePage(i);
                          },
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                const Divider(color: line),
                const SizedBox(height: 8),
                Material(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(15),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    leading: const Icon(Icons.logout_rounded,
                      color: Color(0xFFDC2626)),
                    title: const Text('Sign out', style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 15, fontWeight: FontWeight.w700,
                    )),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      logout();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileNav() {
    final tab = selectedIndex == 0 ? 0 : selectedIndex == 1 ? 1 : selectedIndex == 4 ? 2 : 3;
    const labels = ['Home', 'Products', 'Orders', 'More'];
    const inactiveIcons = [
      Icons.space_dashboard_outlined,
      Icons.inventory_2_outlined,
      Icons.shopping_bag_outlined,
      Icons.grid_view_outlined,
    ];
    const activeIcons = [
      Icons.space_dashboard_rounded,
      Icons.inventory_2_rounded,
      Icons.shopping_bag_rounded,
      Icons.grid_view_rounded,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 5),
          child: Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(child: InkWell(
                onTap: () => i == 3 ? _showMore() : changePage([0, 1, 4][i]),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: tab == i ? const Color(0xFFEEEDFF) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(tab == i ? activeIcons[i] : inactiveIcons[i],
                        color: tab == i ? primary : muted, size: 23),
                    const SizedBox(height: 4),
                    Text(labels[i], style: TextStyle(
                      color: tab == i ? primary : muted,
                      fontWeight: tab == i ? FontWeight.w800 : FontWeight.w500,
                      fontSize: 10,
                    )),
                  ]),
                ),
              )),
          ]),
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
      boxShadow: const [BoxShadow(
        color: Color(0x080F172A), blurRadius: 18, offset: Offset(0, 6),
      )],
    ),
    child: child,
  );

  Widget _metric({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) => Material(
    color: white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const Spacer(),
            Icon(Icons.north_east_rounded, color: accent, size: 18),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(
              color: ink, fontSize: 28, fontWeight: FontWeight.w900,
            )),
          ),
          const SizedBox(height: 3),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 2),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 10)),
        ]),
      ),
    ),
  );

  Widget _quickAction(String label, IconData icon, int page) => Expanded(
    child: OutlinedButton.icon(
      onPressed: () => changePage(page),
      icon: Icon(icon, size: 17),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        backgroundColor: white,
        side: const BorderSide(color: line),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
  );

  Widget _lowStockSection() {
    final items = (stats['lowStockProducts'] as List?) ?? [];
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.warning_amber_rounded, color: orange),
        const SizedBox(width: 9),
        const Expanded(child: Text('Low-stock alerts', style: TextStyle(
          color: ink, fontWeight: FontWeight.w800, fontSize: 17,
        ))),
        Text('${items.length} items', style: const TextStyle(color: muted, fontSize: 12)),
      ]),
      const SizedBox(height: 7),
      const Text('Products that need attention', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 15),
      const Divider(color: line),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 17),
          child: Row(children: [
            Icon(Icons.check_circle_outline, color: green),
            SizedBox(width: 10),
            Expanded(child: Text('All products have sufficient stock',
                style: TextStyle(color: ink, fontSize: 13))),
          ]),
        )
      else
        for (final raw in items)
          if (raw is Map)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E6),
                child: Icon(Icons.inventory_2_outlined, color: orange),
              ),
              title: Text('${raw['name'] ?? 'Product'}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: Text('SKU: ${raw['sku'] ?? '-'}',
                  style: const TextStyle(color: muted, fontSize: 11)),
              trailing: Text('${raw['stock'] ?? 0} left',
                  style: const TextStyle(color: orange, fontWeight: FontWeight.w800)),
              onTap: () => changePage(1, filterLowStock: true),
            ),
      if (items.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => changePage(1, filterLowStock: true),
            child: const Text('View low-stock products'),
          ),
        ),
    ]));
  }

  Widget _recentOrdersSection() {
    final orders = (stats['recentOrders'] as List?) ?? [];
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.receipt_long_outlined, color: primary),
        SizedBox(width: 9),
        Expanded(child: Text('Recent orders', style: TextStyle(
          color: ink, fontWeight: FontWeight.w800, fontSize: 17,
        ))),
      ]),
      const SizedBox(height: 7),
      const Text('Latest customer activity', style: TextStyle(color: muted, fontSize: 12)),
      const SizedBox(height: 15),
      const Divider(color: line),
      if (orders.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 17),
          child: Text('No recent orders available', style: TextStyle(color: muted)),
        )
      else
        for (final raw in orders.take(5))
          if (raw is Map)
            _orderRow(raw),
      if (orders.isNotEmpty)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => changePage(4),
            child: const Text('View all orders'),
          ),
        ),
    ]));
  }

  Widget _orderRow(Map order) {
    final id = (order['_id'] ?? '').toString();
    final shortId = id.length > 6 ? id.substring(id.length - 6) : id;
    final customer = order['customer'];
    final customerName = customer is Map
        ? (customer['name'] ?? 'Customer').toString()
        : (order['customerName'] ?? 'Customer').toString();
    final status = (order['status'] ?? 'Pending').toString();
    final amount = num.tryParse('${order['totalAmount'] ?? order['total'] ?? 0}') ?? 0;
    final success = status.toLowerCase() == 'completed';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: () => changePage(4),
        borderRadius: BorderRadius.circular(10),
        child: Row(children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFEEEDFF),
            child: Icon(Icons.shopping_bag_outlined, color: primary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Order #$shortId', style: const TextStyle(
              color: ink, fontWeight: FontWeight.w700, fontSize: 13,
            )),
            const SizedBox(height: 3),
            Text(customerName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (canSeeFinance && stats.containsKey('totalSales'))
              Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(
                color: ink, fontWeight: FontWeight.w800, fontSize: 12,
              )),
            Text(status.toUpperCase(), style: TextStyle(
              color: success ? green : orange,
              fontWeight: FontWeight.w700, fontSize: 10,
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _dashboardContent() {
    if (loading) return const Center(child: CircularProgressIndicator(color: primary));
    if (error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: muted, size: 38),
          const SizedBox(height: 12),
          Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: ink)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: fetchDashboardStats, child: const Text('Try again')),
          TextButton(onPressed: logout, child: const Text('Sign out')),
        ]),
      ));
    }
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final compact = width < 600;
      return RefreshIndicator(
        color: primary,
        onRefresh: fetchDashboardStats,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(compact ? 15 : 26, 0, compact ? 15 : 26, 36),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _workspaceBanner(compact),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: Text('Workspace overview', style: TextStyle(
                color: ink, fontSize: compact ? 22 : 25,
                fontWeight: FontWeight.w900, letterSpacing: -0.5,
              ))),
              IconButton(
                tooltip: 'Refresh dashboard',
                onPressed: fetchDashboardStats,
                icon: const Icon(Icons.refresh_rounded, color: primary),
              ),
            ]),
            const SizedBox(height: 15),
            if (width >= 900)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 3, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Key metrics', style: TextStyle(
                  color: ink, fontWeight: FontWeight.w800, fontSize: 18,
                )),
                const SizedBox(height: 13),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: compact ? 164 : 170,
                  children: [
                    _metric(
                      title: 'Total products', value: '${stats['totalProducts'] ?? 0}',
                      subtitle: 'Catalog items', icon: Icons.inventory_2_outlined,
                      accent: primary, onTap: () => changePage(1),
                    ),
                    _metric(
                      title: 'Total orders', value: '${stats['totalOrders'] ?? 0}',
                      subtitle: 'Completed orders', icon: Icons.shopping_bag_outlined,
                      accent: const Color(0xFF0284C7), onTap: () => changePage(4),
                    ),
                    if (canSeeFinance && stats.containsKey('totalSales'))
                      _metric(
                        title: 'Total sales', value: '₹${stats['totalSales'] ?? 0}',
                        subtitle: 'Revenue to date', icon: Icons.payments_outlined,
                        accent: green, onTap: () => changePage(5),
                      ),
                    _metric(
                      title: 'Low-stock alerts', value: '${stats['lowStockCount'] ?? 0}',
                      subtitle: 'Need attention', icon: Icons.warning_amber_rounded,
                      accent: orange,
                      onTap: () => changePage(1, filterLowStock: true),
                    ),
                    if (!canSeeFinance)
                      _metric(
                        title: 'Customers', value: '${stats['totalCustomers'] ?? 0}',
                        subtitle: 'Customer records', icon: Icons.people_outline_rounded,
                        accent: const Color(0xFF7C3AED), onTap: () => changePage(3),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                _lowStockSection(),
                ])),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Quick access', style: TextStyle(
                  color: ink, fontWeight: FontWeight.w800, fontSize: 18,
                )),
                const SizedBox(height: 12),
                Row(children: [
                  _quickAction('Products', Icons.inventory_2_outlined, 1),
                  const SizedBox(width: 10),
                  _quickAction('Inventory', Icons.warehouse_outlined, 2),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _quickAction('Customers', Icons.people_outline_rounded, 3),
                  const SizedBox(width: 10),
                  _quickAction('Orders', Icons.shopping_bag_outlined, 4),
                ]),
                const SizedBox(height: 18),
                _recentOrdersSection(),
                  ],
                )),
              ])
            else ...[
            const Text('Key metrics', style: TextStyle(
              color: ink, fontWeight: FontWeight.w800, fontSize: 18,
            )),
            const SizedBox(height: 13),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: compact ? 164 : 170,
              children: [
                _metric(
                  title: 'Total products', value: '${stats['totalProducts'] ?? 0}',
                  subtitle: 'Catalog items', icon: Icons.inventory_2_outlined,
                  accent: primary, onTap: () => changePage(1),
                ),
                _metric(
                  title: 'Total orders', value: '${stats['totalOrders'] ?? 0}',
                  subtitle: 'Completed orders', icon: Icons.shopping_bag_outlined,
                  accent: const Color(0xFF0284C7), onTap: () => changePage(4),
                ),
                if (canSeeFinance && stats.containsKey('totalSales'))
                  _metric(
                    title: 'Total sales', value: '₹${stats['totalSales'] ?? 0}',
                    subtitle: 'Revenue to date', icon: Icons.payments_outlined,
                    accent: green, onTap: () => changePage(5),
                  ),
                _metric(
                  title: 'Low-stock alerts', value: '${stats['lowStockCount'] ?? 0}',
                  subtitle: 'Need attention', icon: Icons.warning_amber_rounded,
                  accent: orange,
                  onTap: () => changePage(1, filterLowStock: true),
                ),
                if (!canSeeFinance)
                  _metric(
                    title: 'Customers', value: '${stats['totalCustomers'] ?? 0}',
                    subtitle: 'Customer records', icon: Icons.people_outline_rounded,
                    accent: const Color(0xFF7C3AED), onTap: () => changePage(3),
                  ),
              ],
            ),
              const SizedBox(height: 20),
            const Text('Quick access', style: TextStyle(
              color: ink, fontWeight: FontWeight.w800, fontSize: 18,
            )),
            const SizedBox(height: 12),
            Row(children: [
              _quickAction('Products', Icons.inventory_2_outlined, 1),
              const SizedBox(width: 10),
              _quickAction('Inventory', Icons.warehouse_outlined, 2),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _quickAction('Customers', Icons.people_outline_rounded, 3),
              const SizedBox(width: 10),
              _quickAction('Orders', Icons.shopping_bag_outlined, 4),
            ]),
            ],
            const SizedBox(height: 25),
            if (width < 900)
              Column(children: [
                _lowStockSection(),
                const SizedBox(height: 16),
                _recentOrdersSection(),
              ]),
          ]),
        ),
      );
    });
  }

  Widget _selectedScreen() {
    switch (selectedIndex) {
      case 0:
        return _dashboardContent();
      case 1:
        return ProductsScreen(
          key: ValueKey(lowStockOnly),
          token: widget.token,
          initialLowStockOnly: lowStockOnly,
        );
      case 2:
        return InventoryScreen(token: widget.token);
      case 3:
        return CustomersScreen(token: widget.token);
      case 4:
        return OrdersScreen(token: widget.token);
      case 5:
        return canSeeFinance
            ? ReportsScreen(token: widget.token)
            : _dashboardContent();
      case 6:
        return isAdmin
            ? UsersScreen(token: widget.token)
            : _dashboardContent();
      default:
        return _dashboardContent();
    }
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
          backgroundColor: white,
          foregroundColor: ink,
          surfaceTintColor: white,
          elevation: 0,
          toolbarHeight: 62,
          titleSpacing: wide ? 24 : 12,
          leading: wide
              ? null
              : selectedIndex == 0
                  ? const Icon(Icons.inventory_2_rounded, color: primary)
                  : IconButton(
                      tooltip: 'Back to overview',
                      onPressed: () => changePage(0),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
          title: Text(wide ? titles[selectedIndex] :
              (selectedIndex == 0 ? 'STOCKORA' : titles[selectedIndex]),
              style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
          actions: [
            if (selectedIndex == 0)
              IconButton(
                tooltip: 'Refresh',
                onPressed: fetchDashboardStats,
                icon: const Icon(Icons.refresh_rounded, color: muted),
              ),
            if (canSeeFinance) _notificationBell(),
            PopupMenuButton<String>(
              tooltip: 'Account',
              color: white,
              surfaceTintColor: white,
              elevation: 10,
              constraints: const BoxConstraints(minWidth: 260, maxWidth: 310),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: line),
              ),
              icon: const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFFEEEDFF),
                child: Icon(Icons.person_outline, color: primary, size: 20),
              ),
              onSelected: (value) {
                if (value == 'logout') logout();
                if (value == 'home') changePage(0);
              },
              itemBuilder: (_) => [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 76,
                  child: Row(children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFEEEDFF),
                      child: Icon(Icons.person_rounded, color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ink,
                            fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('${role.toUpperCase()} · STOCKORA',
                          style: const TextStyle(color: muted,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    )),
                  ]),
                ),
                const PopupMenuDivider(height: 8),
                const PopupMenuItem<String>(
                  value: 'home',
                  height: 49,
                  child: Row(children: [
                    Icon(Icons.space_dashboard_outlined,
                      color: primary, size: 20),
                    SizedBox(width: 12),
                    Text('Workspace overview', style: TextStyle(
                      color: ink, fontWeight: FontWeight.w600, fontSize: 14)),
                  ]),
                ),
                const PopupMenuDivider(height: 8),
                const PopupMenuItem<String>(
                  value: 'logout',
                  height: 52,
                  child: Row(children: [
                    Icon(Icons.logout_rounded,
                      color: Color(0xFFDC2626), size: 20),
                    SizedBox(width: 12),
                    Text('Sign out', style: TextStyle(
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                ),
              ],
            ),
            const SizedBox(width: 12),
          ],
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: line),
          ),
        ),
        bottomNavigationBar: wide ? null : _mobileNav(),
        body: Row(children: [
          if (wide) _sidebar(),
          Expanded(child: _selectedScreen()),
        ]),
      ),
    );
  }
}
