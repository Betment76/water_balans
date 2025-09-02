# Настройка RuStore Billing

## Обзор

Этот документ описывает процесс настройки и интеграции RuStore Billing SDK в приложение Water Balance.

## Версии SDK

- **RuStore Billing SDK**: 10.0.0
- **Flutter Plugin**: flutter_rustore_billing ^10.0.0

## Конфигурация

### 1. Добавление зависимостей

#### pubspec.yaml
```yaml
dependencies:
  flutter_rustore_billing: ^10.0.0
```

#### android/build.gradle.kts
```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        // Добавляем репозиторий RuStore
        maven {
            url = uri("https://artifactory-external.vkpartner.ru/artifactory/maven")
        }
    }
}
```

#### android/app/build.gradle.kts
```kotlin
dependencies {
    implementation("ru.rustore.sdk:billing-client:10.0.0")
}
```

### 2. Настройка AndroidManifest.xml

Добавьте intent-filter для обработки deeplink от RuStore:

```
<!-- RuStore deeplink для платежей -->
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.example.water_balance.rustore"/>
</intent-filter>
```

### 3. Настройка MainActivity.kt

Добавьте обработку deeplink в MainActivity:

```kotlin
import ru.rustore.flutter.billing.RustoreBillingPlugin

// Переопределяем метод для обработки deeplink от RuStore
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    Log.d("RuStore", "Получен deeplink: ${intent.data}")
    // Передаем deeplink в RuStore Billing Plugin
    RustoreBillingPlugin.onNewIntent(intent)
}
```

## Конфигурационные файлы

### Создание конфигурационного файла

1. Скопируйте пример конфигурации:
```bash
cp lib/constants/rustore_config.sample.dart lib/constants/rustore_config.dart
```

2. Отредактируйте файл `lib/constants/rustore_config.dart` с вашими значениями:

```dart
/// Конфигурация RuStore Billing
class RuStoreConfig {
  /// Console Application ID из RuStore Console
  static const String consoleApplicationId = "2063647542";

  /// Application ID вашего приложения
  static const String applicationId = "com.example.water_balance";

  /// Product ID для отключения рекламы
  static const String removeAdsProductId = "water_balance_remove_ads_premium_2024";

  /// Deep Link Scheme для обработки платежей
  static const String deeplinkScheme = "com.example.water_balance.rustore://payment";

  /// Ключ для сохранения статуса покупки в SharedPreferences
  static const String adFreeStatusKey = "ad_free_purchased";
}
```

### Параметры RuStore Console

- **Console Application ID**: 2063647542
- **Application ID**: com.example.water_balance
- **Product ID**: water_balance_remove_ads_premium_2024
- **Deep Link Scheme**: com.example.water_balance.rustore://payment

## Использование

### Инициализация

```dart
await RustoreBillingService.initialize();
```

### Проверка доступности платежей

```dart
final available = await RustoreBillingService.isPaymentsAvailable();
```

### Покупка отключения рекламы

```dart
final success = await RustoreBillingService.purchaseRemoveAds();
```

### Восстановление покупок

```dart
await RustoreBillingService.restorePurchases();
```

### Проверка статуса покупки

```dart
final isAdFree = await RustoreBillingService.isAdFree();
```

## Тестирование

Для тестирования работы RuStore billing в процессе разработки можно использовать тестовые методы, которые были удалены из релизной версии приложения.

Во время разработки использовался класс `TestRustoreBilling` для диагностики интеграции:

```dart
await TestRustoreBilling.runAllTests();
```

Этот функционал был удален из релизной сборки для уменьшения размера приложения и повышения безопасности.

Для тестирования в процессе разработки рекомендуется:
1. Использовать отладочные сборки (debug builds)
2. Проверять логи через Android Studio или командную строку
3. Тестировать все функции покупок через интерфейс настроек

## Возможные ошибки

1. **Платежи недоступны**
   - Проверьте, установлен ли RuStore на устройстве
   - Убедитесь, что пользователь авторизован в RuStore
   - Проверьте настройки в RuStore Console

2. **Ошибка инициализации**
   - Проверьте правильность Console Application ID
   - Убедитесь, что deeplink схема совпадает с настройками в AndroidManifest.xml

3. **Ошибка покупки**
   - Проверьте, опубликован ли продукт в RuStore Console
   - Убедитесь, что приложение опубликовано в RuStore

## Обновление версий

Для обновления RuStore Billing SDK:

1. Обновите версию в pubspec.yaml
2. Обновите версию в android/app/build.gradle.kts
3. Проверьте совместимость API

## Ссылки

- [Документация RuStore Billing SDK](https://www.rustore.ru/help/developers/billing-sdk)
- [RuStore Console](https://console.rustore.ru/)