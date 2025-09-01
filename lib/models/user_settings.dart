/// Модель для хранения пользовательских настроек
class UserSettings {
  /// Вес пользователя (кг)
  final int weight;

  /// Рост пользователя (см, опционально)
  final int? height;

  /// Уровень активности: 0 - низкий, 1 - средний, 2 - высокий
  final int activityLevel;

  /// Дневная норма воды (мл)
  final int dailyNormML;

  /// Включена ли интеграция с погодой
  final bool isWeatherEnabled;

  /// Интервал уведомлений (часы)
  final int notificationIntervalHours;

  /// Час начала уведомлений (0-23)
  final int notificationStartHour;

  /// Час окончания уведомлений (0-23)
  final int notificationEndHour;

  /// Единицы измерения (мл, л, oz)
  final String unit;

  /// Включены ли автоматические запросы отзывов
  final bool isReviewRequestEnabled;

  /// Порог выполнения дневной нормы для показа отзыва (0.0-1.0)
  final double reviewThresholdPercentage;

  /// Конструктор с валидацией
  UserSettings({
    required this.weight,
    this.height,
    required this.activityLevel,
    required this.dailyNormML,
    required this.isWeatherEnabled,
    required this.notificationIntervalHours,
    this.notificationStartHour = 8, // Значение по умолчанию
    this.notificationEndHour = 22, // Значение по умолчанию
    this.unit = 'мл',
    this.isReviewRequestEnabled = true, // По умолчанию включено
    this.reviewThresholdPercentage = 0.75, // 75% от нормы
  }) {
    // Валидация веса
    if (weight < 30 || weight > 200) {
      throw ArgumentError('Вес должен быть в диапазоне 30-200 кг');
    }
    // Валидация роста
    if (height != null && (height! < 100 || height! > 250)) {
      throw ArgumentError('Рост должен быть в диапазоне 100-250 см');
    }
    // Валидация уровня активности
    if (activityLevel < 0 || activityLevel > 2) {
      throw ArgumentError('activityLevel должен быть 0, 1 или 2');
    }
    // Валидация дневной нормы
    if (dailyNormML < 500 || dailyNormML > 10000) {
      throw ArgumentError('dailyNormML должен быть в диапазоне 500-10000 мл');
    }
    // Валидация интервала уведомлений
    if (notificationIntervalHours < 0 || notificationIntervalHours > 6) {
      throw ArgumentError(
        'notificationIntervalHours должен быть в диапазоне 0-6',
      );
    }
    // Валидация часа начала уведомлений
    if (notificationStartHour < 0 || notificationStartHour > 23) {
      throw ArgumentError('notificationStartHour должен быть в диапазоне 0-23');
    }
    // Валидация часа окончания уведомлений
    if (notificationEndHour < 0 || notificationEndHour > 23) {
      throw ArgumentError('notificationEndHour должен быть в диапазоне 0-23');
    }
    // Валидация единиц измерения
    if (!['мл', 'л', 'oz'].contains(unit)) {
      throw ArgumentError('unit должен быть мл, л или oz');
    }
    // Валидация порога отзыва
    if (reviewThresholdPercentage < 0.0 || reviewThresholdPercentage > 1.0) {
      throw ArgumentError(
        'reviewThresholdPercentage должен быть в диапазоне 0.0-1.0',
      );
    }
  }

  /// Копирование с изменёнными полями
  UserSettings copyWith({
    int? weight,
    int? height,
    int? activityLevel,
    int? dailyNormML,
    bool? isWeatherEnabled,
    int? notificationIntervalHours,
    int? notificationStartHour,
    int? notificationEndHour,
    String? unit,
    bool? isReviewRequestEnabled,
    double? reviewThresholdPercentage,
  }) {
    return UserSettings(
      weight: weight ?? this.weight,
      height: height ?? this.height,
      activityLevel: activityLevel ?? this.activityLevel,
      dailyNormML: dailyNormML ?? this.dailyNormML,
      isWeatherEnabled: isWeatherEnabled ?? this.isWeatherEnabled,
      notificationIntervalHours:
          notificationIntervalHours ?? this.notificationIntervalHours,
      notificationStartHour:
          notificationStartHour ?? this.notificationStartHour,
      notificationEndHour: notificationEndHour ?? this.notificationEndHour,
      unit: unit ?? this.unit,
      isReviewRequestEnabled:
          isReviewRequestEnabled ?? this.isReviewRequestEnabled,
      reviewThresholdPercentage:
          reviewThresholdPercentage ?? this.reviewThresholdPercentage,
    );
  }

  /// Преобразование в Map для хранения
  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'height': height,
      'activityLevel': activityLevel,
      'dailyNormML': dailyNormML,
      'isWeatherEnabled': isWeatherEnabled,
      'notificationIntervalHours': notificationIntervalHours,
      'notificationStartHour': notificationStartHour,
      'notificationEndHour': notificationEndHour,
      'unit': unit,
      'isReviewRequestEnabled': isReviewRequestEnabled,
      'reviewThresholdPercentage': reviewThresholdPercentage,
    };
  }

  /// Преобразовать в JSON
  Map<String, dynamic> toJson() => {
    'weight': weight,
    'height': height,
    'activityLevel': activityLevel,
    'dailyNormML': dailyNormML,
    'isWeatherEnabled': isWeatherEnabled,
    'notificationIntervalHours': notificationIntervalHours,
    'notificationStartHour': notificationStartHour,
    'notificationEndHour': notificationEndHour,
    'unit': unit,
    'isReviewRequestEnabled': isReviewRequestEnabled,
    'reviewThresholdPercentage': reviewThresholdPercentage,
  };

  /// Создание из JSON
  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      weight: json['weight'] as int,
      height: json['height'] as int?,
      activityLevel: json['activityLevel'] as int,
      dailyNormML: json['dailyNormML'] as int,
      isWeatherEnabled: json['isWeatherEnabled'] as bool,
      notificationIntervalHours: json['notificationIntervalHours'] as int,
      notificationStartHour:
          json['notificationStartHour'] as int? ?? 8, // Значение по умолчанию
      notificationEndHour:
          json['notificationEndHour'] as int? ?? 22, // Значение по умолчанию
      unit: json['unit'] as String,
      isReviewRequestEnabled: json['isReviewRequestEnabled'] as bool? ?? true,
      reviewThresholdPercentage:
          json['reviewThresholdPercentage'] as double? ?? 0.75,
    );
  }
}
