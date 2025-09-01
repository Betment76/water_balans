import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:water_balance/providers/user_settings_provider.dart';
import 'package:water_balance/services/notification_service.dart';
import 'package:water_balance/services/storage_service.dart';
import 'package:water_balance/models/water_intake.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:water_balance/models/weather_data.dart';
import 'package:water_balance/services/calculation_service.dart';
import 'package:water_balance/services/weather_service.dart';
import 'package:water_balance/services/rustore_review_service.dart';
import 'package:water_balance/widgets/bubble_widget.dart';
import 'package:water_balance/widgets/fish_widget.dart';

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
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final weather = await WeatherService.fetchWeatherByCity('Moscow');
        if (!mounted) return;
        setState(() {
          _weatherData = weather != null
              ? WeatherData(
                  temperature: weather.temperature,
                  condition: weather.condition,
                  city: null,
                )
              : null;
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final weather = await WeatherService.fetchWeather(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _weatherData = weather;
      });
    } catch (e) {
      print('Ошибка при получении погоды: $e');
    }
  }

  Widget _buildAddWaterButton(int amount) {
    return ElevatedButton(
      onPressed: () => _addWater(amount),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      child: Text('$amount мл'),
    );
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
        title: const Text('Водный баланс'),
        centerTitle: true,
        actions: [
          if (_weatherData != null)
            Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_weatherData!.temperature.round()}°C',
                    style: const TextStyle(fontSize: 20),
                  ),
                  if (_weatherData!.city != null)
                    Text(
                      _weatherData!.city!,
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 20),
            _Aquarium(percentage: percentage, waterIntake: _waterIntake),
            const SizedBox(height: 20),
            Text(
              '$_waterIntake / $waterGoal мл',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12.0,
              alignment: WrapAlignment.center,
              children: [
                _buildAddWaterButton(50),
                _buildAddWaterButton(100),
                _buildAddWaterButton(150),
                _buildAddWaterButton(200),
                _buildAddWaterButton(250),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getWeatherIcon(String condition) {
    switch (condition) {
      case 'Clear':
        return const Icon(Icons.wb_sunny, color: Colors.orange);
      case 'Clouds':
        return const Icon(Icons.wb_cloudy, color: Colors.white);
      case 'Rain':
        return const Icon(Icons.beach_access, color: Colors.white);
      case 'Thunderstorm':
        return const Icon(Icons.flash_on, color: Colors.yellow);
      default:
        return const Icon(Icons.thermostat, color: Colors.white);
    }
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
            BubblesWidget(waterHeight: waterHeight),

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
