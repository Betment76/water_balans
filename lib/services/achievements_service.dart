import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../models/water_intake.dart';
import '../services/storage_service.dart';

/// Событие для отслеживания достижений
enum AchievementEvent {
  waterAdded,      // добавлена вода
  dayGoalReached,  // цель дня выполнена
  morningDrink,    // утренний прием воды (до 9:00)
  eveningDrink,    // вечерний прием воды (после 18:00)
}

/// Сервис для управления достижениями и прогрессом
class AchievementsService extends ChangeNotifier {
  static const String _achievementsKey = 'achievements_data';
  static const String _userLevelKey = 'user_level';
  static const String _userXpKey = 'user_xp';
  static const String _currentStreakKey = 'current_streak';
  static const String _lastGoalDateKey = 'last_goal_date';

  List<Achievement> _achievements = [];
  int _userLevel = 1;
  int _userXp = 0;
  int _currentStreak = 0;
  DateTime? _lastGoalDate;
  
  // 🚀 Кэш для оптимизации производительности
  static int? _cachedTotalVolume;
  static DateTime? _cacheTime;

  // Геттеры
  List<Achievement> get achievements => List.unmodifiable(_achievements);
  List<Achievement> get completedAchievements => _achievements.where((a) => a.isCompleted).toList();
  List<Achievement> get activeAchievements => _achievements.where((a) => a.isActive).toList();
  int get userLevel => _userLevel;
  int get userXp => _userXp;
  int get currentStreak => _currentStreak;
  int get nextLevelXp => _userLevel * 1000; // каждый уровень = 1000 XP
  double get levelProgress => (_userXp % nextLevelXp) / nextLevelXp;

  /// Инициализация сервиса с адаптивными достижениями
  Future<void> initialize({int dailyNormML = 2000, bool forceReset = false}) async {
    debugPrint('🏆 ИНИЦИАЛИЗАЦИЯ: dailyNormML=$dailyNormML, forceReset=$forceReset');
    
    if (forceReset) {
      // 🧹 ПРИНУДИТЕЛЬНАЯ ОЧИСТКА всех данных
      debugPrint('🧹 ПРИНУДИТЕЛЬНАЯ ОЧИСТКА достижений');
      await _clearAllData();
    }
    
    await _loadData();
    
    if (_achievements.isEmpty || forceReset) {
      // 🎯 Создаем достижения адаптированные под дневную норму пользователя
      debugPrint('🎯 Создание новых достижений для нормы $dailyNormML');
      _achievements = DefaultAchievements.createForDailyNorm(dailyNormML).map((a) => 
        a.copyWith(status: AchievementStatus.active)).toList();
      await _saveData();
    } else {
      // 🔄 Обновляем существующие ежедневные достижения при изменении нормы
      debugPrint('🔄 Обновление существующих достижений');
      await _updateDailyAchievementsForNorm(dailyNormML);
      
      // 🎨 Синхронизируем цвета и иконки с шаблонами
      await _syncAchievementsWithTemplates(dailyNormML);
    }
    
    // 🎖️ ОДНОКРАТНОЕ восстановление XP за предыдущие дни
    await _checkAndRecoverMissingXp();
    
    // 🚀 АВТОМАТИЧЕСКАЯ СИНХРОНИЗАЦИЯ с текущим потреблением воды
    await _syncWithCurrentWaterIntake();
    
    debugPrint('🏆 ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА: ${_achievements.length} достижений загружено');
    notifyListeners();
  }

  /// Синхронизирует достижения с текущим потреблением воды за день
  Future<void> _syncWithCurrentWaterIntake() async {
    try {
      final DateTime today = DateTime.now();
      
      // 🔄 Сначала сбрасываем ежедневные достижения если прошел день
      await _resetDailyAchievementsIfNeeded(today);
      
      // Получаем сегодняшнее потребление воды
      final intakes = await StorageService.getWaterIntakesForDate(today);
      final todayTotal = intakes.fold(0, (sum, intake) => sum + intake.volumeML);
      
      debugPrint('🚀 СИНХРОНИЗАЦИЯ: Сегодня выпито ${todayTotal}мл');
      
      // 📊 РЕАЛЬНЫЙ расчет общего объема из базы данных
      int totalVolume = 0;
      try {
        final allIntakes = await StorageService.loadWaterIntakes();
        totalVolume = allIntakes.fold(0, (sum, intake) => sum + intake.volumeML);
        debugPrint('🚀 СИНХРОНИЗАЦИЯ: РЕАЛЬНЫЙ общий объем за все время: ${totalVolume}мл (${(totalVolume/1000).toStringAsFixed(1)}л)');
      } catch (e) {
        debugPrint('🚀 СИНХРОНИЗАЦИЯ: ОШИБКА загрузки общего объема: $e');
        totalVolume = todayTotal; // минимальная оценка
      }
      
      // Обновляем достижения с актуальными данными
      await handleEvent(AchievementEvent.waterAdded, data: {
        'amount': 0, // не добавляем новую воду
        'todayTotal': todayTotal,
        'totalVolume': totalVolume, // ТОЧНЫЕ данные из базы!
        'isSync': true, // флаг синхронизации
      });
      
      debugPrint('🚀 СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА: обновлены достижения для ${todayTotal}мл сегодня, ${totalVolume}мл всего');
      
    } catch (e) {
      debugPrint('🚀 ОШИБКА синхронизации: $e');
      // Продолжаем работу без синхронизации
    }
  }

  /// Полная очистка всех данных достижений
  Future<void> _clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_achievementsKey);
      await prefs.remove(_userLevelKey);
      await prefs.remove(_userXpKey);  
      await prefs.remove(_currentStreakKey);
      await prefs.remove(_lastGoalDateKey);
      
      // Сбрасываем внутреннее состояние
      _achievements.clear();
      _userLevel = 1;
      _userXp = 0;
      _currentStreak = 0;
      _lastGoalDate = null;
      
      debugPrint('🧹 ВСЕ ДАННЫЕ ДОСТИЖЕНИЙ ОЧИЩЕНЫ');
    } catch (e) {
      debugPrint('🧹 ОШИБКА очистки данных: $e');
    }
  }

  /// Сбрасывает ежедневные достижения если прошел день
  Future<void> _resetDailyAchievementsIfNeeded(DateTime today) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const lastResetKey = 'achievements_last_daily_reset';
      
      // Получаем дату последнего сброса
      final lastResetString = prefs.getString(lastResetKey);
      final todayKey = _dateToKey(today);
      
      if (lastResetString == null || lastResetString != todayKey) {
        debugPrint('🔄 СБРОС: Сбрасываем ежедневные достижения. Последний сброс: $lastResetString, сегодня: $todayKey');
        
        bool hasChanges = false;
        
        // 🎖️ СОХРАНЯЕМ XP за выполненные вчера достижения перед сбросом
        await _saveCompletedDailyAchievementsXp();
        
        for (int i = 0; i < _achievements.length; i++) {
          final achievement = _achievements[i];
          
          // Сбрасываем только ежедневные достижения
          if (achievement.type == AchievementType.daily) {
            _achievements[i] = achievement.copyWith(
              currentValue: 0,
              status: AchievementStatus.active,
              completedAt: null,
            );
            hasChanges = true;
            debugPrint('🔄 СБРОС: ${achievement.title} сброшено');
          }
        }
        
        if (hasChanges) {
          // Сохраняем изменения
          await _saveData();
          
          // Обновляем дату последнего сброса
          await prefs.setString(lastResetKey, todayKey);
          
          debugPrint('🔄 СБРОС: Ежедневные достижения сброшены на новый день');
        }
      }
    } catch (e) {
      debugPrint('🔄 СБРОС: ОШИБКА сброса ежедневных достижений: $e');
    }
  }

  /// Сохраняет XP за выполненные ежедневные достижения перед сбросом
  Future<void> _saveCompletedDailyAchievementsXp() async {
    final completedDaily = _achievements.where((a) => 
      a.type == AchievementType.daily && a.isCompleted).toList();
    
    if (completedDaily.isNotEmpty) {
      debugPrint('💎 СОХРАНЕНИЕ XP: Найдено ${completedDaily.length} выполненных ежедневных достижений');
      
      for (final achievement in completedDaily) {
        debugPrint('💎 XP за "${achievement.title}": ${achievement.reward} XP уже в общем балансе');
      }
      
      debugPrint('💎 ТЕКУЩИЙ БАЛАНС XP: $_userXp (уровень: $_userLevel)');
    }
  }

  /// Обновляет ежедневные достижения при изменении дневной нормы
  Future<void> _updateDailyAchievementsForNorm(int dailyNormML) async {
    bool needsUpdate = false;
    
    // Обновляем цели в зависимости от новой нормы
    final updatedAchievements = <Achievement>[];
    
    for (final achievement in _achievements) {
      if (achievement.type == AchievementType.daily) {
        Achievement? updatedAchievement;
        
        switch (achievement.id) {
          case 'half_daily_goal':
            final newTarget = (dailyNormML * 0.5).round();
            if (achievement.targetValue != newTarget) {
              updatedAchievement = Achievement(
                id: achievement.id,
                title: achievement.title,
                description: 'Выпей 50% дневной нормы (${newTarget}мл)',
                icon: achievement.icon,
                color: achievement.color,
                type: achievement.type,
                targetValue: newTarget,
                currentValue: achievement.currentValue,
                status: achievement.status,
                reward: achievement.reward,
                completedAt: achievement.completedAt,
              );
              needsUpdate = true;
            }
            break;
            
          case 'daily_goal_100':
            final newTarget = dailyNormML;
            if (achievement.targetValue != newTarget) {
              updatedAchievement = Achievement(
                id: achievement.id,
                title: achievement.title,
                description: 'Выполни дневную норму (${newTarget}мл)',
                icon: achievement.icon,
                color: achievement.color,
                type: achievement.type,
                targetValue: newTarget,
                currentValue: achievement.currentValue,
                status: achievement.status,
                reward: achievement.reward,
                completedAt: achievement.completedAt,
              );
              needsUpdate = true;
            }
            break;
            
          case 'super_hydrated_120':
            final newTarget = (dailyNormML * 1.2).round();
            if (achievement.targetValue != newTarget) {
              updatedAchievement = Achievement(
                id: achievement.id,
                title: achievement.title,
                description: 'Превыси норму на 20% (${newTarget}мл)',
                icon: achievement.icon,
                color: achievement.color,
                type: achievement.type,
                targetValue: newTarget,
                currentValue: achievement.currentValue,
                status: achievement.status,
                reward: achievement.reward,
                completedAt: achievement.completedAt,
              );
              needsUpdate = true;
            }
            break;
        }
        
        updatedAchievements.add(updatedAchievement ?? achievement);
      } else {
        updatedAchievements.add(achievement);
      }
    }
    
    if (needsUpdate) {
      _achievements = updatedAchievements;
      await _saveData();
    }
  }

  /// Обработка событий для обновения достижений
  Future<List<Achievement>> handleEvent(AchievementEvent event, {Map<String, dynamic>? data}) async {
    debugPrint('🏆 СЕРВИС: Получено событие $event с данными: $data');
    
    List<Achievement> newlyCompleted = [];
    final now = DateTime.now();
    
    // 🔄 При любом событии проверяем нужно ли сбросить ежедневные достижения
    await _resetDailyAchievementsIfNeeded(now);
    
    switch (event) {
      case AchievementEvent.waterAdded:
        final int amount = data?['amount'] ?? 0;
        final int todayTotal = data?['todayTotal'] ?? 0;
        final int totalVolume = data?['totalVolume'] ?? 0;
        
        debugPrint('🏆 СЕРВИС: waterAdded - amount:$amount, todayTotal:$todayTotal, totalVolume:$totalVolume');
        
        // Утренний/вечерний прием
        final hour = now.hour;
        if (hour <= 9) {
          newlyCompleted.addAll(await _updateAchievement('morning_habit', 1));
        }
        if (hour >= 18) {
          newlyCompleted.addAll(await _updateAchievement('evening_habit', 1));
        }
        
        // Первый глоток дня - ТОЛЬКО при реальном добавлении воды (не синхронизации)
        final isSync = data?['isSync'] ?? false;
        if (todayTotal == amount && amount > 0 && !isSync) {
          debugPrint('🏆 СЕРВИС: Обнаружен первый глоток дня! amount=$amount');
          final firstGlassResults = await _updateAchievement('first_glass', 250);
          newlyCompleted.addAll(firstGlassResults); // 🎖️ Добавляем для начисления XP
        } else if (isSync && todayTotal > 0) {
          // При синхронизации только обновляем прогресс БЕЗ начисления XP
          await _updateAchievement('first_glass', 250, isSync: true);
        }
        
        // Ежедневные цели (адаптированные под норму пользователя)
        newlyCompleted.addAll(await _updateAchievement('half_daily_goal', todayTotal));
        newlyCompleted.addAll(await _updateAchievement('daily_goal_100', todayTotal));
        newlyCompleted.addAll(await _updateAchievement('super_hydrated_120', todayTotal));
        
        // Общий объем
        newlyCompleted.addAll(await _updateAchievement('total_10l', totalVolume));
        newlyCompleted.addAll(await _updateAchievement('total_100l', totalVolume));
        
        break;
        
      case AchievementEvent.dayGoalReached:
        await _updateStreak();
        // Обновляем достижения по сериям
        newlyCompleted.addAll(await _updateAchievement('streak_3_days', _currentStreak));
        newlyCompleted.addAll(await _updateAchievement('streak_7_days', _currentStreak));
        newlyCompleted.addAll(await _updateAchievement('streak_30_days', _currentStreak));
        break;
        
      case AchievementEvent.morningDrink:
      case AchievementEvent.eveningDrink:
        // Обрабатывается в waterAdded
        break;
    }
    
    // Добавляем XP за новые достижения
    if (newlyCompleted.isNotEmpty) {
      final isSync = data?['isSync'] ?? false;
      
      // 🏆 XP начисляется за ВСЕ достижения, включая синхронизацию
      for (final achievement in newlyCompleted) {
        await _addXp(achievement.reward);
        debugPrint('🎖️ XP начислен: +${achievement.reward} за "${achievement.title}". Всего XP: $_userXp');
      }
      
      debugPrint('🏆 ИТОГО XP: $_userXp, Уровень: $_userLevel');
      notifyListeners();
    }
    
    // Возвращаем достижения для уведомлений только если это не синхронизация
    final isSync = data?['isSync'] ?? false;
    return isSync ? [] : newlyCompleted;
  }

  /// Обновление конкретного достижения
  Future<List<Achievement>> _updateAchievement(String id, int newValue, {bool isSync = false}) async {
    debugPrint('🏆 СЕРВИС: _updateAchievement($id, $newValue)');
    
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index == -1) {
      debugPrint('🏆 СЕРВИС: Достижение $id не найдено!');
      return [];
    }
    
    if (_achievements[index].isCompleted) {
      debugPrint('🏆 СЕРВИС: Достижение $id уже выполнено');
      return [];
    }
    
    final achievement = _achievements[index];
    debugPrint('🏆 СЕРВИС: Текущий прогресс ${achievement.title}: ${achievement.currentValue}/${achievement.targetValue}');
    
    final updatedValue = achievement.type == AchievementType.streak 
      ? newValue // для серий берем точное значение
      : newValue.clamp(0, achievement.targetValue); // для остальных ограничиваем целью
    
    debugPrint('🏆 СЕРВИС: Обновленное значение: $updatedValue');
    
    if (updatedValue > achievement.currentValue) {
      final isNewlyCompleted = updatedValue >= achievement.targetValue && !achievement.isCompleted;
      
      debugPrint('🏆 СЕРВИС: Обновляем прогресс. Завершено: $isNewlyCompleted');
      
      _achievements[index] = achievement.copyWith(
        currentValue: updatedValue,
        status: isNewlyCompleted ? AchievementStatus.completed : AchievementStatus.active,
        completedAt: isNewlyCompleted ? DateTime.now() : null,
      );
      
      // Сохраняем изменения
      await _saveData();
      notifyListeners();
      
      if (isNewlyCompleted) {
        debugPrint('🏆 СЕРВИС: ✅ Достижение "${achievement.title}" ЗАВЕРШЕНО! Награда: ${achievement.reward} XP');
        // Возвращаем достижение для подсчета XP, но уведомления только при реальном добавлении воды
        return [_achievements[index]];
      } else {
        debugPrint('🏆 СЕРВИС: ⏳ Достижение "${achievement.title}" обновлено: ${updatedValue}/${achievement.targetValue}');
      }
    } else {
      debugPrint('🏆 СЕРВИС: Значение не увеличилось, пропускаем обновление');
    }
    
    return [];
  }

  /// Обновление серии дней
  Future<void> _updateStreak() async {
    final today = DateTime.now();
    final todayKey = _dateToKey(today);
    final lastGoalKey = _lastGoalDate != null ? _dateToKey(_lastGoalDate!) : '';
    
    if (lastGoalKey.isEmpty) {
      // Первый день серии
      _currentStreak = 1;
    } else if (todayKey == lastGoalKey) {
      // Уже засчитан сегодня
      return;
    } else {
      // Проверяем, был ли вчера
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayKey = _dateToKey(yesterday);
      
      if (lastGoalKey == yesterdayKey) {
        _currentStreak++;
      } else {
        _currentStreak = 1; // серия прервалась
      }
    }
    
    _lastGoalDate = today;
  }

  /// Добавление XP и проверка повышения уровня
  Future<void> _addXp(int xp) async {
    final oldLevel = _userLevel;
    final oldXp = _userXp;
    _userXp += xp;
    
    debugPrint('💎 XP НАЧИСЛЕН: +$xp (было: $oldXp → стало: $_userXp)');
    
    // Проверяем повышение уровня
    while (_userXp >= nextLevelXp) {
      _userLevel++;
      debugPrint('🎉 УРОВЕНЬ ПОВЫШЕН! Новый уровень: $_userLevel (было: $oldLevel)');
    }
    
    // Принудительно сохраняем XP сразу после начисления
    await _saveData();
    debugPrint('💾 XP СОХРАНЕН: $_userXp (уровень: $_userLevel)');
  }

  /// Получение достижения по ID
  Achievement? getAchievementById(String id) {
    try {
      return _achievements.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Сброс конкретного достижения (для тестирования)
  Future<void> resetAchievement(String id) async {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1) {
      final achievement = _achievements[index];
      _achievements[index] = achievement.copyWith(
        currentValue: 0,
        status: AchievementStatus.active,
        completedAt: null,
      );
      await _saveData();
      notifyListeners();
    }
  }

  /// 🎨 Синхронизация цветов и иконок с шаблонами
  Future<void> _syncAchievementsWithTemplates(int dailyNormML) async {
    debugPrint('🎨 СИНХРОНИЗАЦИЯ: Обновляем цвета и иконки достижений');
    
    final templates = DefaultAchievements.createForDailyNorm(dailyNormML);
    bool hasChanges = false;
    
    for (int i = 0; i < _achievements.length; i++) {
      final currentAchievement = _achievements[i];
      
      // Ищем соответствующий шаблон
      final template = templates.firstWhere(
        (t) => t.id == currentAchievement.id,
        orElse: () => currentAchievement, // если шаблон не найден, оставляем как есть
      );
      
      // Проверяем нужно ли обновление
      if (currentAchievement.color != template.color || 
          currentAchievement.icon != template.icon ||
          currentAchievement.title != template.title ||
          currentAchievement.description != template.description) {
        
        debugPrint('🎨 Обновляем "${currentAchievement.title}" - новый цвет: ${template.color}');
        
        // Обновляем только визуальные свойства, сохраняя прогресс
        _achievements[i] = currentAchievement.copyWith(
          title: template.title,
          description: template.description,
          icon: template.icon,
          color: template.color,
        );
        
        hasChanges = true;
      }
    }
    
    if (hasChanges) {
      await _saveData();
      debugPrint('🎨 СИНХРОНИЗАЦИЯ ЗАВЕРШЕНА: цвета и иконки обновлены');
    } else {
      debugPrint('🎨 СИНХРОНИЗАЦИЯ: обновления не требуются');
    }
  }

  /// Проверяет и восстанавливает пропущенный XP (только один раз)
  Future<void> _checkAndRecoverMissingXp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const xpRecoveryKey = 'achievements_xp_recovered';
      
      final isRecovered = prefs.getBool(xpRecoveryKey) ?? false;
      
      if (!isRecovered) {
        debugPrint('🎖️ ПЕРВЫЙ ЗАПУСК: Восстанавливаем XP за предыдущие дни');
        await recoverMissingXpFromHistory();
        
        // Отмечаем, что восстановление выполнено
        await prefs.setBool(xpRecoveryKey, true);
        debugPrint('🎖️ XP восстановлен и отмечен как завершенный');
      } else {
        debugPrint('🎖️ XP уже был восстановлен ранее');
      }
    } catch (e) {
      debugPrint('🚨 ОШИБКА проверки восстановления XP: $e');
    }
  }

  /// 🎖️ Восстановление пропущенного XP за предыдущие дни
  Future<void> recoverMissingXpFromHistory() async {
    try {
      debugPrint('🔍 ВОССТАНОВЛЕНИЕ XP: Анализируем историю потребления воды');
      
      final allIntakes = await StorageService.loadWaterIntakes();
      final dailyNormML = 2000; // базовая норма, будет обновлена из настроек
      
      // Группируем по дням
      final Map<String, List<WaterIntake>> dailyIntakes = {};
      for (final intake in allIntakes) {
        final dayKey = _dateToKey(intake.dateTime);
        dailyIntakes[dayKey] ??= [];
        dailyIntakes[dayKey]!.add(intake);
      }
      
      int recoveredXp = 0;
      final today = _dateToKey(DateTime.now());
      
      debugPrint('🔍 ВОССТАНОВЛЕНИЕ XP: Найдено ${dailyIntakes.length} дней с данными');
      
      // Анализируем каждый день (кроме сегодняшнего)
      for (final entry in dailyIntakes.entries) {
        final dayKey = entry.key;
        final intakes = entry.value;
        
        if (dayKey == today) continue; // Сегодняшний день не анализируем
        
        final dayTotal = intakes.fold<int>(0, (sum, intake) => sum + intake.volumeML);
        debugPrint('🔍 $dayKey: выпито ${dayTotal}мл');
        
        // Проверяем достижения за этот день
        int dayXp = 0;
        
        // Первый глоток (50 XP)
        if (dayTotal > 0) {
          dayXp += 50;
          debugPrint('  ✅ Первый глоток: +50 XP');
        }
        
        // На полпути к цели (100 XP)
        if (dayTotal >= dailyNormML * 0.5) {
          dayXp += 100;
          debugPrint('  ✅ На полпути: +100 XP');
        }
        
        // Мастер гидрации - дневная норма (250 XP)
        if (dayTotal >= dailyNormML) {
          dayXp += 250;
          debugPrint('  ✅ Мастер гидрации: +250 XP');
        }
        
        // Супер увлажнение - 120% нормы (350 XP)
        if (dayTotal >= dailyNormML * 1.2) {
          dayXp += 350;
          debugPrint('  ✅ Супер увлажнение: +350 XP');
        }
        
        recoveredXp += dayXp;
        debugPrint('  📊 XP за $dayKey: $dayXp');
      }
      
      if (recoveredXp > 0) {
        final oldXp = _userXp;
        _userXp += recoveredXp;
        
        // Проверяем повышение уровня
        while (_userXp >= nextLevelXp) {
          _userLevel++;
        }
        
        await _saveData();
        debugPrint('🎉 ВОССТАНОВЛЕНО XP: +$recoveredXp (было: $oldXp → стало: $_userXp)');
        debugPrint('🎉 Текущий уровень: $_userLevel');
        
        notifyListeners();
      } else {
        debugPrint('🔍 ВОССТАНОВЛЕНИЕ XP: Нет данных за предыдущие дни');
      }
      
    } catch (e) {
      debugPrint('🚨 ОШИБКА восстановления XP: $e');
    }
  }

  /// Сброс всех достижений с учетом дневной нормы
  Future<void> resetAllAchievements({int dailyNormML = 2000}) async {
    debugPrint('🔄 СБРОС ВСЕХ ДОСТИЖЕНИЙ для нормы $dailyNormML');
    await initialize(dailyNormML: dailyNormML, forceReset: true);
  }

  /// Загрузка данных из SharedPreferences
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Достижения
      final achievementsJson = prefs.getString(_achievementsKey);
      if (achievementsJson != null) {
        final List<dynamic> list = json.decode(achievementsJson);
        _achievements = list.map((item) => Achievement.fromJson(item)).toList();
      }
      
      // Пользовательские данные
      _userLevel = prefs.getInt(_userLevelKey) ?? 1;
      _userXp = prefs.getInt(_userXpKey) ?? 0;
      _currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      
      final lastGoalTimestamp = prefs.getInt(_lastGoalDateKey);
      _lastGoalDate = lastGoalTimestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastGoalTimestamp)
        : null;
    } catch (e) {
      debugPrint('Ошибка загрузки достижений: $e');
    }
  }

  /// Сохранение данных в SharedPreferences
  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Достижения
      final achievementsJson = json.encode(_achievements.map((a) => a.toJson()).toList());
      await prefs.setString(_achievementsKey, achievementsJson);
      
      // Пользовательские данные
      await prefs.setInt(_userLevelKey, _userLevel);
      await prefs.setInt(_userXpKey, _userXp);
      await prefs.setInt(_currentStreakKey, _currentStreak);
      
      if (_lastGoalDate != null) {
        await prefs.setInt(_lastGoalDateKey, _lastGoalDate!.millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint('Ошибка сохранения достижений: $e');
    }
  }

  /// Преобразование даты в строку для сравнения
  String _dateToKey(DateTime date) => '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
