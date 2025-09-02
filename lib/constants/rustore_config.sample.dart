// Copy this file to `lib/constants/rustore_config.dart` and replace placeholder values.

/// Конфигурация RuStore Billing
class RuStoreConfig {
  /// Console Application ID из RuStore Console
  static const String consoleApplicationId = "YOUR_CONSOLE_APPLICATION_ID";

  /// Application ID вашего приложения
  static const String applicationId = "YOUR_APPLICATION_ID";

  /// Product ID для отключения рекламы
  static const String removeAdsProductId = "YOUR_REMOVE_ADS_PRODUCT_ID";

  /// Deep Link Scheme для обработки платежей
  static const String deeplinkScheme = "YOUR_SCHEME://payment";

  /// Ключ для сохранения статуса покупки в SharedPreferences
  static const String adFreeStatusKey = "ad_free_purchased";
}
