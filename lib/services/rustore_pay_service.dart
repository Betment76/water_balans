import 'package:flutter_rustore_pay/api/flutter_rustore_pay_client.dart';
import 'package:flutter_rustore_pay/model/purchase_availability.dart';
import 'package:flutter_rustore_pay/model/product.dart';
import 'package:flutter_rustore_pay/model/purchase.dart';
import 'package:flutter_rustore_pay/model/user_authorization_status.dart';
import 'package:flutter_rustore_pay/model/ru_store_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/rustore_config.dart';

/// Сервис для работы с платежами RuStore через новый Pay SDK
///
/// СТАТУС ПЛАТЕЖЕЙ: АКТИВИРОВАН ✅
/// =============================
/// Реальная конфигурация RuStore:
/// - Console Application ID: 2063647542
/// - Application ID: com.example.water_balance
/// - Product ID: water_balance_remove_ads_premium_2024
/// - Deep Link Scheme: com.example.water_balance.rustore://payment
///
/// RuStore Pay SDK 10.0.0 АКТИВИРОВАН согласно документации:
/// ✅ Зависимость flutter_rustore_pay: ^10.0.0 подключена
/// ✅ Deep link схема настроена в AndroidManifest.xml
/// ✅ MainActivity.kt настроена для обработки deep links
/// ✅ Товар создан в RuStore Console и опубликован
class RustorePayService {
  static const String _consoleApplicationId =
      RuStoreConfig.consoleApplicationId;
  static const String _deeplinkScheme = RuStoreConfig.deeplinkScheme;
  static const String _applicationId = RuStoreConfig.applicationId;
  static const String _removeAdsProductId = RuStoreConfig.removeAdsProductId;
  static const String _adFreeStatusKey = RuStoreConfig.adFreeStatusKey;

  static bool _isInitialized = false;

  /// Инициализация RuStore Pay SDK
  static Future<bool> initialize() async {
    // В новом Pay SDK инициализация происходит автоматически через AndroidManifest.xml
    _isInitialized = true;
    print(
      'RuStore Pay SDK успешно инициализирован с ID: $_consoleApplicationId',
    );
    print('Товар для покупки: $_removeAdsProductId');
    return true;
  }

  /// Проверка доступности платежей
  static Future<bool> isPaymentsAvailable() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Проверяем, установлен ли RuStore на устройстве
      try {
        final isInstalled = await RuStorePayClient.instance.ruStoreUtils
            .isRuStoreInstalled();
        if (!isInstalled) {
          print('RuStore не установлен на устройстве');
          return false;
        }
        print('RuStore установлен на устройстве');
      } catch (e) {
        print('Ошибка проверки установки RuStore: $e');
      }

      // Проверяем статус авторизации пользователя
      try {
        final authStatus = await RuStorePayClient.instance.userInteractor
            .getUserAuthorizationStatus();
        print('Статус авторизации: $authStatus');

        // Дополнительная проверка авторизации
        if (authStatus.toString() == 'UserAuthorizationStatus.unauthorized') {
          print('Пользователь не авторизован в RuStore');
          print('Пожалуйста, откройте приложение RuStore и войдите в аккаунт');
        }
      } catch (e) {
        print('Ошибка проверки статуса авторизации: $e');
      }

      // Проверка доступности платежей
      print('Проверка доступности платежей RuStore...');
      print('Console Application ID: $_consoleApplicationId');
      print('Application ID: $_applicationId');
      print('Deep Link Scheme: $_deeplinkScheme');
      print('Product ID: $_removeAdsProductId');

      final result = await RuStorePayClient.instance.purchaseInteractor
          .getPurchaseAvailability();

      if (result is Available) {
        print('Платежи RuStore доступны');
        return true;
      } else if (result is Unavailable) {
        print('Платежи недоступны: ${result.errorMessage}');
        print('Возможные причины:');
        print('1. Приложение не опубликовано в RuStore Console');
        print('2. Покупки не включены для приложения');
        print('3. Продукт не опубликован');
        print('4. Неправильная конфигурация deep link');
        print('5. Приложение заблокировано в RuStore');
        print('6. Пользователь заблокирован в RuStore');
        print('7. Проблемы с подключением к серверу RuStore');
        print('\nПроверьте настройки в RuStore Console:');
        print('- Application ID: $_applicationId');
        print('- Console Application ID: $_consoleApplicationId');
        print('- Product ID: $_removeAdsProductId');
        print('- Deep Link Scheme: $_deeplinkScheme');
        return false;
      }

      print('Статус платежей неизвестен');
      return false;
    } catch (e) {
      print('Ошибка проверки доступности платежей: $e');
      return false;
    }
  }

  /// Покупка отключения рекламы
  static Future<bool> purchaseRemoveAds() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      print('Попытка покупки товара: $_removeAdsProductId');

      // Покупка продукта
      final result = await RuStorePayClient.instance.purchaseInteractor
          .purchase(_removeAdsProductId);

      // Обработка результата покупки
      if (result.purchaseId != null) {
        await _saveAdFreeStatus(true);
        print(
          'Покупка отключения рекламы выполнена успешно. ID покупки: ${result.purchaseId}',
        );
        return true;
      } else {
        print('Ошибка покупки RuStore: Не удалось получить ID покупки');
        return false;
      }
    } catch (e) {
      print('Ошибка при покупке отключения рекламы: $e');
      return false;
    }
  }

  /// Проверка, куплено ли отключение рекламы
  static Future<bool> isAdFree() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_adFreeStatusKey) ?? false;
    } catch (e) {
      print('Ошибка проверки статуса без рекламы: $e');
      return false;
    }
  }

  /// Сохранение статуса покупки отключения рекламы
  static Future<void> _saveAdFreeStatus(bool isAdFree) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adFreeStatusKey, isAdFree);
    } catch (e) {
      print('Ошибка сохранения статуса без рекламы: $e');
    }
  }

  /// Восстановление покупок (проверка существующих покупок)
  static Future<void> restorePurchases() async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      // Получаем список покупок пользователя
      final purchases = await RuStorePayClient.instance.purchaseInteractor
          .getPurchases();

      // Проверяем, есть ли среди покупок наш продукт
      bool hasValidPurchase = false;
      for (var purchase in purchases) {
        // Проверяем, является ли покупка ProductPurchase
        if (purchase is ProductPurchase &&
            purchase.productId == _removeAdsProductId) {
          hasValidPurchase = true;
          break;
        }
      }

      await _saveAdFreeStatus(hasValidPurchase);
      if (hasValidPurchase) {
        print('Восстановление покупок выполнено. Найдена активная покупка.');
      } else {
        print('Восстановление покупок выполнено. Активных покупок не найдено.');
      }
    } catch (e) {
      print('Ошибка восстановления покупок: $e');
    }
  }

  /// Получение информации о статусе интеграции
  static Map<String, String> getIntegrationInfo() {
    return {
      'consoleApplicationId': _consoleApplicationId,
      'applicationId': _applicationId,
      'productId': _removeAdsProductId,
      'deeplinkScheme': _deeplinkScheme,
    };
  }
}
