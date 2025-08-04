import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/user_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_settings_provider.dart';
import '../services/weather_service.dart';
import '../services/notification_service.dart';
import '../constants/app_colors.dart';

/// Экран настроек пользователя
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController weightController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController dailyNormController = TextEditingController();
  
  int activityLevel = 1;
  String selectedUnit = 'мл';
  bool _isProUser = false;

  String? _weightError;
  String? _heightError;
  String? _dailyNormError;
  double? _temperature;
  bool _isLoadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkProStatus();
    _fetchWeather();
  }

  /// Загрузить настройки из хранилища
  void _loadSettings() {
    final settings = ref.read(userSettingsProvider);
    if (settings != null) {
      weightController.text = settings.weight.toString();
      heightController.text = settings.height?.toString() ?? '';
             dailyNormController.text = settings.dailyNormML.toString();
       activityLevel = settings.activityLevel;
       selectedUnit = settings.unit;
    }
  }

  Future<void> _checkProStatus() async {
    final isPro = await StorageService.isProUser();
    setState(() {
      _isProUser = isPro;
    });
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });
    // Для примера — город Москва
    final temp = await WeatherService.fetchTemperatureByCity('Moscow');
    setState(() {
      _isLoadingWeather = false;
      if (temp != null) {
        _temperature = temp;
      } else {
        _weatherError = 'Ошибка загрузки погоды';
      }
    });
  }

  @override
  void dispose() {
    weightController.dispose();
    heightController.dispose();
    dailyNormController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    setState(() {
      _weightError = null;
      _heightError = null;
      _dailyNormError = null;
    });
    
    final weight = int.tryParse(weightController.text);
    final height = heightController.text.isNotEmpty ? int.tryParse(heightController.text) : null;
    final dailyNorm = int.tryParse(dailyNormController.text);
    
    if (weight == null || weight < 30 || weight > 200) {
      setState(() => _weightError = 'Введите вес от 30 до 200');
      return;
    }
    if (height != null && (height < 100 || height > 250)) {
      setState(() => _heightError = 'Рост от 100 до 250');
      return;
    }
    if (dailyNorm == null || dailyNorm < 500 || dailyNorm > 5000) {
      setState(() => _dailyNormError = 'Норма от 500 до 5000 мл');
      return;
    }
    
         final settings = UserSettings(
       weight: weight,
       height: height,
       activityLevel: activityLevel,
       dailyNormML: dailyNorm,
       isWeatherEnabled: true,
       notificationIntervalHours: 2,
       unit: selectedUnit,
     );
    
    ref.read(userSettingsProvider.notifier).save(settings);
    NotificationService.scheduleReminders(settings);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Настройки сохранены')),
    );
  }



  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс данных'),
        content: const Text(
          'Вы уверены, что хотите сбросить все данные? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StorageService.clearAllData();
        await NotificationService.cancelAllNotifications();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Данные сброшены')),
          );
          Navigator.of(context).pushReplacementNamed('/');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка сброса: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kWhite,
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: true,
        backgroundColor: kBlue,
        foregroundColor: AppColors.kWhite,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Основные настройки
          _buildSection(
            title: 'Основные настройки',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: weightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Вес (кг)',
                        errorText: _weightError,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Рост (см)',
                        errorText: _heightError,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: dailyNormController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Норма (мл)',
                        errorText: _dailyNormError,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Укажите ваши параметры для расчета суточной нормы воды',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
                             const SizedBox(height: 16),
               const Text('Уровень активности'),
               const SizedBox(height: 8),
               Row(
                 children: [
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.only(right: 4),
                       child: ElevatedButton(
                         onPressed: () => setState(() => activityLevel = 0),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: activityLevel == 0 ? kBlue : Colors.grey.shade200,
                           foregroundColor: activityLevel == 0 ? Colors.white : Colors.black87,
                           elevation: activityLevel == 0 ? 2 : 0,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: const Text('Низкий'),
                       ),
                     ),
                   ),
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 4),
                       child: ElevatedButton(
                         onPressed: () => setState(() => activityLevel = 1),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: activityLevel == 1 ? kBlue : Colors.grey.shade200,
                           foregroundColor: activityLevel == 1 ? Colors.white : Colors.black87,
                           elevation: activityLevel == 1 ? 2 : 0,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: const Text('Средний'),
                       ),
                     ),
                   ),
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.only(left: 4),
                       child: ElevatedButton(
                         onPressed: () => setState(() => activityLevel = 2),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: activityLevel == 2 ? kBlue : Colors.grey.shade200,
                           foregroundColor: activityLevel == 2 ? Colors.white : Colors.black87,
                           elevation: activityLevel == 2 ? 2 : 0,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: const Text('Высокий'),
                       ),
                     ),
                   ),
                 ],
               ),
            ],
          ),
          
          const SizedBox(height: 24),
          
                     // Единицы измерения
           _buildSection(
             title: 'Единицы измерения',
             children: [
               Row(
                 children: [
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.only(right: 4),
                       child: ElevatedButton(
                         onPressed: () => setState(() => selectedUnit = 'мл'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: selectedUnit == 'мл' ? kBlue : Colors.grey.shade200,
                           foregroundColor: selectedUnit == 'мл' ? Colors.white : Colors.black87,
                           elevation: selectedUnit == 'мл' ? 2 : 0,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: const Text('мл'),
                       ),
                     ),
                   ),
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.symmetric(horizontal: 4),
                       child: ElevatedButton(
                         onPressed: () => setState(() => selectedUnit = 'л'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: selectedUnit == 'л' ? kBlue : Colors.grey.shade200,
                           foregroundColor: selectedUnit == 'л' ? Colors.white : Colors.black87,
                           elevation: selectedUnit == 'л' ? 2 : 0,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: const Text('л'),
                       ),
                     ),
                   ),
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.only(left: 4),
                       child: ElevatedButton(
                         onPressed: () => setState(() => selectedUnit = 'oz'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: selectedUnit == 'oz' ? kBlue : Colors.grey.shade200,
                           foregroundColor: selectedUnit == 'oz' ? Colors.white : Colors.black87,
                           elevation: selectedUnit == 'oz' ? 2 : 0,
                           shape: RoundedRectangleBorder(
                             borderRadius: BorderRadius.circular(8),
                           ),
                         ),
                         child: const Text('oz'),
                       ),
                     ),
                   ),
                 ],
               ),
             ],
           ),
          

          
                     // Погода
           _buildSection(
             title: 'Погода',
             children: [
               Row(
                 children: [
                   const Icon(Icons.wb_sunny, color: Colors.orange),
                   const SizedBox(width: 8),
                   _isLoadingWeather
                     ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                     : _weatherError != null
                       ? Text(_weatherError!, style: const TextStyle(color: Colors.red))
                       : Text(_temperature != null ? 'Температура: ${_temperature!.toStringAsFixed(1)}°C' : 'Нет данных'),
                   IconButton(
                     icon: const Icon(Icons.refresh),
                     tooltip: 'Обновить погоду',
                     onPressed: _isLoadingWeather ? null : _fetchWeather,
                   ),
                 ],
               ),
             ],
           ),
          
          const SizedBox(height: 24),
          
          // Pro функции
          _buildProSection(),
          
          const SizedBox(height: 24),
          
          // Опасная зона
          _buildSection(
            title: 'Опасная зона',
            children: [
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('Сбросить все данные'),
                subtitle: const Text('Удалить все настройки и историю'),
                onTap: _resetData,
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Сохранить настройки'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: kBlue,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  /// Секция Pro функций
  Widget _buildProSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Pro функции',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_isProUser) ...[
          // Pro функции для Pro пользователей
          Container(
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.verified,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pro версия активна',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Вам доступны все функции:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildProFeature('Расширенная статистика'),
                  _buildProFeature('Кастомные уведомления'),
                  _buildProFeature('Редактирование истории'),
                  _buildProFeature('Экспорт данных'),
                  _buildProFeature('Тёмная тема'),
                ],
              ),
            ),
          ),
        ] else ...[
          // Pro функции для обычных пользователей
          Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.star,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Обновите до Pro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Получите доступ к расширенным функциям:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  _buildProFeature('Расширенная статистика'),
                  _buildProFeature('Кастомные уведомления'),
                  _buildProFeature('Редактирование истории'),
                  _buildProFeature('Экспорт данных'),
                  _buildProFeature('Тёмная тема'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _purchasePro,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Купить Pro'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _restorePurchase,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Восстановить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Отображение Pro функции
  Widget _buildProFeature(String feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            _isProUser ? Icons.check_circle : Icons.lock,
            color: _isProUser ? Colors.green : Colors.grey,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            feature,
            style: TextStyle(
              fontSize: 14,
              color: _isProUser ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  /// Покупка Pro версии
  Future<void> _purchasePro() async {
    try {
      // TODO: Интеграция с платежной системой RuStore
      // Пока что просто симулируем покупку
      await Future.delayed(const Duration(seconds: 2));
      
      await StorageService.setProUser(true);
      
      setState(() {
        _isProUser = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pro версия активирована!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка покупки: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Восстановление покупки
  Future<void> _restorePurchase() async {
    try {
      // TODO: Проверка покупки через RuStore
      await Future.delayed(const Duration(seconds: 1));
      
      // Симулируем восстановление
      final isPro = await StorageService.isProUser();
      
      setState(() {
        _isProUser = isPro;
      });

      if (mounted) {
        if (isPro) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pro версия восстановлена!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pro покупка не найдена'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка восстановления: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

const Color kBlue = Color(0xFF1976D2);
