

/// Сервис для расчёта дневной нормы воды
class CalculationService {
  static Stream<int>? _activityStream;

  /// Рассчитать дневную норму воды (мл)
  /// Формула: (вес * 30 мл) + активность (0-500 мл) + погода (0-500 мл при 30°C+)
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
  /// ОТКЛЮЧЕН - базовая норма уже учитывает уровень активности
  static Stream<int> get activityBasedAddition {
    // 🚫 Отключаем автоматические добавки от акселерометра
    // Норма рассчитывается один раз в настройках по весу + выбранному уровню активности
    _activityStream ??= Stream<int>.periodic(
      const Duration(hours: 24), // Раз в сутки
      (_) => 0, // Всегда возвращаем 0 (без добавок)
    ).asBroadcastStream();
    return _activityStream!;
  }
} 