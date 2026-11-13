
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

  Widget panel({required Widget child, EdgeInsets? padding}) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
    ),
    child: child,
  );

  Widget metricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .12), surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(
              color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800,
            )),
          ),
          const SizedBox(height: 6),
          Text(title, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12,
          )),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => panel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: mint.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: mint, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16,
            )),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
          ],
        )),
      ]),
      const SizedBox(height: 20),
      child,
    ],
  ));

  Widget salesChart() {
    if (sales.isEmpty) {
      return const SizedBox(
        height: 175,
        child: Center(child: Text('No sales data available yet',
          style: TextStyle(color: muted))),
      );
    }
    // Sort the daily aggregates so the most recent seven days appear in order.
    final sorted = List<dynamic>.from(sales)
      ..sort((a, b) => (a is Map ? a['_id'] : '').toString()
          .compareTo((b is Map ? b['_id'] : '').toString()));
    final recent = sorted.length > 7 ? sorted.sublist(sorted.length - 7) : sorted;
    double maxSales = 0;
    for (final entry in recent) {
      if (entry is Map) {
        final amount = toDouble(entry['totalSales']);
        if (amount > maxSales) maxSales = amount;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Daily sales · Last 7 reported days',
          style: TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 18),
        SizedBox(
          height: 230,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: recent.map((entry) {
              final item = entry is Map ? entry : <String, dynamic>{};
              final amount = toDouble(item['totalSales']);
              final date = item['_id']?.toString() ?? '';
              final label = date.length >= 10 ? date.substring(5) : date;
              final fraction = maxSales <= 0 ? 0.0 : amount / maxSales;
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: money(amount),
                      child: Text('₹${amount.toStringAsFixed(0)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 10)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 155 * fraction.clamp(0.02, 1.0).toDouble(),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [mint, Color(0xFF218F80)],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 10)),
                  ],
                ),
              ));
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget inventoryTable() {
    if (inventory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: Text('No inventory data available',
          style: TextStyle(color: muted))),
      );
    }
    return Column(children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(flex: 4, child: Text('PRODUCT', style: TextStyle(
            color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
          Expanded(flex: 2, child: Text('STOCK', textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
          Expanded(flex: 3, child: Text('VALUE', textAlign: TextAlign.end,
            style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
          SizedBox(width: 32),
        ]),
      ),
      const Divider(color: border, height: 1),
      ...inventory.map((entry) {
        final product = entry is Map ? entry : <String, dynamic>{};
        final name = product['name']?.toString() ?? 'Product';
        final stock = toInt(product['stock']);
        final value = toDouble(product['stockValue']);
        final low = product['lowStock'] == true;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(children: [
            Expanded(flex: 4, child: Text(name,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12,
                fontWeight: FontWeight.w600))),
            Expanded(flex: 2, child: Text('$stock', textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12))),
            Expanded(flex: 3, child: FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
              child: Text(money(value), style: const TextStyle(
                color: mint, fontWeight: FontWeight.w700, fontSize: 12)),
            )),
            SizedBox(width: 32, child: Tooltip(
              message: low ? 'Low stock' : 'Stock sufficient',
              child: Icon(low ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                size: 18, color: low ? Colors.orangeAccent : mint),
            )),
          ]),
        );
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: loadReports,
        color: mint,
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontalPadding = width < 600 ? 16.0 : 24.0;
          final columns = width >= 1000 ? 4 : 2;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(horizontalPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 16, runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reports & Analytics', style: TextStyle(
                          color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                        SizedBox(height: 5),
                        Text('Business performance and inventory insights',
                          style: TextStyle(color: muted, fontSize: 12)),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: loading ? null : loadReports,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: mint,
                        side: const BorderSide(color: border),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(50),
                    child: Center(child: CircularProgressIndicator(color: mint)),
                  )
                else if (errorMessage != null)
                  panel(child: Column(children: [
                    const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 32),
                    const SizedBox(height: 12),
                    const Text('Unable to load reports', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(errorMessage!, textAlign: TextAlign.center,
                      style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: loadReports, child: const Text('Retry')),
                  ]))
                else ...[
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: width < 600 ? 180 : 155,
                    children: [
                      metricCard(title: 'Total Revenue', value: money(totalRevenue),
                        subtitle: 'Sales to date', icon: Icons.currency_rupee_rounded, color: mint),
                      metricCard(title: 'Total Orders', value: '$totalOrders',
                        subtitle: 'Orders recorded', icon: Icons.shopping_bag_outlined,
                        color: const Color(0xFF73A9FF)),
                      metricCard(title: 'Inventory Value', value: money(totalStockValue),
                        subtitle: 'Current stock worth', icon: Icons.inventory_2_outlined,
                        color: const Color(0xFFFFCB66)),
                      metricCard(title: 'Low Stock Items', value: '$lowStockCount',
                        subtitle: 'Need attention', icon: Icons.warning_amber_rounded,
                        color: const Color(0xFFFF9F75)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (width >= 1000)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: sectionCard(
                          title: 'Sales Performance', subtitle: 'Revenue by date',
                          icon: Icons.bar_chart_rounded, child: salesChart())),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: sectionCard(
                          title: 'Inventory Report', subtitle: 'Stock and inventory value',
                          icon: Icons.table_chart_outlined, child: inventoryTable())),
                      ],
                    )
                  else ...[
                    sectionCard(title: 'Sales Performance', subtitle: 'Revenue by date',
                      icon: Icons.bar_chart_rounded, child: salesChart()),
                    const SizedBox(height: 16),
                    sectionCard(title: 'Inventory Report', subtitle: 'Stock and inventory value',
                      icon: Icons.table_chart_outlined, child: inventoryTable()),
                  ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }
}
