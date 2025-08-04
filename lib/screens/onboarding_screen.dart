import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../providers/user_settings_provider.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import 'main_navigation_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  
  int _currentPage = 0;
  int _activityLevel = 1; // 0 - низкая, 1 - средняя, 2 - высокая
  String _selectedUnit = 'мл'; // мл, л, oz
  bool _notificationsEnabled = true;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Добро пожаловать в Водный баланс!',
      subtitle: 'Отслеживайте потребление воды и формируйте здоровые привычки',
      icon: Icons.water_drop,
      color: Colors.blue,
    ),
    OnboardingPage(
      title: 'Расскажите о себе',
      subtitle: 'Это поможет рассчитать вашу суточную норму воды',
      icon: Icons.person,
      color: Colors.green,
    ),
    OnboardingPage(
      title: 'Настройте уведомления',
      subtitle: 'Получайте напоминания о питье воды',
      icon: Icons.notifications,
      color: Colors.orange,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage++;
      });
    } else {
      _completeOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage--;
      });
    }
  }

  void _completeOnboarding() async {
    final weight = int.tryParse(_weightController.text) ?? 70;
    final height = _heightController.text.isNotEmpty 
        ? int.tryParse(_heightController.text) 
        : null;
    
    final settings = UserSettings(
      weight: weight,
      height: height,
      activityLevel: _activityLevel,
      dailyNormML: _calculateDailyNorm(weight, _activityLevel),
      isWeatherEnabled: false,
      notificationIntervalHours: 2,
      unit: _selectedUnit,
    );
    print('[_completeOnboarding] Настройки пользователя созданы: $settings');

    // Сохраняем через провайдер
    try {
      await ref.read(userSettingsProvider.notifier).save(settings);
      print('[_completeOnboarding] Настройки пользователя сохранены через провайдер.');
    } catch (e) {
      print('[_completeOnboarding] Ошибка при сохранении настроек: $e');
    }
    
    // Настраиваем уведомления если включены
    if (_notificationsEnabled) {
      try {
        await NotificationService.scheduleReminders(settings);
        print('[_completeOnboarding] Уведомления запланированы.');
      } catch (e) {
        print('[_completeOnboarding] Ошибка при планировании уведомлений: $e');
      }
    }

    // Отмечаем что onboarding завершен
    try {
      await StorageService.setFirstLaunch(false);
      print('[_completeOnboarding] Флаг первого запуска установлен в false.');
    } catch (e) {
      print('[_completeOnboarding] Ошибка при установке флага первого запуска: $e');
    }

    // Переходим к главному экрану
    if (mounted) {
      print('[_completeOnboarding] Переход к MainNavigationScreen.');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
      );
    } else {
      print('[_completeOnboarding] Виджет не смонтирован, переход невозможен.');
    }
  }

  int _calculateDailyNorm(int weight, int activityLevel) {
    // Базовая формула: 30 мл на кг веса + бонус за активность
    int baseNorm = weight * 30;
    int activityBonus = activityLevel * 250; // 250, 500, 750 мл
    return baseNorm + activityBonus;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Прогресс индикатор
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: List.generate(
                  _pages.length,
                  (index) => Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage 
                            ? Colors.blue 
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Контент страниц
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),
            
            // Кнопки навигации
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousPage,
                        child: const Text('Назад'),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Начать' : 'Далее',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page, int pageIndex) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          // Иконка
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: page.color,
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Заголовок
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Подзаголовок
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 32),
          
          // Специфичный контент для каждой страницы
          if (pageIndex == 1) _buildUserInfoForm(),
          if (pageIndex == 2) _buildNotificationsForm(),
        ],
        ),
      ),
    );
  }

  Widget _buildUserInfoForm() {
    return Column(
      children: [
        // Вес
        TextField(
          controller: _weightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ваш вес (кг)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.monitor_weight),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Рост
        TextField(
          controller: _heightController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Ваш рост (см) - необязательно',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.height),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Уровень активности
        const Text(
          'Уровень активности:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        
        const SizedBox(height: 12),
        
        Row(
          children: [
                         Expanded(
               child: _ActivityLevelCard(
                 title: 'Низкая',
                 subtitle: 'Малоподвижный образ жизни',
                 isSelected: _activityLevel == 0,
                 onTap: () => setState(() => _activityLevel = 0),
               ),
             ),
             const SizedBox(width: 8),
             Expanded(
               child: _ActivityLevelCard(
                 title: 'Средняя',
                 subtitle: 'Умеренная активность',
                 isSelected: _activityLevel == 1,
                 onTap: () => setState(() => _activityLevel = 1),
               ),
             ),
             const SizedBox(width: 8),
             Expanded(
               child: _ActivityLevelCard(
                 title: 'Высокая',
                 subtitle: 'Спорт, активный образ жизни',
                 isSelected: _activityLevel == 2,
                 onTap: () => setState(() => _activityLevel = 2),
               ),
             ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Единицы измерения
        const Text(
          'Единицы измерения:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        
        const SizedBox(height: 12),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['мл', 'л', 'oz'].map((unit) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ChoiceChip(
                label: Text(unit),
                selected: _selectedUnit == unit,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedUnit = unit);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNotificationsForm() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Включить уведомления'),
          subtitle: const Text('Напоминания о питье воды'),
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
        
        const SizedBox(height: 16),
        
        if (_notificationsEnabled)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(height: 8),
                Text(
                  'Уведомления будут приходить каждые 2 часа в течение дня',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class OnboardingPage {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class _ActivityLevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityLevelCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white70 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}