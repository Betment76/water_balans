import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../models/water_intake.dart';

/// Сервис для работы с локальным хранилищем (shared_preferences)
class StorageService {
  static const String _userSettingsKey = 'user_settings';
  static const String _waterIntakesKey = 'water_intakes';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _isProUserKey = 'is_pro_user';

  /// Сохранить настройки пользователя
  static Future<void> saveUserSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(settings.toJson());
    await prefs.setString(_userSettingsKey, jsonStr);
  }

  /// Загрузить настройки пользователя
  static Future<UserSettings?> loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userSettingsKey);
    if (jsonStr == null) return null;
    return UserSettings.fromJson(jsonDecode(jsonStr));
  }

  /// Сохранить историю воды
  static Future<void> saveWaterIntakes(List<WaterIntake> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = list.map((e) => e.toJson()).toList();
    await prefs.setString(_waterIntakesKey, jsonEncode(jsonList));
  }

  /// Загрузить историю воды
  static Future<List<WaterIntake>> loadWaterIntakes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_waterIntakesKey);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList.map((e) => WaterIntake.fromJson(e)).toList();
  }

  /// Проверить первый запуск
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  /// Установить флаг первого запуска
  static Future<void> setFirstLaunch(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, value);
  }

  /// Проверить Pro статус пользователя
  static Future<bool> isProUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isProUserKey) ?? false;
  }

  /// Установить Pro статус пользователя
  static Future<void> setProUser(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isProUserKey, value);
  }

  /// Получить записи воды за определенную дату
  static Future<List<WaterIntake>> getWaterIntakesForDate(DateTime date) async {
    final allIntakes = await loadWaterIntakes();
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    return allIntakes.where((intake) {
      return intake.dateTime.isAfter(startOfDay) && 
             intake.dateTime.isBefore(endOfDay);
    }).toList();
  }

  /// Обновить запись воды
  static Future<void> updateWaterIntake(WaterIntake intake) async {
    final allIntakes = await loadWaterIntakes();
    final index = allIntakes.indexWhere((item) => item.id == intake.id);
    
    if (index != -1) {
      allIntakes[index] = intake;
      await saveWaterIntakes(allIntakes);
    }
  }

  /// Удалить запись воды
  static Future<void> deleteWaterIntake(String id) async {
    final allIntakes = await loadWaterIntakes();
    allIntakes.removeWhere((item) => item.id == id);
    await saveWaterIntakes(allIntakes);
  }

  /// Очистить все данные приложения
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
} 