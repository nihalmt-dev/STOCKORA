
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:inventory_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'add_product_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProductsScreen extends StatefulWidget {
  final String token;
  final bool initialLowStockOnly;

  const ProductsScreen({
    super.key,
    required this.token,
    this.initialLowStockOnly = false,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const Color bg = Color(0xFFF6F7FC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color mint = Color(0xFF4F46E5);

  String role = 'staff';
  bool get canEdit => role == 'admin' || role == 'manager';
  bool get canDelete => role == 'admin';

  Future<void> loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => role = prefs.getString('user_role') ?? 'staff');
  }

  List<dynamic> products = [];
  bool isLoading = true;
  String? errorMessage;
  String? busyProductId;
  String searchQuery = '';
  bool showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    showLowStockOnly = widget.initialLowStockOnly;
    loadRole();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/products'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch products');
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        products = data is List
            ? data
            : (data['products'] as List? ?? []);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
        isLoading = false;
      });
    }
  }

  void showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  String responseMessage(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}

    return 'Request failed (${response.statusCode})';
  }

  Future<void> openAddProduct() async {
    if (!canEdit) return;
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(
          token: widget.token,
        ),
      ),
    );

    if (added == true && mounted) {
      fetchProducts();
    }
  }

  Future<void> editProduct(
    Map<String, dynamic> product,
  ) async {
    if (!canEdit) return;
    final id = product['_id']?.toString();

    if (id == null || id.isEmpty) {
      showMessage('Product ID missing');
      return;
    }

    final nameController = TextEditingController(
      text: product['name']?.toString() ?? '',
    );

    final skuController = TextEditingController(
      text: product['sku']?.toString() ?? '',
    );

    final categoryController = TextEditingController(
      text: product['category']?.toString() ?? '',
    );

    final priceController = TextEditingController(
      text: product['price']?.toString() ?? '',
    );

    final thresholdController = TextEditingController(
      text: product['lowStockThreshold']?.toString() ?? '5',
    );

    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool dialogClosing = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Widget field(
                String label,
                TextEditingController controller, {
                bool numeric = false,
                bool integer = false,
              }) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextFormField(
                    controller: controller,
                    style: const TextStyle(color: Color(0xFF171B35)),
                    keyboardType: numeric
                        ? TextInputType.numberWithOptions(
                            decimal: !integer,
                          )
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText: label,
                      labelStyle:
                          const TextStyle(color: const Color(0xFF777F96)),
                      filled: true,
                      fillColor: bg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';

                      if (text.isEmpty) {
                        return '$label is required';
                      }

                      if (numeric) {
                        final number = num.tryParse(text);

                        if (number == null || number < 0) {
                          return 'Enter a valid non-negative number';
                        }

                        if (integer && int.tryParse(text) == null) {
                          return 'Enter a whole number';
                        }
                      }

                      return null;
                    },
                  ),
                );
              }

              Future<void> saveChanges() async {
                if (!formKey.currentState!.validate()) return;

                setDialogState(() => saving = true);

                try {
                  final response = await http.put(
                    Uri.parse(
                      '${ApiConfig.baseUrl}/api/products/$id',
                    ),
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer ${widget.token}',
                    },
                    body: jsonEncode({
                      'name': nameController.text.trim(),
                      'sku': skuController.text.trim(),
                      'category': categoryController.text.trim(),
                      'price': double.parse(priceController.text),
                      'lowStockThreshold':
                          int.parse(thresholdController.text),
                    }),
                  );

                  if (!mounted || !dialogContext.mounted) return;

                  if (response.statusCode == 200) {
                    dialogClosing = true;
                    Navigator.of(dialogContext).pop();
                    showMessage(
                      'Product updated successfully!',
                      success: true,
                    );
                    await fetchProducts();
                  } else {
                    showMessage(responseMessage(response));
                  }
                } catch (error) {
                  showMessage('Failed to update product: $error');
                } finally {
                  if (!dialogClosing && dialogContext.mounted) {
                    setDialogState(() => saving = false);
                  }
                }
              }

              return AlertDialog(
                backgroundColor: card,
                title: const Text(
                  'Edit Product',
                  style: TextStyle(color: Color(0xFF171B35)),
                ),
                content: SizedBox(
                  width: 450,
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          field('Product Name', nameController),
                          field('SKU', skuController),
                          field('Category', categoryController),
                          field(
                            'Price',
                            priceController,
                            numeric: true,
                          ),
                          field(
                            'Low Stock Threshold',
                            thresholdController,
                            numeric: true,
                            integer: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: saving ? null : saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      saving ? 'Saving...' : 'Save Changes',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      // Allow the dialog exit animation to finish before releasing fields.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      nameController.dispose();
      skuController.dispose();
      categoryController.dispose();
      priceController.dispose();
      thresholdController.dispose();
    }
  }

  Future<void> deleteProduct(
    Map<String, dynamic> product,
  ) async {
    if (!canDelete) return;
    final id = product['_id']?.toString();

    if (id == null || id.isEmpty) {
      showMessage('Product ID missing');
      return;
    }

    final name = product['name']?.toString() ?? 'this product';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: card,
        title: const Text(
          'Delete Product?',
          style: TextStyle(color: Color(0xFF171B35)),
        ),
        content: Text(
          'Are you sure you want to delete "$name"? '
          'This action cannot be undone.',
          style: const TextStyle(color: const Color(0xFF777F96)),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => busyProductId = id);

    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/products/$id'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        showMessage(
          'Product deleted successfully!',
          success: true,
        );
        await fetchProducts();
      } else {
        showMessage(responseMessage(response));
      }
    } catch (error) {
      showMessage('Failed to delete product: $error');
    } finally {
      if (mounted) {
        setState(() => busyProductId = null);
      }
    }
  }

  Widget productCard(Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? 'Unnamed Product';
    final sku = product['sku']?.toString() ?? '-';
    final category = product['category']?.toString() ?? '-';
    final price = num.tryParse(product['price']?.toString() ?? '') ?? 0;
    final stock = int.tryParse(product['stock']?.toString() ?? '') ?? 0;
    final threshold = int.tryParse(
          product['lowStockThreshold']?.toString() ?? '',
        ) ?? 5;
    final low = stock <= threshold;
    final busy = busyProductId == product['_id']?.toString();
    final accent = low ? const Color(0xFFD97706) : mint;

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAF3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: mint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.inventory_2_outlined,
                      color: mint, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF171B35),
                              fontSize: 16,
                              height: 1.3,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text('SKU  $sku',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF777F96), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(low ? 'Low stock' : 'In stock',
                      style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('UNIT PRICE',
                          style: TextStyle(
                              color: Color(0xFF777F96),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1)),
                      const SizedBox(height: 6),
                      Text('₹${price.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF171B35),
                              fontSize: 21,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('AVAILABLE',
                        style: TextStyle(
                            color: Color(0xFF777F96),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1)),
                    const SizedBox(height: 6),
                    Text('$stock units',
                        style: TextStyle(
                            color: accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),

const SizedBox(height: 14),
Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 8,
  ),
  decoration: BoxDecoration(
    color: const Color(0xFFF6F7FC),
    borderRadius: BorderRadius.circular(9),
  ),
  child: Row(
    children: [
      const Icon(
        Icons.category_outlined,
        size: 15,
        color: Color(0xFF777F96),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(
          category,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF555F77),
            fontSize: 12,
          ),
        ),
      ),
    ],
  ),
),
const SizedBox(height: 14),
const Divider(
  height: 1,
  color: Color(0xFFE8EAF3),
),
if (canEdit) const SizedBox(height: 12),
if (canEdit) Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: busy ? null : () => editProduct(product),
        icon: const Icon(Icons.edit_outlined, size: 17),
        label: const Text('Edit product'),
        style: OutlinedButton.styleFrom(
          foregroundColor: mint,
          side: const BorderSide(color: Color(0xFFC7C4FF)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
      ),
    ),

                if (canDelete) const SizedBox(width: 10),
                if (canDelete) OutlinedButton.icon(
                  onPressed: busy ? null : () => deleteProduct(product),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((product) {
      final item = Map<String, dynamic>.from(product);
      final q = searchQuery.toLowerCase();
      final stock = int.tryParse(item['stock']?.toString() ?? '') ?? 0;
      final threshold = int.tryParse(
            item['lowStockThreshold']?.toString() ?? '') ?? 5;
      final matchesSearch =
          (item['name']?.toString() ?? '').toLowerCase().contains(q) ||
          (item['sku']?.toString() ?? '').toLowerCase().contains(q) ||
          (item['category']?.toString() ?? '').toLowerCase().contains(q);
      return matchesSearch && (!showLowStockOnly || stock <= threshold);
    }).toList();
    final lowCount = products.where((product) {
      final item = Map<String, dynamic>.from(product);
      final stock = int.tryParse(item['stock']?.toString() ?? '') ?? 0;
      final threshold = int.tryParse(
              item['lowStockThreshold']?.toString() ?? '') ?? 5;
      return stock <= threshold;
    }).length;

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        color: mint,
        onRefresh: fetchProducts,
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: mint))
            : errorMessage != null
                ? ListView(children: [
                    const SizedBox(height: 110),
                    const Center(
                        child: Text('Unable to load products',
                            style: TextStyle(color: Color(0xFF171B35)))),
                    const SizedBox(height: 12),
                    Center(
                        child: TextButton(
                            onPressed: fetchProducts,
                            child: const Text('Retry'))),
                  ])
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final desktop = constraints.maxWidth >= 700;
                      final horizontal = desktop ? 28.0 : 18.0;
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                            horizontal, 20, horizontal, 36),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Product catalog',
                                        style: TextStyle(
                                            color: Color(0xFF171B35),
                                            fontSize: 25,
                                            fontWeight: FontWeight.w800)),
                                    SizedBox(height: 6),
                                    Text('Manage your inventory catalog and stock visibility',
                                        style: TextStyle(
                                            color: Color(0xFF777F96),
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                tooltip: 'Refresh products',
                                onPressed: fetchProducts,
                                icon: const Icon(Icons.refresh_rounded,
                                    color: mint),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(children: [
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () => setState(() => showLowStockOnly = false),
                                child: _summaryChip(
                                    Icons.inventory_2_outlined,
                                    '${products.length}',
                                    'Products', mint,
                                    selected: !showLowStockOnly),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(15),
                                onTap: () => setState(() => showLowStockOnly = true),
                                child: _summaryChip(
                                    Icons.warning_amber_rounded,
                                    '$lowCount',
                                    'Low stock',
                                    const Color(0xFFD97706),
                                    selected: showLowStockOnly),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 18),
                          if (canEdit) SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: openAddProduct,
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text('Add new product',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: mint,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(0, 50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextField(
                            onChanged: (value) =>
                                setState(() => searchQuery = value),
                            style: const TextStyle(color: Color(0xFF171B35)),
                            decoration: InputDecoration(
                              hintText: 'Search by name, SKU or category',
                              hintStyle: const TextStyle(
                                  color: Color(0xFF777F96), fontSize: 13),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: Color(0xFF777F96)),
                              filled: true,
                              fillColor: card,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE8EAF3)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(13),
                                borderSide: const BorderSide(color: mint),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (showLowStockOnly) ...[
                            Row(children: [
                              const Expanded(
                                child: Text('Showing low-stock products',
                                    style: TextStyle(
                                        color: Color(0xFFD97706),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700)),
                              ),
                              TextButton(
                                onPressed: () => setState(() => showLowStockOnly = false),
                                child: const Text('Show All',
                                    style: TextStyle(color: mint)),
                              ),
                            ]),
                            const SizedBox(height: 8),
                          ],
                          Row(children: [
                            const Expanded(
                              child: Text('Product catalog',
                                  style: TextStyle(
                                      color: Color(0xFF171B35),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700)),
                            ),
                            Text('${filtered.length} items',
                                style: const TextStyle(
                                    color: Color(0xFF777F96), fontSize: 12)),
                          ]),
                          const SizedBox(height: 14),
                          if (filtered.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 45, horizontal: 20),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(children: [
                                const Icon(Icons.search_off_rounded,
                                    color: Color(0xFF777F96), size: 36),
                                const SizedBox(height: 12),
                                Text(products.isEmpty
                                    ? 'No products added yet'
                                    : showLowStockOnly && searchQuery.isEmpty
                                        ? 'No low-stock products'
                                        : 'No matching products',
                                    style: const TextStyle(
                                        color: const Color(0xFF777F96))),
                              ]),
                            )
                          else
                            Wrap(
                              spacing: 14,
                              runSpacing: 14,
                              children: filtered.map((item) {
                                final width = desktop
                                    ? (constraints.maxWidth - horizontal * 2 -
                                            (constraints.maxWidth >= 1100
                                                ? 28
                                                : 14)) /
                                        (constraints.maxWidth >= 1100 ? 3 : 2)
                                    : constraints.maxWidth - horizontal * 2;
                                return SizedBox(
                                  width: width,
                                  child: productCard(
                                      Map<String, dynamic>.from(item)),
                                );
                              }).toList(),
                            ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _summaryChip(
      IconData icon, String value, String label, Color accent,
      {bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? accent : const Color(0xFFE8EAF3),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Color(0xFF171B35),
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF777F96), fontSize: 11)),
            ],
          ),
        ),
      ]),
    );
  }
}
