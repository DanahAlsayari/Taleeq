import 'package:flutter/material.dart';

import '../HomepageUI/home_screen.dart';
import '../profileUI/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex == 4 ? 1 : 0,
        children: [
          HomeScreen(isActive: _selectedIndex == 0),
          ProfileScreen(isActive: _selectedIndex == 4),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF1F5F5A),
        unselectedItemColor: const Color(0xFF8A9694),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 8,
        onTap: (index) {
          if (index != 0 && index != 4) return;

          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center, color: Color(0xFFB8BFBD)),
            label: 'التدريب',
            tooltip: 'قريبًا',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.graphic_eq, color: Color(0xFFB8BFBD)),
            label: 'طلاقتي',
            tooltip: 'قريبًا',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up, color: Color(0xFFB8BFBD)),
            label: 'تقدمي',
            tooltip: 'قريبًا',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}
