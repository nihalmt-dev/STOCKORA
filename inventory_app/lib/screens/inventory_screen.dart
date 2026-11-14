import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class InventoryScreen extends StatefulWidget {
  final String token;
  const InventoryScreen({super.key, required this.token});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const bg = Color(0xFFF6F7FC);
  static const white = Colors.white;
  static const primary = Color(0xFF4F46E5);
  static const ink = Color(0xFF171B35);
  static const muted = Color(0xFF777F96);
  static const border = Color(0xFFE8EAF3);
  static const green = Color(0xFF059669);
  static const orange = Color(0xFFD97706);

  List<dynamic> products = [];
  List<dynamic> movements = [];
  List<dynamic> lowStock = [];
  bool loading = true;
  bool submitting = false;
  String? errorMessage;
  String? selectedProductId;
  String movementType = 'IN';
  String role = 'staff';
  final quantityController = TextEditingController();
  final noteController = TextEditingController();

  bool get canAdjust => role == 'admin' || role == 'manager';
  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => role = (prefs.getString('user_role') ?? 'staff').toLowerCase());
    await loadInventory();
  }

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  List<dynamic> extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map && data[key] is List) return data[key] as List;
    return [];
  }

  int number(dynamic value) => int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> loadInventory() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://localhost:5000/api/products'), headers: headers),
        http.get(Uri.parse('http://localhost:5000/api/inventory/movements'), headers: headers),
        http.get(Uri.parse('http://localhost:5000/api/inventory/low-stock'), headers: headers),
      ]).timeout(const Duration(seconds: 15));
      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception('Inventory API error: ${response.statusCode}');
        }
      }
      if (!mounted) return;
      setState(() {
        products = extractList(jsonDecode(responses[0].body), 'products');
        movements = extractList(jsonDecode(responses[1].body), 'movements');
        lowStock = extractList(jsonDecode(responses[2].body), 'products');
        if (!products.any((p) => p['_id']?.toString() == selectedProductId)) {
          selectedProductId = null;
        }
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

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? green : const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> submitMovement() async {
    if (!canAdjust || submitting) return;
    if (selectedProductId == null) {
      showMessage('Please select a product');
      return;
    }
    final quantity = int.tryParse(quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      showMessage('Enter a quantity greater than zero');
      return;
    }
    final matching = products.where((p) => p['_id']?.toString() == selectedProductId);
    if (matching.isEmpty) {
      showMessage('Product not found. Refresh inventory.');
      return;
    }
    if (movementType == 'OUT' && quantity > number(matching.first['stock'])) {
      showMessage('Insufficient stock. Available: ${matching.first['stock']}');
      return;
    }
    setState(() => submitting = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/inventory/movement'),
        headers: headers,
        body: jsonEncode({
          'productId': selectedProductId,
          'type': movementType,
          'quantity': quantity,
          'note': noteController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        quantityController.clear();
        noteController.clear();
        showMessage('Stock ${movementType == 'IN' ? 'added' : 'removed'} successfully', success: true);
        await loadInventory();
      } else {
        String message = 'Stock update failed (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) message = data['message'].toString();
        } catch (_) {}
        showMessage(message);
      }
    } catch (error) {
      showMessage('Connection error: $error');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  BoxDecoration _panelDecoration() => BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0924265C), blurRadius: 20, offset: Offset(0, 8))],
      );

  Widget _panel({required String title, required String subtitle, required IconData icon,
      required Widget child, Color accent = primary}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 20),
        child,
      ]),
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: accent, size: 21),
        ),
        const Spacer(),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(color: ink, fontSize: 27, fontWeight: FontWeight.w900))),
        const SizedBox(height: 4),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: muted),
        prefixIcon: icon == null ? null : Icon(icon, color: primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFFAFAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary, width: 1.5)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _stockForm() {
    final selected = products.where((p) => p['_id']?.toString() == selectedProductId);
    return _panel(
      title: 'Manage stock',
      subtitle: 'Record incoming and outgoing inventory',
      icon: Icons.swap_horiz_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButtonFormField<String>(
          key: ValueKey(selectedProductId),
          initialValue: selected.isNotEmpty ? selectedProductId : null,
          isExpanded: true,
          dropdownColor: white,
          style: const TextStyle(color: ink, fontSize: 13),
          decoration: _inputDecoration('Select product', icon: Icons.inventory_2_outlined),
          items: products.map((p) => DropdownMenuItem<String>(
            value: p['_id'].toString(),
            child: Text('${p['name']} (Stock: ${p['stock']})', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: submitting ? null : (value) => setState(() => selectedProductId = value),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Available stock: ${selected.first['stock']}',
            style: const TextStyle(color: green, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _movementButton('Stock IN', Icons.south_west_rounded, 'IN')),
          const SizedBox(width: 10),
          Expanded(child: _movementButton('Stock OUT', Icons.north_east_rounded, 'OUT')),
        ]),
        const SizedBox(height: 17),
        TextField(
          controller: quantityController,
          enabled: !submitting,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(color: ink),
          decoration: _inputDecoration('Quantity', icon: Icons.numbers_rounded),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: noteController,
          enabled: !submitting,
          maxLines: 2,
          style: const TextStyle(color: ink),
          decoration: _inputDecoration('Note (optional)', icon: Icons.notes_rounded),
        ),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: submitting ? null : submitMovement,
          icon: submitting
              ? const SizedBox(width: 17, height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2, color: white))
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(submitting ? 'Updating...' : 'Update stock'),
          style: ElevatedButton.styleFrom(
            backgroundColor: primary, foregroundColor: white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        )),
      ]),
    );
  }

  Widget _movementButton(String label, IconData icon, String type) {
    final active = movementType == type;
    final accent = type == 'IN' ? green : orange;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: submitting ? null : () => setState(() => movementType = type),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: .09) : bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? accent : border),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: active ? accent : muted, size: 18),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: active ? accent : muted, fontSize: 12, fontWeight: FontWeight.w800))),
          ]),
        ),
      ),
    );
  }

  Widget _lowStockSection() => _panel(
    title: 'Low-stock alerts',
    subtitle: 'Products that need attention',
    icon: Icons.warning_amber_rounded,
    accent: orange,
    child: lowStock.isEmpty
      ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Row(children: [
          Icon(Icons.check_circle_outline_rounded, color: green),
          SizedBox(width: 10),
          Expanded(child: Text('All products have sufficient stock',
            style: TextStyle(color: muted, fontSize: 12))),
        ]))
      : Column(children: lowStock.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
          child: Row(children: [
            const Icon(Icons.inventory_2_outlined, color: orange, size: 21),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p['name']}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('SKU: ${p['sku']}', style: const TextStyle(color: muted, fontSize: 11)),
            ])),
            const SizedBox(width: 8),
            Text('${p['stock']} left', style: const TextStyle(color: orange,
              fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        )).toList()),
  );

  Widget _movementHistory() => _panel(
    title: 'Movement history',
    subtitle: 'Recent inventory activity',
    icon: Icons.history_rounded,
    child: movements.isEmpty
      ? const Padding(padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: Text('No stock movements yet', style: TextStyle(color: muted))))
      : Column(children: movements.take(20).map((movement) {
          final isIn = movement['type']?.toString().toUpperCase() == 'IN';
          final product = movement['product'];
          final productName = product is Map ? product['name']?.toString() ?? 'Product' : 'Product';
          final note = movement['note']?.toString() ?? '';
          final accent = isIn ? green : orange;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border)),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accent.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(11)),
                child: Icon(isIn ? Icons.south_west_rounded : Icons.north_east_rounded,
                  color: accent, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ink, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 4),
                Text(note.isNotEmpty ? note : 'Stock ${isIn ? 'IN' : 'OUT'}',
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: muted, fontSize: 11)),
              ])),
              const SizedBox(width: 8),
              Text('${isIn ? '+' : '-'}${movement['quantity']}',
                style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          );
        }).toList()),
  );

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary)));
    }
    if (errorMessage != null) {
      return Scaffold(backgroundColor: bg,
        body: Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, color: muted, size: 42),
            const SizedBox(height: 12),
            const Text('Unable to load inventory',
              style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(errorMessage!, textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: loadInventory, child: const Text('Retry')),
          ]))));
    }
    return Scaffold(backgroundColor: bg,
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 850;
        final compact = constraints.maxWidth < 550;
        final totalUnits = products.fold<int>(0, (sum, p) => sum + number(p['stock']));
        return RefreshIndicator(color: primary, onRefresh: loadInventory,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 18, compact ? 16 : 24, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Inventory management', style: TextStyle(color: ink,
                    fontSize: compact ? 23 : 27, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  const Text('Track stock levels and inventory movements',
                    style: TextStyle(color: muted, fontSize: 12)),
                ])),
                IconButton(onPressed: loadInventory, tooltip: 'Refresh inventory',
                  icon: const Icon(Icons.refresh_rounded, color: primary)),
              ]),
              const SizedBox(height: 22),
              GridView.count(
                crossAxisCount: compact ? 2 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 135,
                children: [
                  _summaryCard('Total products', '${products.length}', Icons.inventory_2_outlined, primary),
                  _summaryCard('Units in stock', '$totalUnits', Icons.warehouse_outlined, green),
                  _summaryCard('Low-stock alerts', '${lowStock.length}', Icons.warning_amber_rounded, orange),
                ],
              ),
              const SizedBox(height: 20),
              if (canAdjust) ...[
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _stockForm()),
                    const SizedBox(width: 16),
                    Expanded(child: _lowStockSection()),
                  ])
                else ...[
                  _stockForm(),
                  const SizedBox(height: 16),
                  _lowStockSection(),
                ],
              ] else _lowStockSection(),
              const SizedBox(height: 18),
              _movementHistory(),
            ]),
          ),
        );
      }),
    );
  }
}
