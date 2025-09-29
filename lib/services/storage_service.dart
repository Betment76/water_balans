import 'dart:convert';
import 'dart:io';
// import 'package:path_provider/path_provider.dart'; // Временно отключаем из-за проблем с репозиторием
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_settings.dart';
import '../models/water_intake.dart';

/// Сервис для работы с локальным хранилищем (shared_preferences)
class StorageService {
  static const String _userSettingsKey = 'user_settings';
  static const String _waterIntakesKey = 'water_intakes';
  static const String _isFirstLaunchKey = 'is_first_launch';
  static const String _isProUserKey = 'is_pro_user';
  
  // 🚀 КЭШИРОВАНИЕ для оптимизации производительности
  static List<WaterIntake>? _cachedWaterIntakes;
  static DateTime? _cacheTime;
  static const Duration _cacheTimeout = Duration(minutes: 5); // Кэш на 5 минут

  /// Сохранить настройки пользователя
  static Future<void> saveUserSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(settings.toJson());
    await prefs.setString(_userSettingsKey, jsonStr);

    // Временно отключаем сохранение в файл из-за проблем с path_provider
    // await _saveBackupToFile('user_settings_backup.json', settings.toJson());
    print('Настройки пользователя сохранены в SharedPreferences');
  }

  /// Загрузить настройки пользователя
  static Future<UserSettings?> loadUserSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_userSettingsKey);

    if (jsonStr != null) {
      print('Настройки пользователя загружены из SharedPreferences: $jsonStr');
      return UserSettings.fromJson(jsonDecode(jsonStr));
    }

    // Временно отключаем загрузку из файла из-за проблем с path_provider
    /*
    // Если в SharedPreferences нет данных, проверяем резервный файл
    print(
      'Настройки пользователя не найдены в SharedPreferences, проверяем резервный файл...',
    );
    final backupData = await _loadBackupFromFile('user_settings_backup.json');

    if (backupData != null) {
      print('Настройки восстановлены из резервного файла!');
      final settings = UserSettings.fromJson(backupData);
      // Сохраняем обратно в SharedPreferences
      await saveUserSettings(settings);
      return settings;
    }
    */

    print('Настройки пользователя не найдены в SharedPreferences');
    return null;
  }

  /// Сохранить историю воды
  static Future<void> saveWaterIntakes(List<WaterIntake> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = list.map((e) => e.toJson()).toList();
    await prefs.setString(_waterIntakesKey, jsonEncode(jsonList));

    // 🚀 ОБНОВЛЯЕМ КЭШ при сохранении новых данных
    _cachedWaterIntakes = List.from(list);
    _cacheTime = DateTime.now();

    // Временно отключаем сохранение в файл из-за проблем с path_provider
    // await _saveBackupToFile('water_intakes_backup.json', {'intakes': jsonList});
    print('История воды сохранена в SharedPreferences');
  }

  /// Загрузить историю воды (с кэшированием!)
  static Future<List<WaterIntake>> loadWaterIntakes() async {
    // 🚀 ПРОВЕРЯЕМ КЭШ перед загрузкой из SharedPreferences
    if (_cachedWaterIntakes != null && _cacheTime != null) {
      final now = DateTime.now();
      if (now.difference(_cacheTime!) < _cacheTimeout) {
        print('📊 История воды загружена из КЭША (${_cachedWaterIntakes!.length} записей)');
        return List.from(_cachedWaterIntakes!);
      }
    }

    // 💾 Загружаем из SharedPreferences если кэш устарел или отсутствует
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_waterIntakesKey);

    if (jsonStr != null) {
      print('💾 История воды загружена из SharedPreferences');
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      final waterIntakes = jsonList.map((e) => WaterIntake.fromJson(e)).toList();
      
      // 🚀 СОХРАНЯЕМ В КЭШ
      _cachedWaterIntakes = List.from(waterIntakes);
      _cacheTime = DateTime.now();
      
      return waterIntakes;
    }

    // Временно отключаем загрузку из файла из-за проблем с path_provider
    /*
    // Если в SharedPreferences нет данных, проверяем резервный файл
    print(
      'История воды не найдена в SharedPreferences, проверяем резервный файл...',
    );
    final backupData = await _loadBackupFromFile('water_intakes_backup.json');

    if (backupData != null && backupData['intakes'] != null) {
      print('История воды восстановлена из резервного файла!');
      final List<dynamic> jsonList = backupData['intakes'];
      final intakes = jsonList.map((e) => WaterIntake.fromJson(e)).toList();
      // Сохраняем обратно в SharedPreferences
      await saveWaterIntakes(intakes);
      return intakes;
    }
    */

    print('История воды не найдена');
    return [];
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
      await saveWaterIntakes(allIntakes); // Автоматически обновит кэш
    }
  }

  /// Удалить запись воды
  static Future<void> deleteWaterIntake(String id) async {
    final allIntakes = await loadWaterIntakes();
    allIntakes.removeWhere((item) => item.id == id);
    await saveWaterIntakes(allIntakes); // Автоматически обновит кэш
  }

  /// Очистить все данные приложения
  static Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // 🚀 ОЧИЩАЕМ КЭШ при полной очистке
    _cachedWaterIntakes = null;
    _cacheTime = null;
  }

  /// Показать все сохраненные ключи (для отладки)
  static Future<void> debugShowAllKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    print('Все сохраненные ключи: $keys');
    for (final key in keys) {
      final value = prefs.get(key);
      print('$key: $value');
    }
  }

  /*
  /// Получить путь к файлу резервной копии настроек
  static Future<File> _getBackupFile(String filename) async {
    // Пробуем использовать внешнее хранилище, которое не очищается при переустановке
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final backupDir = Directory('${directory.path}/water_balance_backup');
        if (!await backupDir.exists()) {
          await backupDir.create(recursive: true);
        }
        return File('${backupDir.path}/$filename');
      }
    } catch (e) {
      print('Ошибка доступа к внешнему хранилищу: $e');
    }

    // Fallback к Documents директории
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  /// Сохранить данные в файл как резервную копию
  static Future<void> _saveBackupToFile(
    String filename,
    Map<String, dynamic> data,
  ) async {
    try {
      final file = await _getBackupFile(filename);
      await file.writeAsString(jsonEncode(data));
      print('Резервная копия сохранена: ${file.path}');
    } catch (e) {
      print('Ошибка сохранения резервной копии: $e');
    }
  }

  /// Загрузить данные из файла резервной копии
  static Future<Map<String, dynamic>?> _loadBackupFromFile(
    String filename,
  ) async {
    try {
      final file = await _getBackupFile(filename);
      if (await file.exists()) {
        final content = await file.readAsString();
        print('Резервная копия найдена: ${file.path}');
        return jsonDecode(content);
      }
    } catch (e) {
      print('Ошибка загрузки резервной копии: $e');
    }
    return null;
  }
  */
}
