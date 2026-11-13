
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
                      'address': addressController.text.trim(),
                    }),
                  )
                : await http.post(
                    Uri.parse(url),
                    headers: headers,
                    body: jsonEncode({
                      'name': nameController.text.trim(),
                      'email': emailController.text.trim(),
                      'phone': phoneController.text.trim(),
                      'address': addressController.text.trim(),
                    }),
                  );

            if (!mounted || !dialogContext.mounted) return;

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
              String message = 'Unable to save customer';

              try {
                final data = jsonDecode(response.body);
                message =
                    data['message']?.toString() ?? message;
              } catch (_) {}

              showMessage(message);
            }
          } catch (error) {
            if (mounted) {
              showMessage('Connection error: $error');
            }
          } finally {
            if (dialogContext.mounted) {
              setDialogState(() => saving = false);
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
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: mint.withValues(alpha: .13),
            child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(color: mint, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('CUSTOMER', style: TextStyle(color: mint, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ])),
          PopupMenuButton<String>(
            tooltip: 'Customer actions',
            icon: const Icon(Icons.more_horiz_rounded, color: muted),
            color: surface,
            onSelected: (action) {
              if (action == 'edit') showCustomerForm(customer: customer);
              if (action == 'delete') deleteCustomer(customer);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit Customer', style: TextStyle(color: Colors.white))),
              PopupMenuItem(value: 'delete', child: Text('Delete Customer', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(color: border, height: 1),
        const SizedBox(height: 13),
        _detailRow(Icons.mail_outline_rounded, email.isEmpty ? 'No email' : email),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          _detailRow(Icons.phone_outlined, phone),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 10),
          _detailRow(Icons.location_on_outlined, address),
        ],
      ]),
    );
  }

  Widget _detailRow(IconData icon, String value) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 17, color: muted),
      const SizedBox(width: 10),
      Expanded(child: Text(value, softWrap: true,
        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5, height: 1.4))),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final filteredCustomers = customers.where((customer) {
      final name = customer['name']?.toString().toLowerCase() ?? '';
      final email = customer['email']?.toString().toLowerCase() ?? '';
      final phone = customer['phone']?.toString().toLowerCase() ?? '';
      return name.contains(query) || email.contains(query) || phone.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 700 ? 2 : 1;
        return RefreshIndicator(
          color: mint,
          onRefresh: fetchCustomers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 20, compact ? 16 : 24, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16, runSpacing: 16, children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Customer Management', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Keep your customer relationships organized', style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                  ElevatedButton.icon(
                    onPressed: () => showCustomerForm(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                    label: const Text('Add Customer'),
                    style: ElevatedButton.styleFrom(backgroundColor: mint, foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ]),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A3C42), surface]),
                  borderRadius: BorderRadius.circular(19), border: Border.all(color: border)),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: mint.withValues(alpha: .13), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.groups_2_outlined, color: mint, size: 26)),
                  const SizedBox(width: 15),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${customers.length}', style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800)),
                    const Text('Total Customers', style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone',
                    hintStyle: const TextStyle(color: muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: mint),
                    suffixIcon: searchQuery.isEmpty ? null : IconButton(
                      onPressed: () { searchController.clear(); setState(() => searchQuery = ''); },
                      icon: const Icon(Icons.close_rounded, color: muted)),
                    filled: true, fillColor: bg,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: mint)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(child: Text('Customer Directory', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                if (!loading && errorMessage == null)
                  Text('${filteredCustomers.length} shown', style: const TextStyle(color: muted, fontSize: 12)),
              ]),
              const SizedBox(height: 14),
              if (loading)
                const Center(child: Padding(padding: EdgeInsets.all(38), child: CircularProgressIndicator(color: mint)))
              else if (errorMessage != null)
                Center(child: Column(children: [
                  Text(errorMessage!, style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: fetchCustomers, child: const Text('Retry')),
                ]))
              else if (filteredCustomers.isEmpty)
                Container(width: double.infinity, padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: border)),
                  child: Column(children: [
                    const Icon(Icons.person_search_rounded, color: muted, size: 40),
                    const SizedBox(height: 12),
                    Text(customers.isEmpty ? 'No customers yet' : 'No matching customers',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(customers.isEmpty ? 'Add your first customer to get started' : 'Try another search term',
                      textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
                  ]))
              else
                // Wrap lets cards grow naturally for long names, emails and addresses.
                Wrap(spacing: 14, runSpacing: 14,
                  children: filteredCustomers.map((item) {
                    final cardWidth = (constraints.maxWidth - (compact ? 32 : 48) - 14 * (columns - 1)) / columns;
                    return SizedBox(width: cardWidth,
                      child: customerCard(Map<String, dynamic>.from(item)));
                  }).toList()),
            ]),
          ),
        );
      }),
    );
  }
}
