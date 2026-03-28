import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.load();
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
      home: const SplashScreen(),
    );
  }
}
