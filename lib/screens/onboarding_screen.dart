import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../providers/user_settings_provider.dart';
import '../services/notification_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../services/storage_service.dart';
import 'main_navigation_screen.dart';
import '../services/mytarget_ad_service.dart';

const Color _kBlue = Color(0xFF1976D2);

/// Экран первого входа (онбординг) в общем стиле приложения
// Удалён первый простой вариант, ниже — полноценный ConsumerStatefulWidget

class _FeatureRow extends StatelessWidget {
  final IconData icon; // иконка фичи
  final String title;  // заголовок
  final String subtitle; // подзаголовок

  const _FeatureRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kBlue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white)),
            ],
          ),
        )
      ],
    );
  }
}

// НИЖЕ — полноценный stateful онбординг

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  DateTime? _birthDate;
  XFile? _avatar;

  int _currentPage = 0;
  int _activityLevel = 3; // 1..5 как в настройках (по умолчанию средний=3)
  String _selectedUnit = 'мл'; // мл, л, oz
  bool _notificationsEnabled = true;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Добро пожаловать в приложение "Водный баланс"!',
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
  void initState() {
    super.initState();
    // Скрываем баннер сразу после построения кадра, чтобы не мигал
    WidgetsBinding.instance.addPostFrameCallback((_) {
      MyTargetAdService.hideBanner();
    });
  }

  @override
  void dispose() {
    // Возвращаем баннер после выхода с онбординга
    MyTargetAdService.showBannerUnderAppBar(1895039);
    _pageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _nameController.dispose();
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
      print(
        '[_completeOnboarding] Настройки пользователя сохранены через провайдер.',
      );
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
      print(
        '[_completeOnboarding] Ошибка при установке флага первого запуска: $e',
      );
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
    int activityBonus = (activityLevel - 1) * 250; // 0..1000 мл
    return baseNorm + activityBonus;
  }

  Future<void> _pickAvatar() async {
    // Запрашиваем доступ (iOS: photos, Android: storage/media)
    final photos = await Permission.photos.request();
    final storage = await Permission.storage.request();
    if (!(photos.isGranted || storage.isGranted)) return;
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _avatar = file);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  void _onBirthDateChanged(String value) {
    final reg = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');
    final m = reg.firstMatch(value);
    if (m != null) {
      final d = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final y = int.tryParse(m.group(3)!);
      if (d != null && mo != null && y != null) {
        try {
          final date = DateTime(y, mo, d);
          setState(() => _birthDate = date);
        } catch (_) {}
      }
    }
  }

  int _calculateAge(DateTime birth) {
    final now = DateTime.now();
    int age = now.year - birth.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF64B5F6), Colors.white],
          ),
        ),
        child: SafeArea(
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
            const SizedBox(height: 16),

            const SizedBox(height: 32),

            // Заголовок
            Text(
              page.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Подзаголовок
            Text(
              page.subtitle,
              style: const TextStyle(fontSize: 16, color: Colors.white),
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
        // Аватар
        GestureDetector(
          onTap: _pickAvatar,
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Colors.blue.shade100,
            backgroundImage: _avatar != null ? FileImage(File(_avatar!.path)) : null,
            child: _avatar == null
                ? const Icon(Icons.camera_alt, color: Colors.blue, size: 28)
                : null,
          ),
        ),

        const SizedBox(height: 16),

        // Имя
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Имя',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),

        const SizedBox(height: 16),

        // Дата рождения: ввод ДД.ММ.ГГГГ + возраст справа
        TextField(
          controller: _birthDateController,
          keyboardType: TextInputType.number,
          onChanged: _onBirthDateChanged,
          inputFormatters: [
            _DateDigitsOnlyFormatter(), // только цифры + автоточки
          ],
          maxLength: 10,
          decoration: InputDecoration(
            counterText: '',
            labelText: 'Дата рождения (ДД.ММ.ГГГГ)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.cake),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  _birthDate != null ? '${_calculateAge(_birthDate!)} лет' : '—',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
          style: const TextStyle(color: Colors.black),
        ),

        const SizedBox(height: 16),

        // Вес и рост в одной строке
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _weightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Вес (кг)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _heightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Рост (см)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Уровень активности (как в настройках)
        const Text('Уровень активности:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Низкий', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  Text('Уровень $_activityLevel', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Высокий', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
              Slider(
                value: _activityLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    _activityLevel = value.round().clamp(1, 5);
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

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
          color: isSelected ? Colors.blue : Colors.white24,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white38,
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
                color: isSelected ? Colors.white70 : Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDigitsOnlyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      sb.write(digits[i]);
      if (i == 1 || i == 3) sb.write('.');
    }
    final formatted = sb.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
