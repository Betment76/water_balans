import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// Сервис резервного копирования, адаптированный из проекта "давление old"
class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const String _lastBackupFileNameKey = 'last_backup_file_name';
  static const String _lastBackupFilePathKey = 'last_backup_file_path';

  /// Создать резервную копию и сохранить в выбранный пользователем файл (перезаписывает)
  Future<String?> createBackupToFile() async {
    // Готовим данные из SharedPreferences как JSON
    final json = await StorageService.exportAllToJson();

    // Предлагаем имя вида water_balance_backup_YYYY-MM-DD_HH-MM.json
    final now = DateTime.now();
    final name = 'water_balance_backup_${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}_${now.hour.toString().padLeft(2,'0')}-${now.minute.toString().padLeft(2,'0')}.json';

    final prefs = await SharedPreferences.getInstance();
    String? lastPath = prefs.getString(_lastBackupFilePathKey);

    // Если ранее выбран путь и файл — перезапишем без выбора
    if (lastPath != null && lastPath.isNotEmpty && await File(lastPath).parent.exists()) {
      final file = File(lastPath);
      await file.writeAsString(json);
      await _remember(file.path);
      await StorageService.setString('cloud_last_sync', now.toIso8601String());
      return file.path;
    }

    // Иначе открываем диалог выбора папки (по умолчанию "Документы"/app docs)
    String? dirPath;
    try {
      dirPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Выберите папку для сохранения резервной копии',
      );
    } catch (_) {
      dirPath = null; // если платформенная реализация отсутствует
    }
    dirPath ??= (await getApplicationDocumentsDirectory()).path;

    final filePath = '$dirPath/$name';
    final file = File(filePath);
    await file.writeAsString(json);
    await _remember(file.path);
    await StorageService.setString('cloud_last_sync', now.toIso8601String());
    return file.path;
  }

  /// Восстановить данные из выбранного JSON файла
  Future<String?> restoreFromBackupFile() async {
    dynamic result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Выберите файл резервной копии',
      );
    } catch (_) {
      result = null; // нет реализации — вернемся без восстановления
    }
    if (result == null || result.files.isEmpty) return null;
    final path = result.files.single.path;
    if (path == null) return null;
    final jsonString = await File(path).readAsString();
    await StorageService.importAllFromJson(jsonString);
    await _remember(path);
    return path;
  }

  Future<void> _remember(String fullPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastBackupFileNameKey, fullPath.split('/').last);
    await prefs.setString(_lastBackupFilePathKey, fullPath);
  }
}


