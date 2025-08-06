import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/water_intake.dart';
import '../services/storage_service.dart';

const Color kBlue = Color(0xFF1976D2);
const Color kLightBlue = Color(0xFF64B5F6);
const Color kWhite = Colors.white;


class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<WaterIntake> _waterIntakes = [];
  bool _isLoading = true;
  // bool _isProUser = false; // Удалено: переменная _isProUser больше не нужна
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // final isPro = await StorageService.isProUser(); // Удалено: загрузка Pro-статуса больше не нужна
      final intakes = await StorageService.getWaterIntakesForDate(_selectedDate);
      
      print('Загружено записей для ${_selectedDate}: ${intakes.length}');
      for (final intake in intakes) {
        print('Запись: ${intake.volumeML} мл в ${intake.dateTime}');
      }
      
      setState(() {
        // _isProUser = isPro; // Удалено: _isProUser больше не используется
        _waterIntakes = intakes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadData();
    }
  }

  Future<void> _editIntake(WaterIntake intake) async {
    // if (!_isProUser) { // Удалено: проверка Pro-статуса больше не нужна
    //   _showProUpgradeDialog(); // Удалено: вызов диалога Pro-версии больше не нужен
    //   return;
    // }

    final TextEditingController amountController = TextEditingController(
      text: intake.volumeML.toString(),
    );

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать запись'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Количество (мл)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = int.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                Navigator.of(context).pop(amount);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _updateIntake(intake, result);
    }
  }

  Future<void> _updateIntake(WaterIntake intake, int newAmount) async {
    try {
      final updatedIntake = WaterIntake(
        id: intake.id,
        volumeML: newAmount,
        dateTime: intake.dateTime,
      );

      await StorageService.updateWaterIntake(updatedIntake);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись обновлена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка обновления: $e')),
        );
      }
    }
  }

  Future<void> _deleteIntake(WaterIntake intake) async {
    // if (!_isProUser) { // Удалено: проверка Pro-статуса больше не нужна
    //   _showProUpgradeDialog(); // Удалено: вызов диалога Pro-версии больше не нужен
    //   return;
    // }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись'),
        content: const Text('Вы уверены, что хотите удалить эту запись?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await StorageService.deleteWaterIntake(intake.id);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Запись удалена')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка удаления: $e')),
          );
        }
      }
    }
  }

  // void _showProUpgradeDialog() { // Удалено: метод _showProUpgradeDialog больше не нужен
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Pro функция'),
  //       content: const Text(
  //         'Редактирование и удаление записей доступно только в Pro версии.',
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.of(context).pop(),
  //           child: const Text('Отмена'),
  //         ),
  //         ElevatedButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //             // TODO: Открыть экран Pro
  //           },
  //           child: const Text('Обновить до Pro'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        title: const Text('История'),
        centerTitle: true,
        backgroundColor: kBlue,
        foregroundColor: kWhite,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final totalAmount = _waterIntakes.fold<int>(
      0,
      (sum, intake) => sum + intake.volumeML,
    );

    return Column(
      children: [
        // Заголовок с датой и общим количеством
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.transparent, // Изменено с kLightBlue.withOpacity(0.1)
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Всего: ${totalAmount} мл',
                      style: const TextStyle(
                        fontSize: 16,
                        color: kBlue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Список записей
        Expanded(
          child: _waterIntakes.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _waterIntakes.length,
                  itemBuilder: (context, index) {
                    final intake = _waterIntakes[index];
                    return _buildIntakeItem(intake);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                     Icon(
             Icons.water_drop_outlined,
             size: 64,
             color: kLightBlue,
           ),
          const SizedBox(height: 16),
                     Text(
             'Нет записей за ${_formatDate(_selectedDate)}',
             style: const TextStyle(
               fontSize: 18,
               color: kBlue,
               fontWeight: FontWeight.w500,
             ),
           ),
           const SizedBox(height: 8),
           Text(
             'Добавьте воду на главном экране',
             style: TextStyle(
               fontSize: 14,
               color: kBlue.withValues(alpha: 0.7),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildIntakeItem(WaterIntake intake) {
    return Dismissible(
      key: ValueKey(intake.id),
      background: Container(
        color: kBlue,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Row(
          children: [
            Icon(Icons.edit, color: kWhite),
            SizedBox(width: 8),
            Text('Редактировать', style: TextStyle(color: kWhite)),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Удалить', style: TextStyle(color: kWhite)),
            SizedBox(width: 8),
            Icon(Icons.delete, color: kWhite),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Свайп влево (удаление)
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Удалить запись'),
              content: const Text('Вы уверены, что хотите удалить эту запись?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Удалить'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await _deleteIntake(intake);
          }
          return false; // Не удаляем элемент сразу, т.к. _deleteIntake уже обновит список
        } else {
          // Свайп вправо (редактирование)
          await _editIntake(intake);
          return false; // Не удаляем элемент
        }
      },
      child: Card(
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0), // Карточки сделаны тоньше
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.water_drop, color: kBlue),
          ),
          title: Text('${intake.volumeML} мл'),
          subtitle: Text(_formatTime(intake.dateTime)),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selected = DateTime(date.year, date.month, date.day);

    if (selected == today) {
      return 'Сегодня';
    } else if (selected == yesterday) {
      return 'Вчера';
    } else {
      return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// Удалено: Дублирующийся класс HistoryScreen и _HistoryScreenState
// class HistoryScreen extends StatefulWidget {
//   const HistoryScreen({super.key});

//   @override
//   State<HistoryScreen> createState() => _HistoryScreenState();
// }

// class _HistoryScreenState extends State<HistoryScreen> {
//   // bool _isProUser = false; // Переменная для определения Pro-пользователя, закомментирована

//   @override
//   void initState() {
//     super.initState();
//     _loadProStatus();
//   }

//   // Загрузка статуса Pro-пользователя, закомментирована, так как функционал Pro не используется
//   void _loadProStatus() async {
//     // final userSettings = Provider.of<UserSettingsProvider>(context, listen: false).userSettings;
//     // setState(() {
//     //   _isProUser = userSettings.isProUser;
//     // });
//   }