import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:inventory_app/config/api_config.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ReportsScreen extends StatefulWidget {
  final String token;
  const ReportsScreen({super.key, required this.token});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const background = Color(0xFFF7F8FD);
  static const ink = Color(0xFF19233D);
  static const muted = Color(0xFF77839B);
  static const purple = Color(0xFF6254D9);
  static const line = Color(0xFFE8EAF3);
  static const green = Color(0xFF159A77);
  static const orange = Color(0xFFE69A39);

  bool loading = true;
  bool allowed = false;
  String? error;
  String period = 'Daily';
  String search = '';
  bool lowOnly = false;
  List<Map<String, dynamic>> sales = [];
  List<Map<String, dynamic>> products = [];
  double stockValue = 0;
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadReports();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${widget.token}',
    'Content-Type': 'application/json',
  };

  double number(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
  int integer(dynamic v) => number(v).toInt();
  String money(dynamic v) => '₹${number(v).toStringAsFixed(2)}';
  String shortMoney(double v) {
    if (v >= 10000000) return '₹${(v / 10000000).toStringAsFixed(2)}Cr';
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(2)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}k';
    return '₹${v.toStringAsFixed(0)}';
  }

  Future<void> loadReports() async {
    if (!mounted) return;
    setState(() { loading = true; error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = (prefs.getString('user_role') ?? '').toLowerCase();
      if (role != 'admin' && role != 'manager') {
        if (mounted) setState(() { allowed = false; loading = false; error = 'Reports are available to Admin and Manager accounts only.'; });
        return;
      }
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/reports/sales'), headers: headers),
        http.get(Uri.parse('${ApiConfig.baseUrl}/api/reports/inventory'), headers: headers),
      ]).timeout(const Duration(seconds: 20));
      if (responses.any((r) => r.statusCode == 401 || r.statusCode == 403)) {
        throw Exception('Access denied. Please sign in with an Admin or Manager account.');
      }
      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Unable to fetch reports. Check the backend server.');
      }
      final s = jsonDecode(responses[0].body);
      final i = jsonDecode(responses[1].body);
      final saleRows = s is List ? s : (s is Map && s['sales'] is List ? s['sales'] as List : <dynamic>[]);
      final inv = i is Map ? i : <String, dynamic>{};
      final invRows = inv['products'] is List ? inv['products'] as List : <dynamic>[];
      if (!mounted) return;
      setState(() {
        allowed = true;
        sales = saleRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        products = invRows.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        stockValue = number(inv['totalStockValue']);
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  double get revenue => sales.fold(0, (double a, e) => a + number(e['totalSales']));
  int get orderCount => sales.fold(0, (int a, e) => a + integer(e['totalOrders']));
  int get lowCount => products.where((e) => e['lowStock'] == true).length;
  int get totalUnits => products.fold(0, (int a, e) => a + integer(e['stock']));

  BoxDecoration panelDecoration() => BoxDecoration(
    color: Colors.white,
    border: Border.all(color: line),
    borderRadius: BorderRadius.circular(19),
    boxShadow: [BoxShadow(color: const Color(0xFF243065).withValues(alpha: .035), blurRadius: 22, offset: const Offset(0, 7))],
  );

  Widget panel({required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(20)}) =>
      Container(width: double.infinity, padding: padding, decoration: panelDecoration(), child: child);

  Widget heading(String title, String subtitle, IconData icon) => Row(children: [
    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFF0EEFF), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: purple, size: 20)),
    const SizedBox(width: 11),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 11)),
    ])),
  ]);

  Widget metric(String label, String value, String subtitle, IconData icon, Color color) => panel(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 21)),
        const Spacer(),
        const Icon(Icons.north_east_rounded, size: 17, color: Color(0xFFBAC0D0)),
      ]),
      const SizedBox(height: 17),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: ink))),
      const SizedBox(height: 5),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink)),
      const SizedBox(height: 3),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
    ]),
  );

  List<Map<String, dynamic>> get chartRows {
    final sorted = List<Map<String, dynamic>>.from(sales)
      ..sort((a, b) => '${a['_id'] ?? ''}'.compareTo('${b['_id'] ?? ''}'));
    if (period == 'Daily') return sorted.length > 10 ? sorted.sublist(sorted.length - 10) : sorted;
    final groups = <String, Map<String, dynamic>>{};
    for (final row in sorted) {
      final date = '${row['_id'] ?? ''}';
      final key = date.length >= 7 ? date.substring(0, 7) : date;
      final item = groups.putIfAbsent(key, () => {'_id': key, 'totalSales': 0.0, 'totalOrders': 0});
      item['totalSales'] = number(item['totalSales']) + number(row['totalSales']);
      item['totalOrders'] = integer(item['totalOrders']) + integer(row['totalOrders']);
    }
    final values = groups.values.toList();
    return values.length > 10 ? values.sublist(values.length - 10) : values;
  }

  Widget salesChart() {
    final rows = chartRows;
    if (rows.isEmpty) return const SizedBox(height: 240, child: Center(child: Text('No sales recorded yet', style: TextStyle(color: muted))));
    final maxValue = math.max(1.0, rows.fold<double>(0, (v, e) => math.max(v, number(e['totalSales']))));
    return Column(children: [
      SizedBox(height: 255, child: LayoutBuilder(builder: (context, size) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: 49, child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(5, (index) => Text(shortMoney(maxValue * (4 - index) / 4), style: const TextStyle(color: muted, fontSize: 10))))),
          const SizedBox(width: 12),
          Expanded(child: Stack(children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(5, (_) => Container(height: 1, color: line))),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: rows.map((e) {
              final value = number(e['totalSales']);
              final date = '${e['_id'] ?? ''}';
              final label = period == 'Daily' && date.length >= 10 ? date.substring(5) : (date.length >= 7 ? date.substring(2) : date);
              return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Expanded(child: LayoutBuilder(builder: (context, barSize) => Align(alignment: Alignment.bottomCenter, child: Tooltip(
                  message: '$date\n${money(value)} Â· ${integer(e['totalOrders'])} orders',
                  child: AnimatedContainer(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic,
                    height: math.max(4, barSize.maxHeight * value / maxValue), width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 46),
                    decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9388F4), purple]), borderRadius: const BorderRadius.vertical(top: Radius.circular(7))),
                  ),
                )))),
                const SizedBox(height: 9),
                Text(label, style: const TextStyle(fontSize: 9, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])));
            }).toList()),
          ])),
        ]);
      })),
      const SizedBox(height: 14),
      const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.circle, size: 9, color: purple), SizedBox(width: 6), Text('Revenue', style: TextStyle(color: muted, fontSize: 11)),
      ]),
    ]);
  }

  Widget inventoryHealth() {
    final healthy = products.length - lowCount;
    final ratio = products.isEmpty ? 0.0 : healthy / products.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('$healthy', style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: ink)),
        const SizedBox(width: 7),
        const Text('healthy products', style: TextStyle(color: muted, fontSize: 12)),
      ]),
      const SizedBox(height: 17),
      ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: ratio, minHeight: 13, backgroundColor: const Color(0xFFFFE5C4), valueColor: const AlwaysStoppedAnimation(green))),
      const SizedBox(height: 17),
      Row(children: [const Icon(Icons.circle, size: 10, color: green), const SizedBox(width: 7), const Expanded(child: Text('Healthy stock', style: TextStyle(fontSize: 12, color: muted))), Text('$healthy', style: const TextStyle(fontWeight: FontWeight.w800, color: ink))]),
      const SizedBox(height: 11),
      Row(children: [const Icon(Icons.circle, size: 10, color: orange), const SizedBox(width: 7), const Expanded(child: Text('Low stock', style: TextStyle(fontSize: 12, color: muted))), Text('$lowCount', style: const TextStyle(fontWeight: FontWeight.w800, color: ink))]),
      const Divider(height: 33, color: line),
      Row(children: [const Icon(Icons.inventory_2_outlined, size: 18, color: purple), const SizedBox(width: 8), const Expanded(child: Text('Total stock units', style: TextStyle(fontSize: 12, color: muted))), Text('$totalUnits', style: const TextStyle(fontWeight: FontWeight.w800, color: ink))]),
      const SizedBox(height: 13),
      Row(children: [const Icon(Icons.category_outlined, size: 18, color: purple), const SizedBox(width: 8), const Expanded(child: Text('Product types', style: TextStyle(fontSize: 12, color: muted))), Text('${products.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: ink))]),
    ]);
  }

  List<Map<String, dynamic>> get filteredProducts {
    final q = search.trim().toLowerCase();
    final rows = products.where((p) {
      if (lowOnly && p['lowStock'] != true) return false;
      return '${p['name'] ?? ''} ${p['sku'] ?? ''}'.toLowerCase().contains(q);
    }).toList();
    rows.sort((a, b) => '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}'));
    return rows;
  }

  String csvCell(dynamic value) => '"${'$value'.replaceAll('"', '""')}"';
  Future<void> copyCsv() async {
    final lines = <String>['Product,SKU,Stock,Stock Value,Status'];
    for (final p in filteredProducts) {
      lines.add([p['name'] ?? '', p['sku'] ?? '', integer(p['stock']), number(p['stockValue']).toStringAsFixed(2), p['lowStock'] == true ? 'Low Stock' : 'Healthy'].map(csvCell).join(','));
    }
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copied. Paste into Excel or a .csv file.')));
  }

  Widget inventoryTable(bool narrow) {
    final rows = filteredProducts;
    if (rows.isEmpty) return const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('No matching inventory records', style: TextStyle(color: muted))));
    return Column(children: [
      if (!narrow) Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(9)), child: const Row(children: [
        Expanded(flex: 4, child: Text('PRODUCT / SKU', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('UNITS', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
        Expanded(flex: 3, child: Text('STOCK VALUE', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
        Expanded(flex: 2, child: Text('STATUS', style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800))),
      ])),
      ...rows.map((p) {
        final low = p['lowStock'] == true;
        final status = Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: low ? const Color(0xFFFFF1E0) : const Color(0xFFE8F8F2), borderRadius: BorderRadius.circular(20)), child: Text(low ? 'Low stock' : 'Healthy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: low ? const Color(0xFFB77825) : green)));
        return Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))), child: narrow
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('${p['name'] ?? 'Product'}', style: const TextStyle(color: ink, fontWeight: FontWeight.w700))), status]),
              const SizedBox(height: 7),
              Text('SKU: ${p['sku'] ?? 'â€”'}  â€¢  ${integer(p['stock'])} units', style: const TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 5),
              Text(money(p['stockValue']), style: const TextStyle(color: purple, fontWeight: FontWeight.w800)),
            ])
          : Row(children: [
              Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['name'] ?? 'Product'}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text('${p['sku'] ?? 'â€”'}', style: const TextStyle(fontSize: 10, color: muted))])),
              Expanded(flex: 2, child: Text('${integer(p['stock'])}', style: const TextStyle(color: ink, fontSize: 12))),
              Expanded(flex: 3, child: Text(money(p['stockValue']), style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 12))),
              Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: status)),
            ]));
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: background, body: RefreshIndicator(onRefresh: loadReports, color: purple, child: LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final compact = width < 680;
      final pad = compact ? 16.0 : 26.0;
      return SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(pad, 22, pad, 35), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 14, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reports & Analytics', style: TextStyle(fontSize: 26, color: ink, fontWeight: FontWeight.w900)),
            SizedBox(height: 5),
            Text('Sales performance, inventory intelligence & business insights', style: TextStyle(fontSize: 12, color: muted)),
          ]),
          OutlinedButton.icon(onPressed: loading ? null : loadReports, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh'), style: OutlinedButton.styleFrom(foregroundColor: purple, side: const BorderSide(color: line))),
        ]),
        const SizedBox(height: 23),
        if (loading) const Padding(padding: EdgeInsets.all(60), child: Center(child: CircularProgressIndicator(color: purple)))
        else if (error != null || !allowed) panel(child: Column(children: [
          const Icon(Icons.lock_outline_rounded, color: purple, size: 38), const SizedBox(height: 10),
          const Text('Reports unavailable', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 8), Text(error ?? 'Access denied', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
          const SizedBox(height: 12), TextButton(onPressed: loadReports, child: const Text('Try again')),
        ]))
        else ...[
          LayoutBuilder(builder: (context, metrics) {
            final count = metrics.maxWidth >= 1050 ? 4 : metrics.maxWidth >= 540 ? 2 : 1;
            final cardWidth = (metrics.maxWidth - (count - 1) * 13) / count;
            return Wrap(spacing: 13, runSpacing: 13, children: [
              SizedBox(width: cardWidth, child: metric('Total Revenue', money(revenue), 'Recorded sales', Icons.payments_outlined, purple)),
              SizedBox(width: cardWidth, child: metric('Total Orders', '$orderCount', 'Orders recorded', Icons.shopping_bag_outlined, const Color(0xFF3E91D4))),
              SizedBox(width: cardWidth, child: metric('Inventory Value', money(stockValue), 'Current stock worth', Icons.inventory_2_outlined, green)),
              SizedBox(width: cardWidth, child: metric('Low Stock Items', '$lowCount', 'Products needing attention', Icons.warning_amber_rounded, orange)),
            ]);
          }),
          const SizedBox(height: 18),
          if (width >= 950) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: panel(child: Column(children: [
              heading('Sales Performance', 'Revenue trend from recorded orders', Icons.bar_chart_rounded),
              const SizedBox(height: 16),
              _periodSelector(), const SizedBox(height: 17), salesChart(),
            ]))),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('Inventory Health', 'Current stock availability', Icons.donut_large_rounded), const SizedBox(height: 27), inventoryHealth()]))),
          ]) else ...[
            panel(child: Column(children: [heading('Sales Performance', 'Revenue trend from recorded orders', Icons.bar_chart_rounded), const SizedBox(height: 16), _periodSelector(), const SizedBox(height: 17), salesChart()])),
            const SizedBox(height: 16),
            panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('Inventory Health', 'Current stock availability', Icons.donut_large_rounded), const SizedBox(height: 23), inventoryHealth()])),
          ],
          const SizedBox(height: 18),
          panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            heading('Detailed Inventory Report', 'Product-wise stock, valuation and alerts', Icons.table_chart_outlined),
            const SizedBox(height: 19),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: compact ? math.max(180, width - 72) : 300, child: TextField(controller: searchController, onChanged: (v) => setState(() => search = v), style: const TextStyle(color: Color(0xFF17233D), fontSize: 13, fontWeight: FontWeight.w500), cursorColor: purple, decoration: InputDecoration(isDense: true, hintText: 'Search product or SKU', hintStyle: const TextStyle(color: muted, fontSize: 12), prefixIcon: const Icon(Icons.search, color: muted), filled: true, fillColor: background, border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: line))))),
              FilterChip(label: const Text('Low stock only'), selected: lowOnly, onSelected: (v) => setState(() => lowOnly = v), selectedColor: const Color(0xFFEAE7FF), checkmarkColor: purple),
              OutlinedButton.icon(onPressed: copyCsv, icon: const Icon(Icons.copy_rounded, size: 16), label: const Text('Copy CSV'), style: OutlinedButton.styleFrom(foregroundColor: purple, side: const BorderSide(color: line))),
            ]),
            const SizedBox(height: 15),
            inventoryTable(compact),
            const SizedBox(height: 12),
            Text('${filteredProducts.length} of ${products.length} products shown', style: const TextStyle(color: muted, fontSize: 11)),
          ])),
        ],
      ]));
    })));
  }

  Widget _periodSelector() => Align(alignment: Alignment.centerRight, child: SegmentedButton<String>(
    showSelectedIcon: false,
    style: ButtonStyle(visualDensity: VisualDensity.compact, foregroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? purple : muted)),
    segments: const [ButtonSegment(value: 'Daily', label: Text('Daily')), ButtonSegment(value: 'Monthly', label: Text('Monthly'))],
    selected: {period},
    onSelectionChanged: (v) => setState(() => period = v.first),
  ));
}
