
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const StockoraApp());
}

class StockoraApp extends StatelessWidget {
  const StockoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STOCKORA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5EEAC4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B1120),
      ),
      home: const AuthChecker(),
    );
  }
}

class AuthChecker extends StatefulWidget {
  const AuthChecker({super.key});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  String? validToken;
  bool checking = true;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      if (token == null || token.isEmpty) {
        if (!mounted) return;
        setState(() => checking = false);
        return;
      }

      // Verify that the saved token still works.
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/dashboard/stats'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          validToken = token;
          checking = false;
        });
      } else if (response.statusCode == 401 ||
          response.statusCode == 403) {
        await prefs.remove('auth_token');

        if (!mounted) return;
        setState(() => checking = false);
      } else {
        setState(() => checking = false);
      }
    } catch (error) {
      if (!mounted) return;

      setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B1120),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF5EEAC4),
          ),
        ),
      );
    }

    if (validToken != null) {
      return DashboardScreen(token: validToken!);
    }

    return const LoginScreen();
  }
}
