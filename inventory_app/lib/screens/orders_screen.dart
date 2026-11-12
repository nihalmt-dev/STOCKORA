
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
  String? errorMessage;

  String? selectedCustomerId;
  String? selectedProductId;
  final quantityController = TextEditingController(text: '1');

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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: mint),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
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

  Widget createOrderSection() {
    return sectionCard(
      title: 'Create New Order',
      icon: Icons.add_shopping_cart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: customers.any(
              (c) => c['_id'].toString() == selectedCustomerId,
            )
                ? selectedCustomerId
                : null,
            isExpanded: true,
            dropdownColor: surface,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Select Customer'),
            items: customers.map((customer) {
              return DropdownMenuItem<String>(
                value: customer['_id'].toString(),
                child: Text(
                  customer['name']?.toString() ?? 'Customer',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: submitting
                ? null
                : (value) {
                    setState(() => selectedCustomerId = value);
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(selectedProductId),
            initialValue: selectedProductId,
            isExpanded: true,
            dropdownColor: surface,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Select Product'),
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
          const SizedBox(height: 16),
          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: inputDecoration('Quantity'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: submitting ? null : addToCart,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Product to Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: mint,
                side: const BorderSide(color: mint),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ORDER ITEMS',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (cart.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Text(
                'No products added yet',
                style: TextStyle(color: muted),
              ),
            )
          else
            ...cart.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

              final subtotal =
                  asDouble(item['price']) *
                      asInt(item['quantity']);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item['name'].toString(),
                  style: const TextStyle(
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  '${item['quantity']} × ₹${item['price']}',
                  style: const TextStyle(color: muted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '₹${subtotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: mint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: submitting
                          ? null
                          : () {
                              setState(() {
                                cart.removeAt(index);
                              });
                            },
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
              );
            }),
          const Divider(color: border),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '₹${cartTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: mint,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : createOrder,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                submitting ? 'Creating...' : 'Create Order',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: mint,
                foregroundColor: bg,
                padding: const EdgeInsets.symmetric(
                  vertical: 17,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget orderHistorySection() {
    return sectionCard(
      title: 'Order History',
      icon: Icons.receipt_long_outlined,
      child: orders.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No orders found',
                style: TextStyle(color: muted),
              ),
            )
          : Column(
              children: orders.map((order) {
                final id =
                    order['_id']?.toString() ?? '';
                final shortId = id.length > 8
                    ? id.substring(id.length - 8)
                    : id;

                final customer = order['customer'];
                String customerName = 'Customer';

                if (customer is Map) {
                  customerName =
                      customer['name']?.toString() ??
                          'Customer';
                }

                final total = asDouble(
                  order['totalAmount'] ??
                      order['total'] ??
                      0,
                );

                final status =
                    order['status']?.toString() ??
                        'Pending';

                final items =
                    (order['items'] as List?) ?? [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Order #$shortId',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: mint,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        customerName,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${items.length} product(s) • $status',
                        style: const TextStyle(
                          color: muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
                'Unable to load orders',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: loadData,
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
        onRefresh: loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 950;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Orders Management',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create orders and track sales',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 24),
                  if (wide)
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: createOrderSection(),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: orderHistorySection(),
                        ),
                      ],
                    )
                  else ...[
                    createOrderSection(),
                    const SizedBox(height: 18),
                    orderHistorySection(),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
