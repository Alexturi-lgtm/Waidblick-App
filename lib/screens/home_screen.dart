import 'package:flutter/material.dart';
import 'analysis_screen.dart';
import 'gamsbook_screen.dart';
import 'info_screen.dart';

/// Haupt-Screen mit BottomNavigationBar.
/// Verwaltet die drei Haupt-Tabs: Analyse, GamsBook, Info.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Screens werden lazy geladen und gecacht
  static const List<Widget> _screens = [
    AnalysisScreen(),
    GamsbookScreen(),
    InfoScreen(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt),
            label: 'Analyse',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'GamsBook',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Info',
          ),
        ],
      ),
    );
  }
}
