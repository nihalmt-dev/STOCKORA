
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CustomersScreen extends StatefulWidget {
  final String token;

  const CustomersScreen({
    super.key,
    required this.token,
  });

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const bg = Color(0xFF0B1120);
  static const surface = Color(0xFF172235);
  static const mint = Color(0xFF5EEAC4);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFF29384D);

  List<dynamic> customers = [];
  bool loading = true;
  String? errorMessage;

  final searchController = TextEditingController();
  String searchQuery = '';

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    fetchCustomers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchCustomers() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/customers'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw Exception('Failed to load customers');
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        if (data is List) {
          customers = data;
        } else if (data is Map && data['customers'] is List) {
          customers = data['customers'];
        } else {
          customers = [];
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            success ? const Color(0xFF17856C) : Colors.redAccent,
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: mint),
      ),
    );
  }

  Future<void> showCustomerForm({
    Map<String, dynamic>? customer,
  }) async {
    final editing = customer != null;

    final nameController = TextEditingController(
      text: customer?['name']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: customer?['email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: customer?['phone']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: customer?['address']?.toString() ?? '',
    );

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                editing ? 'Edit Customer' : 'Add Customer',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration:
                              inputDecoration('Customer Name'),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                                  ? 'Enter customer name'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration:
                              inputDecoration('Email Address'),
                          validator: (value) {
                            final email = value?.trim() ?? '';

                            if (email.isEmpty) {
                              return 'Enter email address';
                            }

                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(email)) {
                              return 'Enter a valid email';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration:
                              inputDecoration('Phone Number'),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: addressController,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                          decoration:
                              inputDecoration('Address'),
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
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: muted),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() => saving = true);

                          try {
                            final url = editing
                                ? 'http://localhost:5000/api/customers/${customer['_id']}'
                                : 'http://localhost:5000/api/customers';

                            final response = editing
                                ? await http.put(
                                    Uri.parse(url),
                                    headers: headers,
                                    body: jsonEncode({
                                      'name': nameController.text.trim(),
                                      'email': emailController.text.trim(),
                                      'phone': phoneController.text.trim(),
                                      'address':
                                          addressController.text.trim(),
                                    }),
                                  )
                                : await http.post(
                                    Uri.parse(url),
                                    headers: headers,
                                    body: jsonEncode({
                                      'name': nameController.text.trim(),
                                      'email': emailController.text.trim(),
                                      'phone': phoneController.text.trim(),
                                      'address':
                                          addressController.text.trim(),
                                    }),
                                  );

                            if (!mounted) return;

                            if (response.statusCode == 200 ||
                                response.statusCode == 201) {
                              Navigator.pop(dialogContext);

                              showMessage(
                                editing
                                    ? 'Customer updated successfully'
                                    : 'Customer added successfully',
                                success: true,
                              );

                              fetchCustomers();
                            } else {
                              String message =
                                  'Unable to save customer';

                              try {
                                final data = jsonDecode(response.body);
                                message =
                                    data['message']?.toString() ??
                                        message;
                              } catch (_) {}

                              showMessage(message);
                            }
                          } catch (error) {
                            showMessage('Connection error: $error');
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(
                                () => saving = false,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mint,
                    foregroundColor: bg,
                  ),
                  child: Text(
                    saving
                        ? 'Saving...'
                        : editing
                            ? 'Save Changes'
                            : 'Add Customer',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Controllers are released after the dialog finishes.
    // Avoid disposing here because the closing animation may
    // still reference them.
  }

  Future<void> deleteCustomer(
    Map<String, dynamic> customer,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          title: const Text(
            'Delete Customer?',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to delete ${customer['name']}?',
            style: const TextStyle(color: muted),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse(
          'http://localhost:5000/api/customers/${customer['_id']}',
        ),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200 ||
          response.statusCode == 204) {
        showMessage(
          'Customer deleted successfully',
          success: true,
        );
        fetchCustomers();
      } else {
        String message = 'Unable to delete customer';

        try {
          final data = jsonDecode(response.body);
          message = data['message']?.toString() ?? message;
        } catch (_) {}

        showMessage(message);
      }
    } catch (error) {
      showMessage('Connection error: $error');
    }
  }

  Widget customerCard(Map<String, dynamic> customer) {
    final name = customer['name']?.toString() ?? 'Unknown';
    final email = customer['email']?.toString() ?? '';
    final phone = customer['phone']?.toString() ?? '';
    final address = customer['address']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: mint.withValues(alpha: 0.13),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: mint,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  email,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    phone,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    address,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Customer actions',
            icon: const Icon(
              Icons.more_vert,
              color: muted,
            ),
            color: surface,
            onSelected: (action) {
              if (action == 'edit') {
                showCustomerForm(customer: customer);
              } else if (action == 'delete') {
                deleteCustomer(customer);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: Text(
                  'Edit Customer',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete Customer',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCustomers = customers.where((customer) {
      final query = searchQuery.toLowerCase();

      final name =
          customer['name']?.toString().toLowerCase() ?? '';
      final email =
          customer['email']?.toString().toLowerCase() ?? '';
      final phone =
          customer['phone']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          email.contains(query) ||
          phone.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: fetchCustomers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment:
                    WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  const Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customers Management',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Manage your customers and contact details',
                        style: TextStyle(color: muted),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => showCustomerForm(),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mint,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Customers: ${customers.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: searchController,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() => searchQuery = value);
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Search by name, email or phone...',
                        hintStyle:
                            const TextStyle(color: muted),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: muted,
                        ),
                        filled: true,
                        fillColor: bg,
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: mint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(35),
                    child: CircularProgressIndicator(
                      color: mint,
                    ),
                  ),
                )
              else if (errorMessage != null)
                Center(
                  child: Column(
                    children: [
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: fetchCustomers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (filteredCustomers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(35),
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: muted),
                    ),
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns =
                        constraints.maxWidth >= 900 ? 2 : 1;

                    return GridView.builder(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: 155,
                      ),
                      itemCount: filteredCustomers.length,
                      itemBuilder: (context, index) {
                        return customerCard(
                          Map<String, dynamic>.from(
                            filteredCustomers[index],
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
