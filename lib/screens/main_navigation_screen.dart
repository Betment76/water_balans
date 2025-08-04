import 'package:flutter/material.dart';
import 'home_screen.dart';

import 'history_screen.dart';
import 'reminders_screen.dart';

import 'settings_screen.dart';

const Color kBlue = Color(0xFF1976D2); // синий для иконок
const Color kLightBlue = Color(0xFF64B5F6); // голубой фон меню

/// Главный экран с нижней навигацией
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Список экранов
  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const RemindersScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        color: kBlue,
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavIcon(
              icon: Icons.home,
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavIcon(
              icon: Icons.history,
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _NavIcon(
              icon: Icons.notifications,
              selected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavIcon(
              icon: Icons.settings,
              selected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// Иконка для нижнего меню
class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _NavIcon({required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        padding: const EdgeInsets.all(8),
        child: Icon(
          icon,
          size: 32,
          color: Colors.white,
        ),
      ),
    );
  }
}

 