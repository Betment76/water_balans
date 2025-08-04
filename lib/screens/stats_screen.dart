import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/weather_service.dart';
import '../providers/user_settings_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:water_balance/l10n/app_localizations.dart'; // Измененный импорт

const Color kBlue = Color(0xFF1976D2);
const Color kLightBlue = Color(0xFF64B5F6);
const Color kWhite = Colors.white;

/// Экран статистики
class StatsScreen extends ConsumerWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userSettings = ref.watch(userSettingsProvider);
    final int dailyGoal = userSettings?.dailyNormML ?? 2000;
    
    // Заглушки для данных
    final List<int> last7days = [1200, 1500, dailyGoal, 1800, 1700, dailyGoal, 1600];
    final int average = (last7days.reduce((a, b) => a + b) / last7days.length).round();
    final int streak = 3;

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statsTitle),
        centerTitle: true,
        backgroundColor: kBlue,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userSettings?.isWeatherEnabled == true)
              const _WeatherCard(),
            if (userSettings?.isWeatherEnabled == true)
              const SizedBox(height: 20),
            const Text(
              'Последние 7 дней',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kBlue),
            ),
            const SizedBox(height: 16),
            // График за 7 дней
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: dailyGoal.toDouble() + 400,
                  minY: 0,
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                          return Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              days[value.toInt() % 7],
                              style: TextStyle(color: kBlue, fontWeight: FontWeight.w600),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                  ),
                  barGroups: List.generate(7, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: last7days[i].toDouble(),
                          color: last7days[i] >= dailyGoal ? kBlue : kLightBlue,
                          width: 22,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatCard(title: 'Среднее', value: '$average мл'),
                _StatCard(title: 'Серия', value: '$streak дней'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Виджет погоды (по текущему местоположению)
class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  double? _temperature;
  String? _city;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    print('[WeatherCard] _fetchWeather called');
    setState(() {
      _loading = true;
      _error = null;
      _city = null;
    });
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      print('[WeatherCard] permission: $permission');
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('[WeatherCard] Нет разрешения, вызываю WeatherService.fetchTemperatureByCity');
        double? temp = await WeatherService.fetchTemperatureByCity('Москва');
        print('[WeatherCard] После WeatherService.fetchTemperatureByCity, temp: $temp');
        setState(() {
          _temperature = temp;
          _city = 'Москва';
          _error = 'Нет доступа к геолокации, показана погода для Москвы';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      print('[WeatherCard] Координаты: ${pos.latitude}, ${pos.longitude}');
      print('[WeatherCard] Вызываю WeatherService.fetchTemperature');
      double? temp = await WeatherService.fetchTemperature(latitude: pos.latitude, longitude: pos.longitude);
      print('[WeatherCard] После WeatherService.fetchTemperature, temp: $temp');
      String? city;
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          city = placemarks.first.locality ?? placemarks.first.administrativeArea ?? placemarks.first.country;
        }
      } catch (e) {
        print('[WeatherCard] Ошибка определения города: $e');
      }
      setState(() {
        _temperature = temp;
        _city = city;
        _loading = false;
      });
    } catch (e) {
      print('[WeatherCard] Exception: $e');
      setState(() {
        _error = 'Ошибка определения погоды';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[WeatherCard] build called');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        color: kBlue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.wb_sunny, color: kWhite, size: 38),
          const SizedBox(width: 16),
          Expanded(
            child: _loading
                ? const Text('Загрузка погоды...', style: TextStyle(color: kWhite, fontSize: 18))
                : (_temperature != null
                    ? Text('${_temperature!.round()}°C${_city != null ? ', $_city' : ''}', style: const TextStyle(color: kWhite, fontSize: 20, fontWeight: FontWeight.bold))
                    : Text(_error ?? 'Нет данных о погоде', style: const TextStyle(color: kWhite, fontSize: 18)) ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: kWhite),
            onPressed: _fetchWeather,
            tooltip: 'Обновить',
          ),
        ],
      ),
    );
  }
}

/// Карточка для показателей
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: kLightBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kBlue),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 16, color: kBlue),
          ),
        ],
      ),
    );
  }
}