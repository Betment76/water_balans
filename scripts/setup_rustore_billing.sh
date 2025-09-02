#!/bin/bash

# Скрипт автоматической настройки RuStore Billing
# Использование: ./scripts/setup_rustore_billing.sh

echo "Настройка RuStore Billing..."

# Проверяем, существует ли файл конфигурации
if [ ! -f "lib/constants/rustore_config.dart" ]; then
    echo "Создание файла конфигурации RuStore..."
    cp lib/constants/rustore_config.sample.dart lib/constants/rustore_config.dart
    echo "Файл конфигурации создан. Пожалуйста, отредактируйте lib/constants/rustore_config.dart"
else
    echo "Файл конфигурации уже существует"
fi

# Обновляем зависимости Flutter
echo "Обновление зависимостей Flutter..."
flutter pub get

# Проверяем версии RuStore пакетов
echo "Проверка версий RuStore пакетов..."
flutter pub deps | grep rustore

echo "Настройка RuStore Billing завершена!"
echo "Не забудьте:"
echo "1. Отредактировать lib/constants/rustore_config.dart с вашими значениями"
echo "2. Проверить настройки в RuStore Console"
echo "3. Протестировать интеграцию"