

/// Модель для хранения информации о приёме воды
class WaterIntake {
  /// Уникальный идентификатор записи
  final String id;

  /// Объём воды в миллилитрах
  final int volumeML;

  /// Время приёма воды
  final DateTime dateTime;

  /// Конструктор с проверкой объёма
  WaterIntake({
    required this.id,
    required this.volumeML,
    required this.dateTime,
  }) {
    // Валидация объёма
    if (volumeML <= 0) {
      throw ArgumentError('Объём воды должен быть больше 0');
    }
  }

  /// Создать копию с изменёнными полями
  WaterIntake copyWith({
    String? id,
    int? volumeML,
    DateTime? dateTime,
  }) {
    return WaterIntake(
      id: id ?? this.id,
      volumeML: volumeML ?? this.volumeML,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  /// Преобразование в Map для хранения
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'volumeML': volumeML,
      'dateTime': dateTime.toIso8601String(),
    };
  }

  /// Преобразовать в JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'volumeML': volumeML,
    'dateTime': dateTime.toIso8601String(),
  };

  /// Создание из Map
  factory WaterIntake.fromMap(Map<String, dynamic> map) {
    return WaterIntake(
      id: map['id'] as String,
      volumeML: map['volumeML'] as int,
      dateTime: DateTime.parse(map['dateTime'] as String),
    );
  }

  /// Создать из JSON
  factory WaterIntake.fromJson(Map<String, dynamic> json) => WaterIntake(
    id: json['id'] as String,
    volumeML: json['volumeML'] as int,
    dateTime: DateTime.parse(json['dateTime'] as String),
  );
} 