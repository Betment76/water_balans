import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/achievement.dart';
import '../services/achievements_service.dart';
import '../providers/achievements_provider.dart';
import '../providers/user_settings_provider.dart';

/// Экран достижений с красивыми карточками и анимациями
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  bool _hasInitialized = false; // 🎯 Флаг для предотвращения повторной инициализации

  @override
  void initState() {
    super.initState();
    
    // 🚀 СТРОГАЯ однократная автосинхронизация ТОЛЬКО при создании экрана
    if (!_hasInitialized) {
      _hasInitialized = true;
      
             WidgetsBinding.instance.addPostFrameCallback((_) async {
               if (mounted) { // Проверяем, что виджет еще существует
                 final userSettings = ref.read(userSettingsProvider);
                 final dailyNormML = userSettings?.dailyNormML ?? 2000;
                 final service = ref.read(achievementsServiceProvider);
                 
                debugPrint('🎯 СТРОГАЯ ОДНОКРАТНАЯ АВТОСИНХРОНИЗАЦИЯ: Обновление данных достижений');
                await service.initialize(dailyNormML: dailyNormML, forceReset: false);
                
                // 🎖️ XP накапливается автоматически при выполнении достижений
                debugPrint('🎖️ XP не пересчитываем - сохраняем накопленный прогресс: ${service.userXp} XP');
               }
             });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 Упрощенная загрузка без повторных вызовов
    final service = ref.watch(achievementsServiceProvider);
    final userSettings = ref.watch(userSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Достижения', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        // 🚀 Автоматическая синхронизация - без ручных кнопок
        actions: const [],
      ),
      body: _buildContent(context, service),
    );
  }

  Widget _buildContent(BuildContext context, AchievementsService service) {
    // 🚀 Показываем загрузку, если достижения еще не готовы
    if (service.achievements.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1976D2), Color(0xFF64B5F6), Colors.white],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 60), // 📺 Отступ под глобальный MyTarget баннер
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text('🧹 Обновляем данные достижений...', 
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Text('Исправляем проблемы с отслеживанием!', 
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
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
          // 📺 Отступ под глобальный MyTarget баннер
          const SizedBox(height: 76),
          
          // 👤 ФИКСИРОВАННАЯ карточка "Мастер гидрации"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildUserCard(service),
          ),
          
          const SizedBox(height: 20),
          
          // 📊 СКРОЛЛИРУЕМЫЙ контент
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Быстрая статистика
                  _buildStatsRow(service),
                  const SizedBox(height: 20),
                  
                  // Группировка достижений по типам
                  _buildAchievementsByType('🎯 Ежедневные', AchievementType.daily, service),
                  _buildAchievementsByType('🔥 Серии дней', AchievementType.streak, service),
                  _buildAchievementsByType('🌊 По объему', AchievementType.volume, service),
                  _buildAchievementsByType('⏰ Привычки', AchievementType.habit, service),
                  
                  const SizedBox(height: 100), // отступ для красоты
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Карточка пользователя с уровнем и XP
  Widget _buildUserCard(AchievementsService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Иконка и уровень
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Мастер гидрации', 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Уровень ${service.userLevel}', 
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14)),
                ],
              ),
              const Spacer(),
              Text('${service.userXp} XP', 
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Прогресс-бар до следующего уровня
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('До уровня ${service.userLevel + 1}', 
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                  Text('${service.nextLevelXp - (service.userXp % service.nextLevelXp)} XP', 
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: service.levelProgress,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Быстрая статистика в строке
  Widget _buildStatsRow(AchievementsService service) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Выполнено', '${service.completedAchievements.length}', Icons.emoji_events, Colors.amber)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Активные', '${service.activeAchievements.length}', Icons.trending_up, Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('Серия дней', '${service.currentStreak}', Icons.local_fire_department, Colors.red)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  /// Группа достижений по типу
  Widget _buildAchievementsByType(String title, AchievementType type, AchievementsService service) {
    final achievements = service.achievements.where((a) => a.type == type).toList();
    if (achievements.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        ...achievements.map((achievement) => _buildAchievementCard(achievement)),
      ],
    );
  }

  /// Карточка отдельного достижения
  Widget _buildAchievementCard(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          gradient: achievement.isCompleted
            ? LinearGradient(colors: [achievement.color.withOpacity(0.3), Colors.white])
            : const LinearGradient(colors: [Colors.white, Colors.white]),
          borderRadius: BorderRadius.circular(20),
          border: achievement.isCompleted 
            ? Border.all(color: achievement.color, width: 2)
            : Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: achievement.isCompleted 
                ? achievement.color.withOpacity(0.3)
                : Colors.black.withOpacity(0.1),
              blurRadius: achievement.isCompleted ? 15 : 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Заголовок с иконкой
              Row(
                children: [
                  // Иконка достижения
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: achievement.color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(achievement.icon, color: achievement.color, size: 24),
                  ),
                  const SizedBox(width: 15),
                  
                  // Название и описание
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(achievement.title, 
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(achievement.description, 
                          style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  
                  // 🎖️ XP и статус в правом верхнем углу
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${achievement.reward} XP', 
                        style: TextStyle(color: achievement.color, fontSize: 14, fontWeight: FontWeight.bold)),
                      
                      if (achievement.isCompleted) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: achievement.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('✓', 
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              
              // Прогресс-бар (если не завершено)
              if (!achievement.isCompleted) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${achievement.currentValue}/${achievement.targetValue}', 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('${(achievement.progress * 100).toInt()}%', 
                      style: TextStyle(color: achievement.color, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: achievement.progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(achievement.color),
                  minHeight: 8,
                ),
              ] else ...[
                // Дата завершения
                if (achievement.completedAt != null)
                  Text('Выполнено ${_formatDate(achievement.completedAt!)}', 
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Форматирование даты
  String _formatDate(DateTime date) {
    final months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн',
                   'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
