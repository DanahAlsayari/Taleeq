import 'package:flutter/material.dart';

import '../HomepageUI/home_screen.dart';
import '../profileUI/profile_screen.dart';
import '../ProgressUi/progress_screen.dart';
import 'package:client/features/training/presentation/training_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final int initialProgressTab;

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.initialProgressTab = 0,
  });
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
    late int _selectedIndex;

    @override
    void initState() {
      super.initState();
      _selectedIndex = widget.initialIndex;
    }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex == 4
            ? 3
            : _selectedIndex == 3
                ? 2
                : _selectedIndex == 1
                    ? 1
                    : 0,
        children: [
          HomeScreen(isActive: _selectedIndex == 0),
          TrainingScreen(
            onStartExercise: (_) {},
            showBottomNav: false,
          ),
          ProgressScreen(
            initialTab: widget.initialProgressTab,
          ),
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
          if (index != 0 && index != 1 && index != 3 && index != 4) return;
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
            icon: Icon(Icons.trending_up_outlined),
            activeIcon: Icon(Icons.trending_up),
            label: 'تقدمي',
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
