import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';
import '../providers/user_settings_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:water_balance/l10n/app_localizations.dart';
import '../services/storage_service.dart';
import '../models/water_intake.dart';

const Color kBlue = Color(0xFF1976D2);
const Color kLightBlue = Color(0xFF64B5F6);
const Color kWhite = Colors.white;

/// Экран статистики
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  List<int> last7days = [];
  int average = 0;
  int streak = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  /// 📊 Загружаем реальную статистику вместо заглушек
  Future<void> _loadRealStats() async {
    try {
      final userSettings = ref.read(userSettingsProvider);
      final int dailyGoal = userSettings?.dailyNormML ?? 2000;
      
      // Получаем данные за последние 7 дней
      final List<int> realData = [];
      final now = DateTime.now();
      
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final intakes = await StorageService.getWaterIntakesForDate(date);
        final totalForDay = intakes.fold(0, (sum, intake) => sum + intake.volumeML);
        realData.add(totalForDay);
      }
      
      // Вычисляем среднее значение
      final avgValue = realData.isEmpty 
        ? 0 
        : (realData.reduce((a, b) => a + b) / realData.length).round();
      
      // Вычисляем серию достижений (подряд выполненных дней)
      int currentStreak = 0;
      for (int i = realData.length - 1; i >= 0; i--) {
        if (realData[i] >= dailyGoal) {
          currentStreak++;
        } else {
          break;
        }
      }
      
      setState(() {
        last7days = realData;
        average = avgValue;
        streak = currentStreak;
        isLoading = false;
      });
      
    } catch (e) {
      print('Ошибка загрузки статистики: $e');
      // В случае ошибки используем дефолтные значения
      setState(() {
        last7days = [0, 0, 0, 0, 0, 0, 0];
        average = 0;
        streak = 0;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userSettings = ref.watch(userSettingsProvider);
    final int dailyGoal = userSettings?.dailyNormML ?? 2000;

    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statsTitle),
        centerTitle: true,
        backgroundColor: kBlue,
        foregroundColor: kWhite,
        elevation: 0,
        actions: [
          // 🔄 Кнопка обновления статистики
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() { isLoading = true; });
              _loadRealStats();
            },
            tooltip: 'Обновить статистику',
          ),
        ],
      ),
      body: isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: kBlue),
                SizedBox(height: 16),
                Text('Загружаем вашу статистику...', style: TextStyle(color: kBlue)),
              ],
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadRealStats,
            color: kBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userSettings?.isWeatherEnabled == true)
                    const _WeatherCard(),
                  if (userSettings?.isWeatherEnabled == true)
                    const SizedBox(height: 20),
                  
                  // 🎯 Мотивационный заголовок
                  _buildMotivationalHeader(),
                  const SizedBox(height: 20),
                  
                  const Text(
                    '📊 Последние 7 дней',
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
                  // 📊 График за 7 дней (обновленный)
                  _buildWeeklyChart(dailyGoal),
                  const SizedBox(height: 24),
                  
                  // 📈 Статистические карточки с улучшенным дизайном
                  _buildStatsCards(),
                  const SizedBox(height: 24),
                  
                  // 🏆 Достижения и инсайты
                  _buildAchievements(dailyGoal),
                  const SizedBox(height: 24),
                  
                  // 📋 Умные рекомендации
                  _buildSmartInsights(dailyGoal),
                  
                ],
              ),
            ),
          ),
    );
  }

  /// 🎯 Мотивационный заголовок
  Widget _buildMotivationalHeader() {
    String message = '';
    IconData icon = Icons.water_drop;
    Color color = kBlue;

    if (streak > 0) {
      message = '🔥 Отлично! $streak ${_getDaysText(streak)} подряд!';
      icon = Icons.local_fire_department;
      color = Colors.orange;
    } else if (average > 0) {
      message = '💪 Продолжай в том же духе!';
      icon = Icons.trending_up;
      color = Colors.green;
    } else {
      message = '🌟 Начни свой путь к здоровью!';
      icon = Icons.rocket_launch;
      color = kBlue;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 Улучшенный график
  Widget _buildWeeklyChart(int dailyGoal) {
    if (last7days.isEmpty) {
      return const Center(
        child: Text('Нет данных для отображения', style: TextStyle(color: kBlue)),
      );
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (dailyGoal + 500).toDouble(),
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            horizontalInterval: dailyGoal / 4,
            getDrawingHorizontalLine: (value) => FlLine(
              color: kLightBlue.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      days[value.toInt() % 7],
                      style: const TextStyle(
                        color: kBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
                reservedSize: 28,
              ),
            ),
          ),
          barGroups: List.generate(last7days.length, (i) {
            final value = last7days[i];
            final percentage = dailyGoal > 0 ? value / dailyGoal : 0;
            
            Color barColor;
            if (percentage >= 1.0) {
              barColor = Colors.green; // Цель достигнута
            } else if (percentage >= 0.8) {
              barColor = Colors.orange; // Близко к цели
            } else {
              barColor = kLightBlue; // Далеко от цели
            }

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: value.toDouble(),
                  color: barColor,
                  width: 24,
                  borderRadius: BorderRadius.circular(8),
                  // Градиент для красивого эффекта
                  gradient: LinearGradient(
                    colors: [barColor, barColor.withOpacity(0.7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
              showingTooltipIndicators: value > 0 ? [0] : [],
            );
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final value = last7days[group.x.toInt()];
                final days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
                return BarTooltipItem(
                  '${days[group.x.toInt()]}\n$value мл',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 📈 Улучшенные статистические карточки
  Widget _buildStatsCards() {
    final totalWeek = last7days.fold(0, (sum, day) => sum + day);
    final maxDay = last7days.isEmpty ? 0 : last7days.reduce((a, b) => a > b ? a : b);
    
    return Row(
      children: [
        Expanded(child: _StatCard(
          title: '📊 Среднее/день',
          value: '$average мл',
          subtitle: 'за неделю',
          color: kBlue,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          title: '🔥 Серия',
          value: '$streak ${_getDaysText(streak)}',
          subtitle: 'подряд',
          color: Colors.orange,
        )),
        const SizedBox(width: 12),
        Expanded(child: _StatCard(
          title: '💧 За неделю',
          value: '${(totalWeek / 1000).toStringAsFixed(1)} л',
          subtitle: 'всего',
          color: Colors.green,
        )),
      ],
    );
  }

  /// 🏆 Система достижений
  Widget _buildAchievements(int dailyGoal) {
    final achievements = <Map<String, dynamic>>[];
    
    // Проверяем различные достижения
    if (streak >= 7) {
      achievements.add({
        'icon': '🏆',
        'title': 'Недельный чемпион',
        'description': 'Неделя подряд выполняете норму!',
        'unlocked': true,
      });
    }
    
    if (last7days.isNotEmpty && last7days.last >= dailyGoal * 1.2) {
      achievements.add({
        'icon': '⚡',
        'title': 'Превосходство',
        'description': 'Превысили дневную норму на 20%!',
        'unlocked': true,
      });
    }
    
    if (average >= dailyGoal) {
      achievements.add({
        'icon': '🎯',
        'title': 'Стабильность',
        'description': 'Среднее потребление выше нормы!',
        'unlocked': true,
      });
    }

    // Заблокированные достижения для мотивации
    if (streak < 3) {
      achievements.add({
        'icon': '🥉',
        'title': 'Новичок',
        'description': 'Выполните норму 3 дня подряд',
        'unlocked': false,
      });
    }

    if (achievements.isEmpty) {
      achievements.add({
        'icon': '🌟',
        'title': 'Первые шаги',
        'description': 'Начните отслеживать потребление воды!',
        'unlocked': false,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏆 Достижения',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kBlue),
        ),
        const SizedBox(height: 12),
        ...achievements.map((achievement) => _buildAchievementCard(achievement)),
      ],
    );
  }

  /// 🏅 Карточка достижения
  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final isUnlocked = achievement['unlocked'] as bool;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? Colors.amber.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            achievement['icon'] as String,
            style: TextStyle(
              fontSize: 24,
              color: isUnlocked ? Colors.black : Colors.black.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement['title'] as String,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isUnlocked ? kBlue : Colors.grey,
                  ),
                ),
                Text(
                  achievement['description'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked ? kBlue.withOpacity(0.7) : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (isUnlocked)
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  /// 📋 Умные рекомендации
  Widget _buildSmartInsights(int dailyGoal) {
    final insights = <String>[];
    
    if (last7days.isEmpty || last7days.every((day) => day == 0)) {
      insights.add('💡 Начните с малого - добавьте стакан воды с утра!');
    } else {
      if (average < dailyGoal * 0.8) {
        insights.add('💧 Попробуйте пить воду небольшими порциями в течение дня');
        insights.add('⏰ Настройте напоминания каждые 2 часа');
      }
      
      if (streak == 0) {
        insights.add('🎯 Сосредоточьтесь на одном дне - выполните сегодняшнюю норму!');
      }
      
      final maxDay = last7days.reduce((a, b) => a > b ? a : b);
      if (maxDay >= dailyGoal && average < dailyGoal) {
        insights.add('👍 Вы можете выполнять норму - будьте более постоянны!');
      }
    }
    
    if (insights.isEmpty) {
      insights.add('🌟 Отличная работа! Продолжайте в том же духе!');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '💡 Рекомендации',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kBlue),
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: kLightBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kLightBlue.withOpacity(0.3)),
          ),
          child: Text(
            insight,
            style: const TextStyle(color: kBlue, fontSize: 14),
          ),
        )),
      ],
    );
  }

  /// Склонение слова "день"
  String _getDaysText(int days) {
    if (days % 10 == 1 && days % 100 != 11) return 'день';
    if ([2, 3, 4].contains(days % 10) && ![12, 13, 14].contains(days % 100)) return 'дня';
    return 'дней';
  }
}

/// Виджет погоды (по текущему местоположению)
class _WeatherCard extends StatefulWidget {
  const _WeatherCard();

  @override
  State<_WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<_WeatherCard> {
  WeatherData? _weatherData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
          _error = 'Нет доступа к геолокации';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final weather = await WeatherService.fetchWeather(latitude: pos.latitude, longitude: pos.longitude);
      if (!mounted) return;
      setState(() {
        _weatherData = weather;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка определения погоды';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                : (_weatherData != null
                    ? Text('${_weatherData!.temperature.round()}°C${_weatherData!.city != null ? ', ${_weatherData!.city}' : ''}', style: const TextStyle(color: kWhite, fontSize: 20, fontWeight: FontWeight.bold))
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
/// Карточка со статистикой (улучшенная)
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final Color? color;

  const _StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = color ?? kBlue;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardColor.withOpacity(0.1),
            cardColor.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: cardColor.withOpacity(0.8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: cardColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                color: cardColor.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}