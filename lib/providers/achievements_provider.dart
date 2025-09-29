import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/achievements_service.dart';
import '../models/achievement.dart';
import 'user_settings_provider.dart';

/// Провайдер сервиса достижений для управления состоянием
final achievementsServiceProvider = ChangeNotifierProvider<AchievementsService>((ref) {
  final service = AchievementsService();
  
  // 🚀 Инициализация с учетом дневной нормы пользователя
  Future.microtask(() async {
    final userSettings = ref.read(userSettingsProvider);
    final dailyNormML = userSettings?.dailyNormML ?? 2000;
    
    // 🎯 Обычная инициализация (очистку делаем по кнопке)
    await service.initialize(dailyNormML: dailyNormML, forceReset: false);
  });
  
  return service;
});

/// Провайдер списка всех достижений
final allAchievementsProvider = Provider<List<Achievement>>((ref) {
  final service = ref.watch(achievementsServiceProvider);
  return service.achievements;
});

/// Провайдер выполненных достижений
final completedAchievementsProvider = Provider<List<Achievement>>((ref) {
  final service = ref.watch(achievementsServiceProvider);
  return service.completedAchievements;
});

/// Провайдер активных достижений
final activeAchievementsProvider = Provider<List<Achievement>>((ref) {
  final service = ref.watch(achievementsServiceProvider);
  return service.activeAchievements;
});

/// Провайдер данных пользователя (уровень, XP)
final userStatsProvider = Provider<Map<String, int>>((ref) {
  final service = ref.watch(achievementsServiceProvider);
  return {
    'level': service.userLevel,
    'xp': service.userXp,
    'streak': service.currentStreak,
    'nextLevelXp': service.nextLevelXp,
  };
});
