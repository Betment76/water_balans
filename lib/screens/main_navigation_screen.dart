import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'calendar_stats_screen.dart';
import 'achievements_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import '../services/mytarget_ad_service.dart';

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
  bool _bannerInitialized = false;

  // Список экранов
  final List<Widget> _screens = [
    const HomeScreen(),
    const CalendarStatsScreen(),
    const AchievementsScreen(),
    const SettingsScreen(),
    const AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // 📺 ИНИЦИАЛИЗАЦИЯ глобального MyTarget баннера один раз
    if (!_bannerInitialized) {
      _bannerInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await MyTargetAdService.initialize();
        await MyTargetAdService.showBannerUnderAppBar(1895039);
        debugPrint('🎯 Глобальный MyTarget баннер инициализирован');
      });
    }

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
              icon: Icons.analytics,
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            _NavIcon(
              icon: Icons.emoji_events,
              selected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavIcon(
              icon: Icons.settings,
              selected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
            _NavIcon(
              icon: Icons.info_outline,
              selected: _currentIndex == 4,
              onTap: () => setState(() => _currentIndex = 4),
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

 