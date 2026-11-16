import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:inventory_app/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UsersScreen extends StatefulWidget {
  final String token;
  const UsersScreen({super.key, required this.token});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  static const purple = Color(0xFF5145E8);
  static const ink = Color(0xFF19233B);
  static const muted = Color(0xFF7B879D);
  static const background = Color(0xFFF6F7FC);
  static const line = Color(0xFFE6E9F3);
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  bool isAdmin = false;
  String? error;
  String search = '';
  final searchController = TextEditingController();

  Map<String, String> get headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    isAdmin = prefs.getString('user_role')?.toLowerCase() == 'admin';
    if (!isAdmin) {
      setState(() { loading = false; error = 'Only administrators can manage users.'; });
      return;
    }
    await loadUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _message(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map && data['message'] != null) return data['message'].toString();
      if (data is Map && data['error'] != null) return data['error'].toString();
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  void _notify(String message, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: success ? const Color(0xFF12876B) : const Color(0xFFBE3B4B),
    ));
  }

  Future<void> loadUsers() async {
    if (!mounted || !isAdmin) return;
    setState(() { loading = true; error = null; });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/users'), headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw Exception(_message(response, 'Unable to load users'));
      final data = jsonDecode(response.body);
      final list = data is List ? data : data is Map && data['users'] is List ? data['users'] as List : <dynamic>[];
      if (!mounted) return;
      setState(() {
        users = list.whereType<Map>().map((u) => Map<String, dynamic>.from(u)).toList();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }

  InputDecoration _input(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: muted),
    prefixIcon: icon == null ? null : Icon(icon, color: muted, size: 20),
    filled: true,
    fillColor: Colors.white,
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: purple, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.red)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  );

  Widget _panel(Widget child, {EdgeInsets padding = const EdgeInsets.all(20)}) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: line)),
    child: child,
  );

  Future<void> _createUser() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = 'staff';
    bool saving = false;
    bool hidePassword = true;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (context, update) => AlertDialog(
        backgroundColor: background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Create team member', style: TextStyle(color: ink, fontWeight: FontWeight.w800)),
        content: SizedBox(width: 440, child: SingleChildScrollView(child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(controller: name, style: const TextStyle(color: ink), decoration: _input('Full name', icon: Icons.person_outline), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a name' : null),
            const SizedBox(height: 13),
            TextFormField(controller: email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: ink), decoration: _input('Email address', icon: Icons.mail_outline), validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email'),
            const SizedBox(height: 13),
            TextFormField(controller: password, obscureText: hidePassword, style: const TextStyle(color: ink), decoration: _input('Temporary password', icon: Icons.lock_outline).copyWith(suffixIcon: IconButton(onPressed: () => update(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => (v?.length ?? 0) < 8 ? 'Use at least 8 characters' : null),
            const SizedBox(height: 13),
            DropdownButtonFormField<String>(value: role, decoration: _input('Role', icon: Icons.shield_outlined), dropdownColor: Colors.white, style: const TextStyle(color: ink), items: const [DropdownMenuItem(value: 'staff', child: Text('Staff')), DropdownMenuItem(value: 'manager', child: Text('Manager'))], onChanged: saving ? null : (v) => update(() => role = v ?? 'staff')),
          ]),
        ))),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(onPressed: saving ? null : () async {
            if (!formKey.currentState!.validate()) return;
            update(() => saving = true);
            try {
              final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/api/users'), headers: headers,
                body: jsonEncode({'name': name.text.trim(), 'email': email.text.trim(), 'password': password.text, 'role': role}),
              ).timeout(const Duration(seconds: 15));
              if (!mounted || !dialogContext.mounted) return;
              if (response.statusCode == 200 || response.statusCode == 201) {
                Navigator.pop(dialogContext);
                _notify('Team member created successfully', success: true);
                await loadUsers();
              } else {
                _notify(_message(response, 'Unable to create user'));
              }
            } catch (e) { _notify('Connection error: $e'); }
            finally { if (dialogContext.mounted) update(() => saving = false); }
          }, style: FilledButton.styleFrom(backgroundColor: purple), child: Text(saving ? 'Creating...' : 'Create user')),
        ],
      ),
    ));
    // Do not dispose here: closing dialog animation can still reference controllers.
  }

  Future<void> _updateUser(Map<String, dynamic> user, {String? role, bool? active}) async {
    final id = (user['_id'] ?? user['id'])?.toString();
    if (id == null || id.isEmpty) return;
    final currentRole = user['role']?.toString().toLowerCase() ?? '';
    if (currentRole == 'admin') {
      _notify('Admin accounts cannot be changed from this screen');
      return;
    }
    try {
      final endpoint = role != null ? 'role' : 'status';
      final response = await http.patch(Uri.parse('${ApiConfig.baseUrl}/api/users/$id/$endpoint'),
        headers: headers, body: jsonEncode(role != null ? {'role': role} : {'isActive': active}),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        _notify('User updated successfully', success: true);
        await loadUsers();
      } else {
        _notify(_message(response, 'Unable to update user'));
      }
    } catch (e) { _notify('Connection error: $e'); }
  }

  Future<void> _confirmUpdate(Map<String, dynamic> user, {String? role, bool? active}) async {
    final action = role != null ? 'Change role to ${role.toUpperCase()}' : active == true ? 'Activate account' : 'Deactivate account';
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(action),
      content: Text('Apply this change to ${user['name'] ?? 'this user'}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm'))],
    ));
    if (confirmed == true) await _updateUser(user, role: role, active: active);
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    if (!isAdmin || user['role']?.toString().toLowerCase() == 'admin') return;
    final id = (user['_id'] ?? user['id'])?.toString();
    if (id == null || id.isEmpty) {
      _notify('User ID missing. Refresh and try again.');
      return;
    }
    final name = (user['name'] ?? 'this user').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.delete_forever_outlined, color: Color(0xFFDC2626)),
          SizedBox(width: 9),
          Expanded(child: Text('Delete team member?', style: TextStyle(color: ink))),
        ]),
        content: Text('Permanently delete $name? This cannot be undone. Deactivate instead if you need to preserve the account.',
          style: const TextStyle(color: ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/users/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _notify('$name deleted successfully', success: true);
        await loadUsers();
      } else {
        _notify(_message(response, 'Unable to delete user'));
      }
    } catch (e) {
      _notify('Connection error: $e');
    }
  }

  Widget _stat(String label, String value, IconData icon, Color accent) => _panel(Row(children: [
    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: accent.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent)),
    const SizedBox(width: 13),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: ink, fontSize: 24, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: muted, fontSize: 12)),
    ])),
  ]));

  Widget _userCard(Map<String, dynamic> user) {
    final name = user['name']?.toString() ?? 'Unknown user';
    final email = user['email']?.toString() ?? '';
    final role = user['role']?.toString().toLowerCase() ?? 'staff';
    final active = user['isActive'] != false;
    final admin = role == 'admin';
    return _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(backgroundColor: const Color(0xFFEDEBFF), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: purple, fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 3),
          Text(email, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12)),
        ])),
        if (!admin) PopupMenuButton<String>(
          tooltip: 'Manage user',
          color: Colors.white,
          icon: const Icon(Icons.more_vert_rounded, color: ink, size: 22),
          onSelected: (value) {
          if (value == 'manager' || value == 'staff') _confirmUpdate(user, role: value);
          if (value == 'toggle') _confirmUpdate(user, active: !active);
          if (value == 'delete') _confirmDelete(user);
     }, itemBuilder: (_) => [
  if (role != 'manager')
    const PopupMenuItem(
      value: 'manager',
      child: Text(
        'Make Manager',
        style: TextStyle(
          color: Color(0xFF19233B),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

  if (role != 'staff')
    const PopupMenuItem(
      value: 'staff',
      child: Text(
        'Make Staff',
        style: TextStyle(
          color: Color(0xFF19233B),
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

  PopupMenuItem(
    value: 'toggle',
    child: Text(
      active ? 'Deactivate account' : 'Activate account',
      style: const TextStyle(
        color: Color(0xFF19233B),
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  const PopupMenuDivider(),

  const PopupMenuItem(
    value: 'delete',
    child: Row(
      children: [
        Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFDC2626),
          size: 19,
        ),
        SizedBox(width: 8),
        Text(
          'Delete user',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  ),
]),
      ]),
      const SizedBox(height: 16),
      const Divider(color: line, height: 1),
      const SizedBox(height: 13),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _pill(role.toUpperCase(), purple, const Color(0xFFEDEBFF)),
        _pill(
          active ? 'ACTIVE' : 'INACTIVE',
          active ? const Color(0xFF0C946B) : const Color(0xFFBE3B4B),
          active ? const Color(0xFFE4F8EF) : const Color(0xFFFFE9ED),
        ),
        if (admin) _pill('PROTECTED', muted, background),
      ]),
    ]));
  }
  Widget _pill(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .5)),
  );

  @override
  Widget build(BuildContext context) {
    final teamUsers = users.where((u) => u['role']?.toString().toLowerCase() != 'admin').toList();
    final filtered = teamUsers.where((u) => '${u['name'] ?? ''} ${u['email'] ?? ''} ${u['role'] ?? ''}'.toLowerCase().contains(search.toLowerCase().trim())).toList();
    final managers = teamUsers.where((u) => u['role']?.toString().toLowerCase() == 'manager').length;
    final staff = teamUsers.where((u) => u['role']?.toString().toLowerCase() == 'staff').length;
    final active = teamUsers.where((u) => u['isActive'] != false).length;
    return Scaffold(backgroundColor: background, body: LayoutBuilder(builder: (context, bounds) {
      final compact = bounds.maxWidth < 680;
      final pad = compact ? 16.0 : 24.0;
      return RefreshIndicator(onRefresh: isAdmin ? loadUsers : () async {}, color: purple,
        child: SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(pad, 22, pad, 36), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 15, runSpacing: 14, children: [
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('User Management', style: TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w800)),
              SizedBox(height: 5),
              Text('Manage team members, roles and account access', style: TextStyle(color: muted, fontSize: 12)),
            ]),
            if (isAdmin) FilledButton.icon(onPressed: _createUser, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add Team Member'), style: FilledButton.styleFrom(backgroundColor: purple, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16))),
          ]),
          const SizedBox(height: 22),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(55), child: CircularProgressIndicator(color: purple)))
          else if (error != null) _panel(Column(children: [
            const Icon(Icons.shield_outlined, color: purple, size: 35),
            const SizedBox(height: 10),
            Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: ink)),
            if (isAdmin) TextButton(onPressed: loadUsers, child: const Text('Retry')),
          ]))
          else ...[
            LayoutBuilder(builder: (context, inner) {
              final cols = inner.maxWidth >= 900 ? 4 : 2;
              final gap = 12.0;
              final cardWidth = (inner.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                SizedBox(width: cardWidth, child: _stat('Team Members', '${teamUsers.length}', Icons.groups_outlined, purple)),
                SizedBox(width: cardWidth, child: _stat('Managers', '$managers', Icons.admin_panel_settings_outlined, const Color(0xFF4F87D9))),
                SizedBox(width: cardWidth, child: _stat('Staff', '$staff', Icons.badge_outlined, const Color(0xFFAD7A35))),
                SizedBox(width: cardWidth, child: _stat('Active Users', '$active', Icons.check_circle_outline, const Color(0xFF0C946B))),
              ]);
            }),
            const SizedBox(height: 20),
            _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Team Directory', style: TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text('Search users and manage their permissions', style: TextStyle(color: muted, fontSize: 12)),
              const SizedBox(height: 16),
              TextField(controller: searchController, onChanged: (v) => setState(() => search = v), style: const TextStyle(color: ink), cursorColor: purple,
                decoration: _input('Search name, email or role', icon: Icons.search_rounded).copyWith(labelText: null, hintText: 'Search name, email or role', hintStyle: const TextStyle(color: muted))),
              const SizedBox(height: 12),
              Text('${filtered.length} of ${teamUsers.length} users', style: const TextStyle(color: muted, fontSize: 12)),
            ])),
            const SizedBox(height: 16),
            if (filtered.isEmpty) _panel(const Center(child: Padding(padding: EdgeInsets.all(25), child: Text('No matching users', style: TextStyle(color: muted)))))
            else LayoutBuilder(builder: (context, inner) {
              final cols = inner.maxWidth >= 1000 ? 3 : inner.maxWidth >= 600 ? 2 : 1;
              final gap = 13.0;
              final w = (inner.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(spacing: gap, runSpacing: gap, children: filtered.map((u) => SizedBox(width: w, child: _userCard(u))).toList());
            }),
          ],
        ])));
    }));
  }
}
