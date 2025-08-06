

import 'package:sensors_plus/sensors_plus.dart';

/// Сервис для расчёта дневной нормы воды
class CalculationService {
  static Stream<int>? _activityStream;

  /// Рассчитать дневную норму воды (мл)
  /// Формула: (вес * 30 мл) + активность (0-500 мл) + погода (0-300 мл)
  static int calculateDailyNorm({
    required int weight,
    required int activityLevel, // 0 - низкий, 1 - средний, 2 - высокий
    int weatherAddition = 0, // Дополнительный объём из-за погоды
  }) {
    // Валидация входных данных
    if (weight < 30 || weight > 200) {
      throw ArgumentError('Вес должен быть в диапазоне 30-200 кг');
    }
    if (activityLevel < 0 || activityLevel > 2) {
      throw ArgumentError('activityLevel должен быть 0, 1 или 2');
    }
    if (weatherAddition < 0) {
      throw ArgumentError('weatherAddition не может быть отрицательным');
    }
    // Расчёт по формуле
    int activityML = [0, 250, 500][activityLevel];
    return (weight * 30) + activityML + weatherAddition;
  }

  /// Поток с дополнительным количеством воды в зависимости от активности
  static Stream<int> get activityBasedAddition {
    _activityStream ??= accelerometerEvents
        .map((event) {
          // Простая логика: если ускорение по любой оси > 10, считаем за активность
          if (event.x.abs() > 15 || event.y.abs() > 15 || event.z.abs() > 15) {
            return 50; // Добавляем 50 мл за всплеск активности
          }
          return 0;
        })
        .where((event) => event > 0) // Фильтруем, чтобы не было лишних событий
        .asBroadcastStream(); // Делаем поток широковещательным
    return _activityStream!;
  }
} 