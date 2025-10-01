import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:water_balance/providers/user_settings_provider.dart';
import 'package:water_balance/providers/achievements_provider.dart';
import 'package:water_balance/services/notification_service.dart';
import 'package:water_balance/services/storage_service.dart';
import 'package:water_balance/services/achievements_service.dart';
import 'package:water_balance/models/water_intake.dart';
import 'package:water_balance/models/achievement.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:water_balance/models/weather_data.dart';
import 'package:water_balance/services/calculation_service.dart';
import 'package:water_balance/services/weather_service.dart';
import 'package:water_balance/services/rustore_review_service.dart';
import 'package:water_balance/widgets/bubble_widget.dart';
import 'package:water_balance/widgets/fish_widget.dart';
import '../widgets/banner_ad_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _waterIntake = 0;
  int _totalWaterAddedToday = 0; // Счётчик добавленной воды за день
  StreamSubscription? _activitySubscription;
  WeatherData? _weatherData;

  @override
  void initState() {
    super.initState();
    _activitySubscription = CalculationService.activityBasedAddition.listen((
      addition,
    ) {
      final settings = ref.read(userSettingsProvider);
      if (settings != null) {
        final newGoal = settings.dailyNormML + addition;
        ref
            .read(userSettingsProvider.notifier)
            .save(settings.copyWith(dailyNormML: newGoal));
      }
    });
    _fetchWeather();
    _loadTodaysIntake();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    super.dispose();
  }

  void _addWater(int amount) async {
    setState(() {
      _waterIntake += amount;
      _totalWaterAddedToday += amount;
    });

    final newIntake = WaterIntake(
      id: DateTime.now().toIso8601String(),
      volumeML: amount,
      dateTime: DateTime.now(),
    );

    final intakes = await StorageService.loadWaterIntakes();
    intakes.add(newIntake);
    await StorageService.saveWaterIntakes(intakes);

    // 🏆 Отслеживание достижений - новая супер-фича!
    await _trackAchievements(amount);

    // Reschedule notifications after adding water
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      await NotificationService.scheduleReminders(
        settings,
        lastIntake: DateTime.now(),
      );
    }

    // Проверяем, нужно ли показать отзыв
    _checkForReviewRequest();
  }

  /// 🏆 Отслеживание достижений при добавлении воды (ТОЧНЫЕ ДАННЫЕ!)
  Future<void> _trackAchievements(int amount) async {
    try {
      debugPrint('🏆 ОТСЛЕЖИВАНИЕ: Добавлено ${amount}мл, всего сегодня: ${_waterIntake}мл');
      
      final achievementsService = ref.read(achievementsServiceProvider);
      
      // 📊 РЕАЛЬНЫЙ расчет общего объема из базы данных
      int totalVolume = 0;
      try {
        // Загружаем ВСЕ записи потребления воды за все время
        final allIntakes = await StorageService.loadWaterIntakes();
        totalVolume = allIntakes.fold(0, (sum, intake) => sum + intake.volumeML);
        debugPrint('🏆 ОТСЛЕЖИВАНИЕ: РЕАЛЬНЫЙ общий объем за все время: ${totalVolume}мл (${(totalVolume/1000).toStringAsFixed(1)}л)');
      } catch (e) {
        debugPrint('🏆 ОТСЛЕЖИВАНИЕ: ОШИБКА загрузки данных: $e');
        totalVolume = _waterIntake; // минимальная оценка - только сегодняшнее потребление
      }
      
      // Отправляем событие добавления воды
      debugPrint('🏆 ОТСЛЕЖИВАНИЕ: Отправляем событие waterAdded');
      final newAchievements = await achievementsService.handleEvent(
        AchievementEvent.waterAdded,
        data: {
          'amount': amount,
          'todayTotal': _waterIntake,
          'totalVolume': totalVolume,
        },
      );

      debugPrint('🏆 ОТСЛЕЖИВАНИЕ: Получено ${newAchievements.length} новых достижений');

      // Проверяем достижение дневной цели
      final settings = ref.read(userSettingsProvider);
      if (settings != null && _waterIntake >= settings.dailyNormML) {
        debugPrint('🏆 ОТСЛЕЖИВАНИЕ: Дневная цель достигнута!');
        final goalAchievements = await achievementsService.handleEvent(
          AchievementEvent.dayGoalReached,
        );
        newAchievements.addAll(goalAchievements);
      }

      // 🎉 Показываем уведомления о новых достижениях
      if (newAchievements.isNotEmpty) {
        debugPrint('🏆 ОТСЛЕЖИВАНИЕ: Показываем ${newAchievements.length} уведомлений');
        _showAchievementNotifications(newAchievements);
      } else {
        debugPrint('🏆 ОТСЛЕЖИВАНИЕ: Новых достижений нет');
      }
    } catch (e) {
      debugPrint('🏆 ОШИБКА отслеживания достижений: $e');
    }
  }

  /// 🎉 Показ уведомлений о новых достижениях
  void _showAchievementNotifications(List<Achievement> achievements) {
    for (final achievement in achievements) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(achievement.icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🏆 Достижение разблокировано!', 
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(achievement.title, 
                      style: const TextStyle(color: Colors.white)),
                    Text('+${achievement.reward} XP', 
                      style: TextStyle(color: Colors.amber.shade200, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: achievement.color,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Проверяем, нужно ли показать запрос на отзыв
  void _checkForReviewRequest() async {
    try {
      final userSettings = ref.read(userSettingsProvider);
      if (userSettings == null) return;

      final waterGoal = userSettings.dailyNormML;
      final percentage = (_waterIntake / waterGoal).clamp(0.0, 1.0);

      // Показываем отзыв при достижении 75% дневной нормы
      // или после добавления 1000мл воды за день
      if (percentage >= 0.75 || _totalWaterAddedToday >= 1000) {
        final success = await RuStoreReviewService.requestReview();
        if (success) {
          print('Отзыв успешно запрощен');
          // Сбрасываем счётчик, чтобы не показывать отзыв повторно
          _totalWaterAddedToday = 0;
        }
      }
    } catch (e) {
      print('Ошибка при проверке отзыва: $e');
    }
  }

  Future<void> _loadTodaysIntake() async {
    final intakes = await StorageService.getWaterIntakesForDate(DateTime.now());
    setState(() {
      _waterIntake = intakes.fold(0, (sum, item) => sum + item.volumeML);
      _totalWaterAddedToday = _waterIntake; // Инициализируем счётчик
    });
  }

  Future<void> _fetchWeather() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() { _weatherData = null; });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final weather = await WeatherService.fetchWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() { _weatherData = weather; });
    } catch (e) {
      print('Ошибка при получении погоды: $e');
      if (!mounted) return;
      setState(() { _weatherData = null; });
    }
  }


  /// Стильная кнопка добавления воды с градиентом
  Widget _buildStylishWaterButton(int amount) {
    // Цветовая схема в зависимости от количества
    List<Color> gradientColors;
    switch (amount) {
      case 50:
        gradientColors = [Colors.blue.shade300, Colors.blue.shade500];
        break;
      case 100:
        gradientColors = [Colors.green.shade300, Colors.green.shade500];
        break;
      case 150:
        gradientColors = [Colors.orange.shade300, Colors.orange.shade500];
        break;
      case 200:
        gradientColors = [Colors.purple.shade300, Colors.purple.shade500];
        break;
      case 250:
        gradientColors = [Colors.red.shade300, Colors.red.shade500];
        break;
      default:
        gradientColors = [Colors.blue.shade300, Colors.blue.shade500];
    }

    return GestureDetector(
      onTap: () => _addWater(amount),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_drink, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text('$amount мл', 
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// Старый метод для совместимости (на всякий случай)
  Widget _buildAddWaterButton(int amount) {
    return _buildStylishWaterButton(amount);
  }

  @override
  Widget build(BuildContext context) {
    final userSettings = ref.watch(userSettingsProvider);
    final waterGoal = userSettings?.dailyNormML ?? 2000;
    final double percentage = (_waterIntake / waterGoal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        leading: _weatherData != null
            ? _getWeatherIcon(_weatherData!.condition)
            : null,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💧 Водный баланс', 
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            if (_weatherData?.city != null)
              Text(_weatherData!.city!, 
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        actions: [
          if (_weatherData != null)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '${_weatherData!.temperature.round()}°C',
                style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF64B5F6), Colors.white],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          children: [
            // MyTarget показывает глобальный баннер автоматически
            const SizedBox(height: 50),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    // 🏆 Мини-виджет уровня пользователя вверху
                    _UserLevelWidget(),
                    
                    // 🐠 Аквариум без контейнера
                    _Aquarium(percentage: percentage, waterIntake: _waterIntake),
                    
                    // 💧 Информация о выпитом и цели (без контейнера)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text('$_waterIntake мл', 
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                            const Text('Выпито', 
                              style: TextStyle(fontSize: 14, color: Colors.blue)),
                          ],
                        ),
                        Column(
                          children: [
                            Text('$waterGoal мл', 
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                            const Text('Цель', 
                              style: TextStyle(fontSize: 14, color: Colors.green)),
                          ],
                        ),
                      ],
                    ),
                    
                    // 🎨 Кнопки добавления воды без контейнера
                    Column(
                      children: [
                        // Первая строка: 3 кнопки
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStylishWaterButton(50),
                            _buildStylishWaterButton(100),
                            _buildStylishWaterButton(150),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Вторая строка: 2 кнопки по центру
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStylishWaterButton(200),
                            const SizedBox(width: 20),
                            _buildStylishWaterButton(250),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20), // небольшой отступ снизу
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getWeatherIcon(String condition) {
    final c = condition.toLowerCase();
    if (c.contains('clear') || c.contains('sun')) {
      return const Icon(Icons.wb_sunny, color: Colors.orange);
    }
    if (c.contains('cloud')) {
      return const Icon(Icons.cloud, color: Colors.white);
    }
    if (c.contains('rain') || c.contains('drizzle')) {
      return const Icon(Icons.beach_access, color: Colors.white);
    }
    if (c.contains('snow')) {
      return const Icon(Icons.ac_unit, color: Colors.white);
    }
    if (c.contains('thunder')) {
      return const Icon(Icons.flash_on, color: Colors.yellow);
    }
    if (c.contains('mist') || c.contains('fog')) {
      return const Icon(Icons.cloud_queue, color: Colors.white);
    }
    return const Icon(Icons.cloud, color: Colors.white);
  }
}

/// 🏆 Мини-виджет уровня пользователя на главном экране
class _UserLevelWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userStats = ref.watch(userStatsProvider);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Иконка уровня
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.trending_up, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          
          // Текст уровня
          Text('Уровень ${userStats['level'] ?? 1}', 
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          
          // Мини прогресс-бар
          Container(
            width: 60,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: _calculateLevelProgress(userStats),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // XP текст
          Text('${userStats['xp'] ?? 0} XP', 
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
        ],
      ),
    );
  }

  /// Расчет прогресса уровня (0.0 - 1.0)
  double _calculateLevelProgress(Map<String, int> stats) {
    final currentXp = stats['xp'] ?? 0;
    final nextLevelXp = stats['nextLevelXp'] ?? 1000;
    return ((currentXp % nextLevelXp) / nextLevelXp).clamp(0.0, 1.0);
  }
}

class _Aquarium extends StatelessWidget {
  final double percentage;
  final int waterIntake;

  const _Aquarium({required this.percentage, required this.waterIntake});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double aquariumSize = screenWidth * 0.8;
    final double waterHeight = aquariumSize * percentage;
    final double fishSize = (30 + 300 * percentage).clamp(
      30.0,
      aquariumSize * 0.8,
    );
    final bool isSwimming = waterHeight > fishSize;
    final double fishBottom = isSwimming ? (waterHeight - fishSize) / 2 : 0;

    return Container(
      width: aquariumSize,
      height: aquariumSize,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // Убрали градиент и тень для прозрачности
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Water
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: waterHeight,
              color: Colors.lightBlue.withOpacity(0.6),
            ),

            // Bubbles
            ExcludeSemantics(
              // отключаем семантику для анимированного слоя пузырьков
              child: RepaintBoundary(
                // изолируем перерисовки, чтобы не трогать соседние элементы
                child: BubblesWidget(waterHeight: waterHeight),
              ),
            ),

            // Fish
            if (waterIntake >= 300)
              Positioned(
                bottom: fishBottom,
                child: FishWidget(
                  progress: percentage,
                  isSwimming: isSwimming,
                  waterHeight: waterHeight,
                  fishSize: fishSize,
                  aquariumSize: aquariumSize,
                ),
              ),

            // Glossy Highlight
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.3),
                    Colors.white.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.6],
                ),
              ),
            ),

            // Border
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.withOpacity(
                    0.6,
                  ), // Более заметный синий контур
                  width: 3, // Немного тоньше
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
