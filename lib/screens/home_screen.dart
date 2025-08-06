import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:water_balance/providers/user_settings_provider.dart';
import 'package:water_balance/services/storage_service.dart';
import 'package:water_balance/models/water_intake.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:water_balance/models/weather_data.dart';
import 'package:water_balance/services/calculation_service.dart';
import 'package:water_balance/services/weather_service.dart';
import 'package:water_balance/widgets/bubble_widget.dart';
import 'package:water_balance/widgets/fish_widget.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Плагин для локальных уведомлений
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Общее количество выпитой воды
  int _waterIntake = 250;

  // Таймер для уведомлений
  Timer? _notificationTimer;
  StreamSubscription? _activitySubscription;
  WeatherData? _weatherData;

  @override
  void initState() {
    super.initState();
    // Инициализация настроек уведомлений
    _initializeNotifications();
    // Запуск таймера для проверки необходимости уведомлений
    _startNotificationTimer();
    // Подписка на поток активности
    _activitySubscription = CalculationService.activityBasedAddition.listen((addition) {
      final settings = ref.read(userSettingsProvider);
      if (settings != null) {
        final newGoal = settings.dailyNormML + addition;
        ref.read(userSettingsProvider.notifier).save(settings.copyWith(dailyNormML: newGoal));
      }
    });
    _fetchWeather();
    _loadTodaysIntake();
  }

  @override
  void dispose() {
    // Остановка таймера при уничтожении виджета
    _notificationTimer?.cancel();
    _activitySubscription?.cancel();
    super.dispose();
  }

  // Инициализация плагина уведомлений
  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Запрос разрешения на уведомления на Android 13+
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // Запуск таймера для отправки уведомлений
  void _startNotificationTimer() {
    // Проверяем каждые 5 минут
    _notificationTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      final waterGoal = ref.read(userSettingsProvider)?.dailyNormML ?? 2000;
      // Если выпито меньше 80% от цели, отправляем уведомление
      if ((_waterIntake / waterGoal) < 0.8) {
        _showNotification();
      }
    });
  }

  // Показать уведомление
  Future<void> _showNotification() async {
    // Детали уведомления для Android
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'water_balance_channel', // ID канала
      'Напоминания о воде', // Имя канала
      channelDescription: 'Напоминания, чтобы выпить воды и поддерживать баланс', // Описание канала
      importance: Importance.max, // Важность уведомления
      priority: Priority.high, // Приоритет уведомления
      showWhen: false, // Не показывать временную метку
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'), // Иконка для уведомления
    );

    // Общие детали уведомления
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // Показ уведомления
    await flutterLocalNotificationsPlugin.show(
      0, // ID уведомления
      'Спаси меня!', // Заголовок уведомления
      'Я умираю от жажды! Срочно выпей воды, иначе я превращусь в сушеную воблу!', // Текст уведомления
      platformChannelSpecifics, // Детали уведомления
      payload: 'item x', // Полезная нагрузка
    );
  }

  // Функция для добавления выпитой воды
  void _addWater(int amount) async {
    setState(() {
      _waterIntake += amount;
    });

    final newIntake = WaterIntake(
      id: DateTime.now().toIso8601String(),
      volumeML: amount,
      dateTime: DateTime.now(),
    );

    final intakes = await StorageService.loadWaterIntakes();
    intakes.add(newIntake);
    await StorageService.saveWaterIntakes(intakes);
  }

  Future<void> _loadTodaysIntake() async {
    final intakes = await StorageService.getWaterIntakesForDate(DateTime.now());
    setState(() {
      _waterIntake = intakes.fold(0, (sum, item) => sum + item.volumeML);
    });
  }

  Future<void> _fetchWeather() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        // Если нет разрешения, показываем погоду для Москвы
        final weather = await WeatherService.fetchWeatherByCity('Moscow');
        setState(() {
          _weatherData = weather;
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final weather = await WeatherService.fetchWeather(latitude: position.latitude, longitude: position.longitude);
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
    // Процент выпитой воды от цели
    final double percentage = (_waterIntake / waterGoal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        leading: _weatherData != null ? _getWeatherIcon(_weatherData!.condition) : null,
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
            // Виджет аквариума
            _Aquarium(percentage: percentage),
            const SizedBox(height: 20),
            // Отображение текущего прогресса
            Text(
              '$_waterIntake / $waterGoal мл',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            // Кнопки для быстрого добавления воды
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

// Виджет, представляющий аквариум
class _Aquarium extends StatelessWidget {
  final double percentage;

  const _Aquarium({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double aquariumSize = screenWidth * 0.8;
    final double waterHeight = aquariumSize * percentage;
    // Размер рыбки теперь зависит от прогресса
    final double fishSize = 30 + 40 * percentage;

    // Проверяем, достаточно ли воды для плавания
    final bool isSwimming = waterHeight > fishSize;

    // Позиция рыбки по вертикали
    // Если не плавает, она на дне. Иначе, плавает в пределах воды.
    final double fishBottom = isSwimming ? (waterHeight - fishSize) / 2 : 0;

    return Container(
      width: aquariumSize,
      height: aquariumSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue, width: 4),
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Анимация воды
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: waterHeight,
              color: Colors.lightBlue.withOpacity(0.5),
            ),
            // Пузырьки
            BubblesWidget(waterHeight: waterHeight),
            // Рыбка
            Positioned(
              bottom: fishBottom,
              child: FishWidget(
                progress: percentage,
                isSwimming: isSwimming, // Передаем состояние плавания
              ),
            ),
          ],
        ),
      ),
    );
  }
}