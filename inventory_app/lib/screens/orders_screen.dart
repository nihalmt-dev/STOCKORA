import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OrdersScreen extends StatefulWidget {
  final String token;
  const OrdersScreen({super.key, required this.token});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const bg = Color(0xFFF6F7FC);
  static const surface = Colors.white;
  static const primary = Color(0xFF4F46E5);
  static const ink = Color(0xFF1D2440);
  static const muted = Color(0xFF788198);
  static const border = Color(0xFFE7EAF3);
  static const green = Color(0xFF059669);
  static const amber = Color(0xFFD97706);

  List<dynamic> orders = [];
  List<dynamic> products = [];
  List<dynamic> customers = [];
  final List<Map<String, dynamic>> cart = [];
  final quantityController = TextEditingController(text: '1');
  final searchController = TextEditingController();
  String? selectedCustomerId;
  String? selectedProductId;
  String orderQuery = '';
  String role = 'staff';
  bool loading = true;
  bool submitting = false;
  bool showCreateForm = false;
  String? errorMessage;

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  bool get canSeeSales => role == 'admin' || role == 'manager';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => role = (prefs.getString('user_role') ?? 'staff').toLowerCase());
    await loadData();
  }

  @override
  void dispose() {
    quantityController.dispose();
    searchController.dispose();
    super.dispose();
  }

  List<dynamic> extractList(dynamic data, String key) {
    if (data is List) return data;
    if (data is Map && data[key] is List) return data[key] as List;
    return [];
  }

  double asDouble(dynamic value) => double.tryParse(value.toString()) ?? 0;
  int asInt(dynamic value) => int.tryParse(value.toString()) ?? 0;
  String money(dynamic value) => '₹${asDouble(value).toStringAsFixed(2)}';
  double get cartTotal => cart.fold<double>(
      0, (sum, item) => sum + asDouble(item['price']) * asInt(item['quantity']));

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('http://localhost:5000/api/orders'), headers: headers),
        http.get(Uri.parse('http://localhost:5000/api/products'), headers: headers),
        http.get(Uri.parse('http://localhost:5000/api/customers'), headers: headers),
      ]).timeout(const Duration(seconds: 15));
      for (final response in responses) {
        if (response.statusCode != 200) {
          throw Exception('API error (${response.statusCode}). Please sign in again if your session expired.');
        }
      }
      if (!mounted) return;
      setState(() {
        orders = extractList(jsonDecode(responses[0].body), 'orders');
        products = extractList(jsonDecode(responses[1].body), 'products');
        customers = extractList(jsonDecode(responses[2].body), 'customers');
        if (!customers.any((c) => c['_id'].toString() == selectedCustomerId)) {
          selectedCustomerId = null;
        }
        if (!products.any((p) => p['_id'].toString() == selectedProductId)) {
          selectedProductId = null;
        }
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
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

  void addToCart() {
    if (selectedProductId == null) {
      showMessage('Select a product first');
      return;
    }
    final quantity = int.tryParse(quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      showMessage('Enter a quantity greater than zero');
      return;
    }
    final matches = products.where((p) => p['_id'].toString() == selectedProductId);
    if (matches.isEmpty) {
      showMessage('Product not found. Refresh the page.');
      return;
    }
    final product = matches.first;
    final existingIndex = cart.indexWhere((item) => item['productId'] == selectedProductId);
    final existingQuantity = existingIndex < 0 ? 0 : asInt(cart[existingIndex]['quantity']);
    final available = asInt(product['stock']);
    if (quantity + existingQuantity > available) {
      showMessage('Insufficient stock. Available: $available');
      return;
    }
    setState(() {
      if (existingIndex >= 0) {
        cart[existingIndex]['quantity'] = existingQuantity + quantity;
      } else {
        cart.add({
          'productId': selectedProductId,
          'name': product['name']?.toString() ?? 'Product',
          'price': asDouble(product['price']),
          'quantity': quantity,
        });
      }
      selectedProductId = null;
      quantityController.text = '1';
    });
    showMessage('Product added to cart', success: true);
  }

  Future<void> createOrder() async {
    if (submitting) return;
    if (selectedCustomerId == null) {
      showMessage('Select a customer');
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
          'items': cart.map((item) => {
                'productId': item['productId'],
                'quantity': item['quantity'],
              }).toList(),
        }),
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          cart.clear();
          selectedCustomerId = null;
          selectedProductId = null;
          showCreateForm = false;
          quantityController.text = '1';
        });
        showMessage('Order placed successfully', success: true);
        await loadData();
      } else {
        String message = 'Unable to create order';
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['message'] != null) message = data['message'].toString();
        } catch (_) {}
        showMessage(message);
      }
    } catch (_) {
      showMessage('Connection error. Check your backend server.');
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  InputDecoration fieldDecoration(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: muted),
        prefixIcon: icon == null ? null : Icon(icon, color: primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFFAFAFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget panel({required String title, required String subtitle, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x08242B58), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: const Color(0xFFEEEDFF), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: primary, size: 21),
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

  Widget statCard(String title, String value, IconData icon, Color accent) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: surface, border: Border.all(color: border), borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(height: 15),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800))),
          const SizedBox(height: 5),
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
        ]),
      );

  Widget stepLabel(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(value, style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
      );

  Widget createOrderSection() {
    return panel(
      title: 'Create a new order',
      subtitle: 'Choose a customer, add items, then confirm',
      icon: Icons.add_shopping_cart_rounded,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        stepLabel('STEP 1 · SELECT CUSTOMER'),
        DropdownButtonFormField<String>(
          key: ValueKey('customer-$selectedCustomerId'),
          initialValue: customers.any((c) => c['_id'].toString() == selectedCustomerId) ? selectedCustomerId : null,
          isExpanded: true,
          style: const TextStyle(color: ink),
          dropdownColor: surface,
          decoration: fieldDecoration('Customer', icon: Icons.person_outline_rounded),
          items: customers.map((c) => DropdownMenuItem<String>(
            value: c['_id'].toString(),
            child: Text(c['name']?.toString() ?? 'Customer', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: submitting ? null : (value) => setState(() => selectedCustomerId = value),
        ),
        const SizedBox(height: 23),
        stepLabel('STEP 2 · ADD PRODUCTS'),
        DropdownButtonFormField<String>(
          key: ValueKey('product-$selectedProductId'),
          initialValue: products.any((p) => p['_id'].toString() == selectedProductId) ? selectedProductId : null,
          isExpanded: true,
          style: const TextStyle(color: ink),
          dropdownColor: surface,
          decoration: fieldDecoration('Product', icon: Icons.inventory_2_outlined),
          items: products.map((p) => DropdownMenuItem<String>(
            value: p['_id'].toString(),
            child: Text('${p['name']} · ${p['stock']} in stock', overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: submitting ? null : (value) => setState(() => selectedProductId = value),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextField(
            controller: quantityController,
           style: const TextStyle(color: Color(0xFF17233D), fontSize: 14),
           cursorColor: Color(0xFF4F46E5),
            enabled: !submitting,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: fieldDecoration('Quantity', icon: Icons.numbers_rounded),
          )),
          const SizedBox(width: 10),
          SizedBox(height: 54, child: ElevatedButton.icon(
            onPressed: submitting ? null : addToCart,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          )),
        ]),
        const SizedBox(height: 24),
        stepLabel('STEP 3 · REVIEW ORDER'),
        if (cart.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 14),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
            child: const Column(children: [
              Icon(Icons.shopping_bag_outlined, color: muted, size: 32),
              SizedBox(height: 9),
              Text('Your cart is empty', style: TextStyle(color: ink, fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text('Select a product to get started', style: TextStyle(color: muted, fontSize: 12)),
            ]),
          )
        else
          ...cart.asMap().entries.map((entry) {
            final item = entry.value;
            final subtotal = asDouble(item['price']) * asInt(item['quantity']);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13), border: Border.all(color: border)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFEEEDFF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.inventory_2_outlined, color: primary, size: 19)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${item['name']}', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text('${item['quantity']} × ${money(item['price'])}',
                    style: const TextStyle(color: muted, fontSize: 12)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(subtotal), style: const TextStyle(color: primary, fontWeight: FontWeight.w800)),
                  IconButton(
                    tooltip: 'Remove product',
                    onPressed: submitting ? null : () => setState(() => cart.removeAt(entry.key)),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFDC2626), size: 19),
                  ),
                ]),
              ]),
            );
          }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(color: const Color(0xFFF0F0FF), borderRadius: BorderRadius.circular(13)),
          child: Row(children: [
            const Expanded(child: Text('Order total', style: TextStyle(color: ink, fontWeight: FontWeight.w700))),
            Flexible(child: Text(money(cartTotal), textAlign: TextAlign.end,
              style: const TextStyle(color: primary, fontSize: 21, fontWeight: FontWeight.w900))),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: submitting ? null : createOrder,
          icon: submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(submitting ? 'Placing order...' : 'Confirm & Place Order'),
          style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 17),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
        )),
        const SizedBox(height: 8),
        const Text('Stock will be updated automatically by the backend after the order is confirmed.',
          style: TextStyle(color: muted, fontSize: 11)),
      ]),
    );
  }

  Widget orderHistorySection() {
    final query = orderQuery.trim().toLowerCase();
    final filtered = orders.where((order) {
      final customer = order['customer'];
      final name = customer is Map ? (customer['name']?.toString() ?? '') : '';
      return query.isEmpty ||
          (order['_id']?.toString() ?? '').toLowerCase().contains(query) ||
          name.toLowerCase().contains(query) ||
          (order['status']?.toString() ?? '').toLowerCase().contains(query);
    }).toList();
    return panel(
      title: 'Order history',
      subtitle: 'View and search your orders',
      icon: Icons.receipt_long_outlined,
      child: Column(children: [
        TextField(
          controller: searchController,
           style: const TextStyle(color: Color(0xFF17233D), fontSize: 14),
           cursorColor: Color(0xFF4F46E5),
          onChanged: (value) => setState(() => orderQuery = value),
          decoration: fieldDecoration('Search customer, order ID or status', icon: Icons.search_rounded).copyWith(
            suffixIcon: orderQuery.isEmpty ? null : IconButton(
              onPressed: () { searchController.clear(); setState(() => orderQuery = ''); },
              icon: const Icon(Icons.close_rounded, color: muted),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (filtered.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 28), child: Column(children: [
            const Icon(Icons.receipt_long_outlined, color: muted, size: 36),
            const SizedBox(height: 10),
            Text(orders.isEmpty ? 'No orders yet' : 'No matching orders',
              style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text(orders.isEmpty ? 'Your orders will appear here' : 'Try another search term',
              style: const TextStyle(color: muted, fontSize: 12)),
          ]))
        else
          ...filtered.map((order) {
            final id = order['_id']?.toString() ?? '';
            final shortId = id.length > 8 ? id.substring(id.length - 8) : id;
            final customer = order['customer'];
            final customerName = customer is Map ? (customer['name']?.toString() ?? 'Customer') : 'Customer';
            final status = order['status']?.toString() ?? 'Pending';
            final isComplete = status.toLowerCase() == 'completed' || status.toLowerCase() == 'delivered';
            final accent = isComplete ? green : amber;
            final items = order['items'] is List ? order['items'] as List : [];
            return Container(
              margin: const EdgeInsets.only(bottom: 11),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Order #$shortId', overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ink, fontWeight: FontWeight.w800))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
                    child: Text(status, style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 11),
                Row(children: [
                  const Icon(Icons.person_outline_rounded, color: muted, size: 17),
                  const SizedBox(width: 7),
                  Expanded(child: Text(customerName, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted, fontSize: 13))),
                ]),
                const SizedBox(height: 13),
                const Divider(color: border, height: 1),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('${items.length} product${items.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: muted, fontSize: 12))),
                  if (canSeeSales)
                    Text(money(order['totalAmount'] ?? order['total'] ?? 0),
                      style: const TextStyle(color: primary, fontWeight: FontWeight.w800, fontSize: 15)),
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
      return const Scaffold(backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: primary)));
    }
    if (errorMessage != null) {
      return Scaffold(backgroundColor: bg, body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, color: muted, size: 43),
          const SizedBox(height: 12),
          const Text('Unable to load orders', style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 15),
          ElevatedButton.icon(onPressed: loadData, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ]),
      )));
    }
    final revenue = orders.fold<double>(0, (sum, order) =>
        sum + asDouble(order['totalAmount'] ?? order['total'] ?? 0));
    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: primary,
        onRefresh: loadData,
        child: LayoutBuilder(builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final padding = compact ? 16.0 : 26.0;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(padding, 18, padding, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(showCreateForm ? 'Create New Order' : 'Orders',
                    style: TextStyle(color: ink, fontSize: compact ? 24 : 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(showCreateForm ? 'Select a customer, add products and confirm' : 'Manage orders and track activity',
                    style: const TextStyle(color: muted, fontSize: 12)),
                ])),
                IconButton(onPressed: submitting ? null : loadData, tooltip: 'Refresh orders',
                  icon: const Icon(Icons.refresh_rounded, color: primary)),
              ]),
              const SizedBox(height: 22),
              if (showCreateForm) ...[
                TextButton.icon(
                  onPressed: submitting ? null : () => setState(() => showCreateForm = false),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Back to Order History'),
                  style: TextButton.styleFrom(foregroundColor: primary),
                ),
                const SizedBox(height: 12),
                Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: createOrderSection(),
                )),
              ] else ...[
                LayoutBuilder(builder: (context, size) {
                  final count = canSeeSales ? 2 : 1;
                  final width = (size.maxWidth - (count - 1) * 12) / count;
                  return Wrap(spacing: 12, runSpacing: 12, children: [
                    SizedBox(width: width, child: statCard('Total orders', '${orders.length}',
                      Icons.receipt_long_outlined, primary)),
                    if (canSeeSales)
                      SizedBox(width: width, child: statCard('Total sales', money(revenue),
                        Icons.trending_up_rounded, green)),
                  ]);
                }),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () => setState(() => showCreateForm = true),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create New Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                )),
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
