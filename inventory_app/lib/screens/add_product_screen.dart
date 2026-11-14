
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AddProductScreen extends StatefulWidget {
  final String token;

  const AddProductScreen({
    super.key,
    required this.token,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _sku = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  final _threshold = TextEditingController(text: '5');

  bool _saving = false;

  static const bg = Color(0xFFF6F7FC);
  static const primary = Color(0xFF4F46E5);
  static const ink = Color(0xFF171B35);
  static const muted = Color(0xFF777F96);
  static const border = Color(0xFFE8EAF3);

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _category.dispose();
    _price.dispose();
    _stock.dispose();
    _threshold.dispose();
    super.dispose();
  }

  void _message(String text, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: success
            ? const Color(0xFF059669)
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:5000/api/products'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.token}',
            },
            body: jsonEncode({
              'name': _name.text.trim(),
              'sku': _sku.text.trim(),
              'category': _category.text.trim(),
              'price': double.parse(_price.text.trim()),
              'stock': int.parse(_stock.text.trim()),
              'lowStockThreshold':
                  int.parse(_threshold.text.trim()),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        _message('Product added successfully!', success: true);
        Navigator.of(context).pop(true);
        return;
      }

      String message = 'Unable to save product';

      try {
        final data = jsonDecode(response.body);
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }
      } catch (_) {}

      if (response.statusCode == 403) {
        message = 'You do not have permission to add products';
      }

      _message(message);
    } catch (_) {
      _message('Connection failed. Check your backend server.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateText(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateNumber(
    String? value,
    String label, {
    bool integer = false,
  }) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) return '$label is required';

    if (integer) {
      final number = int.tryParse(text);
      if (number == null || number < 0) {
        return 'Enter a valid whole number';
      }
    } else {
      final number = double.tryParse(text);
      if (number == null ||
          !number.isFinite ||
          number < 0) {
        return 'Enter a valid non-negative amount';
      }
    }

    return null;
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    bool numeric = false,
    bool integer = false,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      enabled: !_saving,
      keyboardType: numeric
          ? TextInputType.numberWithOptions(
              decimal: !integer,
            )
          : TextInputType.text,
      style: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        prefixIcon: Icon(icon, color: primary, size: 20),
        filled: true,
        fillColor: const Color(0xFFFAFAFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: primary,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(
    String title,
    String subtitle,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEDFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primary, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0924265C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        title: const Text(
          'Add New Product',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 700;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: desktop ? 28 : 16,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create a product',
                        style: TextStyle(
                          color: ink,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'Add a new item to your inventory catalog.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _formCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Basic information',
                              'Identify and organize your product',
                              Icons.inventory_2_outlined,
                            ),
                            const SizedBox(height: 22),
                            _field(
                              label: 'Product Name',
                              controller: _name,
                              icon: Icons.shopping_bag_outlined,
                              hint: 'Enter product name',
                              validator: (value) =>
                                  _validateText(value, 'Product name'),
                            ),
                            const SizedBox(height: 16),
                            if (desktop)
                              Row(
                                children: [
                                  Expanded(
                                    child: _field(
                                      label: 'SKU',
                                      controller: _sku,
                                      icon: Icons.qr_code_rounded,
                                      hint: 'STK-001',
                                      validator: (value) =>
                                          _validateText(value, 'SKU'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _field(
                                      label: 'Category',
                                      controller: _category,
                                      icon: Icons.category_outlined,
                                      hint: 'Electronics',
                                      validator: (value) =>
                                          _validateText(value, 'Category'),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _field(
                                label: 'SKU',
                                controller: _sku,
                                icon: Icons.qr_code_rounded,
                                validator: (value) =>
                                    _validateText(value, 'SKU'),
                              ),
                              const SizedBox(height: 16),
                              _field(
                                label: 'Category',
                                controller: _category,
                                icon: Icons.category_outlined,
                                validator: (value) =>
                                    _validateText(value, 'Category'),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      _formCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _sectionTitle(
                              'Pricing & inventory',
                              'Configure price and initial stock',
                              Icons.warehouse_outlined,
                            ),
                            const SizedBox(height: 22),
                            _field(
                              label: 'Unit Price (₹)',
                              controller: _price,
                              icon: Icons.currency_rupee_rounded,
                              numeric: true,
                              validator: (value) =>
                                  _validateNumber(value, 'Price'),
                            ),
                            const SizedBox(height: 16),
                            if (desktop)
                              Row(
                                children: [
                                  Expanded(
                                    child: _field(
                                      label: 'Initial Stock',
                                      controller: _stock,
                                      icon: Icons.inventory_outlined,
                                      numeric: true,
                                      integer: true,
                                      validator: (value) =>
                                          _validateNumber(
                                        value,
                                        'Initial stock',
                                        integer: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _field(
                                      label: 'Low Stock Threshold',
                                      controller: _threshold,
                                      icon: Icons.warning_amber_rounded,
                                      numeric: true,
                                      integer: true,
                                      validator: (value) =>
                                          _validateNumber(
                                        value,
                                        'Threshold',
                                        integer: true,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            else ...[
                              _field(
                                label: 'Initial Stock',
                                controller: _stock,
                                icon: Icons.inventory_outlined,
                                numeric: true,
                                integer: true,
                                validator: (value) =>
                                    _validateNumber(
                                  value,
                                  'Initial stock',
                                  integer: true,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _field(
                                label: 'Low Stock Threshold',
                                controller: _threshold,
                                icon: Icons.warning_amber_rounded,
                                numeric: true,
                                integer: true,
                                validator: (value) =>
                                    _validateNumber(
                                  value,
                                  'Threshold',
                                  integer: true,
                                ),
                              ),
                            ],
                            const SizedBox(height: 15),
                            Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: primary,
                                    size: 19,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Future stock changes can be managed through the Inventory module.',
                                      style: TextStyle(
                                        color: ink,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ink,
                              minimumSize: const Size(130, 50),
                              side: const BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _saveProduct,
                            icon: _saving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _saving ? 'Saving...' : 'Save Product',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(175, 50),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
