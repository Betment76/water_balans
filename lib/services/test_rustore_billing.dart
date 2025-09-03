import 'package:water_balance/services/rustore_pay_service.dart';

/// Тестовый класс для проверки работы RuStore Pay сервиса
class TestRustoreBilling {
  /// Тест инициализации RuStore billing
  static Future<void> testInitialization() async {
    print('=== ТЕСТ ИНИЦИАЛИЗАЦИИ RUSTORE BILLING ===');

    final result = await RustorePayService.initialize();
    print('Результат инициализации: $result');

    if (result) {
      print('✅ Инициализация RuStore billing прошла успешно');
    } else {
      print('❌ Ошибка инициализации RuStore billing');
    }
  }

  /// Тест проверки доступности платежей
  static Future<void> testPaymentsAvailability() async {
    print('\n=== ТЕСТ ДОСТУПНОСТИ ПЛАТЕЖЕЙ ===');

    final result = await RustorePayService.isPaymentsAvailable();
    print('Платежи доступны: $result');

    if (result) {
      print('✅ Платежи RuStore доступны');
    } else {
      print('❌ Платежи RuStore недоступны');
    }
  }

  /// Тест проверки статуса покупки
  static Future<void> testAdFreeStatus() async {
    print('\n=== ТЕСТ СТАТУСА ПОКУПКИ ===');

    final result = await RustorePayService.isAdFree();
    print('Статус без рекламы: $result');

    if (result) {
      print('✅ Приложение куплено (без рекламы)');
    } else {
      print('❌ Приложение не куплено (с рекламой)');
    }
  }

  /// Тест восстановления покупок
  static Future<void> testRestorePurchases() async {
    print('\n=== ТЕСТ ВОССТАНОВЛЕНИЯ ПОКУПОК ===');

    await RustorePayService.restorePurchases();
    print('Восстановление покупок завершено');
  }

  /// Тест получения информации об интеграции
  static void testIntegrationInfo() {
    print('\n=== ИНФОРМАЦИЯ ОБ ИНТЕГРАЦИИ ===');

    final info = RustorePayService.getIntegrationInfo();
    info.forEach((key, value) {
      print('$key: $value');
    });
  }

  /// Полный тест RuStore billing
  static Future<void> runAllTests() async {
    print('ЗАПУСК ВСЕХ ТЕСТОВ RUSTORE BILLING');
    print('=' * 50);

    // Тест инициализации
    await testInitialization();

    // Тест доступности платежей
    await testPaymentsAvailability();

    // Тест статуса покупки
    await testAdFreeStatus();

    // Тест восстановления покупок
    await testRestorePurchases();

    // Тест информации об интеграции
    testIntegrationInfo();

    print('\n' + '=' * 50);
    print('ВСЕ ТЕСТЫ ЗАВЕРШЕНЫ');
  }
}
