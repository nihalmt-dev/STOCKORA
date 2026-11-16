import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:inventory_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CustomersScreen extends StatefulWidget {
  final String token;
  const CustomersScreen({super.key, required this.token});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  static const bg = Color(0xFFF6F7FC);
  static const primary = Color(0xFF4F46E5);
  static const ink = Color(0xFF171B35);
  static const muted = Color(0xFF777F96);
  static const border = Color(0xFFE8EAF3);
  static const danger = Color(0xFFDC2626);

  final searchController = TextEditingController();
  List<dynamic> customers = [];
  bool loading = true;
  String? errorMessage;
  String searchQuery = '';
  String role = 'staff';
  String? busyId;

  bool get canDelete => role == 'admin';
  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _loadRole();
    fetchCustomers();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => role = (prefs.getString('user_role') ?? 'staff').toLowerCase());
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchCustomers() async {
    if (!mounted) return;
    setState(() { loading = true; errorMessage = null; });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/customers'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(response.statusCode == 401
            ? 'Session expired. Please log in again.'
            : 'Unable to load customers (${response.statusCode})');
      }
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        customers = data is List
            ? data
            : data is Map && data['customers'] is List
                ? data['customers'] as List
                : [];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { errorMessage = e.toString(); loading = false; });
    }
  }

  void _message(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? const Color(0xFF059669) : danger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  String _responseMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) return data['message'].toString();
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: muted),
        prefixIcon: Icon(icon, color: primary, size: 20),
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

  Future<void> showCustomerForm({Map<String, dynamic>? customer}) async {
    final editing = customer != null;
    final name = TextEditingController(text: customer?['name']?.toString() ?? '');
    final email = TextEditingController(text: customer?['email']?.toString() ?? '');
    final phone = TextEditingController(text: customer?['phone']?.toString() ?? '');
    final address = TextEditingController(text: customer?['address']?.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;
    bool closing = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> save() async {
              if (!formKey.currentState!.validate()) return;
              setDialogState(() => saving = true);
              try {
                final url = editing
                    ? '${ApiConfig.baseUrl}/api/customers/${customer['_id']}'
                    : '${ApiConfig.baseUrl}/api/customers';
                final body = jsonEncode({
                  'name': name.text.trim(),
                  'email': email.text.trim(),
                  'phone': phone.text.trim(),
                  'address': address.text.trim(),
                });
                final response = await (editing
                        ? http.put(Uri.parse(url), headers: headers, body: body)
                        : http.post(Uri.parse(url), headers: headers, body: body))
                    .timeout(const Duration(seconds: 20));
                if (!mounted || !dialogContext.mounted) return;
                if (response.statusCode == 200 || response.statusCode == 201) {
                  closing = true;
                  Navigator.of(dialogContext).pop();
                  _message(editing ? 'Customer updated successfully' : 'Customer added successfully', success: true);
                  await fetchCustomers();
                } else {
                  _message(_responseMessage(response, 'Unable to save customer'));
                }
              } catch (e) {
                _message('Connection error: $e');
              } finally {
                if (!closing && dialogContext.mounted) {
                  setDialogState(() => saving = false);
                }
              }
            }

            Widget field(String label, IconData icon, TextEditingController controller,
                {String? Function(String?)? validator, TextInputType? keyboardType, int maxLines = 1}) {
              return TextFormField(
                controller: controller,
                validator: validator,
                enabled: !saving,
                keyboardType: keyboardType,
                maxLines: maxLines,
                style: const TextStyle(color: ink, fontSize: 14),
                decoration: _input(label, icon),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFEEEDFF), borderRadius: BorderRadius.circular(11)),
                  child: Icon(editing ? Icons.edit_outlined : Icons.person_add_alt_1_rounded, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(editing ? 'Edit Customer' : 'Add Customer',
                    style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 19))),
              ]),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      field('Customer Name', Icons.person_outline_rounded, name,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter customer name' : null),
                      const SizedBox(height: 14),
                      field('Email Address', Icons.mail_outline_rounded, email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            final text = v?.trim() ?? '';
                            if (text.isEmpty) return 'Enter email address';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) return 'Enter a valid email';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      field('Phone Number (optional)', Icons.phone_outlined, phone,
                          keyboardType: TextInputType.phone),
                      const SizedBox(height: 14),
                      field('Address (optional)', Icons.location_on_outlined, address, maxLines: 2),
                    ]),
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              actions: [
                OutlinedButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(foregroundColor: ink, side: const BorderSide(color: border)),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(saving ? 'Saving...' : editing ? 'Save Changes' : 'Add Customer'),
                  style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      // Wait for the closing route animation before disposing field controllers.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      name.dispose();
      email.dispose();
      phone.dispose();
      address.dispose();
    }
  }

  Future<void> deleteCustomer(Map<String, dynamic> customer) async {
    if (!canDelete) return;
    final id = customer['_id']?.toString();
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Delete Customer?', style: TextStyle(color: ink)),
        content: Text('Delete "${customer['name']}"? This action cannot be undone.',
            style: const TextStyle(color: muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: danger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => busyId = id);
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/customers/$id'), headers: headers,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _message('Customer deleted successfully', success: true);
        await fetchCustomers();
      } else {
        _message(_responseMessage(response, 'Unable to delete customer'));
      }
    } catch (e) {
      _message('Connection error: $e');
    } finally {
      if (mounted) setState(() => busyId = null);
    }
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: border),
        boxShadow: const [BoxShadow(color: Color(0x0824265C), blurRadius: 16, offset: Offset(0, 6))],
      );

  Widget _detail(IconData icon, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: muted, size: 17),
          const SizedBox(width: 10),
          Expanded(child: Text(value, softWrap: true,
              style: const TextStyle(color: ink, fontSize: 12.5, height: 1.4))),
        ],
      );

  Widget _customerCard(Map<String, dynamic> customer) {
    final name = customer['name']?.toString() ?? 'Unknown';
    final email = customer['email']?.toString() ?? '';
    final phone = customer['phone']?.toString() ?? '';
    final address = customer['address']?.toString() ?? '';
    final id = customer['_id']?.toString();
    final busy = busyId == id;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFEEEDFF),
            child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: primary, fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('CUSTOMER', style: TextStyle(color: primary, fontSize: 10,
                letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ])),
          PopupMenuButton<String>(
            tooltip: 'Customer actions',
            enabled: !busy,
            icon: const Icon(Icons.more_horiz_rounded, color: muted),
            color: Colors.white,
            onSelected: (action) {
              if (action == 'edit') showCustomerForm(customer: customer);
              if (action == 'delete') deleteCustomer(customer);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Customer', style: TextStyle(color: ink))),
              if (canDelete)
                const PopupMenuItem(value: 'delete', child: Text('Delete Customer', style: TextStyle(color: danger))),
            ],
          ),
        ]),
        const SizedBox(height: 16),
        const Divider(color: border, height: 1),
        const SizedBox(height: 13),
        _detail(Icons.mail_outline_rounded, email.isEmpty ? 'No email' : email),
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 10),
          _detail(Icons.phone_outlined, phone),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 10),
          _detail(Icons.location_on_outlined, address),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final filtered = customers.where((item) {
      final customer = Map<String, dynamic>.from(item as Map);
      return ['name', 'email', 'phone'].any((key) =>
          (customer[key]?.toString() ?? '').toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      backgroundColor: bg,
      body: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final columns = constraints.maxWidth >= 1100 ? 3 : constraints.maxWidth >= 700 ? 2 : 1;
        final horizontal = compact ? 16.0 : 24.0;
        final available = constraints.maxWidth - horizontal * 2;
        final cardWidth = (available - 14 * (columns - 1)) / columns;
        return RefreshIndicator(
          color: primary,
          onRefresh: fetchCustomers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 36),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Customer Management', style: TextStyle(color: ink, fontSize: 25, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Keep your customer relationships organized', style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                  ElevatedButton.icon(
                    onPressed: () => showCustomerForm(),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                    label: const Text('Add Customer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFEEEDFF), Colors.white]),
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(color: border),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFE0DEFF), borderRadius: BorderRadius.circular(13)),
                    child: const Icon(Icons.groups_2_outlined, color: primary, size: 26),
                  ),
                  const SizedBox(width: 15),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${customers.length}', style: const TextStyle(color: ink, fontSize: 29, fontWeight: FontWeight.w800)),
                    const Text('Total Customers', style: TextStyle(color: muted, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: _cardDecoration(),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) => setState(() => searchQuery = value),
                  style: const TextStyle(color: ink),
                  decoration: InputDecoration(
                    hintText: 'Search by name, email or phone',
                    hintStyle: const TextStyle(color: muted, fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: primary),
                    suffixIcon: searchQuery.isEmpty ? null : IconButton(
                      onPressed: () { searchController.clear(); setState(() => searchQuery = ''); },
                      icon: const Icon(Icons.close_rounded, color: muted),
                    ),
                    filled: true,
                    fillColor: bg,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primary)),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(children: [
                const Expanded(child: Text('Customer Directory',
                    style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800))),
                if (!loading && errorMessage == null)
                  Text('${filtered.length} shown', style: const TextStyle(color: muted, fontSize: 12)),
                IconButton(onPressed: loading ? null : fetchCustomers,
                    tooltip: 'Refresh customers', icon: const Icon(Icons.refresh_rounded, color: primary)),
              ]),
              const SizedBox(height: 14),
              if (loading)
                const Center(child: Padding(padding: EdgeInsets.all(38),
                    child: CircularProgressIndicator(color: primary)))
              else if (errorMessage != null)
                Center(child: Column(children: [
                  Text(errorMessage!, style: const TextStyle(color: danger), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: fetchCustomers, child: const Text('Retry')),
                ]))
              else if (filtered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(40),
                  decoration: _cardDecoration(),
                  child: Column(children: [
                    const Icon(Icons.person_search_rounded, color: muted, size: 40),
                    const SizedBox(height: 12),
                    Text(customers.isEmpty ? 'No customers yet' : 'No matching customers',
                        style: const TextStyle(color: ink, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(customers.isEmpty ? 'Add your first customer to get started' : 'Try another search term',
                        textAlign: TextAlign.center, style: const TextStyle(color: muted, fontSize: 12)),
                  ]),
                )
              else
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: filtered.map((item) => SizedBox(
                    width: cardWidth,
                    child: _customerCard(Map<String, dynamic>.from(item as Map)),
                  )).toList(),
                ),
            ]),
          ),
        );
      }),
    );
  }
}
