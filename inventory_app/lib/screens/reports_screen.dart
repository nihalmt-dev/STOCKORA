
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReportsScreen extends StatefulWidget {
  final String token;

  const ReportsScreen({
    super.key,
    required this.token,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const bg = Color(0xFF0B1120);
  static const surface = Color(0xFF172235);
  static const mint = Color(0xFF5EEAC4);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF29384D);

  bool loading = true;
  String? errorMessage;

  List<dynamic> sales = [];
  List<dynamic> inventory = [];

  double totalRevenue = 0;
  int totalOrders = 0;
  double totalStockValue = 0;
  int lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  double toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  int toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  String money(dynamic value) {
    return '₹${toDouble(value).toStringAsFixed(2)}';
  }

  Future<void> loadReports() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('http://localhost:5000/api/reports/sales'),
          headers: headers,
        ),
        http.get(
          Uri.parse('http://localhost:5000/api/reports/inventory'),
          headers: headers,
        ),
      ]).timeout(const Duration(seconds: 15));

      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception(
            'Reports API error: ${response.statusCode}',
          );
        }
      }

      final salesResponse = jsonDecode(responses[0].body);
      final inventoryResponse = jsonDecode(responses[1].body);

      // Backend /sales returns a direct array:
      // [
      //   {
      //     "_id": "2026-11-12",
      //     "totalSales": 9993,
      //     "totalOrders": 2
      //   }
      // ]

      final salesList =
          salesResponse is List ? salesResponse : <dynamic>[];

      // Backend /inventory returns:
      // {
      //   "totalProducts": 3,
      //   "totalStockValue": 58060,
      //   "products": [...]
      // }

      final inventoryMap =
          inventoryResponse is Map
              ? inventoryResponse
              : <String, dynamic>{};

      final inventoryList =
          inventoryMap['products'] is List
              ? inventoryMap['products'] as List
              : <dynamic>[];

      double calculatedRevenue = 0;
      int calculatedOrders = 0;

      for (final entry in salesList) {
        if (entry is Map) {
          calculatedRevenue +=
              toDouble(entry['totalSales']);

          calculatedOrders +=
              toInt(entry['totalOrders']);
        }
      }

      int calculatedLowStock = 0;

      for (final entry in inventoryList) {
        if (entry is Map && entry['lowStock'] == true) {
          calculatedLowStock++;
        }
      }

      if (!mounted) return;

      setState(() {
        sales = salesList;
        inventory = inventoryList;

        totalRevenue = calculatedRevenue;
        totalOrders = calculatedOrders;

        totalStockValue =
            toDouble(inventoryMap['totalStockValue']);

        lowStockCount = calculatedLowStock;

        loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        loading = false;
      });
    }
  }

  Widget metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget salesChart() {
    if (sales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(25),
        child: Center(
          child: Text(
            'No completed sales available',
            style: TextStyle(color: muted),
          ),
        ),
      );
    }

    final displayedSales =
        sales.length > 7
            ? sales.sublist(sales.length - 7)
            : sales;

    double maxValue = 0;

    for (final entry in displayedSales) {
      if (entry is Map) {
        final value = toDouble(entry['totalSales']);
        if (value > maxValue) maxValue = value;
      }
    }

    return SizedBox(
      height: 245,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: displayedSales.map((entry) {
          final item = entry is Map
              ? entry
              : <String, dynamic>{};

          final value = toDouble(item['totalSales']);

          final ratio =
              maxValue == 0 ? 0.02 : value / maxValue;

          final date = item['_id']?.toString() ?? '';

          final label = date.length >= 10
              ? date.substring(5)
              : date;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '₹${value.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                   height: 165.0 * ratio.clamp(0.02, 1.0).toDouble(),
                    decoration: const BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    label,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget inventoryTable() {
    if (inventory.isEmpty) {
      return const Text(
        'No inventory data available',
        style: TextStyle(color: muted),
      );
    }

    return Column(
      children: inventory.map((entry) {
        final product = entry is Map
            ? entry
            : <String, dynamic>{};

        final name =
            product['name']?.toString() ?? 'Product';

        final stock = toInt(product['stock']);

        final value = toDouble(
          product['stockValue'],
        );

        final isLowStock =
            product['lowStock'] == true;

        return Container(
          padding: const EdgeInsets.symmetric(
            vertical: 13,
          ),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '$stock',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  money(value),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: mint,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                isLowStock
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: isLowStock
                    ? Colors.orangeAccent
                    : mint,
                size: 18,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: bg,
        body: Center(
          child: CircularProgressIndicator(color: mint),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Unable to load reports',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: loadReports,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: loadReports,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final columns = width >= 950
                ? 4
                : (width >= 500 ? 2 : 1);

            return SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment:
                        WrapCrossAlignment.center,
                    children: [
                      const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reports & Analytics',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Business performance and inventory insights',
                            style: TextStyle(color: muted),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: loadReports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mint,
                          side: const BorderSide(
                            color: border,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics:
                        const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    mainAxisExtent: 155,
                    children: [
                      metricCard(
                        title: 'Total Revenue',
                        value: money(totalRevenue),
                        icon:
                            Icons.currency_rupee_rounded,
                        color: mint,
                      ),
                      metricCard(
                        title: 'Total Orders',
                        value: '$totalOrders',
                        icon:
                            Icons.shopping_bag_outlined,
                        color: const Color(0xFF73A9FF),
                      ),
                      metricCard(
                        title: 'Inventory Value',
                        value: money(totalStockValue),
                        icon:
                            Icons.inventory_2_outlined,
                        color: const Color(0xFFFFCB66),
                      ),
                      metricCard(
                        title: 'Low Stock Items',
                        value: '$lowStockCount',
                        icon:
                            Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  sectionCard(
                    title: 'Sales Performance',
                    icon: Icons.bar_chart_rounded,
                    child: salesChart(),
                  ),
                  const SizedBox(height: 20),
                  sectionCard(
                    title: 'Inventory Report',
                    icon: Icons.table_chart_outlined,
                    child: inventoryTable(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
