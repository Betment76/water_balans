# 💧 Водный баланс

Мобильное приложение для отслеживания потребления воды с интерактивным интерфейсом и умными напоминаниями.

## 🌟 Особенности

- **Интерактивная рыбка**: Анимация рыбки теперь зависит от процента выпитой воды.
- **Динамическая норма**: Дневная норма воды автоматически увеличивается в зависимости от вашей физической активности.
- **Виджет погоды**: На главном экране теперь отображается погода (иконка, температура и город).
- **Умные напоминания**: Настраиваемые уведомления.
- **Статистика потребления**: Графики и история.
- **Персонализация**: Настройка под ваши параметры.
- **Покупки RuStore**: Отключение рекламы через одноразовую покупку.

## 🚀 Установка

### Требования

- Flutter 3.0+
- Dart 3.0+
- Android Studio / VS Code

### Шаги установки

1. **Клонируйте репозиторий**
```bash
git clone https://github.com/Betment76/water_balans.git
cd water_balans
```

2. **Установите зависимости**
```bash
flutter pub get
```

3. **Запустите приложение**
```bash
flutter run
```

## 🏗️ Архитектура

### Структура проекта
```
lib/
├── constants/          # Константы приложения
├── l10n/              # Локализация
├── models/            # Модели данных
├── providers/         # Riverpod провайдеры
├── screens/           # Экраны приложения
├── services/          # Сервисы (хранилище, уведомления)
└── widgets/           # Переиспользуемые виджеты
```

### Технологии

- **Flutter** - UI фреймворк
- **Riverpod** - управление состоянием
- **SharedPreferences** - локальное хранение
- **Flutter Local Notifications** - уведомления
- **Sensors Plus** - датчики устройства
- **Geolocator** - определение местоположения
- **Geocoding** - преобразование координат в адрес
- **Fl Chart** - графики
- **RuStore Billing** - платежи и покупки
- **RuStore Review** - отзывы и рейтинги
- **MyTarget SDK** - реклама

## 💳 Настройка RuStore Billing

### Конфигурация

- **Console Application ID**: 2063647542
- **Application ID**: com.example.water_balance
- **Product ID**: water_balance_remove_ads_premium_2024
- **Deep Link Scheme**: com.example.water_balance.rustore://payment

### Интеграция

1. Добавьте зависимости в `pubspec.yaml`:
```yaml
dependencies:
  flutter_rustore_billing: ^10.0.0
```

2. Настройте репозитории в `android/build.gradle.kts`:
```kotlin
allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://artifactory-external.vkpartner.ru/artifactory/maven")
        }
    }
}
```

3. Добавьте зависимость SDK в `android/app/build.gradle.kts`:
```kotlin
dependencies {
    implementation("ru.rustore.sdk:billing-client:10.0.0")
}
```

4. Настройте deeplink в `AndroidManifest.xml`:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="com.example.water_balance.rustore"/>
</intent-filter>
```

5. Обработайте deeplink в `MainActivity.kt`:
```kotlin
override fun onNewIntent(intent: Intent) {
    super.onNewIntent(intent)
    RustoreBillingPlugin.onNewIntent(intent)
}
```

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробностей.