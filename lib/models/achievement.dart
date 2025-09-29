import 'package:flutter/material.dart';

/// Типы достижений для классификации
enum AchievementType {
  daily,    // ежедневные (выпил 2л в день)
  streak,   // последовательности (7 дней подряд) 
  volume,   // по объему (100л всего)
  habit,    // привычки (утренний стакан 30 дней)
}

/// Статус выполнения достижения
enum AchievementStatus {
  locked,    // заблокировано
  active,    // в процессе
  completed, // выполнено
}

/// Модель достижения с прогрессом и наградами
class Achievement {
  final String id;
  final String title;          // "Мастер гидрации"
  final String description;    // "Выпей 2л воды за день"
  final IconData icon;         // иконка достижения
  final Color color;           // цвет карточки
  final AchievementType type;  // тип достижения
  final int targetValue;       // целевое значение (2000мл, 7 дней)
  final int currentValue;      // текущий прогресс
  final AchievementStatus status;
  final int reward;           // награда в XP
  final DateTime? completedAt; // дата получения
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    this.status = AchievementStatus.locked,
    this.reward = 100,
    this.completedAt,
  });

  /// Прогресс в процентах (0.0 - 1.0)
  double get progress => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;
  
  /// Завершено ли достижение
  bool get isCompleted => status == AchievementStatus.completed;
  
  /// Активно ли (в процессе)
  bool get isActive => status == AchievementStatus.active;

  /// Копирование с изменениями
  Achievement copyWith({
    String? title,           // 🎨 Добавил поддержку обновления заголовка
    String? description,     // 🎨 Добавил поддержку обновления описания
    IconData? icon,          // 🎨 Добавил поддержку обновления иконки
    Color? color,            // 🎨 Добавил поддержку обновления цвета
    int? currentValue,
    AchievementStatus? status,
    DateTime? completedAt,
  }) {
    return Achievement(
      id: id,
      title: title ?? this.title,                      // 🎨 Используем новый или старый заголовок
      description: description ?? this.description,    // 🎨 Используем новое или старое описание
      icon: icon ?? this.icon,                         // 🎨 Используем новую или старую иконку
      color: color ?? this.color,                      // 🎨 Используем новый или старый цвет
      type: type,
      targetValue: targetValue,
      currentValue: currentValue ?? this.currentValue,
      status: status ?? this.status,
      reward: reward,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Конвертация в Map для сохранения
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'iconCode': icon.codePoint,
    'colorValue': color.value,
    'type': type.name,
    'targetValue': targetValue,
    'currentValue': currentValue,
    'status': status.name,
    'reward': reward,
    'completedAt': completedAt?.millisecondsSinceEpoch,
  };

  /// Создание из Map при загрузке
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    id: json['id'],
    title: json['title'],
    description: json['description'],
    icon: IconData(json['iconCode'], fontFamily: 'MaterialIcons'),
    color: Color(json['colorValue']),
    type: AchievementType.values.firstWhere((e) => e.name == json['type']),
    targetValue: json['targetValue'],
    currentValue: json['currentValue'] ?? 0,
    status: AchievementStatus.values.firstWhere((e) => e.name == json['status']),
    reward: json['reward'] ?? 100,
    completedAt: json['completedAt'] != null 
      ? DateTime.fromMillisecondsSinceEpoch(json['completedAt']) 
      : null,
  );
}

/// Предустановленные достижения с красивыми иконками и цветами
class DefaultAchievements {
  /// Создает адаптивные достижения под дневную норму пользователя
  static List<Achievement> createForDailyNorm(int dailyNormML) => [
    // Ежедневные цели 💧 (адаптированные под норму)
    Achievement(
      id: 'first_glass',
      title: 'Первый глоток',
      description: 'Добавь первую порцию воды за день',
      icon: Icons.local_drink,
      color: Colors.blue.shade300,
      type: AchievementType.daily,
      targetValue: 250,
      reward: 50,
    ),
    Achievement(
      id: 'half_daily_goal',
      title: 'На полпути к цели',
      description: 'Выпей 50% дневной нормы (${(dailyNormML * 0.5).round()}мл)',
      icon: Icons.trending_up,
      color: Colors.green.shade300,
      type: AchievementType.daily,
      targetValue: (dailyNormML * 0.5).round(),
      reward: 100,
    ),
    Achievement(
      id: 'daily_goal_100',
      title: 'Мастер гидрации',
      description: 'Выполни дневную норму (${dailyNormML}мл)',
      icon: Icons.emoji_events,
      color: Colors.amber.shade400,
      type: AchievementType.daily,
      targetValue: dailyNormML,
      reward: 250,
    ),
    Achievement(
      id: 'super_hydrated_120',
      title: 'Супер увлажнение',
      description: 'Превыси норму на 20% (${(dailyNormML * 1.2).round()}мл)',
      icon: Icons.whatshot,
      color: Colors.orange.shade400,
      type: AchievementType.daily,
      targetValue: (dailyNormML * 1.2).round(),
      reward: 350,
    ),

    // Серии дней 🔥
    Achievement(
      id: 'streak_3_days',
      title: 'На правильном пути',
      description: 'Выполняй цель 3 дня подряд',
      icon: Icons.trending_up,
      color: Colors.green.shade400,
      type: AchievementType.streak,
      targetValue: 3,
      reward: 250,
    ),
    Achievement(
      id: 'streak_7_days',
      title: 'Неделя силы',
      description: 'Выполняй цель 7 дней подряд',
      icon: Icons.local_fire_department,
      color: Colors.red.shade400,
      type: AchievementType.streak,
      targetValue: 7,
      reward: 500,
    ),
    Achievement(
      id: 'streak_30_days',
      title: 'Мастер привычки',
      description: 'Выполняй цель 30 дней подряд',
      icon: Icons.diamond,
      color: Colors.purple.shade400,
      type: AchievementType.streak,
      targetValue: 30,
      reward: 1000,
    ),

    // По общему объему 🌊
    Achievement(
      id: 'total_10l',
      title: 'Первые 10 литров',
      description: 'Выпей 10 литров всего',
      icon: Icons.waves,
      color: Colors.cyan.shade300,
      type: AchievementType.volume,
      targetValue: 10000,
      reward: 150,
    ),
    Achievement(
      id: 'total_100l',
      title: 'Океан здоровья',
      description: 'Выпей 100 литров всего',
      icon: Icons.pool,
      color: Colors.teal.shade400,
      type: AchievementType.volume,
      targetValue: 100000,
      reward: 1500,
    ),

    // Привычки ⏰
    Achievement(
      id: 'morning_habit',
      title: 'Утренняя свежесть',
      description: 'Выпей стакан до 9:00 утра 7 дней',
      icon: Icons.wb_sunny,
      color: Colors.pink.shade400, // 🌸 Изменил с желтого на розовый
      type: AchievementType.habit,
      targetValue: 7,
      reward: 400,
    ),
    Achievement(
      id: 'evening_habit',
      title: 'Вечерний ритуал',
      description: 'Выпей стакан после 18:00 в течение недели',
      icon: Icons.bedtime,
      color: Colors.indigo.shade400,
      type: AchievementType.habit,
      targetValue: 7,
      reward: 400,
    ),
  ];
}
