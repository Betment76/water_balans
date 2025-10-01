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
              Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.black87)),
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
  int _activityLevel = 1; // 0..2 (0-низкий, 1-средний, 2-высокий)
  String _selectedUnit = 'мл'; // мл, л, oz
  bool _notificationsEnabled = true;
  String _gender = 'male'; // пол для онбординга

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Добро пожаловать в приложение "Водный баланс"!',
      subtitle: 'Поддерживайте оптимальную гидратацию каждый день. Приложение рассчитает вашу персональную норму, подскажет когда пить и поможет закрепить привычку.',
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
      activityLevel: _activityLevel, // 0..2
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
      // Сохраняем профильные поля для экрана профиля
      await StorageService.setString('profile_name', _nameController.text.trim());
      await StorageService.setString('profile_birthdate', _birthDateController.text.trim());
      await StorageService.setString('profile_gender', _gender);
      if (_avatar != null) {
        await StorageService.setString('profile_avatar_path', _avatar!.path);
      }
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(_currentPage == _pages.length - 1 ? 'Начать' : 'Далее'),
                ),
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
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Специфичный контент для каждой страницы
          if (pageIndex == 0) ...[
            const SizedBox(height: 8),
            _FeatureRow(
              icon: Icons.local_drink,
              title: 'Персональная дневная норма',
              subtitle: 'Учитываем вес и активность. Норма обновляется автоматически.'
            ),
            const SizedBox(height: 10),
            _FeatureRow(
              icon: Icons.alarm,
              title: 'Умные напоминания',
              subtitle: 'Не пропустите воду: мягкие пуши без навязчивости.'
            ),
            const SizedBox(height: 10),
            _FeatureRow(
              icon: Icons.emoji_events,
              title: 'Достижения и уровни',
              subtitle: 'Получайте XP, открывайте бейджи и держите серию дней.'
            ),
            const SizedBox(height: 10),
            _FeatureRow(
              icon: Icons.analytics,
              title: 'Статистика и календарь',
              subtitle: 'Дневные и почасовые графики, календарь прогресса.'
            ),
            const SizedBox(height: 10),
            _FeatureRow(
              icon: Icons.health_and_safety,
              title: 'Здоровая привычка',
              subtitle: 'Правильный водный баланс улучшает концентрацию и самочувствие.'
            ),
          ],
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
        _obCard(
          dense: true,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: CircleAvatar(
                  radius: 40, // компактнее, чтобы уместить всё на экране
                  backgroundColor: Colors.white,
                  backgroundImage: _avatar != null ? FileImage(File(_avatar!.path)) : null,
                  child: _avatar == null ? const Icon(Icons.camera_alt, color: Color(0xFF1976D2)) : null,
                ),
              ),
              const SizedBox(height: 8),
              _obTextField(controller: _nameController, label: 'Имя', icon: Icons.person),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _obCard(
          dense: true,
          child: Column(
            children: [
              TextField(
                controller: _birthDateController,
                keyboardType: TextInputType.number,
                onChanged: _onBirthDateChanged,
                inputFormatters: [ _DateDigitsOnlyFormatter() ],
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
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 6),
              Row(children: [
                const Text('Пол:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ChoiceChip(label: const Text('Мужской'), selected: _gender == 'male', onSelected: (_) => setState(() => _gender = 'male')),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Женский'), selected: _gender == 'female', onSelected: (_) => setState(() => _gender = 'female')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _obCard(
          dense: true,
          child: Row(children: [
            Expanded(child: _obTextField(controller: _weightController, label: 'Вес (кг)', icon: Icons.monitor_weight, numeric: true)),
            const SizedBox(width: 12),
            Expanded(child: _obTextField(controller: _heightController, label: 'Рост (см)', icon: Icons.height, numeric: true)),
          ]),
        ),
        const SizedBox(height: 8),
        _obCard(
          dense: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Уровень активности', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Низкий'),
                      selected: _activityLevel == 0,
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(color: _activityLevel == 0 ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _activityLevel = 0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.grey.shade200,
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Средний'),
                      selected: _activityLevel == 1,
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(color: _activityLevel == 1 ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _activityLevel = 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.grey.shade200,
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Высокий'),
                      selected: _activityLevel == 2,
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(color: _activityLevel == 2 ? Colors.white : Colors.black87),
                      onSelected: (_) => setState(() => _activityLevel = 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.grey.shade200,
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  // Карточка в стиле профиля/настроек для онбординга
  Widget _obCard({required Widget child, bool dense = false}) {
    return Container(
      padding: EdgeInsets.all(dense ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }

  // Унифицированный текстфилд
  Widget _obTextField({required TextEditingController controller, required String label, required IconData icon, bool numeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), prefixIcon: Icon(icon)),
      style: const TextStyle(color: Colors.black),
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
