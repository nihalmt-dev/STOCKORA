
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class InventoryScreen extends StatefulWidget {
  final String token;

  const InventoryScreen({
    super.key,
    required this.token,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const bg = Color(0xFF0B1120);
  static const card = Color(0xFF172235);
  static const mint = Color(0xFF5EEAC4);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF29384D);

  List<dynamic> products = [];
  List<dynamic> movements = [];
  List<dynamic> lowStock = [];

  bool loading = true;
  bool submitting = false;
  String? errorMessage;

  String? selectedProductId;
  String movementType = 'IN';

  final quantityController = TextEditingController();
  final noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadInventory();
  }

  @override
  void dispose() {
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  Future<void> loadInventory() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('http://localhost:5000/api/products'),
          headers: headers,
        ),
        http.get(
          Uri.parse('http://localhost:5000/api/inventory/movements'),
          headers: headers,
        ),
        http.get(
          Uri.parse('http://localhost:5000/api/inventory/low-stock'),
          headers: headers,
        ),
      ]);

      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception(
            'Inventory API error: ${response.statusCode}',
          );
        }
      }

      final productData = jsonDecode(responses[0].body);
      final movementData = jsonDecode(responses[1].body);
      final lowStockData = jsonDecode(responses[2].body);

      if (!mounted) return;

      setState(() {
        products = extractList(productData, 'products');
        movements = extractList(movementData, 'movements');
        lowStock = extractList(lowStockData, 'products');
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

  List<dynamic> extractList(dynamic data, String key) {
    if (data is List) return data;

    if (data is Map && data[key] is List) {
      return data[key] as List;
    }

    return [];
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF17856C) : Colors.redAccent,
      ),
    );
  }

  Future<void> submitMovement() async {
    if (selectedProductId == null) {
      showMessage('Please select a product');
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showMessage('Enter a valid quantity greater than zero');
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
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        quantityController.clear();
        noteController.clear();

        showMessage(
          'Stock ${movementType == 'IN' ? 'added' : 'removed'} successfully',
          success: true,
        );

        await loadInventory();
      } else {
        String message = 'Stock update failed';

        try {
          final data = jsonDecode(response.body);
          message = data['message']?.toString() ?? message;
        } catch (_) {}

        showMessage(message);
      }
    } catch (error) {
      showMessage('Connection error: $error');
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
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
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mint, size: 21),
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

  Widget stockForm() {
    return sectionCard(
      title: 'Stock Management',
      icon: Icons.swap_horiz_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Update product stock',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: products.any(
              (p) => p['_id'] == selectedProductId,
            )
                ? selectedProductId
                : null,
            dropdownColor: card,
            decoration: inputDecoration('Select Product'),
            style: const TextStyle(color: Colors.white),
            items: products.map((product) {
              return DropdownMenuItem<String>(
                value: product['_id'].toString(),
                child: Text(
                  '${product['name']} (Stock: ${product['stock']})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: submitting
                ? null
                : (value) {
                    setState(() => selectedProductId = value);
                  },
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Stock IN'),
                  selected: movementType == 'IN',
                  selectedColor: mint,
                  onSelected: submitting
                      ? null
                      : (_) => setState(() => movementType = 'IN'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Stock OUT'),
                  selected: movementType == 'OUT',
                  selectedColor: mint,
                  onSelected: submitting
                      ? null
                      : (_) => setState(() => movementType = 'OUT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Quantity'),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: noteController,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Note (Optional)'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : submitMovement,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                submitting ? 'Updating...' : 'Update Stock',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mint,
                foregroundColor: bg,
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: muted),
      filled: true,
      fillColor: bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
    );
  }

  Widget lowStockSection() {
    return sectionCard(
      title: 'Low Stock Alerts',
      icon: Icons.warning_amber_rounded,
      child: lowStock.isEmpty
          ? const Text(
              'All products have sufficient stock',
              style: TextStyle(color: mint),
            )
          : Column(
              children: lowStock.map((product) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                  ),
                  title: Text(
                    '${product['name']}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'SKU: ${product['sku']}',
                    style: const TextStyle(color: muted),
                  ),
                  trailing: Text(
                    '${product['stock']} left',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget movementHistory() {
    return sectionCard(
      title: 'Stock Movement History',
      icon: Icons.history_rounded,
      child: movements.isEmpty
          ? const Text(
              'No stock movements yet',
              style: TextStyle(color: muted),
            )
          : Column(
              children: movements.take(20).map((movement) {
                final type = movement['type']?.toString() ?? '';
                final isIn = type.toUpperCase() == 'IN';
                final product = movement['product'];

                String productName = 'Product';

                if (product is Map) {
                  productName =
                      product['name']?.toString() ?? 'Product';
                }

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: (isIn ? mint : Colors.orangeAccent)
                        .withValues(alpha: 0.12),
                    child: Icon(
                      isIn
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: isIn ? mint : Colors.orangeAccent,
                    ),
                  ),
                  title: Text(
                    productName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    movement['note']?.toString().isNotEmpty == true
                        ? movement['note'].toString()
                        : 'Stock ${isIn ? 'IN' : 'OUT'}',
                    style: const TextStyle(color: muted),
                  ),
                  trailing: Text(
                    '${isIn ? '+' : '-'}${movement['quantity']}',
                    style: TextStyle(
                      color: isIn ? mint : Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
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
                'Unable to load inventory',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: loadInventory,
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
        onRefresh: loadInventory,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 850;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Inventory Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Track stock levels and inventory movements',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: stockForm()),
                        const SizedBox(width: 16),
                        Expanded(child: lowStockSection()),
                      ],
                    )
                  else ...[
                    stockForm(),
                    const SizedBox(height: 16),
                    lowStockSection(),
                  ],
                  const SizedBox(height: 18),
                  movementHistory(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
