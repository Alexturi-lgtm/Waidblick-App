import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'services/database_service.dart';
import 'services/payment_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://cflfreajuouofuifahsv.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNmbGZyZWFqdW91b2Z1aWZhaHN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2OTYwMzAsImV4cCI6MjA5MDI3MjAzMH0.O2hekntirI8E-PIRMXPfsNWkfMggayNiCTcuJ_18ZNg',
  );

  await DatabaseService.instance.load();
  await PaymentService.initialize();
  runApp(const WaidblickApp());
}

class WaidblickApp extends StatelessWidget {
  const WaidblickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WAIDBLICK',
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      home: const SplashScreen(),
    );
  }
}
