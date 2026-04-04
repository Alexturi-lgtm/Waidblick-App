import 'package:flutter/material.dart';
import 'analysis_screen.dart';
import 'gamsbook_screen.dart';
import 'info_screen.dart';
import 'settings_screen.dart';

/// Haupt-Screen mit BottomNavigationBar.
/// 4 Tabs: Home (Analyse), Lookbook, Info, Einstellungen
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    AnalysisScreen(),
    GamsbookScreen(),
    InfoScreen(),
    SettingsScreen(),
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
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xD9141414),
          border: Border(
            top: BorderSide(color: Color(0x0FFFFFFF), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _buildTab(0, Icons.home_outlined, Icons.home, 'HOME'),
                _buildTab(1, Icons.menu_book_outlined, Icons.menu_book, 'LOOKBOOK'),
                _buildTab(2, Icons.info_outline, Icons.info, 'INFO'),
                _buildTab(3, Icons.settings_outlined, Icons.settings, 'EINSTELLUNGEN'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    const goldColor = Color(0xFFF5A623);
    final inactiveColor = const Color(0xFFF5F0E8).withOpacity(0.35);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? goldColor : inactiveColor,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isSelected ? goldColor : inactiveColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
