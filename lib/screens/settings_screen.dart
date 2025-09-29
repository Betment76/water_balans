import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/user_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_settings_provider.dart';
import '../providers/achievements_provider.dart';
import '../services/weather_service.dart';
import 'onboarding_screen.dart';
import 'package:geolocator/geolocator.dart';
import '../services/notification_service.dart';
import '../services/calculation_service.dart';
import '../services/rustore_review_service.dart';
import '../services/rustore_pay_service.dart';
// import '../services/test_rustore_billing.dart'; // Удалено для релиза
import '../constants/app_colors.dart';
import 'main_navigation_screen.dart';

/// Экран настроек пользователя
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController dailyNormController = TextEditingController();

  int activityLevel = 1;
  String selectedUnit = 'мл';
  bool _isProUser = false;
  bool _isAdFree = false;

  String? _weightError;
  String? _heightError;
  double? _temperature;
  bool _isLoadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkProStatus();
    _checkAdFreeStatus();
    _fetchWeather();

    weightController.addListener(_updateDailyNorm);
  }

  void _updateDailyNorm() {
    final weight = int.tryParse(weightController.text);
    if (weight != null && weight > 0) {
      // 🌡️ Добавка от погоды только при температуре 30°C и выше
      int weatherAddition = 0;
      if (_temperature != null && _temperature! >= 30) {
        // Каждый градус от 30°C добавляет 50 мл (максимум 500 мл при 40°C)
        weatherAddition = ((_temperature! - 30) * 50).clamp(0, 500).round();
      }
      
      final norm = CalculationService.calculateDailyNorm(
        weight: weight,
        activityLevel: activityLevel,
        weatherAddition: weatherAddition,
      );
      
      // 🔧 ДИАГНОСТИКА расчета нормы
      print('🔧 РАСЧЕТ НОРМЫ:');
      print('  Вес: $weight кг');
      print('  Активность: $activityLevel (${[0, 250, 500][activityLevel]} мл)');
      print('  Температура: $_temperature°C');
      print('  Погодная добавка: $weatherAddition мл');
      print('  ИТОГОВАЯ НОРМА: $norm мл');
      
      dailyNormController.text = norm.toString();
    }
  }

  /// Загрузить настройки из хранилища
  void _loadSettings() {
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      weightController.text = settings.weight.toString();
      heightController.text = settings.height?.toString() ?? '';
      activityLevel = settings.activityLevel;
      selectedUnit = settings.unit;
      
      // 🔄 ПРИНУДИТЕЛЬНО пересчитываем норму с новой логикой
      print('🔧 ДИАГНОСТИКА: Старая норма = ${settings.dailyNormML} мл');
      _updateDailyNorm();
      
      // Автоматически сохраняем новую норму и обновляем достижения
      Future.delayed(const Duration(milliseconds: 500), () async {
        final newNorm = int.tryParse(dailyNormController.text);
        if (newNorm != null && newNorm != settings.dailyNormML) {
          print('🔧 АВТОСОХРАНЕНИЕ: Обновляем норму с ${settings.dailyNormML} на $newNorm мл');
          _saveSettings();
          
          // 🏆 Обновляем достижения с новой нормой
          try {
            final achievementsService = ref.read(achievementsServiceProvider);
            await achievementsService.initialize(dailyNormML: newNorm, forceReset: false);
            print('🏆 Достижения обновлены для новой нормы $newNorm мл');
          } catch (e) {
            print('❌ Ошибка обновления достижений: $e');
          }
        }
      });
    }
  }

  Future<void> _checkProStatus() async {
    final isPro = await StorageService.isProUser();
    setState(() {
      _isProUser = isPro;
    });
  }

  Future<void> _checkAdFreeStatus() async {
    try {
      final isAdFree = await RustorePayService.isAdFree();
      setState(() {
        _isAdFree = isAdFree;
      });
    } catch (e) {
      print('Ошибка проверки статуса без рекламы: $e');
    }
  }

  Future<void> _fetchWeather() async {
    setState(() { _isLoadingWeather = true; _weatherError = null; });
    try {
      // Синхронизируем с логикой главного экрана: сначала геолокация, иначе Москва
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        final position = await Geolocator.getCurrentPosition();
        final weather = await WeatherService.fetchWeather(
          latitude: position.latitude,
          longitude: position.longitude,
        );
        if (!mounted) return;
        setState(() { _temperature = weather?.temperature; });
      } else {
        // Без координат погоду не показываем
        setState(() { _temperature = null; });
      }
      if (_temperature == null) {
        setState(() { _weatherError = 'Ошибка загрузки погоды'; });
      }
      _updateDailyNorm();
    } catch (e) {
      if (!mounted) return;
      setState(() { _weatherError = 'Ошибка: $e'; });
    } finally {
      if (mounted) setState(() { _isLoadingWeather = false; });
    }
  }

  @override
  void dispose() {
    weightController.removeListener(_updateDailyNorm);
    weightController.dispose();
    heightController.dispose();
    dailyNormController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    setState(() {
      _weightError = null;
      _heightError = null;
    });

    final weight = int.tryParse(weightController.text);
    final height = heightController.text.isNotEmpty
        ? int.tryParse(heightController.text)
        : null;
    final dailyNorm = int.tryParse(dailyNormController.text);

    if (weight == null || weight < 30 || weight > 200) {
      setState(() => _weightError = 'Введите вес от 30 до 200');
      return;
    }
    if (height != null && (height < 100 || height > 250)) {
      setState(() => _heightError = 'Рост от 100 до 250');
      return;
    }

    final settings = UserSettings(
      weight: weight,
      height: height,
      activityLevel: activityLevel,
      dailyNormML: dailyNorm ?? 0, // dailyNorm не может быть null
      isWeatherEnabled: true,
      notificationIntervalHours: 2,
      unit: selectedUnit,
    );

    ref.read(userSettingsProvider.notifier).save(settings);
    NotificationService.scheduleReminders(settings);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Настройки сохранены')));
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс данных'),
        content: const Text(
          'Вы уверены, что хотите сбросить все данные? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StorageService.clearAllData();
        await NotificationService.cancelAllNotifications();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Данные сброшены')));
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const MainNavigationScreen(),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка сброса: $e')));
        }
      }
    }
  }

  /// Запросить отзыв у пользователя
  Future<void> _requestReview() async {
    try {
      final success = await RuStoreReviewService.requestReview();
      if (mounted) {
        String message;
        Color backgroundColor;

        if (success) {
          message = 'Отзыв успешно запрощен!';
          backgroundColor = Colors.green;
        } else {
          // Получаем статистику для более детального объяснения
          final stats = await RuStoreReviewService.getRequestStats();
          final canRequest = stats['canRequest'] as bool? ?? false;
          final requestCount = stats['requestCount'] as int? ?? 0;
          final maxRequests = stats['maxRequests'] as int? ?? 3;

          if (!canRequest && requestCount >= maxRequests) {
            message = 'Достигнут лимит запросов (макс. $maxRequests)';
          } else if (!canRequest) {
            message = 'Отзыв можно запросить через несколько дней';
          } else {
            message =
                'Невозможно показать отзыв:\n'
                '• RuStore не установлен на устройстве\n'
                '• Пользователь не авторизован в RuStore\n'
                '• Приложение не опубликовано в RuStore';
          }
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Показать статистику отзывов
  Future<void> _showReviewStats() async {
    try {
      final stats = await RuStoreReviewService.getRequestStats();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Статистика отзывов'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Количество запросов: ${stats['requestCount']} / ${stats['maxRequests']}",
                ),
                const SizedBox(height: 8),
                Text("Можно запросить: ${stats['canRequest'] ? 'Да' : 'Нет'}"),
                const SizedBox(height: 8),
                if (stats['lastRequest'] != null)
                  Text(
                    "Последний запрос: ${DateTime.parse(stats['lastRequest']).toString().substring(0, 16)}",
                  ),
                const SizedBox(height: 8),
                if (stats['firstLaunch'] != null)
                  Text(
                    "Первый запуск: ${DateTime.parse(stats['firstLaunch']).toString().substring(0, 16)}",
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Правила:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text("• Мин. дней между запросами: ${stats['minDaysBetween']}"),
                Text(
                  "• Мин. дней перед первым запросом: ${stats['minDaysBeforeFirst']}",
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения статистики: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Покупка отключения рекламы
  Future<void> _purchaseRemoveAds() async {
    try {
      final success = await RustorePayService.purchaseRemoveAds();
      if (mounted) {
        String message;
        Color backgroundColor;

        if (success) {
          await _checkAdFreeStatus(); // Обновляем статус
          message = 'Покупка успешно завершена! Реклама отключена.';
          backgroundColor = Colors.green;
        } else {
          message = 'Покупка не удалась. Попробуйте позже.';
          backgroundColor = Colors.red;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка покупки: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Восстановление покупок
  Future<void> _restorePurchases() async {
    try {
      await RustorePayService.restorePurchases();
      if (mounted) {
        final isAdFree = await RustorePayService.isAdFree();
        String message;
        Color backgroundColor;

        if (isAdFree) {
          message = 'Покупки успешно восстановлены! Реклама отключена.';
          backgroundColor = Colors.green;
        } else {
          message = 'Активные покупки не найдены.';
          backgroundColor = Colors.orange;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: backgroundColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка восстановления: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF64B5F6), Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 60, left: 12, right: 12, bottom: 12),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCompactCard(
                  title: 'Профиль',
                  child: Column(
                    children: [
                      _buildTextFieldRow([
                        _buildStylishTextField(
                          controller: weightController,
                          label: 'Вес (кг)',
                          error: _weightError,
                          icon: Icons.fitness_center,
                        ),
                        _buildStylishTextField(
                          controller: heightController,
                          label: 'Рост (см)',
                          error: _heightError,
                          icon: Icons.height,
                        ),
                      ]),
                      const SizedBox(height: 6),
                      _buildActivitySlider(),
                      const SizedBox(height: 6),
                      _buildDailyNormRow(),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildCompactCard(
                  title: 'Погода',
                  child: Row(
                    children: [
                      Expanded(child: _buildWeatherSummary()),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _fetchWeather,
                        icon: const Icon(Icons.refresh, color: Colors.blue),
                        tooltip: 'Обновить',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildCompactCard(
                  title: 'VIP',
                  child: Row(
                    children: [
                      Icon(_isAdFree ? Icons.verified : Icons.diamond, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_isAdFree ? 'Реклама отключена' : 'Уберите рекламу и поддержите нас')),
                      IconButton(
                        onPressed: _isAdFree ? null : _purchaseRemoveAds,
                        icon: const Icon(Icons.currency_ruble, color: Colors.green),
                        tooltip: 'Купить',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildCompactCard(
                  title: '',
                  child: Column(
                    children: [
                      SizedBox(height: 44, width: double.infinity, child: _buildPrimarySaveButton()),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1976D2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            foregroundColor: const Color(0xFF1976D2),
                          ),
                          icon: const Icon(Icons.slideshow),
                          label: const Text('Показать экран первого входа'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🎨 Стильный заголовок экрана
  Widget _buildStylishHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 70, bottom: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 15),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Настройки', 
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              Text('Персонализируй свой опыт', 
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  /// 🎭 Карточка настроек с градиентом
  Widget _buildSettingsCard({
    required String title,
    required IconData icon,
    required Gradient gradient,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок с градиентом
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Содержимое карточки
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  /// 🧩 Компактная карточка (плоская, без большого хедера)
  Widget _buildCompactCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  /// 📝 Стильное текстовое поле
  Widget _buildStylishTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? error,
  }) {
    return Expanded(
      child: SizedBox(
        height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error != null ? Colors.red.shade300 : Colors.grey.shade300,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }

  /// 📏 Строка с текстовыми полями
  Widget _buildTextFieldRow(List<Widget> fields) {
    return Row(
      children: [
        for (int i = 0; i < fields.length; i++) ...[
          fields[i],
          if (i < fields.length - 1) const SizedBox(width: 12),
        ]
      ],
    );
  }

  /// 🍬 Всплывающее сообщение
  void _showSnack(String message) {
    // Показываем краткое уведомление пользователю
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// ⚡ Быстрое действие (иконка + подпись)
  // Используем локальный виджет для компактных кнопок
  // Комментарии на русском для ясности
  Widget _QuickAction({required IconData icon, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1976D2), size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  /// 🏃 Слайдер уровня активности
  Widget _buildActivitySlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Уровень активности',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
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
                  const Text('Низкий', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text('Уровень $activityLevel', 
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const Text('Высокий', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              Slider(
                value: activityLevel.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                activeColor: Colors.blue,
                onChanged: (value) {
                  setState(() {
                    activityLevel = value.toInt();
                  });
                  _updateDailyNorm();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 💧 Отображение дневной нормы
  Widget _buildDailyNormRow() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4facfe), Color(0xFF00f2fe)]),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.local_drink, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Text('Дневная норма', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const Spacer(),
          Text('${dailyNormController.text} мл',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// 🌤️ Секция погоды
  Widget _buildWeatherSection() {
    return Column(
      children: [
        if (_isLoadingWeather)
          const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Получение данных о погоде...')
            ],
          )
        else if (_weatherError != null)
          Row(
            children: [
              Icon(Icons.error, color: Colors.red.shade400, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(_weatherError!, style: const TextStyle(color: Colors.red))),
            ],
          )
        else if (_temperature != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.thermostat, color: Colors.orange.shade600, size: 24),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущая температура: ${_temperature!.round()}°C',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    Text(
                      _temperature! >= 30 ? 'Жаркая погода - норма увеличена' : 'Комфортная погода',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Краткий вид погоды для компактной карточки
  Widget _buildWeatherSummary() {
    if (_isLoadingWeather) {
      return const Row(children: [SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Загрузка...')]);
    }
    if (_weatherError != null) {
      return Row(children: [Icon(Icons.error, color: Colors.red.shade400, size: 18), const SizedBox(width: 8), Expanded(child: Text(_weatherError!, maxLines: 2))]);
    }
    if (_temperature != null) {
      final hot = _temperature! >= 30;
      return Row(children: [
        Icon(Icons.thermostat, color: hot ? Colors.orange : Colors.blue, size: 20),
        const SizedBox(width: 8),
        Text('${_temperature!.round()}°C'),
        const SizedBox(width: 8),
        Text(hot ? 'Жара' : 'Комфорт', style: TextStyle(color: Colors.grey.shade600)),
      ]);
    }
    return const Text('Нет данных');
  }

  /// 🔔 Настройки уведомлений
  Widget _buildNotificationSettings() {
    return const Column(
      children: [
        ListTile(
          leading: Icon(Icons.alarm, color: Colors.blue),
          title: Text('Настройка напоминаний'),
          subtitle: Text('Перейдите в раздел "Напоминания" для настройки'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }

  /// 💎 Премиум секция
  Widget _buildPremiumSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.remove_circle_outline, color: Colors.orange),
          title: Text(_isAdFree ? 'Реклама отключена' : 'Отключить рекламу'),
          subtitle: Text(_isAdFree ? 'Спасибо за поддержку!' : 'Убрать рекламные баннеры'),
          trailing: _isAdFree 
            ? const Icon(Icons.check, color: Colors.green)
            : const Icon(Icons.arrow_forward_ios, size: 16),
          contentPadding: EdgeInsets.zero,
          onTap: _isAdFree ? null : _purchaseRemoveAds,
        ),
        if (!_isAdFree) const SizedBox(height: 12),
        if (!_isAdFree)
          ListTile(
            leading: const Icon(Icons.restore, color: Colors.purple),
            title: const Text('Восстановить покупки'),
            subtitle: const Text('Проверить существующие покупки'),
            contentPadding: EdgeInsets.zero,
            onTap: _restorePurchases,
          ),
      ],
    );
  }

  /// ⭐ Секция отзывов
  Widget _buildReviewSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.star, color: Colors.amber),
          title: const Text('Оценить приложение'),
          subtitle: const Text('Оставьте отзыв в RuStore'),
          contentPadding: EdgeInsets.zero,
          onTap: _requestReview,
        ),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.info, color: Colors.blue),
          title: const Text('Статистика отзывов'),
          subtitle: const Text('Показать информацию о запросах'),
          contentPadding: EdgeInsets.zero,
          onTap: _showReviewStats,
        ),
      ],
    );
  }

  /// ⚠️ Опасная зона
  Widget _buildDangerZone() {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('Сбросить все данные'),
      subtitle: const Text('Удалить все настройки и историю'),
      contentPadding: EdgeInsets.zero,
      onTap: _resetData,
    );
  }

  /// 💾 Стильная кнопка сохранения (полноразмерная)
  Widget _buildStylishSaveButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _saveSettings,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.save, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Text(
              'Сохранить настройки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 💾 Кнопка для компактной карточки
  Widget _buildPrimarySaveButton({bool textless = false}) {
    return ElevatedButton.icon(
      onPressed: _saveSettings,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.save),
      label: textless ? const SizedBox.shrink() : const Text('Сохранить'),
    );
  }
}
