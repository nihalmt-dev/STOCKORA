
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrdersScreen extends StatefulWidget {
  final String token;

  const OrdersScreen({
    super.key,
    required this.token,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const bg = Color(0xFF0B1120);
  static const surface = Color(0xFF172235);
  static const mint = Color(0xFF5EEAC4);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF29384D);

  List<dynamic> orders = [];
  List<dynamic> products = [];
  List<dynamic> customers = [];

  bool loading = true;
  bool submitting = false;
  bool showCreateForm = false;
  String? errorMessage;

  String? selectedCustomerId;
  String? selectedProductId;
  final quantityController = TextEditingController(text: '1');
  final searchController = TextEditingController();
  String orderQuery = '';

  final List<Map<String, dynamic>> cart = [];

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<dynamic> extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map && data[key] is List) {
      return data[key] as List;
    }
    return [];
  }

  Future<void> loadData() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final responses = await Future.wait([
        http.get(
          Uri.parse('http://localhost:5000/api/orders'),
          headers: headers,
        ),
        http.get(
          Uri.parse('http://localhost:5000/api/products'),
          headers: headers,
        ),
        http.get(
          Uri.parse('http://localhost:5000/api/customers'),
          headers: headers,
        ),
      ]).timeout(const Duration(seconds: 15));

      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception(
            'API Error: ${response.statusCode}',
          );
        }
      }

      if (!mounted) return;

      setState(() {
        orders = extractList(
          jsonDecode(responses[0].body),
          'orders',
        );
        products = extractList(
          jsonDecode(responses[1].body),
          'products',
        );
        customers = extractList(
          jsonDecode(responses[2].body),
          'customers',
        );
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

  void showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF17856C) : Colors.redAccent,
      ),
    );
  }

  double asDouble(dynamic value) {
    return double.tryParse(value.toString()) ?? 0;
  }

  int asInt(dynamic value) {
    return int.tryParse(value.toString()) ?? 0;
  }

  double get cartTotal {
    return cart.fold<double>(
      0,
      (sum, item) =>
          sum +
          asDouble(item['price']) *
              asInt(item['quantity']),
    );
  }

  void addToCart() {
    if (selectedProductId == null) {
      showMessage('Please select a product');
      return;
    }

    final quantity =
        int.tryParse(quantityController.text.trim());

    if (quantity == null || quantity <= 0) {
      showMessage('Enter a valid quantity');
      return;
    }

    final matches = products.where(
      (p) => p['_id'].toString() == selectedProductId,
    );

    if (matches.isEmpty) {
      showMessage('Product not found');
      return;
    }

    final product = matches.first;
    final availableStock = asInt(product['stock']);

    final existingIndex = cart.indexWhere(
      (item) => item['productId'] == selectedProductId,
    );

    final existingQuantity = existingIndex >= 0
        ? asInt(cart[existingIndex]['quantity'])
        : 0;

    if (existingQuantity + quantity > availableStock) {
      showMessage(
        'Insufficient stock. Available: $availableStock',
      );
      return;
    }

    setState(() {
      if (existingIndex >= 0) {
        cart[existingIndex]['quantity'] =
            existingQuantity + quantity;
      } else {
        cart.add({
          'productId': selectedProductId,
          'name': product['name'],
          'price': asDouble(product['price']),
          'quantity': quantity,
        });
      }

      quantityController.text = '1';
      selectedProductId = null;
    });

    showMessage(
      'Product added to order',
      success: true,
    );
  }

  Future<void> createOrder() async {
    if (selectedCustomerId == null) {
      showMessage('Please select a customer');
      return;
    }

    if (cart.isEmpty) {
      showMessage('Add at least one product');
      return;
    }

    setState(() => submitting = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/orders'),
        headers: headers,
        body: jsonEncode({
          'customerId': selectedCustomerId,
          'items': cart.map((item) {
            return {
              'productId': item['productId'],
              'quantity': item['quantity'],
            };
          }).toList(),
        }),
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        setState(() {
          cart.clear();
          selectedCustomerId = null;
          selectedProductId = null;
          showCreateForm = false;
          quantityController.text = '1';
        });

        showMessage(
          'Order created successfully',
          success: true,
        );

        await loadData();
      } else {
        String message = 'Unable to create order';

        try {
          final data = jsonDecode(response.body);
          message =
              data['message']?.toString() ?? message;
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

  InputDecoration inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: muted),
      filled: true,
      fillColor: bg,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: mint),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  String money(dynamic value) => '₹${asDouble(value).toStringAsFixed(2)}';

  Widget sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: mint.withValues(alpha:.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: mint, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
                ],
              ],
            )),
          ]),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget statCard(String title, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: accent.withValues(alpha:.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 14),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget createOrderSection() {
    return sectionCard(
      title: 'Create a new order',
      subtitle: 'Follow the steps below to place an order',
      icon: Icons.add_shopping_cart_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('STEP 1  ·  SELECT CUSTOMER', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          key: ValueKey('customer-$selectedCustomerId'),
          initialValue: customers.any((c) => c['_id'].toString() == selectedCustomerId) ? selectedCustomerId : null,
          isExpanded: true,
          dropdownColor: surface,
          style: const TextStyle(color: Colors.white),
          decoration: inputDecoration('Select customer'),
          items: customers.map((customer) => DropdownMenuItem<String>(
            value: customer['_id'].toString(),
            child: Text(customer['name']?.toString() ?? 'Customer', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: submitting ? null : (value) => setState(() => selectedCustomerId = value),
        ),
        const SizedBox(height: 20),
        const Text('STEP 2  ·  ADD PRODUCTS', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          key: ValueKey('product-$selectedProductId'),
          initialValue: selectedProductId,
          isExpanded: true,
          dropdownColor: surface,
          style: const TextStyle(color: Colors.white),
          decoration: inputDecoration('Select product'),
          items: products.map((product) => DropdownMenuItem<String>(
            value: product['_id'].toString(),
            child: Text('${product['name']} · ${product['stock']} in stock', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: submitting ? null : (value) => setState(() => selectedProductId = value),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: quantityController,
            enabled: !submitting,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Quantity'),
          )),
          const SizedBox(width: 10),
          SizedBox(height: 54, child: ElevatedButton.icon(
            onPressed: submitting ? null : addToCart,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(backgroundColor: mint, foregroundColor: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]),
        const SizedBox(height: 24),
        Row(children: [
          const Expanded(child: Text('STEP 3  ·  REVIEW ORDER', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1))),
          Text('${cart.length} item${cart.length == 1 ? '' : 's'}', style: const TextStyle(color: mint, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        if (cart.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
            child: const Column(children: [
              Icon(Icons.shopping_bag_outlined, color: muted, size: 30),
              SizedBox(height: 8),
              Text('Your cart is empty', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Select a product to get started', style: TextStyle(color: muted, fontSize: 12)),
            ]),
          )
        else
          ...cart.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final subtotal = asDouble(item['price']) * asInt(item['quantity']);
            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: mint.withValues(alpha:.10), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.inventory_2_outlined, color: mint, size: 19)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${item['quantity']} × ${money(item['price'])}', style: const TextStyle(color: muted, fontSize: 12)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(subtotal), style: const TextStyle(color: mint, fontWeight: FontWeight.w700)),
                  SizedBox(height: 30, width: 32, child: IconButton(
                    padding: EdgeInsets.zero,
                    tooltip: 'Remove item',
                    onPressed: submitting ? null : () => setState(() => cart.removeAt(index)),
                    icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                  )),
                ]),
              ]),
            );
          }),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Expanded(child: Text('Order total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
            Flexible(child: Text(money(cartTotal), textAlign: TextAlign.end,
              style: const TextStyle(color: mint, fontSize: 22, fontWeight: FontWeight.w800))),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: submitting ? null : createOrder,
          icon: submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: bg))
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(submitting ? 'Creating order...' : 'Confirm & Place Order', style: const TextStyle(fontWeight: FontWeight.w800)),
          style: ElevatedButton.styleFrom(backgroundColor: mint, foregroundColor: bg,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        )),
      ]),
    );
  }

  Widget orderHistorySection() {
    final query = orderQuery.trim().toLowerCase();
    final filtered = orders.where((order) {
      final customer = order['customer'];
      final name = customer is Map ? (customer['name']?.toString() ?? '') : '';
      return query.isEmpty || order['_id'].toString().toLowerCase().contains(query) ||
          name.toLowerCase().contains(query) || (order['status']?.toString() ?? '').toLowerCase().contains(query);
    }).toList();
    return sectionCard(
      title: 'Order history',
      subtitle: 'View and search your recent orders',
      icon: Icons.receipt_long_outlined,
      child: Column(children: [
        TextField(
          controller: searchController,
          onChanged: (value) => setState(() => orderQuery = value),
          style: const TextStyle(color: Colors.white),
          decoration: inputDecoration('Search customer, order ID or status').copyWith(
            prefixIcon: const Icon(Icons.search_rounded, color: muted),
            suffixIcon: orderQuery.isNotEmpty ? IconButton(
              onPressed: () { searchController.clear(); setState(() => orderQuery = ''); },
              icon: const Icon(Icons.close, color: muted),
            ) : null,
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Column(children: [
            const Icon(Icons.receipt_long_outlined, color: muted, size: 35),
            const SizedBox(height: 10),
            Text(orders.isEmpty ? 'No orders yet' : 'No matching orders',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(orders.isEmpty ? 'New orders will appear here' : 'Try a different search',
              style: const TextStyle(color: muted, fontSize: 12)),
          ]))
        else
          ...filtered.map((order) {
            final id = order['_id']?.toString() ?? '';
            final shortId = id.length > 8 ? id.substring(id.length - 8) : id;
            final customer = order['customer'];
            final customerName = customer is Map ? (customer['name']?.toString() ?? 'Customer') : 'Customer';
            final total = asDouble(order['totalAmount'] ?? order['total'] ?? 0);
            final status = order['status']?.toString() ?? 'Pending';
            final items = order['items'] is List ? order['items'] as List : [];
            final isComplete = status.toLowerCase() == 'completed' || status.toLowerCase() == 'delivered';
            final statusColor = isComplete ? mint : const Color(0xFFFFC66D);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Order #$shortId', overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(color: statusColor.withValues(alpha:.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(status, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 11),
                Row(children: [
                  const Icon(Icons.person_outline_rounded, color: muted, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(customerName, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 13))),
                ]),
                const SizedBox(height: 12),
                const Divider(color: border, height: 1),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('${items.length} product${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: muted, fontSize: 12))),
                  Text(money(total), style: const TextStyle(color: mint, fontSize: 16, fontWeight: FontWeight.w800)),
                ]),
              ]),
            );
          }),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(backgroundColor: bg, body: Center(child: CircularProgressIndicator(color: mint)));
    }
    if (errorMessage != null) {
      return Scaffold(backgroundColor: bg, body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 44, color: muted),
          const SizedBox(height: 12),
          const Text('Unable to load orders', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: loadData, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ]),
      )));
    }

    final revenue = orders.fold<double>(0, (sum, order) => sum + asDouble(order['totalAmount'] ?? order['total'] ?? 0));

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: mint,
        onRefresh: loadData,
        child: LayoutBuilder(builder: (context, constraints) {
          final padding = constraints.maxWidth >= 950 ? 26.0 : 16.0;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 22, padding, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(showCreateForm ? 'Create New Order' : 'Orders',
                      style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(showCreateForm ? 'Select a customer, add items and review your order'
                        : 'Manage orders and track sales',
                      style: const TextStyle(color: muted, fontSize: 13)),
                  ],
                )),
                IconButton(onPressed: loadData, tooltip: 'Refresh orders',
                  icon: const Icon(Icons.refresh_rounded, color: mint)),
              ]),
              const SizedBox(height: 20),
              if (showCreateForm) ...[
                TextButton.icon(
                  onPressed: submitting ? null : () => setState(() => showCreateForm = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Order History'),
                  style: TextButton.styleFrom(foregroundColor: mint),
                ),
                const SizedBox(height: 12),
                Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: createOrderSection(),
                )),
              ] else ...[
                LayoutBuilder(builder: (context, size) {
                  final cardWidth = (size.maxWidth - 12) / 2;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(width: cardWidth, child: statCard('Total orders',
                      '${orders.length}', Icons.receipt_long_outlined, mint)),
                    SizedBox(width: cardWidth, child: statCard('Total sales',
                      money(revenue), Icons.trending_up_rounded, const Color(0xFF9AABFF))),
                  ]);
                }),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => showCreateForm = true),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Create New Order',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                orderHistorySection(),
              ],
            ]),
          );
        }),
      ),
    );
  }
}
