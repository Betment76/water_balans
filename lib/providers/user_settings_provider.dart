import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_settings.dart';
import '../services/storage_service.dart';

/// StateNotifier для управления состоянием настроек пользователя
class UserSettingsNotifier extends StateNotifier<UserSettings?> {
  UserSettingsNotifier() : super(null) {
    _load();
  }

  /// Загрузить настройки из хранилища
  Future<void> _load() async {
    state = await StorageService.loadUserSettings();
  }

  /// Сохранить и обновить настройки
  Future<void> save(UserSettings settings) async {
    await StorageService.saveUserSettings(settings);
    state = settings;
  }
}

/// Провайдер для доступа к состоянию настроек пользователя
final userSettingsProvider = StateNotifierProvider<UserSettingsNotifier, UserSettings?>((ref) {
  return UserSettingsNotifier();
}); 