# Скрипт автоматической настройки RuStore Billing для Windows
# Использование: .\scripts\setup_rustore_billing.ps1

Write-Host "Настройка RuStore Billing..."

# Проверяем, существует ли файл конфигурации
if (!(Test-Path "lib/constants/rustore_config.dart")) {
    Write-Host "Создание файла конфигурации RuStore..."
    Copy-Item "lib/constants/rustore_config.sample.dart" -Destination "lib/constants/rustore_config.dart"
    Write-Host "Файл конфигурации создан. Пожалуйста, отредактируйте lib/constants/rustore_config.dart"
} else {
    Write-Host "Файл конфигурации уже существует"
}

# Обновляем зависимости Flutter
Write-Host "Обновление зависимостей Flutter..."
flutter pub get

# Проверяем версии RuStore пакетов
Write-Host "Проверка версий RuStore пакетов..."
flutter pub deps | Select-String "rustore"

Write-Host "Настройка RuStore Billing завершена!"
Write-Host "Не забудьте:"
Write-Host "1. Отредактировать lib/constants/rustore_config.dart с вашими значениями"
Write-Host "2. Проверить настройки в RuStore Console"
Write-Host "3. Протестировать интеграцию"