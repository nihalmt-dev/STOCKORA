
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
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final skuController = TextEditingController();
  final categoryController = TextEditingController();
  final priceController = TextEditingController();
  final stockController = TextEditingController();
  final thresholdController = TextEditingController();

  bool isSaving = false;

  static const bg = Color(0xFF0B1120);
  static const mint = Color(0xFF5EEAC4);

  @override
  void dispose() {
    nameController.dispose();
    skuController.dispose();
    categoryController.dispose();
    priceController.dispose();
    stockController.dispose();
    thresholdController.dispose();
    super.dispose();
  }

  Future<void> saveProduct() async {
    if (!formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/products'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: jsonEncode({
          'name': nameController.text.trim(),
          'sku': skuController.text.trim(),
          'category': categoryController.text.trim(),
          'price': double.parse(priceController.text),
          'stock': int.parse(stockController.text),
          'lowStockThreshold':
              int.parse(thresholdController.text),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product added successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        String message = 'Failed to add product';

        try {
          final data = jsonDecode(response.body);
          message = data['message']?.toString() ?? message;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection error: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Widget inputField(
    String label,
    TextEditingController controller, {
    bool numeric = false,
    bool integer = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: numeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white60),
          filled: true,
          fillColor: const Color(0xFF172235),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Colors.white24,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: mint),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Add New Product'),
        backgroundColor: bg,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Product Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),

                  inputField('Product Name', nameController),
                  inputField('SKU', skuController),
                  inputField('Category', categoryController),
                  inputField(
                    'Price',
                    priceController,
                    numeric: true,
                  ),
                  inputField(
                    'Initial Stock',
                    stockController,
                    numeric: true,
                    integer: true,
                  ),
                  inputField(
                    'Low Stock Threshold',
                    thresholdController,
                    numeric: true,
                    integer: true,
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton(
                    onPressed: isSaving ? null : saveProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(
                        vertical: 18,
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Save Product',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
