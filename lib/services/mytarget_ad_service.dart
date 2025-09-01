import 'package:flutter/services.dart';

/// Сервис для работы с MyTarget рекламой
class MyTargetAdService {
  static const MethodChannel _channel = MethodChannel('mytarget_ads');
  static bool _isInitialized = false;

  /// Инициализация MyTarget SDK
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
      print('MyTarget SDK инициализирован успешно');
    } catch (e) {
      print('Ошибка инициализации MyTarget SDK: $e');
    }
  }

  /// Создать и показать баннер 320x50
  static Future<void> showBanner(int slotId) async {
    try {
      await _channel.invokeMethod('showBanner', {
        'slotId': slotId,
        'width': 320,
        'height': 50,
      });
      print('MyTarget баннер показан: slotId=$slotId');
    } catch (e) {
      print('Ошибка показа MyTarget баннера: $e');
    }
  }

  /// Скрыть баннер
  static Future<void> hideBanner() async {
    try {
      await _channel.invokeMethod('hideBanner');
      print('MyTarget баннер скрыт');
    } catch (e) {
      print('Ошибка скрытия MyTarget баннера: $e');
    }
  }

  /// Проверить статус рекламы
  static Future<bool> isAdAvailable() async {
    try {
      final result = await _channel.invokeMethod('isAdAvailable');
      return result ?? false;
    } catch (e) {
      print('Ошибка проверки доступности рекламы: $e');
      return false;
    }
  }
}
