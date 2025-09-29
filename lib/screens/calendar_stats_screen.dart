import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../constants/app_colors.dart';
import '../models/water_intake.dart';
import '../models/user_settings.dart';
import '../providers/user_settings_provider.dart';
import '../services/storage_service.dart';
import '../widgets/banner_ad_widget.dart';

class CalendarStatsScreen extends ConsumerStatefulWidget {
  const CalendarStatsScreen({super.key});

  @override
  ConsumerState<CalendarStatsScreen> createState() => _CalendarStatsScreenState();
}

class _CalendarStatsScreenState extends ConsumerState<CalendarStatsScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  List<WaterIntake> _dayIntakes = [];
  Map<DateTime, int> _monthlyData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeLocale();
    _loadDayStats();
    _loadMonthlyData();
  }

  /// 🇷🇺 Инициализация русской локализации для календаря
  void _initializeLocale() {
    // Устанавливаем русскую локаль для календаря
    Intl.defaultLocale = 'ru_RU';
  }

  /// 📊 Загружаем статистику выбранного дня
  Future<void> _loadDayStats() async {
    try {
      setState(() => _isLoading = true);
      
      final intakes = await StorageService.getWaterIntakesForDate(_selectedDate);
      
      setState(() {
        _dayIntakes = intakes;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка загрузки статистики дня: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 📅 Загружаем данные за месяц для календаря
  Future<void> _loadMonthlyData() async {
    try {
      final monthData = <DateTime, int>{};
      final startOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
      final endOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
      
      for (DateTime date = startOfMonth; date.isBefore(endOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final intakes = await StorageService.getWaterIntakesForDate(date);
        final total = intakes.fold(0, (sum, intake) => sum + intake.volumeML);
        if (total > 0) {
          monthData[DateTime(date.year, date.month, date.day)] = total;
        }
      }
      
      setState(() {
        _monthlyData = monthData;
      });
    } catch (e) {
      print('Ошибка загрузки месячных данных: $e');
    }
  }

  /// 📊 Получаем цвет дня в календаре по количеству воды
  Color _getDayColor(DateTime day, int dailyGoal) {
    final amount = _monthlyData[DateTime(day.year, day.month, day.day)] ?? 0;
    if (amount == 0) return Colors.grey.shade100;
    
    final percentage = amount / dailyGoal;
    if (percentage >= 1.0) return Colors.green.shade300; // Цель достигнута
    if (percentage >= 0.75) return Colors.blue.shade400; // Больше 3/4
    if (percentage >= 0.5) return Colors.blue.shade300; // Половина
    return Colors.blue.shade100; // Мало воды
  }

  @override
  Widget build(BuildContext context) {
    final userSettings = ref.watch(userSettingsProvider);
    final dailyGoal = userSettings?.dailyNormML ?? 2000;
    final totalDay = _dayIntakes.fold(0, (sum, intake) => sum + intake.volumeML);

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Календарь-статистика', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: Column(
          children: [
            // 📺 Отступ под глобальный MyTarget баннер (50px + отступы)
            const SizedBox(height: 60),
            
            // 🗓️ КАЛЕНДАРЬ (верхняя часть)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20), // 🔼 Уменьшил отступ сверху в контейнере
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TableCalendar<int>(
                locale: 'ru_RU',
                firstDay: DateTime.now().subtract(const Duration(days: 365)),
                lastDay: DateTime.now(),
                focusedDay: _focusedDate,
                selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
                
                rowHeight: 30.0,
                
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  cellMargin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 0),
                  cellPadding: const EdgeInsets.all(0),
                  rowDecoration: const BoxDecoration(),
                  weekendTextStyle: const TextStyle(color: kBlue, fontSize: 14),
                  holidayTextStyle: const TextStyle(color: Colors.red, fontSize: 14),
                  defaultTextStyle: const TextStyle(fontSize: 14),
                  selectedDecoration: BoxDecoration(
                    color: kBlue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  todayDecoration: BoxDecoration(
                    color: kBlue.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  markerDecoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  headerPadding: EdgeInsets.only(top: 0, bottom: 2), // 🔼 Убрал отступ сверху от месяца
                  headerMargin: EdgeInsets.only(top: 0, bottom: 2), // 🔼 Поднял месяц ещё выше
                  titleTextStyle: TextStyle(
                    color: kBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: kBlue, fontWeight: FontWeight.w600, fontSize: 12),
                  weekendStyle: TextStyle(color: kBlue, fontWeight: FontWeight.w600, fontSize: 12),
                  decoration: BoxDecoration(),
                ),

                startingDayOfWeek: StartingDayOfWeek.monday,
                
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, day, focusedDay) {
                    final dayKey = DateTime(day.year, day.month, day.day);
                    final amount = _monthlyData[dayKey] ?? 0;
                    final color = _getDayColor(day, dailyGoal);
                    
                    return Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                color: amount > 0 ? kBlue : Colors.grey.shade600,
                                fontWeight: amount > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                            if (amount > 0) ...[
                              const SizedBox(width: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: kBlue,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  selectedBuilder: (context, day, focusedDay) {
                    final dayKey = DateTime(day.year, day.month, day.day);
                    final amount = _monthlyData[dayKey] ?? 0;
                    
                    return Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: kBlue,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (amount > 0) ...[
                              const SizedBox(width: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: kWhite,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                  todayBuilder: (context, day, focusedDay) {
                    final dayKey = DateTime(day.year, day.month, day.day);
                    final amount = _monthlyData[dayKey] ?? 0;
                    final color = _getDayColor(day, dailyGoal);
                    
                    return Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: kBlue, width: 2),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: const TextStyle(
                                color: kBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (amount > 0) ...[
                              const SizedBox(width: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  color: kBlue,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDate = selectedDay;
                    _focusedDate = focusedDay;
                  });
                  _loadDayStats();
                },
                
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDate = focusedDay;
                  });
                  _loadMonthlyData();
                },
                
                onHeaderTapped: (focusedDay) {
                  _showMonthStatistics(focusedDay);
                },
              ),
            ),
          
            // 📊 СТАТИСТИКА ДНЯ (нижняя часть)
            Expanded(
              child: _isLoading 
                ? Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Color(0xFF1976D2)),
                          SizedBox(height: 16),
                          Text('Загружаем статистику...', 
                            style: TextStyle(color: Color(0xFF1976D2), fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDayHeader(totalDay, dailyGoal),
                        const SizedBox(height: 4),
                        
                        if (_dayIntakes.isNotEmpty) ...[
                          _buildDayChart(),
                          const SizedBox(height: 4),
                          
                          _buildDayStats(totalDay, dailyGoal),
                          const SizedBox(height: 4),
                          
                          _buildDayIntakesList(),
                        ] else
                          _buildEmptyDayState(),
                      ],
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 Заголовок выбранного дня
  Widget _buildDayHeader(int totalDay, int dailyGoal) {
    final percentage = totalDay / dailyGoal;
    final isToday = isSameDay(_selectedDate, DateTime.now());
    
    String dateText;
    if (isToday) {
      dateText = '🗓️ Сегодня';
    } else if (isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1)))) {
      dateText = '🗓️ Вчера';
    } else {
      dateText = '🗓️ ${_selectedDate.day}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}';
    }

    String statusText = '';
    Color statusColor = kBlue;
    IconData statusIcon = Icons.water_drop;
    
    if (totalDay >= dailyGoal) {
      statusText = '🎉 Цель достигнута!';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (totalDay >= dailyGoal * 0.75) {
      statusText = '💪 Хорошие результаты!';
      statusColor = kBlue;
      statusIcon = Icons.trending_up;
    } else if (totalDay >= dailyGoal * 0.5) {
      statusText = '📈 Половина пути пройдена!';
      statusColor = kBlue; // 🔵 Изменил с оранжевого на синий
      statusIcon = Icons.water_drop;
    } else {
      statusText = '💧 Продолжайте!';
      statusColor = kBlue;
      statusIcon = Icons.water_drop;
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, color: statusColor, size: 24),
              const SizedBox(width: 12),
              Text(dateText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlue)),
            ],
          ),
          const SizedBox(height: 16),
          
          Text('$totalDay мл из $dailyGoal мл (${(percentage * 100).toInt()}%)', 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)),
          
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 8),
              Text(statusText, style: TextStyle(fontSize: 16, color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  /// 📈 График потребления воды в течение дня
  Widget _buildDayChart() {
    if (_dayIntakes.isEmpty) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final currentHour = now.hour;
    final startHour = (currentHour - 10).clamp(0, 23);
    final endHour = currentHour;
    
    final Map<int, int> hourlyData = {};
    for (int i = startHour; i <= endHour; i++) {
      hourlyData[i] = 0;
    }
    
    for (final intake in _dayIntakes) {
      final hour = intake.dateTime.hour;
      if (hour >= startHour && hour <= endHour) {
        hourlyData[hour] = (hourlyData[hour] ?? 0) + intake.volumeML;
      }
    }

    final hasDataInRange = hourlyData.values.any((amount) => amount > 0);
    if (!hasDataInRange) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: kBlue, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text('📈 Потребление по часам (${startHour.toString().padLeft(2, '0')}:00 - ${endHour.toString().padLeft(2, '0')}:00)', 
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kBlue),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            height: 200,
            padding: const EdgeInsets.only(right: 16, top: 16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, horizontalInterval: 200, verticalInterval: 1),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final hour = value.toInt();
                        if (hour >= startHour && hour <= endHour) {
                          return Text('${hour}h', style: const TextStyle(fontSize: 10, color: kBlue));
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 200,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text('${value.toInt()}мл', style: const TextStyle(fontSize: 9, color: kBlue));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: kBlue.withOpacity(0.2))),
                lineBarsData: [
                  LineChartBarData(
                    spots: hourlyData.entries.map((e) => FlSpot(e.key.toDouble(), e.value.toDouble())).toList(),
                    isCurved: true,
                    color: kBlue,
                    barWidth: 3,
                    belowBarData: BarAreaData(show: true, color: kBlue.withOpacity(0.1)),
                    dotData: const FlDotData(show: true),
                  ),
                ],
                minX: startHour.toDouble(),
                maxX: endHour.toDouble(),
                minY: 0,
                maxY: (hourlyData.values.isNotEmpty ? hourlyData.values.reduce((a, b) => a > b ? a : b) * 1.2 : 1000).toDouble(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 Детальная статистика дня
  Widget _buildDayStats(int totalDay, int dailyGoal) {
    final percentage = totalDay / dailyGoal;
    final remaining = (dailyGoal - totalDay).clamp(0, dailyGoal);
    final averageIntake = _dayIntakes.isNotEmpty ? (totalDay / _dayIntakes.length).round() : 0;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: kBlue, size: 24),
              const SizedBox(width: 12),
              const Text('📊 Статистика дня', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlue)),
            ],
          ),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('💧 Выпито', '$totalDay мл', Colors.blue, Icons.local_drink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('🎯 Цель', '$dailyGoal мл', Colors.green, Icons.flag),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('📈 Прогресс', '${(percentage * 100).toInt()}%', 
                  percentage >= 1.0 ? Colors.green : Colors.orange, Icons.trending_up),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('🔄 Осталось', '$remaining мл', Colors.red, Icons.schedule),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('🔢 Записей', '${_dayIntakes.length}', Colors.purple, Icons.format_list_numbered),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('⚖️ Среднее', '$averageIntake мл', Colors.teal, Icons.equalizer),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 📋 Список записей дня
  Widget _buildDayIntakesList() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: kBlue, size: 24),
              const SizedBox(width: 12),
              const Text('📋 Записи дня', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kBlue)),
            ],
          ),
          const SizedBox(height: 16),
          
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _dayIntakes.length,
            separatorBuilder: (context, index) => Divider(color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              // Показываем в обратном порядке - последний прием вверху
              final reversedIndex = _dayIntakes.length - 1 - index;
              final intake = _dayIntakes[reversedIndex];
              final time = DateFormat('HH:mm').format(intake.dateTime);
              
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.water_drop, color: kBlue, size: 20),
                ),
                title: Text('${intake.volumeML} мл', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Время: $time', 
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('#${reversedIndex + 1}', 
                    style: const TextStyle(color: kBlue, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 🌟 Состояние пустого дня
  Widget _buildEmptyDayState() {
    final isToday = isSameDay(_selectedDate, DateTime.now());
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isToday ? Icons.water_drop_outlined : Icons.calendar_today_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            isToday ? '💧 Пока нет записей о воде' : '📅 Нет записей за этот день',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isToday 
              ? 'Начните отслеживать потребление воды прямо сейчас!'
              : 'Выберите другой день для просмотра статистики',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  /// 📊 Показ статистики за месяц при нажатии на заголовок
  Future<void> _showMonthStatistics(DateTime month) async {
    try {
      final userSettings = ref.read(userSettingsProvider);
      final dailyGoal = userSettings?.dailyNormML ?? 2000;
      
      // Загружаем данные за весь месяц
      final monthIntakes = <WaterIntake>[];
      final startOfMonth = DateTime(month.year, month.month, 1);
      final endOfMonth = DateTime(month.year, month.month + 1, 0);
      
      for (DateTime date = startOfMonth; date.isBefore(endOfMonth.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final dayIntakes = await StorageService.getWaterIntakesForDate(date);
        monthIntakes.addAll(dayIntakes);
      }
      
      if (monthIntakes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('📅 Нет данных за этот месяц')),
          );
        }
        return;
      }
      
      final totalVolume = monthIntakes.fold(0, (sum, intake) => sum + intake.volumeML);
      final totalDays = endOfMonth.day;
      final daysWithWater = _monthlyData.length;
      final averagePerDay = (totalVolume / totalDays).round();
      final goalPercent = ((totalVolume / (dailyGoal * totalDays)) * 100).round();
      final maxDay = _monthlyData.values.isNotEmpty ? _monthlyData.values.reduce((a, b) => a > b ? a : b) : 0;
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.analytics, color: kBlue),
                const SizedBox(width: 12),
                Text('📊 ${DateFormat('MMMM yyyy', 'ru_RU').format(month)}', 
                  style: const TextStyle(color: kBlue, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Общий объем
                _buildStatRow('💧 Общий объем:', '$totalVolume мл'),
                const SizedBox(height: 8),
                
                // Среднее в день
                _buildStatRow('📊 Среднее в день:', '$averagePerDay мл'),
                const SizedBox(height: 8),
                
                // Дней с водой
                _buildStatRow('📅 Дней с записями:', '$daysWithWater из $totalDays'),
                const SizedBox(height: 8),
                
                // Выполнение цели
                _buildStatRow('🎯 Выполнение цели:', '$goalPercent%'),
                const SizedBox(height: 8),
                
                // Максимальный день
                _buildStatRow('🏆 Лучший день:', '$maxDay мл'),
                const SizedBox(height: 8),
                
                // Общее количество записей
                _buildStatRow('📝 Всего записей:', '${monthIntakes.length}'),
                
                const SizedBox(height: 16),
                
                // Мотивационное сообщение
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (goalPercent >= 100 ? Colors.green : Colors.blue).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (goalPercent >= 100 ? Colors.green : Colors.blue).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    goalPercent >= 100 ? 
                      '🎉 Отличная работа! Цель месяца выполнена!' :
                      goalPercent >= 75 ?
                        '💪 Хорошие результаты! Продолжайте в том же духе!' :
                        goalPercent >= 50 ?
                          '📈 Неплохо! Есть куда расти!' :
                          '💧 Пора больше пить воды!',
                    style: TextStyle(
                      color: goalPercent >= 100 ? Colors.green : kBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть', style: TextStyle(color: kBlue)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('Ошибка загрузки статистики месяца: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки статистики: $e')),
        );
      }
    }
  }
  
  /// 📊 Вспомогательный виджет для строки статистики
  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kBlue)),
      ],
    );
  }
}

/// 📊 Карточка статистики (мини)
Widget _buildStatCard(String title, String value, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
